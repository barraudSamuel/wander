# Compound Engineering Workflow

This knowledge base follows [Every's Compound Engineering guide](https://every.to/guides/compound-engineering): **Plan → Work → Review → Compound → Repeat**. The objective is for each change to leave the repository easier to understand, validate, and extend.

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
