# iPhone Startup Hitch Diagnosis — Work Codex Handoff

Updated: 2026-07-22

Branch: `codex/iphone-startup-hitch-diagnosis`

Diagnostic source commit: `2c27ac363ffcea658b2fe1415d6b882540329110`

Status: **LARGE-HIVE OWNER REMOVED — IOS AUDIO START BOUNDARY FIXED IN CUSTOM 4.2.2 TEMPLATE — FOCUSED WARM DEVICE RUN ACCEPTED — MATRIX PENDING**

## Outcome

The startup hitches reproduce on the iPhone 16 Pro. They are not caused by canonical simulation work, thermal pressure, the GPU, or a cold-only cache effect.

The iOS audio-init blocker is now isolated and cleared for focused testing. A minimal empty Godot 4.2.2 app reproduced `AudioOutputUnitStart failed, code -50`, proving the error was outside Swarmfront. Godot 4.2.2 attempts to start CoreAudio before the iOS active lifecycle boundary; the unit later mixes successfully after focus activation. A custom 4.2.2 debug template now keeps focus/render activation immediate, suppresses only the premature native start, and starts audio 100 ms after `applicationDidBecomeActive`. The full-module template passed a minimal device probe and an exact-source focused Swarmfront run with no CoreAudio error, zero interactive hitches, unchanged protected state, and zero failed soak rounds. The tracked engine and Xcode 26 compatibility patches are recorded at the end of this handoff.

The long boot interval is principally synchronous scene construction and resource work on the main thread, overlapping worker-thread GDScript/resource compilation. The strongest main-thread stacks are scene `_ready` propagation, synchronous `ResourceLoader` work, WebP decode, Variant/GDScript calls, and texture creation/update.

The focused Metal run also captured one 79.631 ms diagnostic hitch immediately after the first canonical tick. The render/display pipeline continued through that interval, with short drawable waits and ordinary GPU command durations. This event is therefore best classified as an engine/main-thread scheduling or frame-delta anomaly at the prematch-to-running boundary, not GPU starvation and not a long simulation tick.

Separately, the same Metal trace contains a real 87.267 ms gap in application present requests shortly afterward. Time Profiler attributes that gap to a synchronous `Texture2D.get_image()` readback through `RenderingDeviceVulkan::texture_get_data`, including Vulkan flush/device-idle waits. This is actionable render/presentation work, but the native trace cannot identify the originating GDScript source line. The project call sites are bounded below.

The first controlled source variant removes the debug-only `Texture2D.get_image()` call from `HiveVisual._hive_tex_debug()`. It preserves the log's texture metadata but reports alpha as `not_sampled_runtime`, avoiding a synchronous GPU readback while constructing a `log_once` argument. No gameplay rule, timing, or authoritative state is changed.

Three accepted warm launches of the exact signed variant produced no interactive hitch, unchanged protected-state hashes, and canonical tick timing within the baseline range. A comparison Metal trace covering the requested-map transition contains no sampled `get_image`, `texture_get_data`, `texture_2d_get`, or `vkDeviceWaitIdle` stack. This supports the targeted readback attribution. The trace was attached after process launch and did not export app-owned Core Animation/GPU interval rows, so it is supporting rather than standalone proof.

The second controlled variant removes another deterministic boot cost from `LaneRenderer._ready()`. The renderer previously read back the 1536×1024 lane texture, queried its image bounds, and could inspect all 1,572,864 pixels in GDScript to rediscover an immutable crop. The exact crop `(0, 376, 1536, 232)` now lives in the sprite manifest and resolves directly as an `AtlasTexture`; the dead runtime alpha probes were removed as well. Three accepted warm device runs reduced median child-scene `_ready` time by 66.390 ms and median scene-request-to-visible time by 141.621 ms. The median maximum rendered frame remained effectively unchanged, so this is a measured startup-latency reduction, not yet a fix for the remaining approximately 142 ms worst boot frame.

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

The lane-metadata variant was built from clean commit `8b06970f23227e9e2cf216915cb3ce8ce9276376` (tree `01700aa2bef9c13e3318a9334865ca9abe40a29c`). Its build manifest is `artifacts/startup_hitch_diagnostic/device_build_variant_lane_metadata/build_manifest.json`; PCK SHA-256 is `792ecd7850badd38736684e79b03e509ee6e510aff66ba4dbfa5d41cce669eee`, and executable SHA-256 is `30e607ba017c7014df29cfa9502504dfbf434f2bfa27f8b96d857a73427d4568`.

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

## First controlled smoothing variant validation

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

## Second controlled boot-preparation variant validation

Commit `8b06970` moves the immutable lane crop into `skin_manifest.json`, preserves the resulting `AtlasTexture` in `LaneRenderer`, and removes runtime `get_image()`, `get_used_rect()`, alpha-format probing, and the nested per-pixel trim scan from lane boot. The manifest crop was generated with the renderer's previous alpha/luminance rules, so lane geometry is unchanged.

The exact signed build was primed once after installation, then validated in three accepted warm runs on the same iPhone and fixture:

| Run | Maximum rendered frame | Interactive hitches | First / maximum canonical tick | Protected state |
| --- | ---: | ---: | ---: | --- |
| `variant-lane-metadata-01` | 148.273 ms | 0 | 1.597 / 2.569 ms | Pass |
| `variant-lane-metadata-02` | 142.114 ms | 0 | 1.944 / 2.775 ms | Pass |
| `variant-lane-metadata-03` | 141.744 ms | 0 | 2.211 / 2.475 ms | Pass |

All six hitches remained pre-presentation boot events. Interactive-hitch occurrence was 0/3, all protected-state hashes were unchanged, and the worst canonical tick was 2.775 ms.

Compared with the three-run parent variant:

| Metric | Parent median | Lane-metadata median | Change |
| --- | ---: | ---: | ---: |
| Child scene instantiated to Arena `_ready` entry | 636.913 ms | 570.523 ms | −66.390 ms (−10.4%) |
| Match-scene request to Arena presentation visible | 2667.728 ms | 2526.107 ms | −141.621 ms (−5.3%) |
| Per-run maximum rendered frame | 142.152 ms | 142.114 ms | −0.038 ms (effectively unchanged) |

This validates removal of meaningful synchronous boot work, but it does not move the worst-frame envelope. The next variant must target a different part of the scene/resource/first-lane-activity boundary rather than broadening this lane change.

Accepted reports:

- `artifacts/startup_hitch_diagnostic/evidence/variant-lane-metadata-01.json`
- `artifacts/startup_hitch_diagnostic/evidence/variant-lane-metadata-02.json`
- `artifacts/startup_hitch_diagnostic/evidence/variant-lane-metadata-03.json`

One attempted second run failed during iOS audio initialization and produced no diagnostic report. It is retained as `variant-lane-metadata-02-rejected-audio-init.console.log` and is not evidence.

## Attribution decision

Confidence by claim:

- **High:** the long boot hang is CPU-side scene/resource/GDScript/image work.
- **High:** canonical simulation is not the hitch owner.
- **High:** thermal pressure, shader compilation, GPU command duration, and drawable starvation do not explain the captured interactive event.
- **High:** a separate 87.267 ms presentation stall is caused by synchronous GPU texture readback through `Texture2D.get_image()`.
- **Medium:** the 79.631 ms diagnostic event is an engine scheduling/frame-delta discontinuity at the prematch-to-running transition.
- **High:** the comparison variant removes the later sampled readback stack without changing protected state or canonical tick timing.
- **Medium-high:** `HiveVisual._hive_tex_debug()` was the source of the later readback. The controlled result and stack absence support this attribution, while the attach-mode trace lacks app-owned presentation interval rows.
- **High:** lane texture crop discovery was deterministic synchronous boot work; moving it to manifest metadata reduced median child-scene readiness by 66.390 ms without changing authority or lane geometry.
- **High:** the remaining approximately 142 ms maximum boot frame is not explained by lane texture crop discovery alone.

## Recommended next work

Preserve authoritative OpsState/SimState and all gameplay timing while continuing the audit:

1. Add bounded markers around child renderer `_ready`, post-add deferred work, and first lane activity, then run one focused Time Profiler capture to identify the owner of the remaining approximately 142 ms maximum boot frame.
2. Separately test an explicit match-scene readiness boundary. The threaded scene request currently gets a 900 ms allowance, while accepted runs require approximately 1082–1159 ms to report the resource loaded; avoid falling back to synchronous loading just before the threaded request completes.
3. Add a bounded process-boundary probe around prematch completion, simulation activation, and the first few interactive `_process` callbacks to distinguish a real callback pause from a large Godot `delta` value if the 79.631 ms activation anomaly recurs.
4. Keep the remaining production `get_image()` sites out of post-input paths. If another readback occurs, move required alpha/trim work to imported alpha-ready assets or precomputed metadata.

Do not change target FPS, VSync, graphics defaults, simulation order, gameplay rules, map content, or state authority as part of subsequent smoothing work.

## Repository and artifact state

The diagnostic collector and protocol remain as implemented in the diagnostic source commit. The readback smoothing change is committed as `108150f79045d711d593609ff543b1b49d91fb91`; the lane boot-metadata change is committed as `8b06970f23227e9e2cf216915cb3ce8ce9276376`. Generated apps, JSON evidence, raw traces, and exported trace tables are intentionally Git-ignored. Rejected locked-device or incomplete runtime attempts must not be treated as evidence.

The original operating protocol remains in `docs/iphone_startup_hitch_diagnosis_sprint_2026-07-20.md`.

## 2026-07-21 implementation handoff

The retained startup hitch now has a measured owner: the first `hive.large.neutral` lookup spent 215.705 ms constructing an alpha texture from the 1254×1254 RGB source. It accounted for 99.94% of the 15-key hive prewarm loop and aligned with the approximately 142 ms rendered-frame signature.

The current worktree implements the narrow fix and the startup scheduling boundary:

- `hive_large_flatop_alpha.png` is a deterministic, alpha-bearing build asset generated by `tools/build_large_hive_alpha_asset.gd` with the exact former black color-key threshold and softness.
- All five `hive.large.*` manifest entries use the alpha-ready asset and contain no runtime color-key metadata.
- `tools/large_hive_alpha_asset_smoke_test.gd` recomputes the former algorithm and requires exact RGBA byte equality, unchanged dimensions, and correct manifest metadata.
- `SpriteRegistry` now bypasses its alpha cache entirely when a texture requires neither color keying nor automatic white keying. Small and medium hive conversion behavior is unchanged.
- The persistent loading coordinator now supports a match-readiness mode with truthful stages and rotating preparation copy. It owns the heavy scene/map/render interval; the existing approved prematch handshake ad remains the single ad placement, avoiding a duplicate request or impression.
- Shell presents that cover before synchronous map-mode validation, waits up to five seconds for the threaded match scene instead of falling back as soon as map prewarm finishes, waits for Arena/map/render/hive readiness, renders the prepared Arena under the opaque cover, and then releases it.
- Arena holds the prematch clock and countdown sound while the match cover is active. The countdown audio stream is loaded behind the cover and played only when the visible countdown begins.
- VFX impact and collision first-use work is split into a countdown queue that executes at most one task per rendered frame. Countdown completion is gated on an empty required warmup queue.
- The in-game ad surface and debug/telemetry overlays no longer compete with startup. They enter a one-task-per-frame post-start queue after a 1.2-second stability delay. This queue is the extension seam for future nonessential systems; CPU-heavy features such as AI announcers must enqueue incremental slices, not one monolithic callable.

Focused local gates currently pass:

- `large_hive_alpha_asset_smoke_test.gd`
- `sprite_registry_hive_prewarm_smoke_test.gd`
- `main_menu_loading_cover_smoke_test.gd`
- `startup_readiness_pipeline_smoke_test.gd`
- `shell_async_continuation_prematch_smoke_test.gd`
- `ad_surface_placement_smoke_test.gd`
- `prematch_orientation_flow_smoke_test.gd`
- `app_lifecycle_smoke_test.gd`
- `startup_hitch_diagnostic_smoke_test.gd`
- performance contract gates A through F and Phase 2 gate G

The implementation was committed as `8b0c2c074e3518ae30bbba9835912d8a3a9b3990` (tree `722892c82df792cf3161d81568cd9fda242d75e8`) and exercised on the iPhone 16 Pro. The focused device result and remaining acceptance work are recorded below. Do not broaden the implementation until the external audio-init condition is cleared and the exact build completes an accepted run. Preserve protected-state hashes, canonical tick thresholds, ad placement policy, countdown duration, simulation timing, and authority. Android P6 remains a separately reported hardware blocker.

## 2026-07-21 physical-device result

The exact clean implementation commit was exported and signed for the iPhone 16 Pro. Its Xcode project SHA-256 is `0c0e5ec2012d8a36682c13d1bfb827f76bb88cadf96e0a1f386f0939bb677482`, PCK SHA-256 is `49558ce194b7bb7cfe0f0f871f4abc846fa5d7f3d182cf948c8667db6270b6f4`, and signed executable SHA-256 is `96a56e57db0747831e91c3d06c6b7fff0f51371c6b26eee0c3dd1e1e4c9de729`.

The focused run proves the targeted owner was removed:

| Boundary | Before | Alpha-ready build | Change |
| --- | ---: | ---: | ---: |
| Full `SpriteRegistry.prewarm_hive_textures()` | 215.953 ms | 0.170 ms | -215.783 ms (-99.92%) |
| `hive.large.neutral` | 215.705 ms | 0.003 ms | -215.702 ms (greater than -99.99%) |
| `HiveRenderer._prewarm_hive_sprite_cache()` | 215.974 ms | 0.186 ms | -215.788 ms (-99.91%) |

This did **not** remove the full worst-frame envelope. The focused build recorded a 144.725 ms maximum rendered frame versus 142.885 ms in the owner-attribution run. Both reported hitches were classified `PRE_INPUT_LOADING`, the readiness boundary completed before presentation, and there was no interactive hitch. The first canonical tick was 1.318 ms, the maximum canonical tick was 2.459 ms, protected-state integrity passed, and the 25-second soak completed one round with zero failures. Countdown VFX warmup slices measured 0.015 and 0.011 ms; the largest post-start slice was the in-game ad surface at 0.806 ms, followed by telemetry at 0.018 ms and PVP debug overlays at 0.028 ms.

The copied reports are intentionally ignored artifacts:

- `artifacts/startup_hitch_diagnostic/evidence/variant-large-hive-alpha-01.json`
- `artifacts/startup_hitch_diagnostic/evidence/variant-large-hive-alpha-02.json`

Neither is accepted matrix evidence. Run 01 supplied incorrect source-commit metadata and hit `AudioOutputUnitStart failed, code -50`; Run 02 used the correct commit but repeated the same iOS audio initialization failure. Three later launches repeated the audio failure and were stopped, for five consecutive affected launches of this installed build. These runs are sufficient for narrow attribution because the bounded hive timings are direct and consistent, but they are not sufficient for release acceptance or broad timing claims.

### Exact pickup point

1. Resolve or eliminate the external iOS `AudioOutputUnitStart` code `-50` launch condition without changing the performance variant.
2. Rebuild or reuse exact commit `8b0c2c074e3518ae30bbba9835912d8a3a9b3990`, verify its hashes, and repeat the requested-map focused run until all protocol acceptance conditions pass.
3. If accepted, run the unchanged cold/warm comparison matrix, the 150-second soak, performance gates, and Release Readiness.
4. Treat the remaining approximately 145 ms boot frame as a separate owner. It is currently behind the truthful noninteractive cover and is not an interactive defect; diagnose it further only if loading latency or release criteria justify another bounded attribution sprint.

## AudioOutputUnitStart code -50 handoff — 2026-07-22

### What is established

- The failing line is in Godot 4.2.2's CoreAudio driver, not project GDScript. `AudioDriverCoreAudio::start()` calls Apple's `AudioOutputUnitStart(audio_unit)` and prints this error when Apple returns a nonzero `OSStatus`. Godot sets the driver's `active` flag only after a successful return. See the exact [Godot 4.2.2 source](https://github.com/godotengine/godot/blob/4.2.2-stable/drivers/coreaudio/audio_driver_coreaudio.cpp#L244-L253).
- Apple's SDK defines `-50` as `kAudio_ParamError`, a generic invalid-parameter status. It identifies the failing API boundary but does not identify which route, format, session state, or device parameter Apple rejected.
- The message occurs before `STARTUP_HITCH_DIAGNOSTIC status=armed`, before requested-map loading, before Arena construction, and before prematch countdown setup. The game continues after the error, but Godot has not marked its CoreAudio driver active; the run may therefore be silent and its startup timing is not acceptance-equivalent.
- This is not the first occurrence on the branch. One lane-metadata launch from commit `8b06970f23227e9e2cf216915cb3ce8ce9276376`, committed at 12:01 PDT on July 21, failed the same way before the large-hive/readiness commit existed. Other exact lane-metadata launches were accepted, so the earlier behavior was intermittent.
- The large-hive implementation commit does not change `project.godot`, `export_presets.cfg`, Godot's native audio driver, the project audio-system implementation, mix rate, output latency, channel configuration, or input enablement. It does change the later game-level countdown sequence: the same countdown stream is prepared behind the readiness cover and playback begins when the visible countdown is released. That code cannot cause this observed start failure because it executes after the CoreAudio error.
- The same error signature has been reported from an otherwise empty Godot iOS/simulator project, so it is not unique to Swarmfront. That report supports an engine/platform-level possibility but does not establish the cause of this physical-device incident: [Godot issue 74227](https://github.com/godotengine/godot/issues/74227).

### What is not established

- No project regression, bad audio asset, countdown-player bug, or hive/readiness causal link has been demonstrated.
- No particular Bluetooth, AirPlay, speaker, USB, interruption, sample-rate, or iOS route condition has been captured as the trigger.
- Muting the Master bus or disabling game SFX would not validate a workaround: the failure occurs while Godot starts the native output unit, before project audio playback.
- The two completed reports with direct hive timings remain useful attribution evidence, but no run containing this error may become accepted post-fix performance or Release Readiness evidence.

### Bounded pickup procedure

Keep performance commit `8b0c2c074e3518ae30bbba9835912d8a3a9b3990` unchanged while isolating audio:

1. Fully reboot the iPhone. After unlock, select the built-in speaker, disconnect Bluetooth/AirPlay/headsets, end calls/recording/screen-broadcast sessions, verify ordinary device audio once, and close the other audio app. These are controlled resets, not presumed causes.
2. Launch the already-installed build once with the exact focused arguments and capture the complete console from process start. Accept only a run with no `AudioOutputUnitStart` error and a completed diagnostic report.
3. If `-50` persists, launch the same installed app without soak or startup-diagnostic arguments. Persistence there excludes the diagnostic harness and requested-map flow.
4. If it still persists, install either a retained previously accepted Godot 4.2.2 artifact or a minimal empty Godot 4.2.2 iOS export with the same signing/device. If both fail, investigate the iPhone/iOS/Godot audio-session boundary. If only the current artifact fails, compare the exports, embedded PCK, `Info.plist`, entitlements, and project settings before changing gameplay code.
5. Preserve the first full failing console and relevant iOS device log. Record active output route, attached Bluetooth/AirPlay devices, interruption/call/recording state, iOS version, app hash, and whether a plain launch reproduces.
6. Do not weaken the performance acceptance protocol or hide the native error. Once audio starts cleanly, run the single focused performance validation; do not reopen the approximately 145 ms covered-frame investigation unless its existing regression guard fires.

## Audio boundary resolution and accepted focused run — 2026-07-22

### Root cause and isolation

The bounded pickup procedure established all of the following:

- A rebuilt exact-source Swarmfront app, a retained previously accepted app, and a one-node empty Godot 4.2.2 iOS app all emitted the same immediate `AudioOutputUnitStart failed, code -50` error. The empty app has no Swarmfront game, renderer, input, or audio content, so project code is excluded as the owner.
- Changing the project mix rate to the device's 48 kHz hardware rate did not change the failure.
- The active route was the built-in speaker with two output channels, a 48 kHz sample rate, and a 1024-frame/21.333 ms buffer. Explicit AVAudioSession category selection and activation both succeeded before Godot, but the early CoreAudio start still failed.
- Despite that single early return code, the minimal probe's mixer clock advanced normally after the app became active. Godot 4.2.2's iOS focus path calls `audio_driver.start()` again from `applicationDidBecomeActive`, explaining why the app later mixed even though the first call failed.
- A Godot 4.6.3 comparison export installed and remained running but did not reach the probe-ready marker, so it is not counted as a pass or failure for this incident.

The working fix is deliberately below the project layer. The CoreAudio driver returns without calling Apple's output-unit start while the app-delegate audio-ready flag is false. `applicationDidBecomeActive` preserves the existing immediate focus/render activation, then schedules audio alone 100 ms later on the main queue. Resign-active clears the flag before Godot stops audio. No gameplay, simulation, renderer, input, project audio content, countdown timing, or state authority changed.

Tracked reproduction patches:

- `tools/patches/godot_4_2_2_ios_deferred_audio_start.patch`
- `tools/patches/godot_4_2_2_xcode_26_embree_compat.patch`

The second patch changes only two invalid Embree debug stream formatters that Xcode 26's Clang now rejects because they reference nonexistent members. It restores the normal raycast/Embree module to the custom template; it does not alter geometry or raycast behavior.

Both patches were dry-run validated against pristine Godot `4.2.2-stable` source. The final full-module device library was built with:

```sh
PYTHONPATH=/path/to/scons-local python3 -m SCons \
  platform=ios \
  target=template_debug \
  arch=arm64 \
  -j8 \
  CXXFLAGS=-Wno-module-import-in-extern-c \
  module_raycast_enabled=yes
```

The final custom template retained the official 4.2.2 release library and simulator slices and replaced only `libgodot.ios.debug.xcframework/ios-arm64/libgodot.a`.

### Final template and exact-source build

- Godot source: exact `4.2.2-stable` archive plus the two tracked patches above.
- Full-module custom debug library SHA-256: `517916b03cbadfb612848b87b4df89c60b4ae34e86186f18ebc32fffaa9e5b82`.
- Local custom-template archive SHA-256: `273f1b794eb02443f0a401415c3d8e3bd70d74222436337833f3cf488be9b1fc`.
- Game source commit: `8b0c2c074e3518ae30bbba9835912d8a3a9b3990`.
- Game source tree: `722892c82df792cf3161d81568cd9fda242d75e8`.
- PCK SHA-256: `42d9064e3dd746ca0f9b773f18b26ac41d86d793bd1275e221e1bdebdb722e2e`.
- Signed executable SHA-256: `50200d7c52df69603eb1cfc94a6b3c38b0330de01054c611a03b3240ed5eceb2`.
- Bundle: `com.matthew.swarmfront`.
- Local ignored build: `artifacts/startup_hitch_diagnostic/source_exact_custom_audio_full/`.

The full-module minimal probe reached `AUDIO_PROBE_READY`, emitted repeated 48 kHz mixer-clock telemetry, and emitted no `AudioOutputUnitStart` error. Before the full-module rebuild, the same audio patch also passed three consecutive launches in a temporary module-reduced probe; those exploratory runs are not the final parity evidence.

### Focused device result

The accepted full-module report is the ignored artifact `artifacts/startup_hitch_diagnostic/evidence/variant-large-hive-alpha-audio-deferred-start-03.json`, SHA-256 `3a8e2f88941bea97f3c3b8811a00ec53d4ed66a45928a6a6ac891c2db27314d6`.

| Metric | Result |
| --- | ---: |
| Diagnostic status | `COMPLETE` / `window_elapsed` |
| Maximum rendered frame | 141.778 ms |
| Hitch count | 2 |
| Interactive hitch count | 0 |
| Hitch visibility | Both `PRE_INPUT_LOADING` |
| First canonical tick | 1.352 ms |
| Maximum canonical tick | 2.555 ms |
| Protected-state integrity | Pass; before/after hashes identical |
| 25-second soak | 1 round, 0 failed rounds |
| Native CoreAudio start error | None |

The two recorded frames were 141.778 ms after `arena_deferred_match_flow_scheduled` and 50.000 ms after `arena_deferred_match_flow_first_frame_resumed`. Both occurred while input was locked and gameplay commands were rejected. The remaining worst frame therefore stays inside the truthful loading cover and does not regress the established approximately 145 ms envelope.

Two earlier exploratory reports are not the final evidence:

- `variant-large-hive-alpha-audio-deferred-start-fix-01.json` was the first launch of a newly installed executable. It recorded cold first-use lane/unit rendering spikes and used the temporary module-reduced template: 7 hitches, 3 interactive. It is rejected.
- `variant-large-hive-alpha-audio-deferred-start-02.json` was a clean warm repeat with 1 pre-input hitch and 0 interactive hitches, but it also used the temporary module-reduced template. It is superseded by Run 03.

### Exact pickup point

1. Use the final full-module custom template consistently for the unchanged cold/warm comparison matrix. Prime only where the existing protocol calls for a warm run; do not label a first launch after install as warm.
2. Run the unchanged 150-second soak, performance gates, and Release Readiness checks. Keep the native CoreAudio error as a hard rejection condition.
3. Build and validate a matching custom **release** template before treating this as a shipping engine solution. The currently accepted artifact is a custom debug template for physical-device diagnosis.
4. Decide the long-term engine path separately: carry the narrow Godot 4.2.2 patch with reproducible templates, upstream the lifecycle fix, or upgrade Godot after a complete migration comparison. Do not move this timing workaround into project GDScript.
5. Treat the remaining approximately 142 ms covered boot frame as a separate owner. Reopen it only if loading-latency or release criteria require another bounded attribution sprint.

## Post-fix matrix, readiness, and release-template follow-up — 2026-07-22

### Outcome

The deferred iOS audio-start patch remained clean in every retained physical-device diagnostic report and in a normal launch of the custom release build. No retained log emitted `AudioOutputUnitStart failed`. The build is nevertheless **not release-ready under the unchanged acceptance protocol**: a narrow 15-second harness start boundary prevented completion of the 10-cold-run matrix and prevented the 150-second production soak from reaching its measurement window.

No gameplay rule, authoritative state, simulation timing, prematch duration, renderer, or input behavior was changed during this follow-up.

### Partial physical-device matrix

The fixed full-module debug build was exercised on an iPhone 16 Pro (`iPhone17,1`) running iOS 26.5.2. The ignored evidence directory is `artifacts/startup_hitch_diagnostic/evidence_audio_deferred_full_matrix/`.

| Cohort | Accepted runs | Maximum-frame median | Maximum-frame P95/worst | First-tick median | First-tick P95/worst | Maximum-tick median | Maximum-tick P95/worst | Interactive hitch occurrence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Warm | 10 | 133.819 ms | 142.183 ms | 1.422 ms | 1.540 ms | 2.610 ms | 2.990 ms | 0/10 |
| Cold | 3 | 133.535 ms | 141.824 ms | 1.361 ms | 1.376 ms | 2.717 ms | 4.053 ms | 0/3 |
| Combined | 13 | 133.789 ms | 142.183 ms | — | — | 2.631 ms | 4.053 ms | 0/13 |

All 13 accepted reports completed with `COMPLETE` / `window_elapsed`, passed protected-state integrity, completed one 25-second soak round with zero failures, and recorded zero interactive hitches. All ten warm reports attributed their maximum frame to `arena_deferred_match_flow_scheduled`. The cold-minus-warm maximum-frame median delta was -0.284 ms.

The partial summary is `partial_matrix_summary.json`, SHA-256 `9179a1324464a6ed2c4bd22caf65b2802ba78a031c90aab3733863214980296f`. It is useful diagnostic evidence, but it is not the controlled matrix acceptance result: only 3 of 10 required cold runs completed, and the external battery, Low Power Mode, and initial/final thermal fields were not captured. Those fields must be recorded when the matrix is rerun.

### Acceptance-harness boundary

The unchanged soak harness allows 15,000 ms for the initial match to reach running state. The visible prematch lasts 10,000 ms and remains held while the startup cover is active. Valid launches completed the prematch at approximately 14.875–14.950 seconds, leaving almost no scheduling margin. Later cover releases can therefore make an otherwise healthy launch fail with `initial_match_not_running` before gameplay measurement begins.

After the three accepted cold runs, cold run 4 produced three consecutive observed `initial_match_not_running` attempts under the unchanged protocol. Two rejected reports were retained before any further testing:

- `rejected-cold-04-initial-match-not-running-02.json`, SHA-256 `0fe1b7448a75bda8293052f002f96af17c4abed8391bad54ff3b6f21e1660961`, with presentation completion at 4809.029 ms.
- `rejected-cold-04-initial-match-not-running-03.json`, SHA-256 `6b239beb0b5f8c27c834e311239a7f3f88894f706c6ccf3ba79d9cdeaf4460d6`, with presentation completion at 5555.484 ms.

Both rejected reports still had zero interactive hitches and no native audio-start error, but neither reached canonical gameplay ticks. The first of the three observed failures was overwritten before it could be retained and is not represented as an artifact.

Two attempts to run the unchanged 150-second production soak failed at the same pre-measurement boundary. No 150-second gameplay soak was therefore completed, and neither attempt is an acceptance result. The threshold was not extended, and the gameplay prematch duration was not shortened to make the test pass.

### Local verification

All 28 focused startup, lifecycle, performance, Phase 1, and Phase 2 tests passed after refreshing the local Godot import cache. The initial two texture-related attempts were environment-invalid because the imported `.ctex` cache did not yet exist; their clean reruns are the relevant results.

The default Release Readiness gate also passed:

- MVP smoke: 26 passed, 0 failed.
- Matrix contracts: 15 passed, 0 failed, 13 skipped.
- Boot routes: 8 passed, 0 failed, 5 skipped.
- Soak routes: 3 passed, 0 failed, 0 skipped.
- Final marker: `RELEASE_READINESS_PASS`.

Logs are retained under `artifacts/startup_hitch_diagnostic/evidence_audio_deferred_full_matrix/local_gates/`. The local editor executable is Godot 4.2 stable (`4.2.stable.official.46dc27791`), not the exact 4.2.2 editor. The physical apps and custom engine libraries still use the exact patched Godot 4.2.2 source described below.

### Matching custom release template

A full-module arm64 release library was built from the same patched Godot 4.2.2 source with:

```sh
PYTHONPATH=/path/to/scons-local python3 -m SCons \
  platform=ios \
  target=template_release \
  arch=arm64 \
  -j8 \
  CXXFLAGS=-Wno-module-import-in-extern-c \
  module_raycast_enabled=yes
```

- Custom release device library SHA-256: `57fba584e0a550d3ec21a737cca298a8147e86d007566e2d6cabf89fa7ebe0d4`.
- Combined debug/release template archive: `artifacts/startup_hitch_diagnostic/custom_godot_4_2_2_template/ios-deferred-audio-start-xcode26-full-debug-release.zip`.
- Combined archive SHA-256: `57a7cfeeecd2eb485a6b7c1903fe7637d2d09ad27ae23bb673be826681ef973b`.
- Custom debug device library SHA-256: `517916b03cbadfb612848b87b4df89c60b4ae34e86186f18ebc32fffaa9e5b82`.
- The archive retained the official 4.2.2 release/debug simulator slices and passed `unzip -tq`.

An Xcode Release configuration using that release library built and signed successfully. The installed app retained the exact-source PCK SHA-256 `42d9064e3dd746ca0f9b773f18b26ac41d86d793bd1275e221e1bdebdb722e2e`; its arm64 executable SHA-256 is `d28ceee50f69345f15c94d1d5109930022f8d269abd4d5babe693489d0faec17`. A normal physical-device launch remained alive for 15 seconds with no `AudioOutputUnitStart failed` console event.

An attempted on-device release diagnostic-refusal probe was inconclusive because the reused export did not appear to consume the supplied user arguments and release logging suppressed normal project output. Do not count that probe as device evidence for the refusal policy. The local `startup_hitch_diagnostic_smoke_test` did pass and continues to verify that diagnostic activation is forbidden outside debug builds.

### Defined stopping point and exact next step

The audio-boundary investigation and paired debug/release template construction are complete. The remaining blocker is now a test-contract decision:

1. Either explicitly revise the harness initial-match timeout—for example, to 20 seconds or to a bound defined relative to presentation completion and the 10-second prematch—then rebaseline the acceptance protocol and rerun the complete 10-cold/10-warm matrix plus the 150-second soak; or
2. Retain the 15-second threshold and classify this build as blocked because valid covered startup can consume nearly the entire allowance before the match reaches running state.

Do not change gameplay countdown or prematch behavior to satisfy the harness. If the harness contract is revised, rebuild/install the exact-source debug app, capture battery/Low Power Mode/thermal fields for every controlled cohort, require the native audio error to remain absent, and replace the partial summary with a complete matrix result. The separate long-term engine decision remains whether to carry the narrow 4.2.2 patch with reproducible templates, upstream it, or undertake a fully measured Godot upgrade.

## Twenty-second protocol rerun and thermal stop — 2026-07-22

### Protocol decision

The user explicitly authorized a 20,000 ms initial-match allowance. The rerun used the existing `--soak-start-timeout-ms=20000` override for every physical diagnostic and the production soak. No shared default changed. The visible prematch remains 10 seconds; no gameplay, authoritative state, simulation, countdown, presentation, map, fixture, diagnostic threshold, or post-input acceptance threshold changed.

Cold run 4—the point where three consecutive attempts had failed under the 15,000 ms contract—completed normally under the 20,000 ms contract. This establishes that the longer allowance removes the harness race without shortening gameplay timing.

### Complete timeout20 behavior matrix

The ignored summary is `artifacts/startup_hitch_diagnostic/evidence_audio_deferred_full_matrix/timeout20-complete-matrix-summary.json`, SHA-256 `159c059631c4727d0543b4b5b5d4b6382790391d69204561c62739fe7cfb81a4`.

| Cohort | Eligible reports | Maximum-frame median | Maximum-frame P95/worst | First-tick median | First-tick P95/worst | Maximum-tick median | Maximum-tick P95/worst | Interactive-hitch occurrence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Warm | 10 | 141.891 ms | 148.274 ms | 1.440 ms | 1.556 ms | 2.700 ms | 4.723 ms | 1/10 |
| Cold | 10 | 142.210 ms | 147.801 ms | 1.388 ms | 2.605 ms | 3.125 ms | 4.939 ms | 0/10 |
| Combined | 20 | 141.974 ms | 147.801 ms | 1.401 ms | 1.977 ms, worst 2.605 ms | 2.764 ms | 4.723 ms, worst 4.939 ms | 1/20 |

All 20 selected reports completed with `COMPLETE` / `window_elapsed`, passed protected-state integrity, completed one 25-second soak round with zero failures, and attributed the per-run maximum frame to `arena_deferred_match_flow_scheduled`. The cold-minus-warm maximum-frame median delta was 0.319 ms. All 20 selected console logs were free of `SOAK_ERROR`, `Audio interruption began`, and `AudioOutputUnitStart failed`.

This is a complete **behavior** matrix, but it is not a controlled-environment acceptance matrix. Battery percentage, Low Power Mode, and per-run initial/final thermal state were not recorded. A later focused Time Profiler capture showed the phone at `Serious` thermal state, proving that continued physical testing was no longer eligible and making it unsafe to assume the preceding cohort remained Nominal throughout.

### Isolated interactive hitch

Warm run 3 retained one 126.882 ms `INTERACTIVE` rendered-frame hitch at diagnostic elapsed 15,485.947 ms, approximately 879 ms after the first interactive frame. The report is `timeout20-warm-03.json`, SHA-256 `fa1c991ae41cc8974984fce692a3d2f3684dbbde25a2c81df098c5ca533ec010`.

At the hitch, input was unlocked, gameplay commands were accepted, two authoritative lanes were active, the last canonical tick was 2.152 ms, and the maximum canonical tick for the run was 4.723 ms. The last completed marker was `lane_rebuild_04_completed`; the next bounded work marker did not begin until approximately 330 ms after the hitch. The engine process measurement for the frame was 18.588 ms. The event therefore has no demonstrated GDScript or simulation owner and is compatible with an external scheduling/render-presentation stall, but that classification remains an inference.

The other 19 matrix reports recorded zero interactive hitches. A non-acceptance Time Profiler repetition also recorded zero interactive hitches, a 133.014 ms maximum covered frame, a 1.476 ms first tick, and a 2.714 ms maximum tick. It contained no Instruments potential-hang or hang-risk rows. That clean repetition does not erase warm run 3.

### Transient native audio failure

One attempted cold run 9 emitted `AudioOutputUnitStart failed, code: -50` at the deferred CoreAudio output-start line and never reached a diagnostic report. A plain launch on the same boot repeated the error. The two retained console logs are:

- `rejected-timeout20-cold-09-transient-audio-start-failure.log`, SHA-256 `3efd9f96f635ce335a55135a0da03e2dee5345ef88e8eaa8e41be145a84c2259`.
- `diagnostic-after-cold-09-audio-failure-plain-launch.log`, SHA-256 `8c72737be053a2ceb6414901af0ed77772db47be4857d6204cbf4d8602ae43b4`.

After a full reboot, replacement cold run 9 completed normally and emitted no audio error. `ReplayKitAngel` was present both before and after that reboot, before Swarmfront launched, so process residency alone does not establish ReplayKit as the owner. The two failures remain real, rejected, and unexplained. They prevent claiming that the current single 100 ms deferred audio start is fully reliable.

### Production soak

The production-component soak passed with the rebaselined startup allowance:

```text
--soak-perf
--soak-seconds=150
--soak-round-seconds=150
--soak-pairs=8
--soak-map=res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json
--soak-sim-profile
--soak-start-timeout-ms=20000
```

The console is `timeout20-production-soak-150s.log`, SHA-256 `5fa96b3e81ca7b1d80daa9bb1f9399f603da6afdf619928c2ca0b8ed10ac9c7f`. It completed one 150-second round with zero failed rounds and no audio/interruption error. Across 162 one-second Arena heartbeat windows, the maximum reported frame was 133.6 ms. Across 145 simulation heartbeat windows, the maximum per-window tick was 15.4 ms and 14 windows contained a maximum over 8 ms. These are retained as load telemetry; the prior focused performance gates and Release Readiness pass remain the actual local contract checks.

### Focused thermal evidence

The ignored trace is `focused-time-profiler-warm-01.trace`; its paired report is `focused-time-profiler-warm-01.json`, SHA-256 `29953ee1b9c51154a28823f2ff8a65341888f15eb3da9b5838835aa8184dd960`. Instruments recorded the device thermal state as `Serious` for the trace's full 26.17 seconds. The run is therefore thermally ineligible and is attribution evidence only.

### Current verdict and exact pickup point

The 20-second harness revision is validated, the full behavior matrix is recorded, and the 150-second soak passes. The build is still **not release-ready** because:

1. The required external battery, Low Power Mode, and per-run thermal controls were not captured, and the later trace proves the phone reached `Serious` thermal state.
2. One of 20 selected reports contains a 126.882 ms interactive hitch, violating the post-input target.
3. Two same-boot launches emitted the native `-50` error before a reboot restored clean startup.

Do not continue physical timing work until the phone has cooled and a short Instruments preflight reports `Nominal`. On pickup, record battery percentage, external-power state, Low Power Mode, and Instruments thermal state before and after every run. Reproduce the native audio failure separately from performance acceptance; if it recurs under Nominal conditions, replace the single fixed 100 ms start with a bounded, lifecycle-aware engine-level recovery only after capturing the AVAudioSession state and return codes. For the interactive hitch, repeat focused warm traces under Nominal conditions and retain the first recurrence; do not optimize GDScript or simulation without a trace-owned boundary.
