---
title: "Lock iPhone interface to portrait"
status: completed
completed_at: 2026-09-21
date: 2026-09-21
owner: Samuel
tags: [plan, ios]
---

# Lock iPhone interface to portrait

## Outcome and approval

Wander stays upright in portrait when an iPhone rotates. Samuel approved the
proposed plan in the conversation on 2026-09-21 with "oui".

## Scope and approach

Set the app target's iPhone supported orientations to
`UIInterfaceOrientationPortrait` in Debug and Release. Keep iPad settings and
map camera rotation unchanged. No Swift changes or Git mutations are needed.

## Affected files

- `wander.xcodeproj/project.pbxproj`: update the two iPhone orientation settings.
- `docs/plans/2026-09-21-lock-portrait.md`: track implementation and validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`:
  document portrait-only iPhone behavior under experience principles and update
  the `updated` frontmatter property. Clarify that historical landscape checks
  no longer apply to the iPhone interface.

## Implementation

- [x] Obtain explicit approval.
- [x] Restrict iPhone orientations in both configurations.
- [x] Update the Obsidian UX note and preserve its wikilinks.
- [x] Review the diff and perform available validation; simulator limitation recorded below.

## Risks and validation

The main risk is changing only one build configuration or changing iPad
behavior. Inspect both settings and the built Info.plist. Compile the Debug
scheme and exercise rotations on the existing booted iPhone 17 simulator only.
Do not create or boot another simulator. No dedicated accessibility tests.
No new tests are needed for this configuration-only change; use the build,
generated configuration, and simulator checks as evidence.

## Acceptance criteria

- Both iPhone configurations declare portrait only.
- iPad orientation declarations remain unchanged.
- Build succeeds without new warnings and generated iPhone orientations match.
- The app stays portrait during simulator rotation, or any environment blocker
  is explicitly recorded without claiming that this check passed.
- The UX note is updated, or its exact pending section is recorded if access
  prevents the update.

## Review notes

- Hardest decision: scope the lock to iPhone as explicitly approved.
- Rejected alternative: runtime orientation overrides, unnecessary for this
  configuration change.
- Least certain: simulator access and external Obsidian vault write access.
- No routine solution note is needed for this standard build-setting change.

## Validation results

- PASS: `git diff --check`.
- PASS: `plutil -lint wander.xcodeproj/project.pbxproj`.
- PASS: `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build`.
  Log: `/tmp/wander-lock-portrait-build.log`.
- PASS: the built `wander.app/Info.plist` contains
  `UISupportedInterfaceOrientations~iphone = [UIInterfaceOrientationPortrait]`.
  Both source configurations contain portrait only; the iPad declarations
  are identical to HEAD.
- PASS: the Obsidian note has the new orientation section, an updated
  `updated` timestamp, and unchanged wikilinks. Obsidian was not opened.
- SKIP: visual rotation check. `xcrun simctl list devices booted` succeeded
  with no booted devices. No simulator was booted or created.
- XcodeBuildMCP is not exposed in this session. The `ce-test-xcode` availability
  gate could not pass; native CLI compilation and plist checks were used as
  the equivalent available validation. Overall simulator validation: PARTIAL.
- Existing warnings: extension versions 15 and 27 versus app 42, already
  tracked in `todos/054-ready-p2-aligner-build-extensions.md`; AppIntents
  metadata extraction skipped, previously recorded in todo 025. No warning
  points to the orientation change.
- Simplification: no Swift implementation changed; nothing to simplify.
- Code review: lite review of the two changed settings against the approved
  scope and AGENTS.md. No introduced defect found. Simulator behavior is
  unverified. The plan and external UX note were also checked directly.
- No Git mutations, commit, or PR. Work remains in the approved checkout.
