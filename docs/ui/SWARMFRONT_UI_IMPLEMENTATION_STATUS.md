# Swarmfront UI Implementation Status

Status: Time-sensitive implementation record
Governed by: [UX & Menu Visuals Bible](UX_MENU_VISUALS_BIBLE.md)
Skin: [Swarmfront Game Skin](SWARMFRONT_GAME_SKIN.md)
Snapshot date: 2026-07-16

This record may become stale without changing the validity of the normative UX standard.

## Established

- Canonical 1080 × 1920 portrait viewport and `keep_width` behavior
- Canonical Swarmfront logo source
- Shared semantic typography tokens in `UITypography`
- 64-unit baseline mobile touch target
- Larger Dashboard tabs and readable Garage category grid
- Dashboard Settings as a modal category workspace with 2× menu type tokens, 64-unit controls, explicit Call Sign commit, player-only content, and persistent DONE/Back escape behavior
- Portrait stacking for Buffs and Achievements dashboard panels
- Enlarged primary Hive pull-down with explicit Back action
- Persistent bottom “BACK TO MAIN MENU” action in Jukebox
- Identity-first pre-match presentation with redundant map/mode facts removed; countdown and actionable setup prompts remain
- Content-hugging post-match modal with scrollable details and an always-visible responsive action footer
- Portrait smoke coverage for Dashboard, Settings, Hive, Jukebox, and dense post-match layout/exit behavior
- Dark panel, steel edge, and honey-gold emphasis direction
- Hex background presets for Store, Hive, Dash, and Popup contexts

## Partial adoption

- Typography tokens exist but are not used by every menu.
- Button styling is split among raw Godot buttons, `UIButton`, `HexButton`, sprite-backed controls, and local helpers.
- Color roles are recognizable, but values remain duplicated across scripts.
- Several dialogs meet touch sizing, while older utilities still use 30–52-unit controls.
- Main flows are portrait-first, but tablet/large-screen references are not declared.
- Some art buttons contain baked text, limiting responsive layout and localization.
- Modal behavior is implemented screen by screen rather than through one shared template.

## Known migration debt

- Complete type-token adoption across menus and dialogs
- Consolidate a semantic theme/component layer
- Normalize Back, Close, Cancel, Apply, and Confirm usage
- Guarantee persistent escape actions on every overlay
- Remove clipped copy, raw identifiers, and development language
- Add unified focus/controller behavior and restoration
- Add safe-area tokens instead of screen-specific margins
- Standardize loading, empty, offline, locked, pending, and error components
- Separate localized live labels from artwork
- Add localization expansion and missing-glyph testing
- Complete reduced-motion and accessibility audits
- Add menu open/close resource-baseline tests
- Automate screenshot matrices across declared reference sizes

## Component migration order

1. **Type roles** — one shared token source
2. **Action button** — primary, secondary, tertiary, destructive, escape
3. **Panel surface** — standard, elevated, modal, selected
4. **Screen frame** — title, context, content, persistent action/safe area
5. **Tabs and segmented control** — selected/focus/disabled states
6. **List/grid item** — selected, locked, pending, empty
7. **Modal template** — title, focus trap, scroll body, primary, escape
8. **Status components** — loading, empty, error, offline
9. **Toast/banner** — supplemental event feedback
10. **Focus/accessibility layer** — input-mode-independent behavior

Component code owns behavior and semantic styling. Game Skin resources supply palette, typography, imagery, sound, and motion values.

## Current exclusions

- Map topology or map visual redesign
- In-match lane, hive, unit, or capture-rule presentation
- Economy or progression rule changes
- Gameplay-state architecture changes

## Updating this record

Update the snapshot date whenever an item changes category. Do not modify the normative bible merely to make this status record match an implementation shortcut.
