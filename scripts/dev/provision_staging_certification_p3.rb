#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "openssl"
require "securerandom"
require "uri"
require "yaml"

WORKSPACE_ID = ENV.fetch("SF_RENDER_WORKSPACE_ID", "tea-d7uhka9kh4rs73a7k080")
ENVIRONMENT_ID = ENV.fetch("SF_RENDER_ENVIRONMENT_ID", "evm-d9f68mos116c738bmf60")
DATABASE_ID = ENV.fetch("SF_RENDER_DATABASE_ID", "dpg-d9f68vn7f7vs73c0tal0-a")
REPOSITORY = ENV.fetch("SF_RENDER_REPOSITORY", "https://github.com/entap11/SF")
DEPLOY_BRANCH = ENV.fetch("SF_RENDER_DEPLOY_BRANCH", "deploy/staging-cert-baseline-20260720")
REGION = ENV.fetch("SF_RENDER_REGION", "oregon")
PLAN = ENV.fetch("SF_RENDER_SERVICE_PLAN", "starter")
API_ROOT = URI("https://api.render.com/v1/")

RANK_ROLE = "sf_cert_rank_runtime"
VS_ROLE = "sf_cert_vs_runtime"

def abort_with(message)
  warn("P3_PROVISION_ERROR: #{message}")
  exit(1)
end

def render_token
  config_path = File.expand_path("~/.render/cli.yaml")
  config = YAML.safe_load(File.read(config_path))
  token = config.dig("api", "key").to_s
  abort_with("Render CLI token is unavailable; run render login") if token.empty?
  token
rescue Errno::ENOENT, Psych::Exception
  abort_with("Render CLI configuration is unavailable; run render login")
end

def api_request(token, method, path, payload = nil)
  uri = API_ROOT + path.sub(%r{\A/}, "")
  request_class = {
    get: Net::HTTP::Get,
    post: Net::HTTP::Post,
    patch: Net::HTTP::Patch,
    put: Net::HTTP::Put
  }.fetch(method)
  request = request_class.new(uri)
  request["Accept"] = "application/json"
  request["Authorization"] = "Bearer #{token}"
  if payload
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload)
  end
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  unless response.code.to_i.between?(200, 299)
    abort_with("Render API #{method.to_s.upcase} #{uri.path} returned HTTP #{response.code}; response body suppressed")
  end
  response.body.to_s.empty? ? {} : JSON.parse(response.body)
rescue JSON::ParserError
  abort_with("Render API #{method.to_s.upcase} #{uri.path} returned invalid JSON")
end

def postgres_details
  stdout, stderr, status = Open3.capture3(
    "render", "postgres", "get", DATABASE_ID,
    "--include-sensitive-connection-info", "--output", "json"
  )
  abort_with("Render CLI could not retrieve certification PostgreSQL details: #{stderr.lines.first.to_s.strip}") unless status.success?
  JSON.parse(stdout).fetch("data")
rescue JSON::ParserError, KeyError
  abort_with("Render CLI returned malformed certification PostgreSQL details")
end

def psql_command(connection_url, sql)
  uri = URI(connection_url)
  env = { "PGPASSWORD" => URI.decode_www_form_component(uri.password.to_s) }
  args = [
    "/usr/local/opt/libpq/bin/psql", "--no-psqlrc", "--set", "ON_ERROR_STOP=1",
    "--host", uri.host, "--port", (uri.port || 5432).to_s,
    "--username", URI.decode_www_form_component(uri.user.to_s),
    "--dbname", uri.path.sub(%r{\A/}, "")
  ]
  stdout, _stderr, status = Open3.capture3(env, *args, stdin_data: sql)
  abort_with("PostgreSQL role/grant operation failed; database output suppressed") unless status.success?
  stdout
end

def sql_literal(value)
  "'#{value.gsub("'", "''")}'"
end

def provision_database_roles(owner_url, database_name, rank_password, vs_password)
  sql = <<~SQL
    DO $roles$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '#{RANK_ROLE}') THEN
        ALTER ROLE #{RANK_ROLE} LOGIN PASSWORD #{sql_literal(rank_password)};
      ELSE
        CREATE ROLE #{RANK_ROLE} LOGIN PASSWORD #{sql_literal(rank_password)};
      END IF;
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '#{VS_ROLE}') THEN
        ALTER ROLE #{VS_ROLE} LOGIN PASSWORD #{sql_literal(vs_password)};
      ELSE
        CREATE ROLE #{VS_ROLE} LOGIN PASSWORD #{sql_literal(vs_password)};
      END IF;
    END
    $roles$;
    GRANT CONNECT ON DATABASE "#{database_name.gsub('"', '""')}" TO #{RANK_ROLE}, #{VS_ROLE};
    GRANT USAGE ON SCHEMA public TO #{RANK_ROLE}, #{VS_ROLE};
    GRANT CREATE ON SCHEMA public TO #{RANK_ROLE};
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE schema_migrations TO #{RANK_ROLE}, #{VS_ROLE};
    GRANT USAGE, SELECT ON SEQUENCE schema_migrations_id_seq TO #{RANK_ROLE}, #{VS_ROLE};
    DO $grants$
    DECLARE
      item RECORD;
    BEGIN
      FOR item IN
        SELECT schemaname, tablename FROM pg_tables
        WHERE schemaname = 'public' AND (tablename LIKE 'rank\_%' ESCAPE '\\' OR tablename LIKE 'entap\_%' ESCAPE '\\')
      LOOP
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I.%I TO #{RANK_ROLE}', item.schemaname, item.tablename);
      END LOOP;
      FOR item IN
        SELECT sequence_schema, sequence_name FROM information_schema.sequences
        WHERE sequence_schema = 'public' AND (sequence_name LIKE 'rank\_%' ESCAPE '\\' OR sequence_name LIKE 'entap\_%' ESCAPE '\\')
      LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I.%I TO #{RANK_ROLE}', item.sequence_schema, item.sequence_name);
      END LOOP;
      FOR item IN
        SELECT schemaname, tablename FROM pg_tables
        WHERE schemaname = 'public' AND tablename LIKE 'vs\_%' ESCAPE '\\'
      LOOP
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I.%I TO #{VS_ROLE}', item.schemaname, item.tablename);
      END LOOP;
      FOR item IN
        SELECT sequence_schema, sequence_name FROM information_schema.sequences
        WHERE sequence_schema = 'public' AND sequence_name LIKE 'vs\_%' ESCAPE '\\'
      LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I.%I TO #{VS_ROLE}', item.sequence_schema, item.sequence_name);
      END LOOP;
    END
    $grants$;
  SQL
  psql_command(owner_url, sql)
end

def role_url(connection_url, role, password)
  uri = URI(connection_url)
  uri.user = role
  uri.password = password
  uri.to_s
end

def test_database_role(connection_url, expected_prefix)
  query = <<~SQL
    SELECT CASE WHEN bool_and(has_table_privilege(current_user, quote_ident(schemaname) || '.' || quote_ident(tablename), 'SELECT'))
      THEN '#{expected_prefix}_role_ok' ELSE '#{expected_prefix}_role_missing_grant' END
    FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '#{expected_prefix}\_%' ESCAPE '\\';
  SQL
  output = psql_command(connection_url, query)
  abort_with("#{expected_prefix} runtime database role failed its bounded grant check") unless output.include?("#{expected_prefix}_role_ok")
end

def key_pair
  key = OpenSSL::PKey::EC.generate("prime256v1")
  private_pem = key.to_pem
  public_pem, stderr, status = Open3.capture3("openssl", "ec", "-pubout", stdin_data: private_pem)
  abort_with("could not derive an ES256 public key: #{stderr.lines.last.to_s.strip}") unless status.success?
  [private_pem, public_pem]
end

def secret
  SecureRandom.urlsafe_base64(48, false)
end

def env_vars(hash)
  hash.map { |key, value| { key: key, value: value.to_s } }
end

def native_details(build_command:, start_command:, health_path: nil)
  details = {
    runtime: "node",
    plan: PLAN,
    region: REGION,
    numInstances: 1,
    maxShutdownDelaySeconds: 60,
    envSpecificDetails: {
      buildCommand: build_command,
      startCommand: start_command
    }
  }
  details[:healthCheckPath] = health_path if health_path
  details
end

def create_service(token, type:, name:, root_dir:, environment:, details:)
  payload = {
    type: type,
    name: name,
    ownerId: WORKSPACE_ID,
    repo: REPOSITORY,
    autoDeploy: "no",
    branch: DEPLOY_BRANCH,
    rootDir: root_dir,
    environmentId: ENVIRONMENT_ID,
    envVars: env_vars(environment),
    serviceDetails: details
  }
  result = api_request(token, :post, "/services", payload)
  service = result.fetch("service")
  {
    id: service.fetch("id"),
    name: service.fetch("name"),
    url: service.dig("serviceDetails", "url").to_s,
    deploy_id: result.fetch("deployId")
  }
rescue KeyError
  abort_with("Render create-service response omitted required identifiers for #{name}")
end

def wait_for_deploy(token, service)
  terminal = %w[live deactivated build_failed update_failed canceled pre_deploy_failed]
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1_800
  last_status = nil
  loop do
    deploy = api_request(token, :get, "/services/#{service[:id]}/deploys/#{service[:deploy_id]}")
    status = deploy.fetch("status")
    if status != last_status
      puts("P3_DEPLOY_STATUS service=#{service[:name]} deploy=#{service[:deploy_id]} status=#{status}")
      last_status = status
    end
    abort_with("initial deploy failed for #{service[:name]} with status #{status}") if terminal.include?(status) && status != "live"
    return if status == "live"
    abort_with("timed out waiting for #{service[:name]} initial deploy") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep(10)
  end
end

def main
  abort_with("set SF_P3_PROVISION_CONFIRM=CREATE_ISOLATED_CERT_SERVICES") unless ENV["SF_P3_PROVISION_CONFIRM"] == "CREATE_ISOLATED_CERT_SERVICES"

  token = render_token
  existing = api_request(token, :get, "/services?ownerId=#{WORKSPACE_ID}&limit=100")
  target_names = %w[swarmfront-cert-rank swarmfront-cert-vs swarmfront-cert-authority]
  existing_names = existing.map { |entry| entry.dig("service", "name") }.compact
  conflicts = target_names & existing_names
  abort_with("target services already exist: #{conflicts.join(',')}; refusing to rotate database credentials") unless conflicts.empty?

  postgres = postgres_details
  owner_external_url = postgres.dig("connectionInfo", "externalConnectionString").to_s
  internal_url = postgres.dig("connectionInfo", "internalConnectionString").to_s
  database_name = postgres.fetch("databaseName")
  abort_with("certification PostgreSQL connection data is incomplete") if owner_external_url.empty? || internal_url.empty?

  rank_db_password = secret
  vs_db_password = secret
  provision_database_roles(owner_external_url, database_name, rank_db_password, vs_db_password)
  rank_external_url = role_url(owner_external_url, RANK_ROLE, rank_db_password)
  vs_external_url = role_url(owner_external_url, VS_ROLE, vs_db_password)
  test_database_role(rank_external_url, "rank")
  test_database_role(vs_external_url, "vs")
  rank_database_url = role_url(internal_url, RANK_ROLE, rank_db_password)
  vs_database_url = role_url(internal_url, VS_ROLE, vs_db_password)
  puts("P3_DATABASE_ROLES status=ready roles=#{RANK_ROLE},#{VS_ROLE} credentials=redacted")

  player_private, player_public = key_pair
  service_private, service_public = key_pair
  verifier_private, verifier_public = key_pair
  api_token = secret
  admin_token = secret
  spectator_admin_token = secret
  match_authority_token = secret
  worker_token = secret
  contest_grant_secret = secret
  worker_build_id = "authority-worker-1beb355"
  verifier_key_id = "sf-cert-verifier-20260720"

  rank_environment = {
    "NODE_ENV" => "production",
    "BIND_HOST" => "0.0.0.0",
    "DATABASE_URL" => rank_database_url,
    "RANK_API_TOKEN" => api_token,
    "RANK_ECONOMY_MUTATIONS_ENABLED" => "false",
    "RANK_ECONOMY_RESET_ENABLED" => "false",
    "RANK_VERIFIED_MATCH_MUTATIONS_ENABLED" => "false",
    "RANK_PUBLIC_LEADERBOARDS_ENABLED" => "false",
    "RANK_ENABLE_DEBUG_ACTIONS" => "false",
    "RANK_ENFORCE_CANONICAL_PLAYER_IDS" => "true",
    "ENTAP_PLAYER_TOKEN_ISSUER" => "entap-identity-cert",
    "ENTAP_PLAYER_TOKEN_AUDIENCE" => "swarmfront-vs-cert",
    "ENTAP_PLAYER_TOKEN_KEY_ID" => "entap-player-cert-20260720",
    "ENTAP_PLAYER_TOKEN_PRIVATE_KEY_PEM" => player_private,
    "ENTAP_PLAYER_TOKEN_PUBLIC_KEY_PEM" => player_public,
    "RANK_SERVICE_TOKEN_ISSUER" => "swarmfront-vs-cert",
    "RANK_SERVICE_TOKEN_AUDIENCE" => "swarmfront-rank-cert",
    "RANK_SERVICE_TOKEN_SUBJECT" => "vs-settlement-worker-cert",
    "RANK_SERVICE_TOKEN_KEY_ID" => "vs-rank-cert-20260720",
    "RANK_SERVICE_TOKEN_PUBLIC_KEY_PEM" => service_public,
    "RANK_VERIFIER_KEY_ID" => verifier_key_id,
    "RANK_VERIFIER_PUBLIC_KEY_PEM" => verifier_public,
    "RANK_VERIFIER_WORKER_BUILD_ID" => worker_build_id,
    "RANK_VERIFIER_RECEIPT_MAX_AGE_SEC" => "3600"
  }

  rank = create_service(
    token,
    type: "web_service",
    name: "swarmfront-cert-rank",
    root_dir: "tools/rank-service",
    environment: rank_environment,
    details: native_details(
      build_command: "npm ci --include=dev && npm run build",
      start_command: "npm start",
      health_path: "/health"
    )
  )
  abort_with("Rank service URL is unavailable") if rank[:url].empty?
  puts("P3_SERVICE_CREATED role=rank id=#{rank[:id]} deploy=#{rank[:deploy_id]} auto_deploy=no secrets=redacted")

  false_flags = %w[
    VS_ECONOMY_MUTATIONS_ENABLED VS_ECONOMY_RESET_ENABLED
    VS_DURABLE_CORE_ENABLED VS_DURABLE_PUBLIC_1V1_ENABLED
    VS_AUTHENTICATED_1V1_SLICE_ENABLED VS_MATCH_VERIFICATION_ENABLED
    VS_ENABLE_PUBLIC_1V1 VS_ENABLE_PUBLIC_2V2 VS_ENABLE_PUBLIC_3P_FFA
    VS_ENABLE_PUBLIC_4P_FFA VS_ENABLE_PUBLIC_CTF VS_ENABLE_PUBLIC_HCTF
    VS_ENABLE_PUBLIC_CRUCIBLE VS_ENABLE_CRUCIBLE_WAX_SETTLEMENT
    VS_HCTF_LIVE_SECRECY_CERTIFIED VS_ENABLE_CTF_BOT_FALLBACK
    VS_ENABLE_RANK_MUTATIONS VS_ENABLE_PUBLIC_LEADERBOARDS
    VS_ENABLE_PUBLIC_CONTESTS VS_ENABLE_PUBLIC_TIME_PUZZLES
    VS_ENABLE_PUBLIC_GAUNTLET VS_ENABLE_PUBLIC_ASYNC_3MAP
    VS_ENABLE_PUBLIC_ASYNC_5MAP VS_ENABLE_CONTEST_REWARDS
    VS_ENABLE_REMOTE_OPS_CONFIG VS_SPECTATOR_ENABLED VS_SPECTATOR_DEV_OPEN
    VS_SPECTATOR_LIVE_ENABLED VS_SPECTATOR_PUBLIC_ENABLED
  ].to_h { |key| [key, "false"] }

  vs_environment = {
    "NODE_ENV" => "production",
    "BIND_HOST" => "0.0.0.0",
    "VS_PRODUCTION_MODE" => "true",
    "VS_CORS_ENABLED" => "false",
    "VS_DURABLE_STORE" => "postgres",
    "VS_DATABASE_URL" => vs_database_url,
    "VS_OPS_RECONCILE_INTERVAL_MS" => "0",
    "VS_ADMIN_TOKEN" => admin_token,
    "VS_SPECTATOR_ADMIN_TOKEN" => spectator_admin_token,
    "VS_MATCH_AUTHORITY_TOKEN" => match_authority_token,
    "VS_VERIFIER_WORKER_TOKEN" => worker_token,
    "VS_PUBLIC_CONTEST_GRANT_SECRET" => contest_grant_secret,
    "VS_PLAYER_TOKEN_ISSUER" => "entap-identity-cert",
    "VS_PLAYER_TOKEN_AUDIENCE" => "swarmfront-vs-cert",
    "VS_PLAYER_TOKEN_KEY_ID" => "entap-player-cert-20260720",
    "VS_PLAYER_TOKEN_PUBLIC_KEY_PEM" => player_public,
    "VS_RANK_SERVICE_URL" => rank[:url],
    "VS_RANK_SERVICE_TOKEN_ISSUER" => "swarmfront-vs-cert",
    "VS_RANK_SERVICE_TOKEN_AUDIENCE" => "swarmfront-rank-cert",
    "VS_RANK_SERVICE_TOKEN_SUBJECT" => "vs-settlement-worker-cert",
    "VS_RANK_SERVICE_TOKEN_KEY_ID" => "vs-rank-cert-20260720",
    "VS_RANK_SERVICE_TOKEN_PRIVATE_KEY_PEM" => service_private,
    "VS_VERIFIER_KEY_ID" => verifier_key_id,
    "VS_VERIFIER_PUBLIC_KEY_PEM" => verifier_public,
    "VS_VERIFIER_WORKER_BUILD_ID" => worker_build_id,
    "VS_PUBLIC_1V1_MINIMUM_CLIENT_BUILD" => "2026071701",
    "VS_PUBLIC_1V1_SIM_BUILD_ID" => "sf-sim-1beb355",
    "VS_PUBLIC_1V1_RULESET_ID" => "standard-v1",
    "VS_PUBLIC_1V1_RULESET_HASH" => "d7a78887b71c7d010db1b8ea1af84aa847ca877644878f6c3a0d96aed26aa57c",
    "VS_PUBLIC_1V1_MAP_ID" => "MAP_closequarters__CQ2__1p",
    "VS_PUBLIC_1V1_MAP_HASH" => "325e97a6677eb32e2f396fa9077b614c76a2150dad960243e8ae00b55909d14a"
  }.merge(false_flags)

  vs = create_service(
    token,
    type: "web_service",
    name: "swarmfront-cert-vs",
    root_dir: "tools/vs-service",
    environment: vs_environment,
    details: native_details(
      build_command: "npm ci --include=dev && npm run build",
      start_command: "npm start",
      health_path: "/health"
    )
  )
  abort_with("VS service URL is unavailable") if vs[:url].empty?
  puts("P3_SERVICE_CREATED role=vs id=#{vs[:id]} deploy=#{vs[:deploy_id]} auto_deploy=no secrets=redacted")

  authority_environment = {
    "NODE_ENV" => "production",
    "VS_BASE_URL" => "#{vs[:url]}/v1",
    "VS_VERIFIER_WORKER_TOKEN" => worker_token,
    "MATCH_AUTHORITY_WORKER_ID" => "sf-cert-authority-1",
    "MATCH_AUTHORITY_WORKER_BUILD_ID" => worker_build_id,
    "MATCH_AUTHORITY_VERIFIER_KEY_ID" => verifier_key_id,
    "MATCH_AUTHORITY_VERIFIER_PRIVATE_KEY_PEM" => verifier_private,
    "MATCH_AUTHORITY_ARTIFACT_MANIFEST" => "./cert-artifact-manifest.json",
    "MATCH_AUTHORITY_GODOT_BIN" => "godot",
    "MATCH_AUTHORITY_POLL_MS" => "60000",
    "MATCH_AUTHORITY_REPLAY_TIMEOUT_MS" => "120000",
    "MATCH_AUTHORITY_RUN_ONCE" => "false"
  }

  authority = create_service(
    token,
    type: "background_worker",
    name: "swarmfront-cert-authority",
    root_dir: "tools/match-authority",
    environment: authority_environment,
    details: native_details(
      build_command: "npm ci --include=dev && npm run build",
      start_command: "npm start"
    )
  )
  puts("P3_SERVICE_CREATED role=authority id=#{authority[:id]} deploy=#{authority[:deploy_id]} auto_deploy=no ingress=none secrets=redacted")

  [rank, vs, authority].each { |service| wait_for_deploy(token, service) }
  puts("P3_PROVISION_COMPLETE branch=#{DEPLOY_BRANCH} services=#{[rank, vs, authority].map { |service| service[:id] }.join(',')} secrets=redacted")
end

main
