# Compound Engineering Workflow

This knowledge base follows [Every's Compound Engineering guide](https://every.to/guides/compound-engineering): **Plan → Work → Review → Compound → Repeat**. The objective is for each change to leave the repository easier to understand, validate, and extend.

## Mapbox setup

The main map uses Mapbox Maps SDK for iOS 11.32.0 through the official
[binary Swift package](https://github.com/mapbox/mapbox-maps-ios-binary).
Xcode resolves the exact version declared in `wander.xcodeproj`. Apple MapKit
remains available for place search and geocoding. `LocationTracker` remains
the source of positions and permission requests; the Mapbox location puck is
disabled.

To configure a local build:

1. Copy `Config/Mapbox.local.xcconfig.example` to
   `Config/Mapbox.local.xcconfig`.
2. Set `MAPBOX_ACCESS_TOKEN` in the local file to your public Mapbox token,
   starting with `pk.`.
3. Build the `wander` scheme. Its Debug and Release configurations include
   `Config/Mapbox.xcconfig`, which loads the optional local file. The build
   setting supplies `MBXAccessToken` in the app's Info.plist.

The local configuration is ignored by Git. Do not put a token in the tracked
example, project file, documentation, or logs. CI can supply the
`MAPBOX_ACCESS_TOKEN` Xcode build setting through its build configuration;
avoid echoing the value in build logs.

`MapboxConfiguration` creates the Streets map. The Debug simulator scenario
`-debug-social-map` uses a local background style when no public token is
configured. That mode exercises Mapbox gestures and annotations, but does not
verify downloaded tiles. With a configured token, the scenario loads the real
style. The native map controller tests use an empty local style to isolate
camera, viewport, and annotation behavior from tile requests.

`MapboxFogGeometry` deduplicates H3 cell values, groups them by resolution,
and merges their contours with the native H3 `cellsToLinkedMultiPolygon`
function. CoreGraphics then subtracts those contours from a Mercator world
path, preserving unexplored holes and handling the date line.
`MapboxFogRenderer` sends the resulting polygons to a
GeoJSON source and fill layer. `MapAnnotationStore` hosts the existing UIKit
markers as Mapbox view annotations. The camera and viewport controllers use
Mapbox's native camera and projection APIs; the existing SwiftData and Firebase
exploration data remain unchanged. The compass sits below the profile button.
The logo and attribution track the presented native sheet's frame without
changing the map viewport or camera.

The migration is validated on the existing iPhone 17 Pro simulator. The app
and test targets compile with the official SDKs. All 113 selected native tests
pass, and 26 distinct UI scenarios pass across focused runs 2 through 6.
Twenty repeated renderer tests also pass. Real tiles, the H3 fog ring,
background/foreground return, and attribution placement and telemetry access
have been inspected. These checks use local scenario data; they do not verify
live Firebase exchanges or physical-device haptics.

The [migration plan](plans/2026-10-09-remplacer-mapkit-par-mapbox.md) records the
exact runs, screenshots, and limits. The
[geometry and renderer note](solutions/2026-10-09-fusionner-h3-avant-masque-mapbox.md)
records the H3 merge, synthetic Mac timings, and the source-parsing race fixed
during native validation.

## Artifact Map

- `brainstorms/`: optional exploration when requirements or product direction are unclear.
- `plans/`: implementation blueprints and the source of truth during execution.
- `solutions/`: durable lessons from solved problems, written for future retrieval.
- `../todos/`: prioritized findings discovered during review.

Start from the `_template.md` in the relevant directory. Name documents `YYYY-MM-DD-short-description.md`; name findings `NNN-status-pN-short-description.md`. Keep YAML frontmatter accurate and link related artifacts with relative Markdown links. Move plans through `proposed`, `approved`, `in-progress`, and `completed`; do not implement a `proposed` plan.

## Mandatory Approval Gate

Every repository change requires an explicitly approved plan, including small or unambiguous requests. Codex may perform read-only investigation, then must present the proposed plan to the project owner and stop. The initial request is not approval. No file edit, mutating command, implementation step, or transition to `Work` is allowed until the owner explicitly validates that plan. Once validated, change its status to `approved` before beginning implementation. Any material change to scope or approach returns the plan to `proposed` and requires another explicit validation.

## The Loop

### 1. Plan

Research existing code and authoritative platform documentation. Define the outcome, constraints, non-goals, affected files, edge cases, implementation steps, and validation. For uncertain requirements, write a brainstorm first. Present the proposed plan, request explicit owner approval, and stop. No change—trivial or otherwise—may begin without that approval.

### 2. Work

Use the plan as the working checklist. Implement one coherent step at a time and validate proportionally to risk. Update the plan when discoveries change the approach; never let code silently diverge from it.

### 3. Review

Compare the diff with the plan, test the affected user journeys, and inspect security, data integrity, performance, accessibility, and native iOS behavior. Record unresolved findings in `todos/` as `P1` (must fix), `P2` (should fix), or `P3` (optional). Before approval, answer:

1. What was the hardest decision?
2. Which alternatives were rejected, and why?
3. What remains least certain?

### 4. Compound

For a reusable or surprising lesson, create a solution note covering root cause, resolution, evidence, and prevention. Update `AGENTS.md` only when the lesson is a durable rule that should guide every future task. Skip solution notes for routine changes to avoid documentation noise.
