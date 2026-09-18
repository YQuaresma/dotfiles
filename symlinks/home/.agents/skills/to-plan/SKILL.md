---
name: to-plan
description: Turn a PRD into a phased execution plan directory — a PLAN.md index plus decisions-and-risks, phases-and-gates, rollout, and traceability files derived from the PRD's must-build items and sequencing; no fresh interview, and stops short of story/ticket breakdown.
disable-model-invocation: true
author: NasCarreras
---

This skill turns a **PRD** (product requirements document) into a **multi-file execution plan** and writes it into the repo. Synthesize from the PRD and the code it references; do NOT re-interview the user or re-derive requirements. If the PRD's Open Questions still hold an unresolved *decision* that gates work, surface it and stop until the user settles it — a plan built on an open decision is the failure mode this skill prevents.

The output is a **plan directory**: one `PLAN.md` **index** that a reviewer reads first, plus **numbered companion files** it links, each owning one concern. The plan is the bridge from the PRD to `plan-execution`: it groups the PRD's **must-build IDs** (`BE-1`, `FE-3`, …) into gated phases. It stops at phases; the `US-*`/`EN-*` story breakdown is `to-tickets`' job, run against this plan.

## Traceability standard

- Every must-build ID in the PRD's §6.2 lands in exactly one phase. Account for all of them; a dropped ID is a hole in the plan.
- Every phase names the PRD IDs it delivers and the PRD acceptance criteria it satisfies, so a reader traces plan → PRD → acceptance end to end.
- Derive phase order from the PRD's §15 Sequencing and the dependencies between IDs. Never invent work absent from the PRD; if the PRD is missing a step the sequence needs, record it in `01-decisions-and-risks.md` as an open decision, don't paper over it.

## Process

1. **Read the PRD in full.** Resolve the path (argument, or the one just written). Read §6.2 Must build, §12 Acceptance Criteria, §13 Risks, §14 Open Questions, §15 Sequencing, and the source/repo baseline. If any §14 item is an unresolved *decision* (not a risk or dependency) that gates work, stop and ask the user to settle it.

2. **Pin the source baseline.** Record each repo the plan touches with its default branch and the exact revision you inspected (the commit SHA), so every architecture claim is attributable to inspected code, not assumption. Spot-check that the extension points the PRD names still exist; note drift.

3. **Group IDs into phases.** A **phase** is a set of IDs that land together and verify as one checkpoint, honoring dependency order. Prefer the fewest phases that keep each independently verifiable. Cross-repo contract boundaries (backend schema → published package → frontend codegen) become phase boundaries, not intra-phase steps.

4. **Define gates.** Each phase ends on a concrete, checkable gate drawn from the PRD acceptance criteria plus the repo's validation commands (from the environment, e.g. `check:all`/`test:quiet`). Later phases start only after the prior gate passes.

5. **Capture decisions and risks.** Lift the PRD's settled decisions (§7) into **Agreed decisions**, its unresolved decisions (§14) into **Open decisions** — each tagged with its owner, whether it awaits a human call or peer investigation, and the phase it must clear before — and its risks/dependencies (§13) into **Risks & unknowns**. A gating open decision still stops the run (step 1); a non-gating one is recorded here and named beside the phase it touches.

6. **Write the plan directory** to `docs/<author>/plan/` (or the path the user names), then report the directory, the phase count, the count of open vs agreed decisions, and any drift found. Prefix the feature with the project acronym if one is in the glossary.

7. **Freeze the PRD's copies.** Set the PRD header's **Plan** row to the plan directory path. From this point, `01-decisions-and-risks.md` is the single live source for decision/risk state — never edit the PRD's §7/§13/§14 tables again to reflect new information; update this plan file instead. If the PRD lacks a **Plan** header row (older PRD), add one.

## Output layout

Write `PLAN.md` as the index plus these companion files. One file per concern; `PLAN.md` links each in a **Review order** list.

- **`PLAN.md`** — index. Sections: Status; **Source baseline** table (repo | default branch | inspected revision | role); Scope (inherited from PRD); **Required repository changes** table (repo | required change); **Review order** (links to each companion file, one line each); **Dependency map** (mermaid across the must-build IDs, covering every §6.2 ID); Handoff (`plan-execution` runs this, working phases in order, stopping at each gate). It carries no decision content itself — it links `01-decisions-and-risks.md`.
- **`01-decisions-and-risks.md`** — three sections: **Agreed decisions** (settled, each with rationale + PRD reference); **Open decisions** (needs peer investigation or awaiting a human call — each with owner, what unblocks it, and the phase it must clear before); **Risks & unknowns** (each with impact and mitigation/disposition). This is the single home for decision state; other files reference it rather than restating it. Once this file exists, it supersedes the PRD's §7/§13/§14 as the live record — the PRD keeps its original tables only as a frozen point-in-time snapshot. A PRD/plan conflict is resolved in favor of this file, not the PRD.
- **`02-phases-and-gates.md`** — the phased execution plan. Per phase: Delivers (PRD IDs), Depends on, Steps (behaviour, naming IDs), Gate (acceptance criteria # + validation command).
- **`03-rollout-and-acceptance.md`** — deployment order across repos, feature-flag rollout, verification/monitoring, rollback, and the acceptance gates that mark the feature releasable.
- **`04-traceability.md`** — tables: PRD acceptance criterion → phase; repository → phase/IDs; must-build ID → phase. Confirms full coverage.

## Boundaries

- This produces a **phased plan directory**, not a story/ticket breakdown and not tracker tickets. Run `to-tickets` against this plan to decompose phases into `US-*`/`EN-*` stories or tracker tickets with blocking edges; run `plan-execution` to execute it.
- Avoid volatile file paths and code snippets in phase steps (they go stale); name components, IDs, and contracts. Exception: a schema/type/state-machine shape that encodes a decision more precisely than prose — inline the decision-rich part only.
