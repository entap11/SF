# Hive Port Geometry Experiment

Status: Approved direction; implementation plan under iteration
Date: 2026-07-15
Initial port count: 16 per hive

## Goal

Give every hive a deterministic set of lane attachment ports so incident lanes have distinct, stable, visually coherent endpoints.

The system must:

- Prefer the port closest to the connected hive's bearing.
- Never choose a “next closest” port that tangles or crosses the existing lane fan at that hive.
- Reuse a newly available port when doing so shortens an existing lane.
- Propagate shortening opportunities through connected hives until the network reaches a stable assignment.
- Make endpoint changes visually subtle.
- Never reject an otherwise valid lane connection because ordinary ports are occupied.

## Capacity decision

The current playable-map audit covers 16 maps.

- Maximum potential hive degree: 12.
- Two current No Man's Land variants reach degree 12.
- Several maps exceed degree 8.
- Sixteen ports therefore provide four ordinary spare ports above the densest current topology.

The repeatable audit lives at `res://tools/hive_port_capacity_audit.gd`.

## Authority boundary

Port assignment is gameplay geometry, not renderer-owned decoration.

- Simulation state owns the assigned port index at each end of each lane.
- Assignment and rebalancing run deterministically in simulation code.
- The edge cache derives canonical lane endpoints from those assignments.
- Lane and unit renderers consume the same canonical endpoints.
- The presentation layer may interpolate between old and new endpoints, but it may not choose ports or mutate the assignment.
- Port movement does not create a second gameplay state in the renderer.

The likely persisted fields are `a_port_index` and `b_port_index` on `LaneData`, including snapshot/replay serialization.

## Port geometry

- Each hive exposes 16 ordinary ports.
- Port `0` is at twelve o'clock.
- Indices increase clockwise.
- Ports are evenly spaced by angle: 22.5 degrees apart.
- Each port is projected onto the canonical hive lane shell, so attachment geometry remains coupled to hive size.
- The shell is art-calibrated toward the lower skirt: horizontal bearings receive the full skirt Y offset, diagonals receive a proportional offset, and vertical bearings receive no extra offset.
- The skirt offset follows the deterministic small/medium/large/max power tier so larger hive art retains the same socket alignment.
- A final 10px art-calibration offset lowers horizontal sockets to the visible skirt edge and blends proportionally into diagonal bearings.
- Opposing horizontal endpoints therefore meet matching points on the visible source and destination bases instead of crossing the hive waist.
- Ports are invisible during normal play.
- A development-only overlay may show port indices, occupancy, and reassignment.

## Terminology

**Desired bearing**
The center-to-center direction from the local hive to the other hive.

**Incident lane**
Any active lane connected to the local hive, regardless of flow direction or ownership.

**Local lane fan**
The ordered set of incident lane segments as they leave a shared hive shell.

**Local crossing**
A port assignment that reverses the clockwise order of incident lanes relative to the clockwise order of their desired bearings, causing the lane fan to tangle near the hive.

**Map-level crossing**
An intersection caused by the wider map topology. Existing lane overlap/gap presentation may still handle these. Ordinary port assignment must not introduce an additional local crossing.

## Assignment priority

For a newly created lane endpoint, candidates are evaluated in this order:

1. Preserve connection legality. Port scarcity never rejects the lane.
2. Preserve the clockwise order of the local lane fan; crossing candidates are invalid.
3. Use an unoccupied ordinary port.
4. Minimize true lane length with the far endpoint held fixed.
5. Minimize angular distance from the desired bearing.
6. Prefer the existing assignment when costs are effectively equal.
7. Resolve remaining ties by lower port index, then lower lane ID.

“Next closest” therefore means the closest **legal, non-crossing** available port, not simply the next numerical or clockwise index.

## Non-crossing rule

For each hive:

1. Sort incident lane endpoints by desired bearing clockwise.
2. Break equal-bearing ties by the other hive ID, then lane ID.
3. Assigned ordinary port indices must have the same cyclic order.
4. A new endpoint may use only a free port that can be inserted without reversing that order.
5. If no such free port exists between its angular neighbors, the solver may shift an adjacent chain of existing endpoints while preserving cyclic order.
6. The solver chooses the legal shift with the lowest total lane-length cost.

This order constraint prevents local fan crossings without relying on renderer pixels or frame-by-frame visual inference.

## Stable insertion

The first implementation should favor stability:

- Preserve existing assignments when the new lane can be inserted legally.
- Move the fewest existing endpoints needed to create a legal ordered slot.
- Among equal move counts, choose the smallest total lane length.
- Do not reorganize unrelated hives during initial insertion.
- Commit the assignment atomically at a simulation boundary.

This makes lane creation predictable while leaving full network optimization to the rebalancing phase.

## Rebalancing after a port becomes free

When a lane disappears or changes its assigned endpoint:

1. Enqueue both affected hives in ascending hive-ID order.
2. At each hive, solve the order-preserving assignment for all incident endpoints while holding far endpoints fixed.
3. Accept a new assignment only when it strictly reduces total canonical lane length beyond a small numeric epsilon.
4. Prefer fewer moved endpoints when two assignments have equivalent length.
5. Enqueue the opposite hive of every moved lane, because its best local assignment may now change.
6. Continue until the queue is empty and no accepted move reduces the global total.
7. Use deterministic queue order and tie-breaking.
8. Impose a generous deterministic iteration guard and fail safely to the last valid assignment if violated.

Because every accepted step strictly reduces one global length objective, the process terminates rather than oscillating.

## Presentation of reassignment

Simulation assignments change atomically. Presentation makes them nearly imperceptible.

- Interpolate the rendered endpoint from its previous port to its new port.
- Use a short, eased transition rather than a snap.
- Keep lanes and units on the same interpolated presentation path.
- Do not alter simulation travel progress during the visual transition.
- Do not emit per-frame logs.
- Provide a reduced-motion mode that uses a very short crossfade or immediate update.

Exact duration and easing will be tuned from device captures after canonical assignment works.

## Exhaustion and override contract

Sixteen ordinary ports are a layout preference, not a connection cap.

If no unique ordinary port can satisfy the connection:

- The connection remains valid.
- The system enters an explicit overflow mode rather than silently rejecting it.
- Overflow must preserve local cyclic order and avoid a local crossing.
- A likely first override is a shared/stacked boundary port with a short ordered fan-out outside the hive shell.
- Controlled overlap or a shared launch path is preferable to either crossing or rejecting the connection.
- The final overflow geometry will be designed and tested as a separate phase.

Until the overflow phase is enabled, the legacy continuous shell anchor remains the safe compatibility fallback and must not affect connection legality.

## Implementation phases

### Phase 0 — Capacity audit

Complete.

- Audit playable map candidate degrees.
- Establish 16 ordinary ports.

### Phase 1 — Pure deterministic assignment

- Add a simulation-safe `HivePortGeometry`/assignment helper.
- Generate the 16 elliptical port positions.
- Implement stable insertion and cyclic-order validation.
- Keep it independent of render nodes and frame timing.
- Add unit tests for bearings, ties, occupied ports, wraparound, and non-crossing insertion.

### Phase 2 — Authoritative integration

- Add endpoint port indices to `LaneData`.
- Include assignments in snapshots, replay state, and deterministic signatures.
- Invoke assignment only from the owning simulation system.
- Make `EdgeCacheSystem` build canonical geometry from assigned ports.
- Keep the legacy anchor path as a compatibility fallback.
- Verify units and lanes consume identical endpoints.

### Phase 3 — Local release/reassignment

- Detect freed ports from lane topology changes.
- Solve local order-preserving shortening.
- Verify no crossing and no unnecessary movement.

### Phase 4 — Network ripple

- Add the deterministic connected-hive work queue.
- Prove monotonic total-length reduction and termination.
- Verify replay and multiplayer determinism.

### Phase 5 — Subtle presentation

- Interpolate lane and unit presentation together.
- Tune duration/easing on target devices.
- Add reduced-motion behavior.

### Phase 6 — Exhaustion overrides

- Implement and validate stacked/fan-out overflow geometry.
- Stress more than 16 incident connections.
- Prove that port exhaustion never blocks lane creation.

## Acceptance tests

- Sixteen stable port positions are generated for every supported hive radius.
- Identical state produces identical assignments across runs.
- Lane IDs and endpoint orientation survive snapshot/replay round trips.
- Adding a lane uses the closest legal non-crossing port.
- Stable insertion moves no existing endpoint when an ordered free slot exists.
- Every local lane fan preserves cyclic bearing order, including the 15-to-0 wraparound.
- Freeing a port never lengthens total canonical lane geometry.
- Ripple processing terminates and is independent of dictionary iteration order.
- Lane renderer and unit renderer use the same endpoints.
- Port exhaustion never rejects an otherwise valid connection.
- Normal play shows no port-debug visuals or per-frame logs.

## Explicitly deferred

- Changing lane legality, walls, occlusion, or map topology
- Prohibiting unavoidable map-level lane intersections
- Changing lane budgets or hive power rules
- Final overflow art treatment
- Final transition timing and easing
