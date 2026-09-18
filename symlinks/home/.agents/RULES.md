# Personal Sticky Rules (oh-my-pi only)

Rules that must never get lost, even in a long conversation.
Mirrored by hand from `~/.agents/AGENTS.md`'s "Rules" section (this file's
source of truth) — this file exists so oh-my-pi keeps the rules re-attached
near the current turn, instead of relying on opening context staying
visible, a mechanism the other harnesses don't need.

- Before making any file changes, check the current branch. If it's `main`,
  `master`, `develop`, or the repo's default branch, stop and ask what the
  new branch should be named before proceeding. Never skip this, even for a
  single-file change.
- Never commit or push automatically. Wait for explicit request before
  running `git commit` or `git push`.
- Never embed real tokens or secrets in documentation or code — use
  placeholders. If a real token/secret appears in conversation, flag it
  immediately and replace it with a placeholder.
- Verify actual file and directory names before documenting them — read or
  list them, never document from memory or assumption.
- Always ask before choosing a PR merge strategy (squash/merge/rebase) —
  confirm first, never assume.
- Never delete branches (local or remote) without explicit instruction.
- Always confirm before creating a PR — agree on title, description, and
  base branch first.
