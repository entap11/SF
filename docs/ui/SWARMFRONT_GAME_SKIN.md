# Swarmfront Game Skin

Status: Non-normative title implementation v0.1
Governed by: [UX & Menu Visuals Bible](UX_MENU_VISUALS_BIBLE.md)
Last reviewed: 2026-07-15

This document defines Swarmfront's replaceable visual implementation. It may evolve without changing UX Core behavior.

## Identity

Swarmfront's interface language is forged dark metal, restrained honey-gold energy, and hex-derived geometry.

The emotional target is:

- Tactical
- Industrial
- Charged

The interface should not glow everywhere. Gold is a scarce hierarchy signal.

## Reference canvases

| Class | Reference | Purpose |
| --- | --- | --- |
| Authored portrait | 1080 × 1920 | Primary Swarmfront viewport |
| Narrow/tall stress | 944 × 2048 | Clipping and hidden-exit validation |
| Small portrait | 720 × 1280 | Density and minimum-size validation |
| Tablet/large | Must be declared before tablet release | Line length and dead-space validation |

Godot currently uses `viewport` stretch with `keep_width` aspect behavior.

## Typography

Primary interface face: Iceland
Limited display treatments: specialized atlas fonts only where their character set is known and static

Current shared tokens live in `res://scripts/ui/ui_typography.gd`.

Menu and dashboard portrait surfaces use the shared 2× scale. Player-facing pre-match, in-game, and post-match surfaces use a 2.5× scale—25% larger—because attention is split between UI and the playfield and the device is commonly held farther away.

| Token | Base size | Menu/dashboard portrait 2× | Pre/in/post-match portrait 2.5× |
| --- | ---: | ---: | ---: |
| `screen_title` | 28 | 56 | 70 |
| `panel_title` | 24 | 48 | 60 |
| `section_title` | 18 | 36 | 45 |
| `panel_subtitle` | 17 | 34 | 43 |
| `body` | 16 | 32 | 40 |
| `meta` | 15 | 30 | 38 |
| `button` | 17 | 34 | 43 |
| `compact_button` | 15 | 30 | 38 |

Atlas fonts must not receive dynamic player-facing copy. Frame art and live text should remain separate.

## Spacing and touch

Swarmfront uses a 4-unit authored-canvas rhythm:

| Token | Value | Typical use |
| --- | ---: | --- |
| `space_1` | 4 | Tight internal relationships |
| `space_2` | 8 | Button groups and compact rows |
| `space_3` | 12 | Standard sibling separation |
| `space_4` | 16 | Control padding |
| `space_6` | 24 | Panel padding and section gaps |
| `space_8` | 32 | Major section separation |
| `space_12` | 48 | Screen-level separation |

Current mobile control floor: 64 authored units high
Standard menu actions: 64–72
Persistent or high-consequence actions: 88–112

These are Swarmfront authored-canvas values, not automatic numeric requirements for another title.

## Working palette

| Role | Approximate value | Use |
| --- | --- | --- |
| Deep background | `#0A0A0D` | Page foundation |
| Panel background | `#14171F` at high opacity | Readable content surfaces |
| Elevated popup | `#0F121A` at near-opaque | Modal/dropdown separation |
| Steel edge | `#595C70` | Secondary boundaries |
| Honey gold | `#F7BA30` | Primary emphasis and currency |
| Warm text | `#FFF0B8` | Primary action labels |
| Cool body text | `#EBEDF3` | General reading |
| Muted text | `#AEB3C0` | Nonessential metadata only |
| Destructive red | Muted dark red plus light red edge | Consequential actions |

## Control treatments

| Type | Swarmfront treatment |
| --- | --- |
| Primary | Warm dark fill, gold edge, brightest readable label |
| Secondary | Cool charcoal fill, steel edge, light label |
| Tertiary | Quiet dark surface; compact but readable |
| Destructive | Restrained red edge/fill plus explicit consequence copy |
| Escape | Visually secondary, persistent, and easy to locate |

Interactive state must remain stronger than seams, particles, and decorative glow.

## Backgrounds and surfaces

- Dense text sits on a stable near-opaque panel.
- Hex seams, particles, and animated energy are atmosphere, not navigation.
- Important copy does not sit directly over logos or high-frequency texture.
- Store, Hive, Dash, and Popup contexts currently have distinct hex background presets.

## Imagery and assets

- Canonical logo source: `res://assets/branding/swarmfront_logo_1024.png`
- Sprite inventory: [SF UI Sprites V1](SF_UI_SPRITES_V1.md)
- Background presets: `res://ui/backgrounds/HexBgPresets.gd`
- Shared typography: `res://scripts/ui/ui_typography.gd`

Selected and locked state layers should remain independent from base art. Logos and character renders preserve aspect ratio and never define hit geometry.

## Motion and sound direction

Motion should feel mechanical and energized without becoming ceremonial during frequent navigation.

- State response is immediate.
- Panel transitions are short and purposeful.
- Persistent ambient movement remains quieter than selection or confirmation.
- Reduced-motion mode uses immediate updates or restrained crossfades.
- Navigation, confirmation, and warning sounds remain distinct.

Exact timing and sound values remain open for device tuning.

## Skin prohibitions

Swarmfront's skin must never:

- Hide or displace an escape route
- Use gold on every action
- Bake dynamic or localized labels into art
- Make decoration look more actionable than controls
- Use unsupported display-font characters for dynamic copy
- Override UX Core semantics to preserve a visual composition
