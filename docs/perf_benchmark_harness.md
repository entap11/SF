# SF Performance Benchmark Harness

Purpose:
- bring the OMM smoothness process into SF without importing OMM gameplay architecture
- produce repeatable JSON reports for frame time, hitches, and worst-frame context
- isolate expensive SF layers before treating the full match as stable

## Current Status

Implemented in `tools/perf_benchmark_suite.gd`:
- SF-native Arena boot path using `Arena.tscn`
- JSON map loading through SF map utilities
- deterministic opposing hive intent reapplication
- gated JSON reports under `debug_reports/`
- per-scenario latest reports under `debug_reports/perf_benchmarks/`
- baseline comparison through `tools/perf_compare.gd`

The first runner is an Arena/render-path benchmark. It is intentionally not a pure sim-headless harness yet, because SF simulation currently runs through scene-owned systems. A future adapter should tick `OpsState` and the simulation systems without Arena or renderer nodes.

## Run

From the SF project root:

```bash
godot --path /Users/matthewballou/SideProjects/SF/project --script res://tools/perf_benchmark_suite.gd -- --suite=quick --mode=render_windowed --output=res://debug_reports/perf_benchmark_latest.json
```

For a short headless smoke of the Arena path:

```bash
godot --headless --path /Users/matthewballou/SideProjects/SF/project --script res://tools/perf_benchmark_suite.gd -- --suite=quick --scenario=boot_5s --mode=arena_headless --map=res://maps/_future/closequarters/MAP_closequarters__SBASE__4p.json --output=res://debug_reports/perf_benchmark_boot_latest.json
```

Compare against a saved baseline:

```bash
godot --headless --path /Users/matthewballou/SideProjects/SF/project --script res://tools/perf_compare.gd -- res://debug_reports/perf_benchmark_baseline.json res://debug_reports/perf_benchmark_latest.json
```

## Suites

`quick`:
- `boot_5s`
- `duel_10s`
- `pressure_20s`

`sprint_layers`:
- all `quick` scenarios
- `stress_30s`

`stress_30s` is a regression target. Do not water it down just to pass.

## Next Adapter Work

1. Add a pure `sim_headless` runner that creates map state and ticks SF simulation systems without Arena/render nodes.
2. Add renderer section counters for lane renderer, unit renderer, tower renderer, barracks renderer, polish layer, and UI/HUD.
3. Add scenario switches that isolate lanes, swarms, towers, bots, buffs, polish, and HUD.
4. Add startup warm-up counters around map load, prematch, pool prewarm, first gameplay frame, and first 10 seconds.
