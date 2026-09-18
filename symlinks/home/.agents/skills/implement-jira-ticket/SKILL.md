---
name: implement-jira-ticket
description: Use when the user asks to implement a JIRA ticket, story, or task end to end. The skill reads the ticket from Jira, reads or generates an implementation plan, implements the approved scope on a dedicated branch with an isolated execution team, requests explicit user approval before committing and before pushing, then invokes the pull-request skill to produce a draft pull request with the plan attached.
disable-model-invocation: false
author: NasCarreras
---

# Implement JIRA Ticket

Implement a JIRA ticket end to end: read inputs, plan, implement in gated phases with independent review, obtain approval gates before committing and pushing, and produce a draft PR with the implementation plan attached.

Invocation examples:

```text
/skill:implement-jira-ticket DEMO-123
/skill:implement-jira-ticket DEMO-123 ~/Developer/AI/DEMO-123.md
/skill:implement-jira-ticket DEMO-123 project-plan: ~/Developer/AI/project.md implementation-plan: ~/Developer/AI/DEMO-123.md
```

## Inputs

| Input | Rule |
|---|---|
| **JIRA ticket** | Required. Ticket key (e.g. `DEMO-123`) or full Jira URL. |
| **Project plan** | Optional. Absolute path to a feature-level plan covering related stories. Read-only background context; never modify it. |
| **Implementation plan** | Optional. Absolute path to the plan for this ticket. If absent, generate it at `~/Developer/AI/<TICKET-ID>.md` before writing any code. |

**Read all inputs before doing anything else.** Fetch the Jira ticket and all linked artefacts; read the project plan and implementation plan if paths are provided.

**Project plan** provides feature-level context — related stories, dependencies, and architectural direction. Use it as background when generating the implementation plan.

**Implementation plan** is the authoritative source for architecture, implementation sequence, scope boundaries, and design decisions. Where it conflicts with the Jira ticket, raise the discrepancy before proceeding.

## Contract

- Treat the ticket's acceptance criteria as the authoritative scope. Do not materially change scope without documenting and approving the change.
- If the implementation plan is not provided, generate it and write it to `~/Developer/AI/<TICKET-ID>.md` before writing any code.
- All changes must be contained within a single repository. If a second repository is required, stop and raise it with the user before proceeding.
- Never commit until the user explicitly approves the presented diff.
- Never push or invoke `skill://pull-request` until the user explicitly approves the presented push and PR summary.
- Keep the PR in **draft**. Do not request reviewers. Do not mark ready for review. Do not merge.
- Write the implementation report to `~/Developer/AI/<TICKET-ID>-report.md` and present the path to the user on completion.
- Make no unsupported completion claim. Every claim must point to an observed diff, command result, or runtime observation.

## Execution Team

Create an isolated execution group for this ticket:

- **Lead orchestrator** — accountable for the full outcome; the only thread that authorizes commits, pushes, and PRs.
- **Implementation** — owns all code changes.
- **Testing & verification** — owns automated, integration, and manual verification.
- **Architecture & integration** — owns consistency, interface boundaries, and compatibility.
- **Adversarial review** — independently challenges the plan and implementation.

Each thread owns its own subagents. No subagent is shared with another project task. A reviewer must not be the producer of the work under review.

## Workflow

### Gate 1: Read Inputs and Plan

1. Read all inputs: fetch the Jira ticket and linked artefacts; read the project plan and implementation plan if provided.
2. If the implementation plan is absent, generate it at `~/Developer/AI/<TICKET-ID>.md`. Use the project plan as context if available. The plan must cover scope, architecture, implementation sequence, and acceptance criteria.
3. Inspect the repository: working tree, current branch, `origin` remote, related branches and PRs.
4. **Branch bootstrap:**
   - If the `<TICKET-ID>` branch does not exist, create it from the latest `origin/main`.
   - If the branch already exists, inspect its commits and working tree. Resume it only when its existing work belongs to this ticket and the worktree contains no unrelated changes. Never reset, rebase, or repoint it without explicit user approval.
   - If existing work is found on the branch, present a summary of those changes to the user and confirm the intent to build on top of them before proceeding.
5. Extract every acceptance criterion, dependency, and out-of-scope sibling ticket.
6. Have each specialist thread independently review the scope and surface risks, gaps, and conflicts.
7. Repeat until ownership is explicit, criteria are testable, and no major planning gaps remain.

Exit only when the plan, repository state, and acceptance criteria are explicit and valid.

### Gate 2: Implement Each Phase

For each phase:

1. Confirm dependencies are ready; check for new external changes.
2. Implement the approved scope; migrate all affected callers; remove obsolete code.
3. Run narrow checks exercising the changed behaviour.
4. Submit to an independent reviewer; remediate all major findings.
5. Collect concrete evidence of correct behaviour.

Do not stop at a phase boundary while later phases remain actionable.

### Gate 3: Integrated Verification

1. Run the applicable build, lint, type checks, automated tests, and end-to-end scenarios.
2. Map every acceptance criterion to **Pass**, **Fail**, or **Blocked** with observed evidence.
3. Run a final adversarial review of the integrated diff.
4. Remediate all major findings and rerun invalidated checks.

Exit only when no major finding remains and every criterion has an evidence-backed status.

### Gate 4: Commit Approval

Present to the user before committing:

- Full diff and a plain-language summary of every change.
- Proposed commit message.

Do not commit until the user explicitly approves. Then read and follow `skill://code-commit`.

### Gate 5: Push and PR Approval

Present to the user before pushing or creating the PR:

- Branch name and target base branch.
- Summary of commits to be pushed.
- Draft PR title and description.
- Resolved implementation plan path to be attached.

Do not push or invoke `skill://pull-request` until the user explicitly approves.

Once approved, invoke `skill://pull-request` passing:

```
Create a PR for <Jira ticket URL>.
Implementation plan: <resolved implementation plan path>
```

The resolved path is the implementation plan path from **Inputs** if provided, otherwise `~/Developer/AI/<TICKET-ID>.md`.

### Gate 6: Implementation Report

Write the report to `~/Developer/AI/<TICKET-ID>-report.md` and present the path to the user.

Include:

1. **Executive summary** — ticket, scope, status, outcome.
2. **Execution team** — threads, subagent summary, isolation confirmation.
3. **Implementation details** — components changed, design decisions, interface changes.
4. **Project coordination** — external tasks, dependencies, conflicts resolved.
5. **Scope changes** — original expectation, approved change, reason, impact.
6. **Testing & verification** — tests added, commands run, results, evidence.
7. **Adversarial review** — findings, reproduction, remediation, remaining limitations.
8. **Acceptance criteria** — each criterion, status, evidence, qualifications.
9. **PR details** — branch, title, reference, target, commit summary, draft confirmation.
10. **Final assessment** — exactly one of: **Complete** / **Complete with documented minor limitations** / **Incomplete**.

## Definition of Done

- Ticket scope implemented end to end and product goal achieved.
- Execution group isolated; no subagents shared with other tasks.
- All acceptance criteria evaluated; all major findings resolved.
- Material scope changes documented and approved.
- All changes contained within the single target repository.
- Parallel and overlapping work reconciled; shared interfaces compatible.
- Implementation report written to `~/Developer/AI/<TICKET-ID>-report.md`.
- Draft PR created, technically review-ready, and **not** merged.
