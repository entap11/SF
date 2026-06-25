# Player Config Matrix

## Purpose

The player config matrix is the source-of-truth gate for supported and explicitly rejected PvP configurations.

It separates:

- `topology`: `1v1`, `2v2`, `3p_ffa`, `4p_ffa`
- `contract_mode`: `1V1`, `2V2`, `3P_FFA`, `4P_FFA`
- `rules_mode`: `STAGE_RACE`, `CAPTURE_FLAG`, `HIDDEN_CAPTURE_FLAG`, `TIMED_RACE`, `MISS_N_OUT`

`contract_mode` validates map variant and owner legality. `rules_mode` drives lobby/runtime rule behavior.

## One-Command Gates

Fast local gate:

```bash
scripts/dev/run_player_config_matrix_gate.sh --gate fast
```

PR gate:

```bash
scripts/dev/run_player_config_matrix_gate.sh --gate pr
```

Nightly-style local gate:

```bash
scripts/dev/run_player_config_matrix_gate.sh --gate nightly
```

Contract and boot only:

```bash
scripts/dev/run_player_config_matrix_gate.sh --gate fast --no-soak
```

## Soak Tiers

Fast soak is intentionally small:

- `1v1__stage_race__free`
- `1v1__hidden_capture_flag__free`
- `4p_ffa__stage_race__free`

PR soak covers every rules mode, every topology family, and the paid-entry samples in the manifest:

- `1v1__stage_race__free`
- `1v1__stage_race__paid_1`
- `1v1__hidden_capture_flag__free`
- `2v2__capture_flag__free`
- `2v2__capture_flag__paid_1`
- `3p_ffa__timed_race__free`
- `3p_ffa__timed_race__paid_1`
- `4p_ffa__miss_n_out__free`
- `4p_ffa__hidden_capture_flag__paid_1`

Nightly soak runs all valid manifest rows for the `nightly` tier.

Default soak settings:

- Fast: 1 seed, 10 seconds per config, 10 second rounds
- PR: 2 seeds, 20 seconds per config, 10 second rounds
- Nightly: 3 seeds, 45 seconds per config, 10 second rounds

Use `--seed-runs`, `--seconds`, `--round-seconds`, and `--pairs` to override these locally.

## CI

GitHub Actions wiring lives at `.github/workflows/release-readiness.yml`.

It expects a self-hosted macOS runner with these labels:

```text
self-hosted, macOS, godot
```

The runner must have Godot available as `godot`, or expose a repository/org variable:

```text
GODOT_BIN=/absolute/path/to/Godot
```

CI behavior:

- Pull request: fast release-readiness gate
- Push to `main`: PR matrix gate
- Nightly schedule: nightly matrix gate plus legacy perf soak
- Manual dispatch: selectable matrix tier, seed, seed runs, no-soak, perf soak, and TestFlight preflight

## Individual Stages

Contract validation:

```bash
scripts/dev/run_player_config_matrix.sh --tier fast --seed 123
```

Boot/runtime route validation:

```bash
scripts/dev/run_player_config_matrix.sh --boot-routes --tier fast --seed 123
```

Soak route validation:

```bash
scripts/dev/run_player_config_matrix.sh --soak-routes --soak-tier fast --seed 123 --seconds 10 --round-seconds 10 --pairs 1
```

Deterministic seed sweep:

```bash
scripts/dev/run_player_config_matrix.sh --soak-routes --soak-tier fast --seed 123 --seed-runs 3 --seconds 10 --round-seconds 10 --pairs 1
```

## Reports

Latest reports:

- `artifacts/player_config_matrix/latest.json`
- `artifacts/player_config_matrix/boot_routes_latest.json`
- `artifacts/player_config_matrix/soak_latest.json`

Soak logs are written under:

```text
artifacts/player_config_matrix/logs/
```

Each row includes a `replay_command`. Prefer that command when reproducing a failure because it pins the exact config, seed, soak duration, pair count, and start timeout.

## Source Files

- `tools/player_config_matrix_manifest.gd`
- `tools/player_config_matrix_contract_test.gd`
- `tools/player_config_matrix_boot_runner.gd`
- `tools/player_config_matrix_topology_boot_runner.gd`
- `tools/player_config_matrix_mode_runtime_runner.gd`
- `tools/player_config_matrix_soak_runner.gd`
- `scripts/dev/run_player_config_matrix.sh`
- `scripts/dev/run_player_config_matrix_gate.sh`
