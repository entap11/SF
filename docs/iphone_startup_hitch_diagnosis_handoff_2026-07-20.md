# iPhone Startup Hitch Diagnosis — Work Codex Handoff

Updated: 2026-07-21

Branch: `codex/iphone-startup-hitch-diagnosis`

Diagnostic source commit: `2c27ac363ffcea658b2fe1415d6b882540329110`

Status: **PHYSICAL BASELINE AND FOCUSED CPU/METAL ATTRIBUTION COMPLETE — FIRST CONTROLLED SMOOTHING VARIANT STAGED FOR DEVICE VALIDATION**

## Outcome

The startup hitches reproduce on the iPhone 16 Pro. They are not caused by canonical simulation work, thermal pressure, the GPU, or a cold-only cache effect.

The long boot interval is principally synchronous scene construction and resource work on the main thread, overlapping worker-thread GDScript/resource compilation. The strongest main-thread stacks are scene `_ready` propagation, synchronous `ResourceLoader` work, WebP decode, Variant/GDScript calls, and texture creation/update.

The focused Metal run also captured one 79.631 ms diagnostic hitch immediately after the first canonical tick. The render/display pipeline continued through that interval, with short drawable waits and ordinary GPU command durations. This event is therefore best classified as an engine/main-thread scheduling or frame-delta anomaly at the prematch-to-running boundary, not GPU starvation and not a long simulation tick.

Separately, the same Metal trace contains a real 87.267 ms gap in application present requests shortly afterward. Time Profiler attributes that gap to a synchronous `Texture2D.get_image()` readback through `RenderingDeviceVulkan::texture_get_data`, including Vulkan flush/device-idle waits. This is actionable render/presentation work, but the native trace cannot identify the originating GDScript source line. The project call sites are bounded below.

The first controlled source variant now removes the debug-only `Texture2D.get_image()` call from `HiveVisual._hive_tex_debug()`. It preserves the log's texture metadata but reports alpha as `not_sampled_runtime`, avoiding a synchronous GPU readback while constructing a `log_once` argument. No gameplay rule, timing, or authoritative state is changed. The device evidence below is the production-timing baseline and does not yet validate this variant.

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
- `scripts/hive/hive_visual.gd`: `_hive_tex_debug()`; the leading candidate because the trace reaches the readback through a process-time GDScript signal after the first simulation tick. Its debug-only readback has been removed in the staged variant.
- `scripts/ui/main_menu.gd`: several runtime UI texture keying, cropping, rotation, and inlay-building paths.

`LaneRenderer` loads and retains its lane texture during `_ready`, and `UnitRenderer` prewarms its default unit keys during `_ready`; those facts reduce, but do not eliminate, their likelihood for the later occurrence. The trace's outer signal path and timing make `_hive_tex_debug()` the strongest candidate, but native sampling does not expose the GDScript function name. The staged variant therefore changes only that debug path first; a repeat trace must confirm whether the 87 ms gap disappears before broadening the change.

## Attribution decision

Confidence by claim:

- **High:** the long boot hang is CPU-side scene/resource/GDScript/image work.
- **High:** canonical simulation is not the hitch owner.
- **High:** thermal pressure, shader compilation, GPU command duration, and drawable starvation do not explain the captured interactive event.
- **High:** a separate 87.267 ms presentation stall is caused by synchronous GPU texture readback through `Texture2D.get_image()`.
- **Medium:** the 79.631 ms diagnostic event is an engine scheduling/frame-delta discontinuity at the prematch-to-running transition.
- **Medium-high:** `HiveVisual._hive_tex_debug()` is the source of the later readback; this remains a validation hypothesis until the variant is traced on device.

## Recommended next controlled variant

Validate the staged render-only smoothing variant while preserving authoritative OpsState/SimState and all gameplay timing:

1. Rebuild from a clean variant commit and repeat a smaller paired physical-iPhone validation plus one focused Metal trace. Acceptance should require unchanged authoritative results and protected-state hashes, canonical tick timing within baseline range, removal of the `texture_get_data` stall, and no new interactive hitch.
2. If the readback remains, add bounded one-shot timing around the remaining production `get_image()` sites, then move required work to imported alpha-ready assets or precomputed trim/crop metadata. Do not perform per-pixel texture inspection after input unlock.
3. Independently add a bounded process-boundary probe around prematch completion, simulation activation, and the first few interactive `_process` callbacks to distinguish a real callback pause from a large Godot `delta` value.
4. After the readback is resolved, stage unavoidable boot scene/resource/image preparation before Arena presentation. Do not add a false loading delay; the readiness boundary must correspond to completed preparation.

Do not change target FPS, VSync, graphics defaults, simulation order, gameplay rules, map content, or state authority as part of this variant.

## Repository and artifact state

The diagnostic collector and protocol remain as implemented in the source commit. Generated apps, JSON evidence, raw traces, and exported trace tables are intentionally Git-ignored. Rejected locked-device attempts are retained with `rejected-device-locked` in their names and must not be treated as evidence.

The original operating protocol remains in `docs/iphone_startup_hitch_diagnosis_sprint_2026-07-20.md`.
