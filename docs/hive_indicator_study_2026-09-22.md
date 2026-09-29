# Hive indicator reference — September 22

The floor pass is committed and pushed. The next review is hive artwork and the
placement of power/lane indicators before growth, shrinkage and pressure polish.

This first study retains the existing industrial artwork, pending the owner's
visual-direction preference. Following owner feedback, the revised proposal shows
only a white power number and a spaced row of lane sockets, with subtle dark
outlines for contrast. The black card, frame, ownership stripe and divider are
removed. The duplicate fuchsia indicators on the lower rim are also hidden in
the proposed version. Filled sockets remain available and hollow sockets occupied.
The number remains centered for longer values. Power text uses the current display's
effective size. The study includes all three tiers, occupied/full slots, selected
state and a three-digit red-player example.

This is a proposal in an isolated rendering fixture, not a production UI change.
No gameplay state, rules, art files or existing effects have been changed. The
enlarged comparisons do not establish phone-size readability. Review the indicators'
footprint and relationship to the hive before integration; the final hive art and
effects remain separate follow-up work.

Run `tools/hive_indicator_reference.gd` with Godot's `--script` argument in an
isolated offline test project. Keys 1–4 change owner, Space changes occupied slots,
S toggles selection, and P switches the large hive between 35 and 125 power.
Append `-- --capture` to export the four examples. Set `SF_HIVE_REFERENCE_DIR`
to choose the output directory. Fixture values only feed presentation nodes.

Review gallery: outer workspace
`artifacts/hive-indicator-reference-2026-09-22/index.html`.
