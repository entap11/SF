# iPhone Startup Hitch Diagnosis — Work Codex Handoff

Updated: 2026-07-21

Branch: `codex/iphone-startup-hitch-diagnosis`

Diagnostic source commit: `2c27ac363ffcea658b2fe1415d6b882540329110`

Status: **PHYSICAL BASELINE AND FOCUSED CPU/METAL ATTRIBUTION COMPLETE — FIRST CONTROLLED SMOOTHING VARIANT VALIDATED ON DEVICE**

## Outcome

The startup hitches reproduce on the iPhone 16 Pro. They are not caused by canonical simulation work, thermal pressure, the GPU, or a cold-only cache effect.

The long boot interval is principally synchronous scene construction and resource work on the main thread, overlapping worker-thread GDScript/resource compilation. The strongest main-thread stacks are scene `_ready` propagation, synchronous `ResourceLoader` work, WebP decode, Variant/GDScript calls, and texture creation/update.

The focused Metal run also captured one 79.631 ms diagnostic hitch immediately after the first canonical tick. The render/display pipeline continued through that interval, with short drawable waits and ordinary GPU command durations. This event is therefore best classified as an engine/main-thread scheduling or frame-delta anomaly at the prematch-to-running boundary, not GPU starvation and not a long simulation tick.

Separately, the same Metal trace contains a real 87.267 ms gap in application present requests shortly afterward. Time Profiler attributes that gap to a synchronous `Texture2D.get_image()` readback through `RenderingDeviceVulkan::texture_get_data`, including Vulkan flush/device-idle waits. This is actionable render/presentation work, but the native trace cannot identify the originating GDScript source line. The project call sites are bounded below.

The first controlled source variant removes the debug-only `Texture2D.get_image()` call from `HiveVisual._hive_tex_debug()`. It preserves the log's texture metadata but reports alpha as `not_sampled_runtime`, avoiding a synchronous GPU readback while constructing a `log_once` argument. No gameplay rule, timing, or authoritative state is changed.

Three accepted warm launches of the exact signed variant produced no interactive hitch, unchanged protected-state hashes, and canonical tick timing within the baseline range. A comparison Metal trace covering the requested-map transition contains no sampled `get_image`, `texture_get_data`, `texture_2d_get`, or `vkDeviceWaitIdle` stack. This supports the targeted readback attribution. The trace was attached after process launch and did not export app-owned Core Animation/GPU interval rows, so it is supporting rather than standalone proof.

## Device and build

- iPhone 16 Pro (`iPhone17,1`), iOS 26.5.2.
- Apple A18 Pro GPU, Godot 4.2.2 stable, Forward+, Vulkan/MoltenVK.
- 120 Hz display, VSync enabled, portrait, Wi-Fi, Low Power Mode off.
- Device remained thermally Nominal in the accepted Instruments captures.
- CoreDevice identifier: `B8F36805-35EE-5AC8-B9A7-4944062B98F7`.
- Xcode destination UDID: `00008140-000614482E00401C`.
- Bundle: `com.matthew.swarmfront`.
- PCK SHA-256: `3cbff712f39f8f75033544d6896e1691fda04a665e87c636d47b894011f08636`.
- Executable SHA-256: `6a6b9d3088348716ac397b3595b0765fddfa2f832305ff030af16f9fe9763f37`.
- Build manifest: `artifacts/startup_hitch_diagnostic/device_build_4_2_2/build_manifest.json`.

All accepted reports completed their diagnostic windows, passed protected-state integrity, and reported zero failed soak rounds.

The smoothing variant was built from clean commit `108150f79045d711d593609ff543b1b49d91fb91` (tree `62573d381c9e33b4ec934e32a55836151dbe150c`). Its build manifest is `artifacts/startup_hitch_diagnostic/device_build_variant_hive_debug_readback/build_manifest.json`; PCK SHA-256 is `979d22433d69c8954c5d8225d4cc258a0fdbeb5ffbb906eb180b7cf504ace9e7`, and executable SHA-256 is `0a0febbc1178517dd33d3220eeacb7776615897ae6f303aa6dddca8671142ccf`.

## Controlled physical baseline

Twenty runs were eligible: 10 cold and 10 warm. No run was rejected.

| Metric | Cold | Warm | Combined |
| --- | ---: | ---: | ---: |
| Eligible runs | 10 | 10 | 20 |
| Median per-run maximum rendered frame | 144.693 ms | 142.140 ms | 142.209 ms |
| P95 / worst maximum rendered frame | 150.000 ms | 150.000 ms | 150.000 ms |
| Interactive-hitch occurrence | 9/10 | 6/10 | 15/20 |
| Median per-run maximum canonical tick | 2.574 ms | 2.671 ms | 2.614 ms |
| Worst canonical tick | 3.669 ms | 3.327 ms | 3.669 ms |

The cold-minus-warm median maximum-frame difference is only 2.553 ms. The signature is not materially cold-launch/cache driven.

Every run's maximum hitch was last associated with `first_lane_activity`. Focused tracing shows that marker is correlational: the expensive work is scene/resource construction, not lane simulation.

Authoritative summary: `artifacts/startup_hitch_diagnostic/evidence/baseline_summary.json`.

## Focused Time Profiler attribution

### Capture 01 — reproduced boot and interactive events

Evidence:

- `artifacts/startup_hitch_diagnostic/traces/iphone16pro-time-profiler-01.trace`
- `artifacts/startup_hitch_diagnostic/evidence/time-profiler-01.json`

The diagnostic's 2345.678 ms `engine_process_ms` event aligns with the Instruments potential-hang interval at 19.201691–21.547504 seconds, a 2.345813 second hang.

During that hang, the trace records approximately 1113 ms of main-thread CPU and 1077 ms of worker CPU. The main thread is dominated by GDScript calls, `Node::_propagate_ready`, synchronous resource loading, WebP image decode, Variant work, and texture creation/update. Worker time is dominated by threaded resource loading plus GDScript tokenize/parse/analyze/compile work.

Approximate boundary breakdown:

- Scene request to resource loaded: 1086.8 ms, dominated by resource loading and GDScript compilation.
- Scene instantiated to Arena `_ready` entry: 618.4 ms, dominated by main-thread image decode and ready propagation plus continuing worker compilation.
- Scene added to map-model ready: 507.4 ms, dominated by main-thread GDScript/ready/deferred work.
- Requested-map application: approximately 31.4 ms.
- Map complete to first lane activity: approximately 283.3 ms, mostly main-thread GDScript/CallQueue work.

The canonical simulation tick remained cheap: 2.196 ms first tick and 3.686 ms maximum during the report window.

### Capture 02 — extended transition capture

Evidence:

- `artifacts/startup_hitch_diagnostic/traces/iphone16pro-time-profiler-02.trace`
- `artifacts/startup_hitch_diagnostic/evidence/time-profiler-02.json`

This run reproduced the boot signature but no interactive hitch. It remained thermally Nominal. The first canonical tick was 1.572 ms and the maximum was 2.589 ms. Later transition activity showed normal Metal/render work and no long stall.

## Focused Metal System Trace attribution

Evidence:

- `artifacts/startup_hitch_diagnostic/traces/iphone16pro-metal-system-01.trace`
- `artifacts/startup_hitch_diagnostic/evidence/metal-system-01.json`
- Exported Metal, Core Animation, display, thermal, hang, and Time Profiler tables alongside the trace.

The accepted run recorded:

- maximum rendered frame: 133.824 ms;
- two pre-input boot events: 133.824 ms and 125.077 ms;
- one interactive event: 79.631 ms;
- first canonical tick: 2.274 ms;
- maximum canonical tick: 2.479 ms;
- protected-state integrity: pass.

The interactive sequence was:

- prematch complete: 12890.632 ms;
- player input unlocked: 12898.886 ms;
- first interactive frame: 12901.101 ms;
- first canonical tick start: 13000.021 ms;
- first canonical tick complete: 13002.347 ms;
- diagnostic hitch record: 13092.583 ms;
- first unit activity: 14400.215 ms.

### Why the 79.631 ms event is not GPU-bound

Across the reported interval:

- Core Animation present requests continued.
- Drawable/buffer waits were 1.831–7.177 ms; the trace-wide maximum was 13.98 ms elsewhere.
- GPU command spans remained approximately 5.6–7.7 ms; the broader transition-region maximum was 9.151 ms.
- VSync continued, normally at approximately 8.335 ms, with no 79 ms display gap.
- No shader compilation occurred inside the interval.
- Instruments did not classify it as a potential hang.
- Main-thread sampled CPU was about 45 ms of the 79.6 ms window, with no single long dominant function.
- Physics processing was 0.256 ms and the last canonical tick was 2.274 ms.

The diagnostic records `delta` at `_process`, but constructs runtime context before timestamping the hitch event. The Arena heartbeat independently observed the same 79.6 ms maximum frame, so the event is not merely collector overhead. The best current interpretation is a Godot scheduling/frame-delta discontinuity around activation, while the presentation pipeline itself continues.

### Separate synchronous texture-readback stall

Application present requests have an 87.267 ms gap from approximately 21.396244 to 21.483512 seconds in trace time, after the diagnostic event.

The main thread spends approximately 62 ms of that interval in this stack family:

```text
Texture2D.get_image
RendererRD::TextureStorage::texture_2d_get
RenderingDeviceVulkan::texture_get_data
VulkanContext::flush / vkDeviceWaitIdle
platform memory copy
```

The GPU simultaneously shows a burst of small compute command buffers associated with the readback. Shader compilation begins only after the gap and is sub-millisecond, so it is not the cause. A later heartbeat maximum of approximately 86.9 ms corresponds to this stall.

Project `get_image()` call sites in production scripts are:

- `scripts/renderers/lane_renderer.gd`: `_texture_has_alpha()` and `_trim_texture()`; trimming can additionally scan every image pixel.
- `scripts/renderers/sprite_registry.gd`: `_ensure_alpha()`; performs conversion and per-pixel alpha rewriting for keyed assets.
- `scripts/hive/hive_visual.gd`: `_hive_tex_debug()`; the leading candidate because the trace reaches the readback through a process-time GDScript signal after the first simulation tick. Its debug-only readback has been removed in the validated variant.
- `scripts/ui/main_menu.gd`: several runtime UI texture keying, cropping, rotation, and inlay-building paths.

`LaneRenderer` loads and retains its lane texture during `_ready`, and `UnitRenderer` prewarms its default unit keys during `_ready`; those facts reduce, but do not eliminate, their likelihood for the later occurrence. The trace's outer signal path and timing make `_hive_tex_debug()` the strongest candidate, but native sampling does not expose the GDScript function name. The controlled variant therefore changes only that debug path first and uses a repeat trace plus accepted device reports to test the attribution.

## Controlled smoothing variant validation

The signed `hive_debug_no_texture_readback` build was validated in three accepted warm runs on the same iPhone and fixture:

| Run | Maximum rendered frame | Interactive hitches | First / maximum canonical tick | Protected state |
| --- | ---: | ---: | ---: | --- |
| `variant-hive-debug-01` | 133.840 ms | 0 | 2.259 / 2.854 ms | Pass |
| `variant-hive-debug-02` | 142.152 ms | 0 | 1.882 / 2.452 ms | Pass |
| `variant-hive-debug-03` | 144.344 ms | 0 | 2.280 / 2.577 ms | Pass |

All six recorded hitches were pre-presentation boot frames; no run recorded an interactive hitch. Interactive-hitch occurrence was therefore 0/3, compared with 6/10 in the warm baseline. This is a small validation set, not a replacement statistical baseline, but its direction is consistent with removal of the late synchronous readback.

The variant's median maximum rendered frame was 142.152 ms, effectively unchanged from the 142.140 ms warm-baseline median. That is the expected result: the variant targets the later runtime readback and does not change the independently attributed scene/resource/image boot work. Its worst canonical tick was 2.854 ms, within the baseline range, and all protected-state hashes were unchanged.

Accepted reports:

- `artifacts/startup_hitch_diagnostic/evidence/variant-hive-debug-01.json`
- `artifacts/startup_hitch_diagnostic/evidence/variant-hive-debug-02.json`
- `artifacts/startup_hitch_diagnostic/evidence/variant-hive-debug-03.json`

The comparison trace is `artifacts/startup_hitch_diagnostic/traces/iphone16pro-metal-system-variant-hive-debug-01.trace`. It covered the requested-map transition, remained thermally Nominal, and reported no potential hangs. Its Time Profiler export has no sampled texture-readback/device-idle stack. Because Instruments attached approximately 9.5 seconds after launch, the exported app Core Animation and GPU-submission tables contain no rows. The trace run's companion diagnostic JSON also could not be copied, so the trace is not counted as a fourth accepted diagnostic run; the three reports above are the accepted measurement set.

## Attribution decision

Confidence by claim:

- **High:** the long boot hang is CPU-side scene/resource/GDScript/image work.
- **High:** canonical simulation is not the hitch owner.
- **High:** thermal pressure, shader compilation, GPU command duration, and drawable starvation do not explain the captured interactive event.
- **High:** a separate 87.267 ms presentation stall is caused by synchronous GPU texture readback through `Texture2D.get_image()`.
- **Medium:** the 79.631 ms diagnostic event is an engine scheduling/frame-delta discontinuity at the prematch-to-running transition.
- **High:** the comparison variant removes the later sampled readback stack without changing protected state or canonical tick timing.
- **Medium-high:** `HiveVisual._hive_tex_debug()` was the source of the later readback. The controlled result and stack absence support this attribution, while the attach-mode trace lacks app-owned presentation interval rows.

## Recommended next work

Preserve authoritative OpsState/SimState and all gameplay timing while continuing the audit:

1. Stage unavoidable scene/resource/image preparation before Arena presentation, addressing the remaining approximately 142 ms warm boot-frame median and the multi-second synchronous construction boundary. Do not add a false loading delay; readiness must correspond to completed preparation.
2. Add a bounded process-boundary probe around prematch completion, simulation activation, and the first few interactive `_process` callbacks to distinguish a real callback pause from a large Godot `delta` value if the 79.631 ms activation anomaly recurs.
3. Keep the remaining production `get_image()` sites out of post-input paths. If another readback occurs, add bounded one-shot timing, then move required alpha/trim work to imported alpha-ready assets or precomputed metadata.
4. Expand the variant validation set only if a release-level occurrence estimate is needed. The current three runs establish a clean targeted check but are not powered as a full comparative baseline.

Do not change target FPS, VSync, graphics defaults, simulation order, gameplay rules, map content, or state authority as part of subsequent smoothing work.

## Repository and artifact state

The diagnostic collector and protocol remain as implemented in the diagnostic source commit. The readback smoothing change is committed as `108150f79045d711d593609ff543b1b49d91fb91`. Generated apps, JSON evidence, raw traces, and exported trace tables are intentionally Git-ignored. Rejected locked-device attempts are retained with `rejected-device-locked` in their names and must not be treated as evidence.

The original operating protocol remains in `docs/iphone_startup_hitch_diagnosis_sprint_2026-07-20.md`.
