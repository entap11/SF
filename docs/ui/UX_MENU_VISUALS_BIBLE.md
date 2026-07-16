# UX & Menu Visuals Bible

Status: Normative working standard v0.2
Scope: Menus, dashboards, HUDs, modal flows, blocking in-match and post-match overlays, out-of-match navigation, and reusable UI presentation
Last reviewed: 2026-07-15

## 1. Purpose and document model

This document is the normative source of truth for how ENTaP games organize, present, and validate player-facing UX.

The documentation family deliberately separates permanent behavior from title-specific and time-sensitive material:

- **This bible** defines required product behavior and portable UX doctrine.
- [Swarmfront Game Skin](SWARMFRONT_GAME_SKIN.md) defines Swarmfront's replaceable visual implementation values.
- [Swarmfront UI Implementation Status](SWARMFRONT_UI_IMPLEMENTATION_STATUS.md) records current adoption, debt, and migration progress.
- [New-Title UX Adoption Guide](NEW_TITLE_UX_ADOPTION_GUIDE.md) provides the screen brief and Game Skin worksheet.
- [Swarmfront UI Sprite Inventory](SF_UI_SPRITES_V1.md) records available and planned artwork.

Normative sections in this bible define required product behavior. Companion documents describe implementations and may change without altering the UX Core.

The goal is not to make every screen or title look identical. The goal is to make every screen feel internally coherent, every title feel deliberately skinned, and every ENTaP product behave according to a shared interaction standard.

## 2. Requirement language and precedence

### 2.1 Requirement language

- **MUST** indicates a release requirement. Failure requires correction or an approved exception.
- **SHOULD** indicates the expected implementation. Deviation requires a documented reason.
- **MAY** indicates an optional technique that remains subject to all applicable requirements.

Unqualified declarative rules in the UX Core are treated as MUST requirements unless the text explicitly provides flexibility.

### 2.2 Order of precedence

When requirements collide, use this order:

1. Player safety, legal requirements, accessibility, and platform requirements
2. UX Core
3. Title-specific Game Skin
4. Screen-specific design decisions

A Game Skin or screen-specific exception MUST NOT weaken navigation safety, accessibility, state clarity, touch geometry, or authoritative-state boundaries.

## 3. Product promise

Every player-facing screen or blocking overlay MUST answer four questions immediately:

1. **Where am I?**
2. **What can I do here?**
3. **What is the most important action, if any?**
4. **How do I leave or go back?**

If an answer requires experimentation, scrolling without a cue, or force-quitting the application, the screen is not ready.

## 4. Non-negotiable UX principles

### 4.1 Clarity before spectacle

Art supports interaction. It MUST NOT compete with labels, obscure state, or determine hit geometry.

- Readability beats ornament.
- A plain working control beats a beautiful ambiguous control.
- Decorative effects MUST remain quieter than interactive state.
- Branding moments MAY be large, but MUST NOT displace the screen's purpose or escape action.

### 4.2 One screen, one player goal

Every screen has one dominant player goal. A navigational hub MAY offer several peer destinations because its job is to orient and route the player. It MUST NOT simultaneously ask the player to complete unrelated transactions, configure detailed settings, and consume substantial explanatory content.

Examples:

- Jukebox: choose and inspect a map, then play.
- Garage: inspect and equip cosmetics.
- Hive entry menu: create, find, or enter a hive.
- Battle pass: inspect progression and claim rewards.
- Dashboard: orient the player and route them to peer account tools.

### 4.3 Zero or one dominant action

Each decision step has zero or one visually dominant action. Do not manufacture a primary action on screens whose purpose is browsing, comparison, or orientation.

Other actions are secondary, tertiary, escape, or destructive. Repeated accent color, glow, animation, or oversized art creates fake primaries and destroys hierarchy.

### 4.4 A visible escape route

Every non-root screen and modal MUST provide an explicit way out.

- The escape control remains visible while content scrolls.
- It is never hidden below a long list.
- It uses text, not an unexplained icon alone.
- System Back/Escape MAY duplicate it, but MUST NOT be the only route.
- Opening a screen MUST NOT trap the player.

### 4.5 Design for the real device

Screens MUST be reviewed at their actual physical size and expected viewing distance. A desktop editor preview is not release evidence for mobile readability.

- HUD messages, pause flows, match-result overlays, post-match summaries, and their actions use the same physical readability and touch floors as menu UI.
- Font sizes are evaluated after final viewport and content scaling; an authored numeric size alone is not evidence of compliance.
- Developer diagnostics MAY use a compact diagnostic scale in development builds, but MUST NOT carry essential player decisions or ship as the only explanation of player-facing state.

### 4.6 Progressive disclosure

Show the decision first and explanation second.

- Put the current selection and next action above detail.
- Collapse developer notes and technical metadata.
- Reveal advanced controls only when relevant.
- Avoid presenting an entire feature database as one uninterrupted screen.

### 4.7 State must be explicit

Selected, available, locked, disabled, loading, empty, pending, success, and error are distinct states. They require distinct copy and presentation.

Color alone MUST NOT communicate state.

## 5. UX Core versus Game Skin

| UX Core: portable | Game Skin: replaceable |
| --- | --- |
| Navigation behavior | Logo and key art |
| Screen hierarchy | Display font |
| Type roles and physical minimums | Exact typeface pairing and authored values |
| Touch geometry | Button silhouette |
| Semantic spacing rhythm | Numeric spacing scale |
| Button semantics | Palette and glow color |
| Modal and scrolling behavior | Icons and illustrations |
| Loading, empty, and error states | Sound and motion personality |
| Accessibility and QA gates | Branded transitions |
| State/intent architecture | Game-specific terminology |

Future games SHOULD adopt the UX Core and define a new Game Skin. They MUST NOT fork interaction semantics solely to create visual differentiation.

## 6. Navigation vocabulary

Labels describe outcomes. Use these terms consistently:

| Label | Meaning | Behavior |
| --- | --- | --- |
| **Back** | Return to the previous navigational level | Preserve safe, already-applied state |
| **Close** | Dismiss a non-sequential overlay | Return to the screen beneath it |
| **Cancel** | Abandon an in-progress edit or transaction | Restore the pre-edit value |
| **Done** | Finish a flow whose changes apply immediately | Close the flow |
| **Apply** | Commit reversible settings without necessarily leaving | Remain or close as stated |
| **Confirm** | Approve a consequential decision | Show the consequence in nearby copy |
| **Play / Enter / Buy / Claim** | Perform the named domain action | Never replace with generic “OK” |

Rules:

- Use **Back** when the player navigated deeper; use **Close** for a non-sequential overlay.
- Back MUST NOT discard unsaved work without warning.
- An icon-only X MUST NOT be the sole escape route on mobile.
- A destructive action SHOULD name the object and consequence: “LEAVE HIVE,” not “CONFIRM.”
- Do not alternate between “Main Menu,” “Home,” and “Dashboard” for the same destination.

### 6.1 Unsaved-change contract

Every editable flow MUST declare one behavior before implementation:

1. Changes apply immediately and **Done** closes the flow.
2. Changes remain staged until **Apply** or another named commit action.
3. Leaving prompts the player to discard changes or continue editing.

Back, Close, system Back, scene replacement, and app interruption MUST follow the same declared behavior. Closing a flow MUST NOT silently commit or discard changes contrary to that contract.

## 7. Screen anatomy and navigation structures

The default portrait screen follows this order:

```text
┌────────────────────────────────────┐
│ System-safe top / global status    │
│ Screen title                       │
│ Short purpose or current context   │
├────────────────────────────────────┤
│ Primary decision / selected item   │
│                                    │
│ Scrollable supporting content      │
│                                    │
├────────────────────────────────────┤
│ Persistent primary or escape area  │
│ System-safe bottom                 │
└────────────────────────────────────┘
```

Not every screen needs every band. The reading order remains stable:

1. Identity and context
2. Current state or selection
3. Available choices
4. Action, if applicable
5. Escape

### 7.1 Global navigation

Global navigation is for top-level destinations only. It MUST NOT visually compete with an active task or modal.

When a modal is open:

- Background navigation is inert.
- The background is visibly subordinate.
- Only modal actions receive input or accessibility focus.
- The modal owns a visible Close, Back, or Cancel action.

### 7.2 Tabs

Tabs switch peer views without changing navigational depth.

- Selected tabs use at least two signals: fill/border plus text or marker.
- Tabs MUST NOT look identical to primary actions.
- Labels remain short; the strip MAY scroll when necessary.
- Text MUST NOT shrink below its minimum merely to fit all tabs.

### 7.3 Lists and grids

- Prefer one-column lists for descriptive choices.
- Use grids for visually comparable items with short labels.
- Narrow portrait grids SHOULD use no more than three columns for ordinary text buttons.
- Preserve a consistent reading order.
- Make the entire item row actionable, not only its label or icon.

## 8. Responsive layout standard

### 8.1 Declared reference canvases

Before menu implementation begins, each title MUST declare exact references for:

- Primary authored canvas or responsive baseline
- Minimum supported physical size
- Maximum supported aspect ratio
- Narrow/tall stress case
- Tablet or large-screen case when supported
- Safe-area configurations
- Text/UI scaling behavior

“Representative device” without a named resolution, scale, safe-area configuration, and physical-size check is not sufficient release evidence. Title-specific values belong in the Game Skin.

### 8.2 Safe areas

- Interactive controls MUST NOT touch unsafe device edges.
- Persistent bottom actions sit above the system-safe inset.
- Scroll content receives bottom padding equal to the persistent action area.
- Top branding and titles remain below the system-safe top inset.
- Safe-area handling is layout data, never an art-image assumption.

### 8.3 Reflow before shrink

When space becomes constrained, use this order:

1. Remove low-priority explanatory copy.
2. Stack horizontal panels vertically.
3. Reduce column count.
4. Allow intentional scrolling.
5. Shorten copy without changing meaning.
6. Reduce decoration.
7. Only then consider a modest type reduction, never below the declared physical floor.

### 8.4 Scrolling

- A scroll region has one clear axis.
- Nested vertical scroll regions are prohibited unless a platform convention requires them.
- Primary and escape actions remain outside long scroll regions.
- Content MUST NOT appear cut off without a scroll affordance.
- Returning to a list SHOULD preserve a useful position.

## 9. Typography system

Typography is semantic. Code and design refer to roles, not arbitrary pixel sizes.

| Role | Purpose | Guidance |
| --- | --- | --- |
| Display | Rare branded moments | Logos and event identity; never body copy |
| Screen title | Names the current destination | One per screen |
| Panel title | Names a major content block | Short and scannable |
| Section title | Names a subsection or list | Visually distinct from body |
| Subtitle | One-line purpose or context | Omit if it adds no information |
| Body | Decisions, descriptions, values | Primary reading size |
| Meta | Secondary metadata | Never essential instructions |
| Button | Action label | Short, active, high contrast |
| Compact button | Tabs and constrained controls | Not for primary actions |

Each title MUST declare numeric values and physical-size floors for these roles. A Game Skin MAY change the numbers and fonts, but MUST preserve the hierarchy and readability contract.

The declared roles apply wherever live player-facing text appears, including HUD status, blocking match overlays, post-match results, and persistent in-game navigation.

- Stylized faces SHOULD be limited to short labels and headings.
- Limited-character fonts MUST NOT be used for dynamic copy.
- Unsupported characters MUST NOT disappear silently.
- Avoid long all-caps paragraphs.
- Avoid outlines and glow on body copy.
- Text baked into art is not a reusable component solution; frame art and live text SHOULD remain separate.

### 9.1 Copy density

- Screen subtitle: one short sentence.
- Button label: preferably one to three words.
- Panel introduction: one or two lines.
- Technical notes belong in diagnostics, help, or development builds.
- Empty space MUST NOT be filled with prose merely to look occupied.

## 10. Spacing and touch geometry

Every title MUST define a semantic spacing scale with at least tight, standard, section, panel, and screen-level roles. The rhythm is portable; exact authored units are title-specific.

- Touch targets MUST meet the title's declared physical floor and platform requirements.
- Transparent hit padding MAY enlarge a target whose visible art is smaller.
- Adjacent targets MUST have deliberate separation.
- A target MUST NOT shrink because its icon looks small.
- Important targets SHOULD avoid screen corners and unsafe edges.

## 11. Button hierarchy, states, and feedback

### 11.1 Hierarchy

| Type | Use |
| --- | --- |
| Primary | The next or dominant action in a decision step |
| Secondary | An alternate safe action |
| Tertiary | Tabs, filters, and low-emphasis utilities |
| Destructive | An irreversible or socially consequential action |
| Escape | Back, Close, or Cancel |

### 11.2 Required states

Every actionable component MUST support applicable states:

- Default
- Hover where pointer exists
- Pressed
- Keyboard/controller/accessibility focus
- Selected
- Disabled
- Loading or pending
- Error

Disabled is not merely lower opacity. It includes a reason when the player could reasonably expect the action to work.

### 11.3 Feedback and asynchronous actions

- Press feedback begins immediately.
- Success or failure appears near the initiating action.
- Toasts supplement state changes; they do not replace persistent state.

Once an asynchronous action is accepted:

- The initiating control prevents duplicate submission.
- The UI preserves enough context to display the canonical result.
- Leaving the screen MUST NOT manufacture success, failure, or cancellation.
- Re-entering the screen renders authoritative current state.
- A presentation timeout MUST NOT imply transaction failure unless the authoritative operation reports failure.

## 12. Color and surface system

- Body text targets at least 4.5:1 contrast against its actual background.
- Large text and essential non-text controls target at least 3:1.
- Decorative glow does not count toward contrast.
- Color is paired with text, shape, icon, or position to indicate state.
- Interactive surfaces are distinguishable from decorative frames.
- Background texture remains below the contrast needs of foreground content.
- Dense text sits on a stable surface.
- Important labels MUST NOT sit directly over high-frequency art.

Exact palette, material language, and surface recipes belong in the Game Skin.

## 13. Iconography and imagery

- Icons reinforce labels; they MUST NOT replace unfamiliar actions.
- Use one icon metaphor per action across a title.
- Maintain a consistent stroke, perspective, material, and lighting family.
- Selected and locked overlays remain separate state layers, not baked variants of every asset.
- Key art uses aspect-preserving containers and MUST NOT define interaction bounds.
- Crop intentionally; never stretch logos or character art.
- Essential information MUST NOT exist only inside an image.

## 14. Modal, drawer, and overlay contracts

### 14.1 Modal

Use a modal for a focused decision that temporarily blocks the parent screen.

- Clear title and purpose
- Zero or one primary action
- One explicit escape action
- Dimmed, inert background
- Bounded content with intentional scrolling when needed
- Persistent action area outside long content

### 14.2 Drawer

Use a drawer for peer navigation or a workspace that benefits from retaining background context.

- Drawer position remains consistent.
- Opening or closing does not change gameplay state.
- The drawer owns a visible handle or Close/Back action.
- Background input behavior is explicit.

### 14.3 Full-screen destination

Use a full-screen destination for deep browsing, progression, commerce, or tasks with multiple subviews. It receives its own screen title and Back route.

## 15. Content-state contract

Every data-driven surface defines these states before visual polish:

| State | Required presentation |
| --- | --- |
| Loading | Stable skeleton/progress and plain-language status |
| Empty | What is empty, why it matters, and the next useful action |
| Error | What failed, what remains safe, and retry/back options |
| Offline | Which features remain available and which require connection |
| Locked | Requirement and, when appropriate, route to unlock |
| Pending | Prevent duplicate input and show that work continues |
| Success | Updated state plus a clear next action when needed |

Raw identifiers, debug labels, and placeholder “Unknown” copy MUST NOT appear in a final player-facing state when a graceful fallback is possible.

## 16. Motion and sound

Motion explains change and reinforces hierarchy.

- Small state transitions SHOULD be brief.
- Frequent navigation MUST NOT use long blocking reveals.
- Motion SHOULD animate position, opacity, or emphasis with a clear purpose.
- Decorative elements MUST NOT all animate simultaneously.
- Reduced-motion behavior is required.
- UI timing is presentation-only and MUST NOT mutate or infer gameplay state.

Sound follows the same hierarchy: restrained navigation, clear confirmation, distinct warning, and no repeated noise during scrolling.

Exact duration, easing, and sound values belong in the Game Skin.

## 17. Copy, localization, and dynamic content

Interface copy is direct, specific, and player-facing.

- Start buttons with verbs: Play, Browse, Claim, Equip, Leave.
- Prefer concrete nouns: Hive, Map, Loadout, Reward.
- Remove implementation language such as “profile-backed,” “scaffold,” and raw state names.
- Explain restrictions next to the restricted action.
- Use sentence case for prose. Branded all-caps MAY be used for short navigation labels.
- Numbers use consistent separators, units, currency formatting, and time formats.
- Novelty copy MUST NOT obscure a purchase or destructive decision.

Player-facing components MUST tolerate:

- At least 30–50% text expansion
- Long player, group, map, and event names
- Plural and variable-number substitution
- Missing-glyph fallback
- Right-to-left layout where the title commits to supporting it

Truncation MUST be intentional and MUST NOT hide the distinction between consequential actions.

## 18. Input and focus contract

- Every actionable flow MUST work with each supported input mode.
- Opening a modal moves focus into it.
- Focus MUST NOT escape to inert background controls.
- Closing a modal restores focus to the invoking control or nearest valid replacement.
- System Back/Escape resolves only the topmost active layer.
- One physical input event MUST trigger at most one semantic action.
- Touch, mouse, controller, keyboard, and accessibility paths MUST produce equivalent outcomes.
- Input-mode changes SHOULD preserve the player's current context and selection.

## 19. Accessibility baseline

Every release candidate MUST support:

- Readable text at target physical size
- Required contrast
- Declared touch target floor
- Visible focus state
- Logical focus and reading order
- Color-independent state communication
- Accessibility labels where supported
- Reduced motion
- No essential information that exists only in an image
- Dynamic text tolerance or a documented platform constraint

Accessibility is part of component definition, not a final polish pass.

## 20. Technical architecture contract

### 20.1 Authoritative state

- Simulation or operations state is the source of truth.
- UI reads authoritative state and renders it.
- UI emits intents or commands.
- UI, input, and render layers MUST NOT mutate gameplay state directly.
- Visual state MUST NOT be used to infer gameplay state.
- Opening, closing, or animating a menu has no hidden gameplay side effect.
- Presentation caches are disposable and never become a second authority.

Reusable components SHOULD receive semantic inputs such as `primary`, `selected`, `locked`, or `loading`, rather than reconstructing styles from raw values on every screen.

### 20.2 Permissible UI-local state

UI MAY own disposable view-local state such as:

- Focus and hover
- Scroll position
- Expanded or collapsed sections
- Temporary animation progress
- An explicitly uncommitted edit buffer

View-local state MUST NOT become evidence that a gameplay, economy, identity, purchase, or progression operation succeeded.

### 20.3 Analytics boundary

Analytics observes UI behavior. It MUST NOT determine whether an action succeeds, block navigation, delay feedback, or become authoritative product state. Analytics failure MUST be invisible to the player.

## 21. Menu performance contract

- Animation MUST NOT delay input availability unless the transition intentionally blocks interaction.
- Decorative animation MUST NOT cause sustained node, material, texture, or memory growth.
- Repeated opening and closing MUST return to a stable resource baseline.
- Loading remote data MUST NOT block Back, Close, or safe local navigation.
- Performance validation MUST use representative low-end target hardware.
- A title SHOULD define measurable frame-time, memory, and load-time budgets before release hardening.

## 22. Review and iteration loop

Use this loop for Ralph-style visual iteration or any human/AI design pass:

1. Capture the current screen at every declared reference size.
2. Write the screen's player goal and primary action, if any, in one sentence.
3. Mark failures by severity:
   - **P0**: trapped player, inaccessible action, purchase/destructive ambiguity
   - **P1**: clipped essential copy, unreadable decision, broken state feedback
   - **P2**: inconsistent hierarchy, density, spacing, or terminology
   - **P3**: cosmetic polish and atmosphere
4. Fix navigation and comprehension before ornament.
5. Change a small, named set of variables per pass.
6. Capture the same states and sizes again.
7. Run interaction, focus, and layout tests.
8. Record accepted UX decisions here and visual decisions in the Game Skin.

Do not judge a pass solely from a static beauty shot. Verify normal, selected, disabled, loading, pending, empty, error, localized, focused, and scrolled states.

## 23. Release acceptance checklist

A menu is release-ready only when all applicable items pass.

### Purpose and hierarchy

- [ ] The destination is named.
- [ ] The player goal is understandable within a few seconds.
- [ ] There is zero or one dominant action per decision step.
- [ ] Essential information is visually stronger than decoration.

### Navigation and editing

- [ ] A visible Back, Close, or Cancel route exists.
- [ ] The escape route remains reachable while content scrolls or loads.
- [ ] System Back/Escape resolves the topmost active layer.
- [ ] Background controls cannot activate through a modal.
- [ ] Editable flows declare and honor their unsaved-change behavior.

### Layout and readability

- [ ] Every exact title reference size and safe-area case has been reviewed.
- [ ] Essential text and controls do not clip.
- [ ] Type and touch geometry meet declared physical floors.
- [ ] Scrolling is obvious and intentional.
- [ ] Localization expansion and long dynamic names have been tested.

### Input and accessibility

- [ ] Supported input modes produce equivalent outcomes.
- [ ] Focus enters, remains within, and exits modals correctly.
- [ ] One physical event triggers no more than one semantic action.
- [ ] Selected and disabled states use more than color alone.
- [ ] Reduced-motion behavior works.

### State and feedback

- [ ] Applicable loading, empty, error, offline, locked, pending, and success states exist.
- [ ] Asynchronous actions prevent duplicates and render canonical results.
- [ ] Failed actions explain recovery.
- [ ] Presentation timeout does not manufacture authoritative failure.

### Architecture, performance, and verification

- [ ] UI reads authoritative state and emits intents only.
- [ ] No gameplay rules live in menu or render code.
- [ ] Analytics failure cannot affect player outcomes or navigation.
- [ ] Repeated open/close cycles return to a stable resource baseline.
- [ ] Layout, interaction, focus, and screenshot tests pass.
- [ ] Player-facing copy contains no debug language or raw identifiers.

## 24. Governance

- This bible owns interaction and presentation behavior for menus.
- Game-specific canon owns terminology and fiction.
- Simulation specifications own gameplay rules.
- Game Skins own title-specific visual values but MUST conform to this bible.
- Asset inventories describe artwork and do not override UX behavior.
- Exceptions require a player benefit, affected screens, violated requirement, test plan, approver, and review date.
- A repeated exception SHOULD become a component or revised core rule, not permanent screen-local handling.

When this document and an existing screen disagree, treat the screen as migration work unless a newer approved decision explicitly supersedes the bible.
