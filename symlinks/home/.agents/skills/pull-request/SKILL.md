---
name: pull-request
description: Use when creating a pull request — enforces a Conventional Commits (conventionalcommits.org v1.0.0) style title, a short body (under 10 lines: what, why, how verified), and confirms title/description/base branch with the user before creation and merge strategy before merging.
author: NasCarreras
---

# Pull Request

Four responsibilities: confirm the PR's shape with the user before creating
it, write the title to Conventional Commits spec, keep the body short, and
never pick a merge strategy unilaterally.

The body is the part that goes wrong. The default failure is a wall of
headings restating the diff — write under 10 lines unless length is genuinely
load-bearing (§3).

## 1. Confirm before creating — every time

Per sticky rules, never create a PR without agreeing on title, description,
and base branch first. Don't guess and open it silently:

- **Base branch** — default to the repo's default branch (usually `main`)
  unless the user names another; confirm if ambiguous (e.g. stacked PRs,
  release branches).
- **Title** — propose the Conventional Commits line (see below), let the
  user adjust.
- **Description** — propose the body (see below), let the user adjust.

Only run `gh pr create` (or equivalent) once these three are agreed.

## 2. Title format — Conventional Commits v1.0.0

Same grammar as commit messages (see the `code-commit` skill for full
type/scope/breaking-change rules):

```
<type>[optional scope][!]: <description>
```

- Imperative, lowercase, no trailing period: `fix(alias): pin eza icons flag`.
- One logical change per PR → one type. A PR mixing unrelated types signals
  it should be split, not that the title should smush multiple `type:`
  prefixes together.
- Breaking change → `!` after type/scope, and/or a `BREAKING CHANGE:` footer
  in the body.
- If the PR is a straight carry of a single commit, the title MAY just reuse
  that commit's message line verbatim.

## 3. Body — short by default

**Target: under 10 lines.** A reviewer reads the diff; the body exists to say
what they can't see from it. Cover three things and stop:

- **What + why** — one or two sentences. The problem, not the diff.
- **How verified** — one line, naming what was actually run. Never claim
  verification that didn't happen.
- **Footers** — `Refs #123`, `Closes #123`, and `BREAKING CHANGE: <what now
  fails>` when behaviour breaks.

Example — this is a normal-sized body, not a minimal one:

```
fix(alias): pin eza icons flag

`--icons` takes an optional value, so a bare trailing arg (`la t`) was
swallowed as the value instead of a path: "invalid value 't' for '--icons'".
Pin every eza alias to `--icons=auto`.

Verified: `la /tmp/eza_test t` now treats `t` as a path.
```

Never write these:

- Markdown section headings (`## What`, `## Changes`, `## Testing`) — at this
  length they cost more than they organise.
- A per-file or per-commit inventory. That's `git log` and the Files tab.
- Restating the diff in prose, or re-explaining a rationale already in the
  commit messages.
- Verification transcripts. One line of claim, not pasted output.
- Marketing ("comprehensive", "robust") or self-praise.

Go longer **only** when the extra length is load-bearing, and prefer adding
one short paragraph over adding structure:

- Multiple independent changes landing together (a squash) where each
  rationale would otherwise be lost.
- A security fix whose exploitability the reviewer must grasp to judge it.
- A migration the reader has to perform by hand.

Even then: prose paragraphs, no headings, and keep it scannable. If the body
needs sections to be followable, the PR is probably too big — split it.

## 4. Creating the PR

```bash
gh pr create --base <base> --title "<type(scope): description>" --body "<body>"
```

Confirm the branch is already pushed (`git push -u origin <branch>`) before
calling `gh pr create` — it will fail otherwise.

## 5. Merge strategy — never assume

Per sticky rules, always ask before choosing squash/merge/rebase, even if
the user asked you to "merge the PR." Present the options
(`squash` / `merge commit` / `rebase`) and wait for an explicit choice before
running `gh pr merge`.

## 6. Reporting back

State plainly: the PR URL, the title used, the base branch, and (once
merged) the merge strategy applied. Don't just say "PR created" — give the
URL and confirm title/base match what was agreed.
