---
name: to-PRD
description: "Turn the current conversation into a grounded PRD and write it to the repo: synthesize what you already explored and decided, no fresh interview."
disable-model-invocation: true
author: NasCarreras
---

This skill turns the current conversation, codebase understanding, and design references into a **PRD** (product requirements document) and writes it into the repo. Synthesize what you already know; do NOT re-interview the user. If decisions are still open, run `grill-me` first, then return here.

A PRD here is **grounded**: every "already exists" and "must build" claim is backed by a file path or design node you actually inspected, not assumed. An ungrounded PRD is the failure mode this skill exists to prevent.

## Process

1. **Ground in the real code.** Explore the actual target repos (not a scratch repo) for the feature's current state. When the surface is large, dispatch read-only `scout` subagents in parallel to map it; wait for their reports before writing. Establish the stack, the components/queries/tables that already exist, and the extension points. Use the project's domain glossary (e.g. `docs/CONTEXT.md`) and respect ADRs in the area.

2. **Ground in the design source.** If a Figma/design or upstream product doc is referenced, read it. Render design nodes to images and inspect them for exact labels, columns, states, and flows rather than guessing. Reconcile any contradiction between design frames and record it as an open question.

3. **Separate exists from must-build.** Produce two explicit lists with evidence: what to reuse (path + one-line note) and what to add. This is the spine of the PRD; a reader must be able to tell, per piece, whether it is a wiring job or new work.

4. **Carry the resolved decisions.** Every design decision settled in the conversation becomes a row in §7's rationale column, inline — don't also duplicate it into a separate decision-log appendix unless the trail itself needs preserving beyond the one-line rationale. Open decisions the user did not settle stay in Open Questions, never silently resolved; if none remain by the time you write, drop that section entirely rather than shipping it empty. Confirm the shared understanding with the user before writing if any decision is ambiguous.

5. **Sketch the seams.** Identify the seams at which the feature will be tested: existing seams over new ones, and the highest seam possible — the fewer seams across the codebase, the better, ideally one. Propose new seams only where none exist, and pitch them at the highest point you can. Check with the user that the proposed seams match their expectations before writing.

6. **Write the PRD** using the template below to `docs/<author>/PRD.md` (or the path the user names), then report the path and the open items that need sign-off. Prefix the project name/stories with the project acronym if one is in the glossary.

<prd-template>

# PRD — <feature>

| Field | Value |
|---|---|
| **Author** | <author> |
| **Scope** | <one line; the narrowed surface> |
| **Status** | 📝 Draft for engineering. |
| **Sources** | <product PRD / Jira / Figma links> |
| **Repos** | <repo names + stack> |
| **Plan** | — (filled in by `to-plan` once a plan directory exists; a filled row means §7/§13/§14 below are frozen) |

**Status icons:** 📝 Draft · 👀 In Review · ✅ Approved · 🔴 Blocked
**Severity icons:** 🔴 High · 🟡 Medium · 🟢 Low

## 1. Problem & Goal
The problem from the user's perspective, and the business goals it serves. **Anti-pattern:** "User can't do \<my solution\>" is not a problem statement — a missing feature is not itself the problem. State the pain that missing feature actually causes; look past the absent feature to the underlying friction, cost, or failure it produces.

## 2. Target Users & Use Cases
Who this is for and the concrete use cases they hit, stated separately from the problem narrative. Note where a use case is niche vs. primary — this drives what belongs in scope for V1 vs. later. Keep this aligned with however the feature will actually be positioned/rolled out; a mismatch between who it's built for and who it's announced to is a sign the scope is wrong.

## 3. Success Metrics
A table: metric | target | timeframe. Each metric must be measurable by something in the design (see Analytics).

## 4. Scope
Table: ID | capability | note. Specific, observable capabilities in V1. Anchor each ID (`<a id="fr1"></a>FR1`) so Must-build, Seams, and Acceptance Criteria can link back to it (`[FR1](#fr1)`) instead of restating it — this is what makes "IDs referenced by later sections" mechanically checkable rather than just a naming convention.

## 5. Out of Scope
Table: item | reason / owner. Each exclusion with the reason it's excluded or the PRD/epic that owns it instead.

## 6. Current State
### 6.1 Already exists — reuse
Table: piece | location (path) | note. Split by repo/layer as needed.
### 6.2 Must build
Table: ID | work item | note. IDs (BE-1, FE-1, …) referenced by later sections.

## 7. Design Decisions
Table: # | decision | chosen | rationale. One row per settled decision from the conversation.

## 8. Seams & Test Boundaries
The seams chosen for testing this feature: existing seams preferred, highest/fewest possible. State what each seam lets a test exercise, and why it was chosen over alternatives.

## 9. Testing Decisions
What makes a good test for this feature (external behavior only, never implementation details); which modules from section 6 get tested; prior art — similar tests already in the codebase to follow as precedent.

## 10. Technical Design
Concrete contracts: schema/API deltas, data flow, per-file frontend/backend changes, derivations. Prefer interface shapes and named extension points over full code. Note documented behaviours (lag, eventual consistency) rather than engineering them away when out of scope.

## 11. Analytics / Instrumentation
Event table mapped 1:1 to the success metrics. State which events answer which metric.

## 12. Acceptance Criteria
Numbered, checkable, exhaustive: covers each in-scope item and each must-build ID.

## 13. Risks
Table: risk | type (risk/dependency) | severity (icon) | disposition. Anything that threatens delivery or is blocked on something outside this PRD's control. **Frozen once a plan exists** (see header **Plan** row) — live risk state moves to the plan's `01-decisions-and-risks.md`; do not edit this table to reflect execution-time changes, only append a note pointing at the plan.

## 14. Open Questions
Table: question | status (icon) | disposition. Unsettled decisions the user did not settle in the conversation; never silently resolved. **Omit this section entirely (and renumber Sequencing up) if every decision was resolved during drafting** — don't ship an empty table. **Frozen once a plan exists**, same rule as §13: resolution status from that point forward lives in the plan's **Open decisions**, not here.

**Question status icons:** 🟡 Open · ✅ Answered · ⏸️ Deferred

## 15. Sequencing
Ordered plan honoring dependencies (backend contract → schema publish → frontend wiring → analytics/tests/flag).

## Appendix A — Source references
Design node ids, doc links, key file paths. If every decision in §7 already carries its rationale inline, fold what would have been a separate decision-log appendix into this one rather than keeping a redundant table — reserve a standalone "Decision log" appendix only when §7 rationale is intentionally terse and the fuller trail matters.

## Appendix B — Reference detail (optional)
For design-heavy features: the full token/spec dump (colors, type scale, spacing, radius, elevation, key components) that §10 Technical Design would otherwise bloat with. Per Length Discipline below, anything here is expected to change independently of sections 1–9 and lives here specifically so it can churn without touching the stable spine.

</prd-template>

## Grounding standard

- Once the header **Plan** row is filled in, §7 Design Decisions, §13 Risks, and §14 Open Questions are a historical snapshot, not a live document — the plan's `01-decisions-and-risks.md` is the single source of truth for decision/risk state from that point on. If the user reports a PRD/plan conflict, the plan wins; fix the drift by updating the plan file, not by editing the frozen PRD sections.

- Never claim a component/query/table exists without a path you inspected. Absent evidence, list it under "must build" or as an open question.
- Never invent file paths or design labels. Render and read the design; grep and read the code.
- Keep the "must build" IDs stable and referenced by Acceptance Criteria and Sequencing, so a reader can trace each work item end to end.

## Length discipline

Push for brevity: sections 1–9 (Problem through Testing Decisions) should stand the test of time and stay stable through design and execution — resist padding them with detail that will only need updating later. Push implementation depth, exhaustive edge cases, and anything volatile into Technical Design, Analytics, and the appendices instead. A PRD that keeps growing past what a reader can hold in one sitting is a sign scope needs splitting into a separate PRD, not that this one needs more sections.
