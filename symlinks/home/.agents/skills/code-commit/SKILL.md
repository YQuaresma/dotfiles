---
name: code-commit
description: Use when writing a commit message or making a commit — enforces Conventional Commits format, a short body, and a verified GPG signature.
author: NasCarreras
---

# Code Commit

Three responsibilities: write the message to spec, keep it short, then prove
the commit that carries it is actually signed and verified — not just "signing
is configured somewhere," but *this specific commit* shows a good signature.

## 1. Message format — Conventional Commits v1.0.0

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

**Types** (pick one):

| Type | Use for |
|---|---|
| `feat` | a new feature |
| `fix` | a bug fix |
| `docs` | documentation only |
| `style` | formatting, no code meaning change |
| `refactor` | code change that's neither a fix nor a feature |
| `perf` | performance improvement |
| `test` | adding/correcting tests |
| `build` | build system or external dependencies |
| `ci` | CI configuration/scripts |
| `chore` | everything else (tooling, maintenance) |
| `revert` | reverts a previous commit |

Rules:

- `description` is imperative, lowercase, no trailing period: `fix: correct null check`, not `Fixed the null check.`
- `[optional scope]` is a parenthesized noun describing the affected area: `feat(auth): add token refresh`.
- **Breaking change** — either form (not both):
  - `!` right after the type/scope: `feat(api)!: remove deprecated endpoint`
  - or a footer: `BREAKING CHANGE: <description>` (this footer form MUST be uppercase and MUST appear even if `!` is also used, whichever the project's convention prefers — but never omit the breaking-change signal entirely when a change is in fact breaking).
- Footers use `token: value` or `token #value`, one per line, `-` replacing spaces in multi-word tokens (`Reviewed-by: ...`, `Refs #123`).
- Multiple types/changes → multiple commits, not one commit with several unrelated `type:` prefixes.
- Subject line under ~72 characters. It shows up truncated everywhere else.

Examples:

```
fix(parser): handle trailing comma in array literal

feat(auth)!: require MFA for admin accounts

BREAKING CHANGE: admin sessions created before this release are invalidated
```

## 2. Body — omit it unless it earns its place

**Most commits need no body.** If the subject line says it, stop there.

Write one only to record what the diff cannot show: why this approach, what
was rejected, a non-obvious constraint, or how a bug was actually triggered.
**Target 1–3 sentences.** Separate it from the subject by one blank line.

Never write these:

- A restatement of the diff, or a per-file list of what changed.
- Bullet inventories of every touched behaviour — that's `git show`.
- Verification transcripts or pasted command output. If verification matters,
  one clause: `Verified: repro no longer triggers.`
- Migration instructions that belong in a `BREAKING CHANGE:` footer.
- Marketing ("comprehensive", "robust") or self-praise.

Go longer **only** when the length is load-bearing — a squash carrying several
independent rationales, or a security fix whose exploitability the reader must
grasp. Even then: prose paragraphs, no headings, no bullet lists. A commit
message that needs sections is usually several commits.

```
fix(bin): derive the repo root instead of hardcoding the clone path

The hardcoded path meant a clone anywhere else re-pointed ~/.dotfiles at a
missing directory, after which every later link replaced a real dotfile with
a dangling symlink.

Verified: sandbox $HOME with a non-default clone path, no dangling links.
```

## 3. Commit, then verify signing — every time

Composing the message correctly is not the end of the task. After running
`git commit`, verify the signature on the commit that was just created:

```bash
git log -1 --show-signature
```

or, for a scriptable pass/fail check:

```bash
git log -1 --pretty="%H %G?"
```

`%G?` meaning:

| Code | Meaning | Acceptable? |
|---|---|---|
| `G` | Good signature | ✅ pass |
| `U` | Good signature, unknown validity | ⚠️ flag — key not trusted, still investigate |
| `X` / `Y` | Good signature, expired key/sig | ⚠️ flag |
| `B` | **Bad** signature | ❌ fail — stop and investigate immediately |
| `E` | Signature couldn't be checked (e.g. missing key) | ❌ fail — can't confirm, treat as unverified |
| `N` | **No signature** | ❌ fail — commit isn't signed at all |

Only `G` (and arguably `U`/`X`/`Y` with an explicit note) counts as "verified."
`N`, `B`, and `E` mean the commit does **not** meet the bar — do not report
the commit as done without calling this out.

If signing isn't configured for the current repo/identity at all (`git config
commit.gpgsign` is unset or `false`, or `git log` shows no signature line),
say so explicitly rather than silently treating an unsigned commit as fine —
the user may need to switch identity, set `commit.gpgsign true`, or add a
`user.signingkey`.

## 4. Reporting back

State plainly: the commit hash, the message's `type(scope): description`
line, and the signature verdict (`git log -1 --pretty="%G? %GK"` gives verdict
+ key id in one line). Don't just say "committed" — say "committed and
signature verified (`G`, key `<id>`)" or flag the specific failure mode from
the table above.
