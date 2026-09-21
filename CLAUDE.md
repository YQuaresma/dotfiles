# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rules for Claude

Personal, project-independent rules (branch-protection check before edits,
never auto-commit/push, never embed real tokens/secrets, verify file/dir
names before documenting, ask before PR merge strategy, never delete
branches without instruction, confirm before creating a PR) live in
`~/.agents/AGENTS.md` (mirrored to `~/.claude/CLAUDE.md` and every other
harness — see `symlinks/home/.agents/AGENTS.md` in this repo) and apply here
too, same as any project. Only this repo's own project-specific rules are
listed below.

- **When asked to create an install script for a program**, do all of the following in order:
  1. Research the official installation process for both macOS and Ubuntu before writing anything.
  2. Read existing `install-*.sh` and `remove-*.sh` scripts in `install/` to match their structure, style, and conventions.
  3. Create `install/install-<name>.sh` — must work on both macOS and Ubuntu (`$OSTYPE`-detected).
  4. Create the matching `install/remove-<name>.sh` that fully reverses the install.
  5. Add the install stage to `setup.sh` in the correct sequence.
  6. Read `symlinks/home/.zshrc` and add any required env vars, paths, or init hooks — following the existing OS-conditional structure.
  7. Update `README.md` and `CLAUDE.md` (Architecture/Key Scripts sections) to document both scripts.
  8. Source `functions.sh` in both scripts for consistent output helpers.

- **`~/bin` is a whole-directory symlink to `symlinks/home/bin`, never a real directory.** `sys-symlinks.sh` backs up any pre-existing real `~/bin` to `~/bin_bak` before linking.
- **`~/.config` and `~/Developer` must be real directories, not symlinks** — other apps' own config/data live alongside the symlinked entries `sys-symlinks.sh` places inside them. If either exists as a symlink, `sys-symlinks.sh` renames it to `<path>_bak` first.
- **`~/.ssh` is a real directory, `chmod 700`, but its contents (`config`, `config.d/`) are not repo-managed** — real files, not symlinks, populated entirely by manual edits; `sys-symlinks.sh` only creates the directory and locks down permissions.
- **`~/.config/gh` is not managed by `sys-symlinks.sh` at all** — no folder, no symlink; `gh` creates the directory itself on first `gh auth login` and writes secrets (`hosts.yml`) into it, so nothing about it is tracked.
- **`~/.claude` is a real directory** — Claude Code writes its own runtime state there (`history.jsonl`, `sessions/`, `projects/`, `plugins/`, `settings.json`, …), so it can't be a whole-directory symlink. Only `~/.claude/skills` is repo-managed, symlinked into it as a subdirectory (`sys-symlinks.sh`) pointing at the same `symlinks/home/.agents/skills` content oh-my-pi/Codex/OpenCode read directly via the whole-directory `~/.agents` symlink — one canonical skill source, two mount points, since Claude Code doesn't read `.agents/skills` itself.
- **`~/.gitconfig_personal` is a real file, not a symlink** — gitignore-matched, populated entirely by manual edits (same pattern as `~/.gitconfig_work`); `sys-symlinks.sh` does not manage it.
- **`~/.tool-versions` is a real, local, untracked file, not a symlink** — asdf (`sys-update.sh`) writes its version pins directly there; it's a record of what's installed, not a source of truth to hand-edit or track in the repo.
- **Almost all dotfiles live under `symlinks/home/` at the repo root, mirroring their `$HOME` path 1:1** (`symlinks/home/.zshrc` → `~/.zshrc`, `symlinks/home/bin/` → `~/bin`, etc.); the one exception, `symlinks/Developer/Docker/docker-compose.yaml`, lands under `~/Developer` instead. `symlinks/home/bin/sys-symlinks.sh` is the only supported way to apply them. Never add a config file outside `symlinks/` — except `~/.gitconfig_work`, `~/.gitconfig_personal`, `~/.ssh/*`, `~/.tool-versions`, `~/Developer/Docker/.env`, and `~/.config/pi-check/config`, which are intentionally local-only (see Architecture and Git Identity sections below). Site-specific values — LAN IPs, hostnames, passwords — belong in those local files, never in a tracked script's defaults.
- **`$HOME/.dotfiles` is always a symlink, never assume a fixed real location.** The actual clone lives wherever the developer manually cloned it (see Bootstrap section below — default suggestion is `~/Developer/Repos/dotfiles`, but any location works). Scripts must reference `$HOME/.dotfiles` or derive the repo root from their own script location (`pwd -P` after resolving `dirname "$0"`) — never hardcode a real path.

## What This Repo Is

A macOS and Linux dotfiles repo. Every path under `symlinks/home/` mirrors its target path under `$HOME` exactly — no package indirection, no external symlink manager (`symlinks/Developer/` is the sole exception, landing under `~/Developer` instead). `symlinks/home/bin/sys-symlinks.sh` walks a fixed list of files/directories and symlinks each `symlinks/home/<rel>` (and `symlinks/Developer/<rel>`) to `$HOME/<rel>`.

## Applying Dotfiles

```bash
# Symlink everything into $HOME (run from repo root)
cd ~/.dotfiles
bash symlinks/home/bin/sys-symlinks.sh
```

`sys-symlinks.sh` handles pre-flight checks (ensures `~/.config`, `~/Developer`, and
`~/.ssh` — `chmod 700` — are real directories; backs up any pre-existing non-symlink or
wrongly-targeted symlink at a destination to `<path>_bak`) before linking. `~/.ssh`'s
contents (`config`, `config.d/`) are not symlinked — real, local-only files populated
entirely by manual edits, not this repo. It's idempotent — safe to re-run any
time `symlinks/` changes.

## Bootstrap a New Machine / Re-running Setup

Three steps — the two scripts are idempotent:

**1. `install/initialise.sh`** — minimum requirements to clone this repo. On a
fresh machine, download it to `$HOME` and run it:

```bash
bash ~/initialise.sh
```

Installs base deps (git, zsh, curl, gh), authenticates with GitHub (`gh auth login`,
or point `GH_TOKEN_FILE` at a file containing a PAT — never `GH_TOKEN=<pat> bash …`,
which leaks the token into shell history and `ps`), prints the next-step clone
command, then deletes
itself. Does **not** clone — that's manual (step 2).

**2. Clone** — manual, `gh` is already authenticated by step 1:

```bash
gh repo clone YQuaresma/.dotfiles ~/Developer/Repos/dotfiles
ln -s ~/Developer/Repos/dotfiles ~/.dotfiles
```

Any destination works — every other script in this repo only ever references
`$HOME/.dotfiles` or derives the repo root from its own script location, never a
hardcoded real path.

**3. `install/setup.sh`** — now inside the clone. Assumes `~/.dotfiles` already
exists. Run it (also how you re-run/update later — same command, idempotent):

```bash
cd ~/.dotfiles
bash install/setup.sh
```

Works on both macOS and Ubuntu (`detect_os()`). Stages run sequentially without
prompts: **symlink dotfiles** first (`sys-symlinks.sh`) → install packages (apt:
build-essential/ca-certificates/software-properties-common only, Ubuntu, rest
Nix-managed) → install the `nix`
binary → **`sys-update.sh`** (bumps `nix/flake.lock` + switches — CLI utils,
oh-my-zsh, fonts, azure-cli, awscli2, google-cloud-sdk, azurite, claude-code, Zed editor; asdf dev tools — hardcoded
`ASDF_PLUGINS` list, always latest; full OS package-manager upgrade — `apt
full-upgrade` / `brew upgrade`) → set Zsh as default shell (both OSes). Same
script routine maintenance uses — install and update converge on one code path.
A Python interpreter (via `uv`, which is Nix-managed), Docker, GUI apps,
Ghostty, and Helium Browser are **optional** — not run automatically; the
script prints their `install/*.sh` commands at the end.

Package-manager stages delegate to a dedicated `install-*.sh` script in `install/`.

## Key Utility Scripts (`symlinks/home/bin/` → symlinked to `~/bin`)

```bash
sys-symlinks.sh                               # symlink symlinks/home/ (+ symlinks/Developer/) into $HOME (also invoked directly by setup.sh)
sys-update.sh                                 # system update (Homebrew/apt/snap + oh-my-zsh plugins)
sys-remove-dsstore.sh [path]                  # recursively remove .DS_Store files (confirms before delete)
pi-check.sh [ip...]                           # verify Pi-hole blocking (read-only; IPs from argv, PI_IPS, or ~/.config/pi-check/config)
pi-update.sh <ip>                             # update OS + Pi-hole on a Pi, reboot, wait for recovery
```

Shell aliases are defined in `symlinks/home/.zshrc.alias` (e.g. `rm-dsstore`).

Pi-hole scripts are self-contained and require a passwordless SSH key at `~/.ssh/pihole`. See the Pi-hole section in `README.md` for setup.

## Architecture

| Path under `symlinks/home/` (unless noted) | Symlinks to |
|-----------|-------------|
| `.zshrc`, `.zshrc.alias`, `.zshrc.private`, `.zprofile` | matching dotfile in `$HOME` |
| `.bashrc`, `.bashrc.alias`, `.bashrc.private`, `.profile` | matching dotfile in `$HOME` (bash equivalent of `.zshrc`/`.zshrc.alias`/`.zshrc.private`; `.profile` is the login-shell PATH fallback) |
| `.gitconfig`, `.gitignore_global` | matching dotfile in `$HOME` |
| `.fzf.zsh`, `.p10k.zsh` | matching dotfile in `$HOME` |
| `.config/ghostty/config` | `~/.config/ghostty/config` (shared config; loads `.config/ghostty/config.linux` via `config-file = ?config.linux` for Linux-only Ctrl-based keybinds, so macOS keeps Ghostty's own Cmd-based defaults) |
| `.config/ghostty/config.linux` | `~/.config/ghostty/config.linux` (optional include, only meaningful on Linux) |
| `.config/zed/settings.json` | `~/.config/zed/settings.json` (editor font, theme, keymap base, project panel prefs) |
| `bin/` | `~/bin` (whole dir — utility scripts, setup/install scripts, `functions.sh`) |
| `.agents/` | `~/.agents` (whole dir — skill packs, read directly by oh-my-pi's `agents` provider, Codex, and OpenCode); `.agents/skills` is also symlinked separately into `~/.claude/skills` since Claude Code only reads its own path |
| `.agents/AGENTS.md` | Personal cross-project instructions, individually symlinked to every harness's own user-level filename: `~/.omp/agent/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/.config/opencode/AGENTS.md`, `~/.copilot/copilot-instructions.md` — one canonical file, six mount points |
| `.agents/RULES.md` | `~/.omp/agent/RULES.md` — oh-my-pi's sticky-rule mechanism only; no other harness has an equivalent to symlink into |
| `.githooks/` | `~/.githooks` (whole dir — global `core.hooksPath`, set in `.gitconfig`; branch-protection + secret-scanning `pre-commit` applied to every repo on this machine, including this one — see Git Hooks section below) |
| `symlinks/Developer/Docker/docker-compose.yaml` (note: under `symlinks/`, not `symlinks/home/`) | `~/Developer/Docker/docker-compose.yaml` (file — dir stays real, holds untracked `Volumes/` bind-mount data and a local-only `.env` supplying `MSSQL_SA_PASSWORD`/`SEQ_PASSWORD`; the compose file hardcodes no credentials and binds every port to `127.0.0.1`) |

## Git Identity — Conditional Includes

`~/.gitconfig` uses `includeIf` to switch identity automatically:

- `~/.dotfiles/`, `~/Developer/Repos/dotfiles/` (real, non-symlinked location — `includeIf` matches
  on the resolved `.git` dir, so both patterns are needed), and `~/Developer/Repos/Personal/` →
  `~/.gitconfig_personal` (personal email, GPG signing **on** — local-only, gitignore-matched,
  not tracked by this repo; create it manually on a new machine, see README's PGP Configuration section)
- `~/Developer/Repos/Work/` → `~/.gitconfig_work` (work email, GPG signing **off** — local-only,
  gitignore-matched by `*[Ww][Oo][Rr][Kk]*`; not tracked, create manually on a new machine)

When working inside this repo, commits are signed with GPG key `F8917E2CD78733A5`.

## Shell Environment Notes

- `symlinks/home/.zshrc` detects OS (`$OSTYPE`) and sets `$OS` to `macos` or `linux`, used throughout the config for conditional paths.
- `ls`, `cat`, `bat`, and `jq` are aliased: `ls`→`eza`, `cat`→`bat --style=plain`, `jq`→`gojq` (both `bat` and `gojq` are Nix-provisioned on both OSes).
- Private/sensitive env vars go in `~/.zshrc.private` (not tracked; excluded by `.gitignore_global`).
- `zoxide` replaces `cd` (`eval "$(zoxide init --cmd cd zsh)"`).
- Key env vars exported from `.zshrc`: `DEV_ROOT`, `DEV_BIN`, `DEV_REPOS`, `DEV_SUPPORT`, `TF_CLI_ARGS_apply=-auto-approve`.

## Git Hooks (`.githooks/`)

This repo has no local `pre-commit` hook of its own — it relies entirely on
the **global** one at `symlinks/home/.githooks/pre-commit` (see the
`.githooks/` row in Architecture above), same as every other repo on this
machine. That hook blocks commits on `main`/`master`/`develop` and scans
staged content for secrets (private key material incl. bare PKCS#8, AWS/GitHub/
Slack/Stripe keys, AI-provider and package-registry tokens, JWTs, Azure
credentials and shared keys, service passwords, URI and ADO.NET connection
strings with embedded credentials, personal emails, internal IPs). It used to
also carry a dotfiles-specific OS-detection audit for `symlinks/home/bin/*.sh`,
`install/*.sh`, and `nix/*.sh` scripts (checked `$OSTYPE` usage, missing
`elif debian` branches, missing `Unsupported OS` guards, missing
`functions.sh` sourcing) — that check was repo-specific and had no meaningful
global form, so it was dropped rather than kept as a local-only hook; enforce
those conventions by review instead.

Three invariants the scanner depends on — do not regress them:

- **It scans `git show ":$path"`, the staged blob — never the working-tree file.**
  Grepping the file on disk is bypassed by `git add secret.env` followed by
  cleaning the file, and by `git add -p`.
- **POSIX ERE only: no `(?i)` inline flags, no `\s`.** Use `-i` via `scan_i` and
  `[[:space:]]`. `(?i)` fails *quietly* on Linux — GNU grep 3.12 warns and
  returns exit 1 (a silent no-match), older GNU greps error — so such a rule is
  dead on Ubuntu while the hook still prints a pass. macOS BSD grep happens to
  honour it, which is how two rules stayed broken on one OS only. Patterns are
  passed with `-e` because the private-key rule starts with `-----`, and a grep
  status above 1 is fatal, never swallowed.
- **Binary staged files are reported, not skipped.** `.p12`/`.pfx`/`.jks` can hold
  key material; the hook flags them for manual review instead of claiming a pass.

Both userlands matter: this repo targets macOS (BSD grep/mktemp) and Ubuntu
(GNU). Verify hook and installer changes against both — GNU `mktemp -t` is
deprecated and its suffix handling is version-dependent, so scripts use plain
`mktemp`/`mktemp -d` rather than a suffixed template.

The hook is local and `--no-verify`-bypassable: it is a convenience, not a
control. Any public repo also needs GitHub secret scanning + push protection.

`sys-symlinks.sh` clears any local `core.hooksPath` left over from before this
consolidation — a local override, even pointing at an empty hook directory,
blocks fallback to the global one.

## Shared Script Libraries (`symlinks/home/bin/`)

**`functions.sh`** — sourced by all scripts. Provides: `info`, `success`, `warn`, `error`, `cog_msg`, `arrow`, `banner`, `tick`, `highlight`, `bold` log helpers; `confirm` Y/N prompt; `detect_os`; `fix_apt_hooks` (removes broken `99-ubuntu-virt.conf` apt hook on Ubuntu when the referenced script is missing — call before any `apt-get` operation). It deliberately has no `keep_sudo_alive`: a detached `sudo -n true` refresh loop outlives a `SIGKILL`ed parent and leaves passwordless root on the tty, and nothing called it.

New scripts under `symlinks/home/bin/` source `functions.sh` (co-located) as `${SCRIPT_DIR}/functions.sh`; scripts living elsewhere (`install/`, `nix/`) source it as `${SCRIPT_DIR}/../symlinks/home/bin/functions.sh` for consistent output and error handling.

**GUI app installers (`install/install-gui-*.sh`)** — one script per package
manager: `install-gui-macos.sh` (Homebrew casks, macOS), `install-gui-snap.sh`
(Snap, Ubuntu — apps with no official apt path), `install-gui-ubuntu.sh`
(official apt repos/packages/tarballs/installers, Ubuntu). `install-gui-apps.sh`
is a thin OS-dispatch wrapper over those three (cask on macOS; snap + the
Ubuntu installer script on Ubuntu, since those two are complementary, not
overlapping). Each has a matching `remove-gui-*.sh`. The
package list (`GUI_CASKS`/`GUI_SNAPS`) is duplicated between an install/remove
pair, not shared via a sourced file — **keep both copies in sync by hand.** A
prior shared-list design existed specifically to prevent that drift (the
installer and remover had kept separate lists that drifted, so removal
uninstalled apps the installer never installed while leaving behind ones it
did); the list was inlined back into each script on request, so the sync
discipline is now manual.

## Update Gates (`sys-update.sh`, `nix/nix-update.sh`)

`sys-update.sh` fast-forwards `~/.dotfiles` and then executes the scripts it
just pulled — `nix-update.sh` activates that tree with `sudo` on macOS. An
unattended merge is therefore remote root execution, so both points prompt:

- `update_dotfiles_repo()` prints incoming commits, counts those without a good
  GPG signature, and requires a `confirm` before merging.
- `nix-update.sh` snapshots `flake.lock`, shows a per-input revision diff after
  `nix flake update`, and requires a `confirm` before calling `nix-switch.sh`.

Both **fail closed** when there is no tty (`[[ ! -t 0 ]]`), because `confirm`
declines on EOF. Overrides: `DOTFILES_UPDATE_ASSUME_YES=1`,
`NIX_UPDATE_ASSUME_YES=1`. Do not remove these gates or make them default-yes.

Unsigned commits are **reported, not rejected** — GitHub web merges are signed
by GitHub's key, which is usually absent from a local keyring, so hard failure
would break every legitimate update.

Also deliberate: `.zshrc`/`.bashrc` do **not** export
`TF_CLI_ARGS_apply="-auto-approve"`. It removed the last confirmation before
`terraform apply` mutated or destroyed real infrastructure in every workspace,
and was inherited by every subshell, script and coding agent. Opt in per project.

## Uninstall Scripts (`install/`)

Each `install-*.sh` has a matching `remove-*.sh` that reverses its changes. CLI utils,
azure-cli, awscli2, google-cloud-sdk, azurite, claude-code, and fonts are Nix-managed on
both OSes now (edit `nix/home/packages.nix` + `nix/nix-switch.sh`, no script pair);
oh-my-zsh + theme/plugins are Nix-managed too, but via `nix/home/zsh.nix` specifically,
not `packages.nix`; Node/Go/Terraform/pnpm/.NET SDK are asdf-managed on both OSes
(`asdf uninstall <name> <version>`, no script pair). Zed editor left Nix — see the GUI
app installers note above.

```
remove-gui-macos.sh   remove-gui-snap.sh          remove-gui-ubuntu.sh
remove-docker.sh
```
