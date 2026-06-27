# Beta Ops Config Runbook

Swarmfront beta uses one ops config layer for feature flags, MOTD/maintenance, version gating, ad mode, beta service gates, analytics, and match-affecting tuning.

## Files

- Bundled defaults: `res://data/ops/ops_config_defaults.json`
- Static remote sample: `res://data/ops/ops_config_remote_sample.json`
- Runtime autoload: `res://scripts/state/ops_config.gd`
- Analytics queue autoload: `res://scripts/state/analytics_client.gd`
- Support payload UI: `res://scenes/ui/SupportDiagnosticsPanel.tscn`
- Ops console view: `res://scenes/ops/ops_console.tscn`

## Remote URL

Set the static JSON URL through either:

- Environment: `SF_OPS_CONFIG_URL`
- Project setting: `swarmfront/ops_config/remote_url`

For local validation, use:

```sh
godot --headless --path . --script res://tools/ops_config_sample_validate_smoke_test.gd
```

## Config Source Values

- `bundled_default`: no remote URL configured; using bundled defaults.
- `remote_fresh`: valid remote/static JSON loaded and cached.
- `remote_cached`: remote fetch failed or malformed, valid cache loaded.
- `malformed_fallback`: remote was fetched but did not validate, no valid cache.
- `fetch_failed_fallback`: remote fetch failed, no valid cache.

The active source, version, and hash are visible in support diagnostics and the Ops Config tab.

## Fail-Closed Defaults

- `paid_entries=false`
- `honey_rewards=false`
- `observer_mode=false`
- `rank_backend=false`
- `rank_local_beta_fallback=true`
- `external_ads=false`
- `house_ads=true`
- `maintenance_mode=false` unless loaded config is valid
- `force_update=false` unless loaded config is valid

## Determinism Rule

Runtime simulation code must never read `OpsConfig` directly. Any match-affecting value must be copied into `config_snapshot` before launch and included in telemetry as `config_version`, `config_hash`, and `config_source`.

Both `match_start` and `match_end_summary` analytics events must include the same config provenance fields.

Guard:

```sh
godot --headless --path . --script res://tools/ops_config_no_runtime_sim_access_smoke_test.gd
```

## Smoke Commands

Run the full beta ops gate:

```sh
scripts/dev/run_beta_ops_gate.sh
```

Include it in release readiness:

```sh
scripts/dev/run_release_readiness_gate.sh --include-beta-ops
```

Individual smokes:

```sh
godot --headless --path . --script res://tools/beta_ops_runtime_parse_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_fetch_success_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_fetch_fail_fallback_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_malformed_fallback_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_force_update_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_maintenance_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_sample_validate_smoke_test.gd
godot --headless --path . --script res://tools/honey_rewards_ops_gate_smoke_test.gd
godot --headless --path . --script res://tools/config_snapshot_determinism_smoke_test.gd
godot --headless --path . --script res://tools/ops_config_no_runtime_sim_access_smoke_test.gd
godot --headless --path . --script res://tools/analytics_client_queue_smoke_test.gd
godot --headless --path . --script res://tools/analytics_auto_flush_smoke_test.gd
godot --headless --path . --script res://tools/analytics_match_config_contract_smoke_test.gd
godot --headless --path . --script res://tools/support_diagnostics_payload_smoke_test.gd
godot --headless --path . --script res://tools/ops_console_config_tab_smoke_test.gd
```
