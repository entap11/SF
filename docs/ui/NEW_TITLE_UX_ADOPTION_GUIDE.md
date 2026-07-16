# New-Title UX Adoption Guide

Status: Maintained adoption guide
Governed by: [UX & Menu Visuals Bible](UX_MENU_VISUALS_BIBLE.md)

Do not begin a new title by copying Swarmfront's finished screens. Adopt the UX Core and create a new Game Skin.

## Adoption sequence

1. Adopt the semantic type roles, spacing rhythm, navigation vocabulary, state model, and release gates.
2. Declare exact target devices, reference canvases, viewport strategy, safe areas, and accessibility targets.
3. Complete the Game Skin worksheet.
4. Build semantic components with neutral placeholder styling.
5. Prove one representative screen at every declared reference size.
6. Apply the Game Skin to components, not individual screens.
7. Validate loading, empty, error, locked, disabled, selected, localized, focused, and scrolled states.
8. Add screenshot, focus, resource-baseline, and interaction tests before multiplying screens.

## Game Skin worksheet

```text
Title:
Audience and platform:
Emotional promise (three words):
World/material metaphor:

Primary typeface:
Secondary/readability typeface:
Display-only typeface or treatment:

Page background:
Panel surface:
Elevated/modal surface:
Primary accent:
Secondary accent:
Body text:
Muted text:
Success:
Warning:
Destructive:

Primary control silhouette:
Secondary control silhouette:
Panel geometry:
Icon style:
Illustration/render style:

Default motion character:
Reduced-motion behavior:
Navigation sound:
Confirm sound:
Warning sound:

Primary authored canvas/responsive baseline:
Minimum supported physical size:
Maximum supported aspect ratio:
Narrow/tall stress reference:
Tablet/large-screen reference:
Safe-area configurations:
Text/UI scaling behavior:
Minimum physical touch target:
Contrast target:

Localization expansion target:
Right-to-left commitment:
Low-end performance target:

What this skin must never do:
Three reference screens:
```

## Screen design brief

Every new menu starts with this brief before polished art:

```text
Screen:
Player goal:
Entry points:
Exit destination:
Primary action, if any:
Secondary actions:
Unsaved-change behavior:
Information required to decide:
Loading state:
Empty state:
Error/offline state:
Locked state:
Pending/async behavior:
Scrollable region:
Persistent controls:
Initial focus:
Focus restoration target:
Supported input modes:
State read from:
Intent(s) emitted:
Reference sizes and safe areas tested:
Localization stress cases:
Accessibility considerations:
Performance considerations:
Analytics/telemetry events:
```

If the player goal or exit destination is unclear, the screen is not ready for visual design. A browsing or orientation screen may correctly have no primary action.

## Portability test

The system is portable when a new palette, font family, silhouette, icon set, and motion profile can be applied without rewriting navigation behavior, screen state, or interaction tests.

If a visual change requires changing the meaning of Back, selected, disabled, loading, pending, or primary, the Game Skin has crossed into UX Core and needs explicit review.

## Adoption completion

Adoption is complete when:

- The title has a reviewed Game Skin.
- Exact reference canvases and physical checks are recorded.
- Core components implement supported input, focus, accessibility, and content states.
- One representative flow passes the normative release checklist.
- Analytics can fail without affecting the experience.
- Repeated menu use returns to a stable resource baseline.
