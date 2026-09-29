// Build the complete certified worker/simulation pair, independently of main's game source.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const pin = JSON.parse(fs.readFileSync(new URL('./certified-release.json', import.meta.url), 'utf8'));
const output = path.join(root, '.authority');
const project = path.join(output, 'release');
const manifestPath = path.join(output, 'cert-manifest.json');
const godot = path.join(output, 'godot');
const worker = path.join(project, 'tools/match-authority');
const run = (command, args, options = {}) => execFileSync(command, args, {
  cwd: root, stdio: 'inherit', timeout: 10 * 60_000, ...options,
});
const capture = (command, args, options = {}) => run(command, args, {
  ...options, stdio: ['ignore', 'pipe', 'inherit'], encoding: 'utf8',
}).trim();
function verifyHash(file, expected) {
  const actual = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  assert.equal(actual, expected, `SHA-256 mismatch: ${file}`);
}

assert.equal(process.platform, 'linux', 'The certified Render build requires Linux x86_64');
assert.equal(process.arch, 'x64', 'The certified Render build requires Linux x86_64');
// Reject incompatible runtime settings before replacing any build outputs.
for (const [key, expected] of Object.entries({
  MATCH_AUTHORITY_WORKER_BUILD_ID: pin.worker_build_id,
  MATCH_AUTHORITY_ARTIFACT_MANIFEST: manifestPath,
  MATCH_AUTHORITY_GODOT_BIN: godot,
})) {
  if (process.env[key]) assert.equal(process.env[key], expected, `${key} differs from the certified release`);
}

fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, '.gdignore'), '');
// A failed rebuild must not leave an apparently valid old manifest behind.
fs.rmSync(manifestPath, { force: true });
fs.rmSync(path.join(output, 'build-receipt.json'), { force: true });
fs.rmSync(project, { recursive: true, force: true });
fs.mkdirSync(project);
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'sf-certified-build-'));
try {
  // A dedicated fetch also works in Render's shallow checkout. No branch or tag is needed.
  const source = path.join(temporary, 'source.git');
  run('git', ['init', '--bare', '--quiet', source]);
  run('git', ['--git-dir', source, 'fetch', '--quiet', '--depth=1', pin.repository, pin.commit]);
  assert.equal(capture('git', ['--git-dir', source, 'rev-parse', 'FETCH_HEAD']), pin.commit);
  assert.equal(capture('git', ['--git-dir', source, 'rev-parse', `${pin.commit}^{tree}`]), pin.tree);
  const archive = path.join(temporary, 'source.tar');
  run('git', ['--git-dir', source, 'archive', '--format=tar', `--output=${archive}`, pin.commit]);
  run('tar', ['-xf', archive, '-C', project]);
  // The extracted tree contains neither a Git checkout nor credentials.
  for (const artifacts of [pin.map_artifacts, pin.ruleset_artifacts]) {
    for (const [hash, relative] of Object.entries(artifacts)) verifyHash(path.join(project, relative), hash);
  }

  // Bootstrap the pinned project's global classes before headless import, as in its certification.
  function walk(directory) {
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) return entry.name.startsWith('.') || entry.name === 'node_modules' ? [] : walk(file);
      return entry.isFile() && file.endsWith('.gd') ? [file] : [];
    });
  }
  const classes = [];
  for (const file of walk(project).sort()) {
    const text = fs.readFileSync(file, 'utf8');
    const name = text.match(/^class_name\s+([A-Za-z_]\w*)/m)?.[1];
    if (!name) continue;
    let base = text.match(/^extends\s+(.+)$/m)?.[1];
    const seen = new Set();
    while (base?.startsWith('"')) {
      const parent = base.slice(1, -1).replace(/^res:\/\//, '');
      assert(!seen.has(parent), `Cyclic extends: ${file}`);
      seen.add(parent);
      base = fs.readFileSync(path.join(project, parent), 'utf8').match(/^extends\s+(.+)$/m)?.[1];
    }
    assert(base, `Missing base class: ${file}`);
    classes.push({ name, base, resource: `res://${path.relative(project, file)}` });
  }
  assert.equal(classes.length, pin.godot_class_count, 'Certified class registry changed');
  assert.equal(new Set(classes.map((entry) => entry.name)).size, classes.length, 'Duplicate Godot classes');
  classes.sort((a, b) => a.name.localeCompare(b.name));
  fs.mkdirSync(path.join(project, '.godot'));
  const registry = classes.map(({ name, base, resource }) => `{
"base": &${JSON.stringify(base)},
"class": &${JSON.stringify(name)},
"icon": "",
"language": &"GDScript",
"path": ${JSON.stringify(resource)}
}`).join(', ');
  fs.writeFileSync(path.join(project, '.godot/global_script_class_cache.cfg'), `list=Array[Dictionary]([${registry}])\n`);

  const engineArchive = path.join(temporary, 'godot.zip');
  run('curl', ['--fail', '--location', '--silent', '--show-error', '--retry', '3', '--max-time', '300', '-o', engineArchive, pin.godot.url]);
  verifyHash(engineArchive, pin.godot.archive_sha256);
  const descriptor = fs.openSync(godot, 'w', 0o700);
  try {
    run('unzip', ['-p', engineArchive, pin.godot.binary_name], { stdio: ['ignore', descriptor, 'inherit'] });
  } finally {
    fs.closeSync(descriptor);
  }
  fs.chmodSync(godot, 0o700);
  verifyHash(godot, pin.godot.binary_sha256);
  assert.equal(capture(godot, ['--version']), pin.godot.version);
  run(godot, ['--headless', '--path', project, '--import']);
  run('npm', ['ci', '--include=dev'], { cwd: worker });
  run('npm', ['run', 'build'], { cwd: worker });
  // This smoke uses local fixtures and temporary signing keys; it never leases a live job.
  run('npm', ['run', 'smoke'], { cwd: worker, env: { ...process.env, MATCH_AUTHORITY_GODOT_BIN: godot } });

  const manifest = {
    worker_build_id: pin.worker_build_id, sim_build_id: pin.sim_build_id, project_path: project,
    map_artifacts: pin.map_artifacts, ruleset_artifacts: pin.ruleset_artifacts,
  };
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  const receipt = {
    source_commit: pin.commit, source_tree: pin.tree, worker_build_id: pin.worker_build_id,
    sim_build_id: pin.sim_build_id, godot_version: pin.godot.version,
    godot_binary_sha256: pin.godot.binary_sha256, godot_class_count: classes.length,
    smoke_passed: true,
  };
  fs.writeFileSync(path.join(output, 'build-receipt.json'), JSON.stringify(receipt, null, 2) + '\n');
  console.log('CERTIFIED_AUTHORITY_BUILD_PASS', JSON.stringify(receipt));
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
