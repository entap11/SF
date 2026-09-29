# Hero Spot Production Backlog

Status: Phase 0 audit/backlog only; no Blender assets edited  
Audit date: 2026-08-07

## Asset audit

| Asset/capability | Evidence | Readiness |
| --- | --- | --- |
| Cinematic source | `assets/blender/bees/bee_models_cinematic_teaser.blend` | Present through Git LFS. Repository README reports 36 objects, two armatures, and 17 actions. Needs Blender 5-compatible inspection and render QA. |
| Rigged source | `assets/blender/bees/bee_models_with_rig.blend` | Present through Git LFS. Repository README reports 36 objects and two armatures. Needs Blender 5-compatible inspection and render QA. |
| Textures | High/low bee maps and compatibility copies under `assets/blender/bees/` | Present. Relative-path validation still required. |
| Lighting | Authored `HDRI - STUDIO.hdr`; alternate 2K HDR and 4K EXR environments | Present. No certified final lighting setup. |
| Game exports | `assets/models/bees/bee_high.glb`, `bee_low.glb` and texture derivatives | Present. Export parity with current Blender source needs verification. |
| Canonical logo | `assets/branding/swarmfront_logo_1024.png` | Present and governed. |
| Gameplay/cinematic trigger concept | `docs/entap_cinematics_in_game_triggers.md` | Deferred concept; explicitly not trailer V1. Do not make it a hero-spot dependency. |
| Clean marketing capture | No Marketing Capture Candidate record found. | Missing/blocking for gameplay integration. |

The installed Blender is 4.2.17 LTS. Both source files were authored/verified under Blender 5.0.1 according to the repository README and could not be opened by 4.2.17. Internal scene inspection therefore stopped rather than converting or resaving the files. The known skeleton/internal-rig render artifact is carried forward from the marketing production plan and remains unverified locally.

## Bounded backlog

Priority uses `P0` (blocks a credible hero master), `P1` (production polish), `P2` (adaptation), and `P3` (future enhancement).

| ID | Class | Priority | Work item | Acceptance evidence | Depends on |
| --- | --- | --- | --- | --- | --- |
| HERO-001 | Blocking defect | P0 | Open both canonical sources in a supported Blender 5.x version without migration/resave; inventory scenes, collections, objects, armatures, actions, cameras, lights, compositor, render engine, color management, and external paths. | Read-only audit report with Blender version and screenshots; no modified `.blend`. | Supported Blender runtime. |
| HERO-002 | Blocking defect | P0 | Reproduce and isolate bee skeleton/internal-rig artifacts in representative final-quality frames. | Frame numbers, camera, action, render settings, and annotated crops showing cause. | HERO-001. |
| HERO-003 | Blocking defect | P0 | Correct render visibility so bones, armatures, controls, relationship lines, helpers, and internal rig geometry cannot appear in beauty output. | Beauty, alpha, and holdout/checker renders across every used camera/action; zero rig artifacts. | HERO-002; explicit asset-edit authorization. |
| HERO-004 | Blocking defect | P0 | Validate skinning/deformation at extreme poses for body, wings, legs, antennae, and abdomen. | Pose matrix with no collapsing, tearing, intersections that read as defects, or detached parts. | HERO-001. |
| HERO-005 | Blocking defect | P0 | Resolve missing/absolute texture and environment paths, including the documented unused legacy `E:/...HDR` reference. | Pack/path report proves all active dependencies resolve from repository-relative sources on a clean machine. | HERO-001. |
| HERO-006 | Blocking defect | P0 | Inspect model topology, normals, material slots, transparency, emissive behavior, and high/low model mismatch. | Turntable/contact-sheet review at final resolution with defect disposition. | HERO-001. |
| HERO-007 | Blocking defect | P0 | Establish one canonical hero scene/version and protect source/master separation. | Named master, immutable source backup/hash, edit branch, and dependency manifest. | HERO-001 and asset owner. |
| HERO-008 | Blocking defect | P0 | Define final render QA preset and deterministic rerender record. | Versioned preset records engine/device, samples, denoise, motion blur, resolution, FPS, color management, camera, and output path; repeat frames match visually. | HERO-001. |
| HERO-009 | Production polish | P1 | Finalize lighting that preserves silhouette, material separation, team-color readability, and background contrast. | Approved still matrix on bright/dark and representative motion frames; no clipped emissive/highlight detail. | HERO-003–008. |
| HERO-010 | Production polish | P1 | Polish animation timing, weight, wing motion, anticipation, follow-through, and loop boundaries for selected 17-action subset. | Approved playblasts plus frame-range/action manifest. | HERO-004. |
| HERO-011 | Production polish | P1 | Lock camera language and safe crop zones for landscape, square, vertical, and thumbnail use. | Composition guides and crop tests preserve subject/readability without inventing new action. | HERO-009–010. |
| HERO-012 | Production polish | P1 | Establish render consistency checks for exposure, color, motion blur, shadows, DOF, grain, and team colors across shots. | Shot contact sheet and automated/manual checklist with no unexplained drift. | HERO-008–011. |
| HERO-013 | Production polish | P1 | Build a restrained compositing pass: grade, glow, atmosphere, logo/title, legal copy, and audio handoff. | Layered master plus clean beauty; effects do not hide defects or imply nonexistent gameplay. | HERO-012 and copy approval. |
| HERO-014 | Production polish | P1 | Define export masters and review deliverables without lossy-only dependency. | Lossless image sequence or approved mezzanine master, alpha where needed, audio stems, captions/transcript, and checksum manifest; channel encodes remain derivable. | HERO-013. |
| HERO-015 | Production polish | P1 | Run final render QA for dead pixels, rig exposure, texture pop, clipping, banding, aliasing, frame drops, audio sync, title-safe, and spelling. | Two-person checklist across every delivery aspect ratio; issues linked to rerender frames. | HERO-014. |
| HERO-016 | Adaptation work | P2 | Prove a reusable shot/asset package for a **hero spot**. | One approved master with shot list and reuse map. | HERO-015. |
| HERO-017 | Adaptation work | P2 | Adapt a **competition spot** using truthful match stakes and clean gameplay, not merely a new title card. | Distinct argument, at least one materially different shot/sequence, truth review. | HERO-016 + capture candidate. |
| HERO-018 | Adaptation work | P2 | Adapt a **swarm spectacle spot** focused on scale/motion while preserving gameplay truth. | Distinct storyboard and approved scale claim/capture. | HERO-016 + performance/visual approval. |
| HERO-019 | Adaptation work | P2 | Adapt a **manifesto-adjacent spot** that connects one verified promise to product proof. | Canon principle is non-`VERIFY`; claim and shown mechanic match. | Marketing Canon approval. |
| HERO-020 | Adaptation work | P2 | Adapt a **launch spot** only after release timing and availability are public-approved. | Final platform/date/CTA review with current store links. | Release approval; not authorized now. |
| HERO-021 | Blocking defect | P0 | Create a Marketing Capture Candidate for clean gameplay integration. | Git SHA, build, platform/device, resolution, maps, teams, bots, graphics, fixtures, settings, audit result, and raw-capture hashes. | Remaining major visual/gameplay work and separate capture authorization. |
| HERO-022 | Production polish | P1 | Match cinematic-to-gameplay transitions for color, scale, direction, pacing, and audio without disguising the cut. | A/B review shows clear actual-gameplay labeling and no false continuity. | HERO-015 + HERO-021. |
| HERO-023 | Future enhancement | P3 | Evaluate deterministic in-game victory chase camera concept. | Separate design/authority review; presentation never predicts or changes authoritative outcome. | Deferred `entap_cinematics_in_game_triggers.md`; not trailer V1. |
| HERO-024 | Future enhancement | P3 | Evaluate automated multi-aspect reframing and batch encode only after repeated manual deliveries prove stable needs. | At least three completed spots demonstrate the repeated task and extraction value. | HERO-016–020. |

## Spot-family reuse boundary

Reusable across approximately 3–5 spots:

- certified bee model/rig/material package;
- approved action subset and animation cleanup;
- lighting rigs and color-management preset;
- camera/crop guides;
- render/compositing/output presets;
- logo/title-safe package;
- Marketing Capture Candidate clips and provenance manifests;
- final QA checklist.

Each spot still requires a distinct argument, storyboard, timing, and truth review. Replacing only text/music does not count as a genuinely distinct spot.

## Definition of hero-pipeline ready (Gate M3)

- Supported Blender version and canonical master are named.
- All used external dependencies resolve on a clean machine.
- No rig/skeleton/internal artifacts appear in final frames.
- Skinning and model defects pass the pose/turntable matrix.
- One hero spot is approved from a lossless master.
- The adaptation path is demonstrated by at least one materially distinct second spot.
- Clean gameplay integration uses a governed Marketing Capture Candidate.
- Every public mechanic survives the advertising-truth checklist.

Gate M3 is not passed at Phase 0.

