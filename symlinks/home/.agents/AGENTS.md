# Personal Agent Instructions

The one canonical source for personal, cross-project instructions, symlinked
under every AI harness's own expected filename (see below), so it's
maintained in exactly one place.

This is for things that apply to **every** project, not just this dotfiles
repo (which has its own project-scoped `CLAUDE.md`/`AGENTS.md`): rules,
coding style preferences, communication tone, things that should never be
done without asking, etc.

## What belongs here vs. a project's own instructions file

- **Here** (`~/.agents/AGENTS.md` and friends): durable, project-independent
  preferences — how to work, regardless of which repo it is.
- **A project's own `AGENTS.md`/`CLAUDE.md`**: that repo's conventions,
  architecture, build/test commands — takes precedence per-repo and stays
  there, not duplicated here.

## Rules

Source of truth for this list; mirrored by hand into `~/.agents/RULES.md`
(see that file for why oh-my-pi additionally gets these as a sticky rule).

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

## Availability

Symlinked into place by `sys-symlinks.sh` from this single source
(`symlinks/home/.agents/AGENTS.md`) to each harness's own user-level path —
one canonical file, several mount points:

| Harness | Destination |
|---|---|
| oh-my-pi (native) | `~/.omp/agent/AGENTS.md` |
| oh-my-pi (`agents` provider) | `~/.agents/AGENTS.md` (free — same dir as skills) |
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.gemini/GEMINI.md` |
| OpenCode | `~/.config/opencode/AGENTS.md` |
| GitHub Copilot | `~/.copilot/copilot-instructions.md` |

Note: within oh-my-pi itself, only **one** user-level context file survives
across all its discovery providers — the native one (`~/.omp/agent/AGENTS.md`)
always wins and shadows the `agents`-provider copy at `~/.agents/AGENTS.md`,
since both resolve to identical content anyway.

See `~/.agents/RULES.md` for oh-my-pi's separate, always-sticky rules file —
a different mechanism (re-attached near the current turn, survives long
conversations) with no equivalent in the other harnesses.

## Skills sharing

`symlinks/home/.agents/skills/` is the single canonical skills directory
(each skill a `<name>/SKILL.md` subdirectory), symlinked/discovered across
harnesses the same way as `AGENTS.md`:

| Harness | How it sees `~/.agents/skills` |
|---|---|
| oh-my-pi (`agents` provider) | Reads `~/.agents/skills` natively — free, no symlink needed. |
| Claude Code | `~/.claude/skills` symlinked to `~/.agents/skills`. |
| Codex CLI | `~/.codex/skills` symlinked to `~/.agents/skills`. |
| OpenCode | Reads `~/.agents/skills` natively — free, no symlink needed. |

Gemini CLI and GitHub Copilot have no Agent Skills concept as of this
writing, so there's nothing to wire up for them. Add a skill once under
`symlinks/home/.agents/skills/<name>/SKILL.md` and every harness above picks
it up after a session restart/reload.
