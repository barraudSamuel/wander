# Repository Guidelines

## Project Structure & Module Organization

`wander/` contains the SwiftUI app, MapKit rendering, SwiftData models, and Firebase services. City data is under `wander/Cities/` and `Cities/`. Assets live in `wander/Assets.xcassets`, configuration in `wander/Info.plist`, and Firestore rules at the root. Development artifacts and reusable knowledge live in `docs/`; review findings live in `todos/`.

## Build, Test, and Development Commands

- `open wander.xcodeproj`: open and run the `wander` scheme in Xcode.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build`: perform a CLI debug build.
- `firebase deploy --only firestore:rules`: publish reviewed rules to the selected Firebase project.

Xcode resolves Firebase and H3Swift with Swift Package Manager.

## Coding Style & Naming Conventions

Use four-space indentation and Xcode's Swift formatting. Use `UpperCamelCase` for types, `lowerCamelCase` for members, and `*View` for views. Prefer one primary type per file, `// MARK: -` sections, narrow access control, and main-actor UI updates. Treat compiler warnings as defects.

## Native iOS Design Direction

Until explicitly changed by the project owner, use only Apple's default iOS visual language. Prefer standard SwiftUI/UIKit controls, navigation, sheets, alerts, toolbars, SF Symbols, semantic system colors, Dynamic Type, and platform spacing. Do not add custom fonts, decorative gradients or shadows, bespoke cards/buttons, nonstandard navigation, or third-party UI libraries. Custom drawing is allowed only where core map, heat-map, or fog behavior requires it; surrounding controls must remain native and accessible.

## Compound Engineering Workflow

Follow `Plan → Work → Review → Compound` as documented in `docs/README.md`. For non-trivial work, use the installed Compound Engineering skills when they are available:

- For a new or still-ambiguous feature, invoke `ce-brainstorm`, then `ce-plan`.
- For an existing plan or a clear implementation request, invoke `ce-work`.
- For a bug or unexplained failure, invoke `ce-debug`.
- After implementation, invoke `ce-simplify-code`, run the appropriate validation (`ce-test-xcode` for iOS flows), then invoke `ce-code-review`.
- After a verified, reusable learning emerges, invoke `ce-compound`.

### Mandatory Plan Approval Gate

Before changing any code, configuration, documentation, tests, or repository state, Codex must:

1. Perform only the read-only investigation needed to understand the request.
2. Write and present a concrete plan covering the outcome, scope, affected files, implementation steps, risks, and validation.
3. Keep the plan in `proposed` status and stop the turn.
4. Ask the project owner to explicitly approve the plan.

The original implementation request does not count as plan approval. Codex must not edit files, run mutating commands, begin implementation, or advance to the next workflow stage until the owner explicitly replies that the presented plan is approved. This gate applies to every change, including trivial or apparently unambiguous changes. After approval, mark the plan `approved` before starting work. If the approach or scope changes materially during implementation, stop again, present the revised plan, and obtain a new explicit approval.

Keep the approved plan checklist current, validate before completion, record review findings as prioritized files in `todos/`, and capture reusable lessons in `docs/solutions/`. Never invoke `ce-commit`, `ce-commit-push-pr`, `ce-babysit-pr`, or `lfg` without an explicit user request. If the plugin or a required skill is unavailable, follow the equivalent workflow manually and say so. Update `AGENTS.md` only for durable repository-wide rules, not task-specific notes.

## Testing Guidelines

There is no XCTest target yet. Verify affected flows on a simulator or device. Add non-UI tests to a future `wanderTests` target using `<TypeName>Tests.swift`; record exact validation in the plan and PR.

## Commit & Pull Request Guidelines

Use focused Conventional Commits such as `feat(map): ...`, `fix: ...`, and `perf: ...`. PRs must explain user impact, link the plan or issue, list validation, and include screenshots for UI/map changes. Highlight permission, migration, Firebase schema, and rule changes.

## Security & Configuration

Never commit `GoogleService-Info*.plist`, signing assets, or `.env` files. Review `firestore.rules` with data-model or sync changes. Never log precise locations or authentication identifiers.
