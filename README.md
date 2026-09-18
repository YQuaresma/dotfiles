# dotfiles

Cross-platform dotfiles repo for macOS and Ubuntu. Config files live in `symlinks/home/`,
mirroring their target path under `$HOME` 1:1, plus `symlinks/Developer/` for the one file
that lands under `~/Developer` instead of a top-level `$HOME` dotfile. `symlinks/home/bin/
sys-symlinks.sh` symlinks all of it into place — no GNU Stow, no package indirection.

> [!WARNING]
> **These are one person's dotfiles, not an installer you should run blind.**
> `install/setup.sh` is not additive-only. On the machine it runs on it will:
> replace files in `$HOME` with symlinks into this repo (anything pre-existing is
> moved to `<path>_bak`, never deleted); perform a **full OS package upgrade**
> (`brew upgrade` / `apt full-upgrade`); install Nix as a multi-user daemon;
> change your **default login shell** to Zsh; and fetch-and-execute third-party
> installer scripts over the network (Homebrew, Determinate Nix, `omp.sh`), none
> of which are version-pinned or checksum-verified.
>
> It uses `sudo` throughout. Read `install/setup.sh` and the scripts it calls
> before running any of it, or cherry-pick the parts you want.

## Quick Start (Fresh Machine)

Four steps — the two scripts are idempotent, safe to re-run:

1. **`install/initialise.sh`** — minimum requirements to get this repo onto the
   machine. Installs `git` + the `gh` CLI, authenticates with GitHub (over HTTPS —
   no SSH key needed for this part), clones the repo to `~/Developer/Repos/dotfiles`,
   symlinks `~/.dotfiles` to it, then deletes itself.
2. **`install/setup.sh`** — now inside the clone. Symlinks dotfiles into `$HOME`,
   installs the full toolchain (Nix, asdf via `sys-update.sh`), sets Zsh as the
   default shell.
3. **SSH setup** — optional but recommended. Lets you push code over SSH.
4. **PGP setup** — optional but recommended. Lets you sign your commits.

### 1. Bootstrap & Clone

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YQuaresma/.dotfiles/main/install/initialise.sh)
```

Clones into `~/Developer/Repos/dotfiles` and symlinks `~/.dotfiles` to it — every
other script in this repo only ever references `~/.dotfiles`, none of them need to
know or care where you actually put the real clone. Want it somewhere else? Clone
manually first (`gh repo clone YQuaresma/.dotfiles <path>` then
`ln -s <path> ~/.dotfiles`) before running `initialise.sh` — it leaves an existing
`~/.dotfiles` symlink alone.

### 2. Full Install

```bash
cd ~/.dotfiles
bash install/setup.sh
```

1. Symlinks dotfiles into `$HOME` (`sys-symlinks.sh`)
2. Installs remaining Homebrew/apt packages
3. Installs Nix, then hands off to `sys-update.sh` for the full toolchain (Nix + asdf)
4. Sets Zsh as the default shell (both OSes)

A Python interpreter (via `uv`, which is Nix-managed), Docker, and GUI apps are
optional — see below.

### 3. SSH Configuration

This step lets you push code over SSH. It's optional, but recommended. Every
command below can be copy-pasted as-is into your terminal, one block at a time.

**Create an SSH key.** This makes two files: a private key (never share this) and
a public key (safe to share — this is what you give to GitHub). Name it after
the GitHub account it's for — `personal` in the example below:

```bash
ssh-keygen -t ed25519 -C "<YOUR EMAIL ADDRESS>" -f ~/.ssh/id_gh_personal_ed25519
```

You'll be asked for a passphrase — press Enter to accept the default (none).

**Tell SSH to use this key for GitHub.** Create a small config file for it —
this makes the key work whether you clone with `git@github.com:...` or the
`git@gh-personal:...` alias set up below:

```bash
mkdir -p ~/.ssh/config.d
cat > ~/.ssh/config.d/gh-personal.conf <<'EOF'
# SSH config for gh-personal
Host github.com gh-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_gh_personal_ed25519
  AddKeysToAgent yes
EOF
```

Then make sure `~/.ssh/config` loads it (safe to re-run, won't add it twice):

```bash
touch ~/.ssh/config
grep -qxF "Include config.d/gh-personal.conf" ~/.ssh/config || echo "Include config.d/gh-personal.conf" >> ~/.ssh/config
```

**Give the public key to GitHub.** `gh` is already installed and logged in from
step 1, so this one command does it — no copy-pasting keys into a website. Each
machine generates its own distinct SSH key (`gh-personal.conf` above always points
at the same local filename, but the key material differs per machine) — a
machine-specific title keeps them apart in GitHub's key list, so you can tell
which device a key belongs to and revoke just that one without guessing:

```bash
gh ssh-key add ~/.ssh/id_gh_personal_ed25519.pub --title "gh-personal-mac"
```

```bash
gh ssh-key add ~/.ssh/id_gh_personal_ed25519.pub --title "gh-personal-ubuntu"
```

Prefer to do it by hand on the website instead? Print the key and copy it:

```bash
cat ~/.ssh/id_gh_personal_ed25519.pub
```

Then go to <https://github.com/settings/ssh/new>, paste it into the "Key" box,
and click **Add SSH key**.

**Check it worked** — both should print `Hi <your-username>! You've successfully
authenticated`:

```bash
ssh -T git@github.com
ssh -T git@gh-personal
```

You can now clone with either `git@github.com:YQuaresma/.dotfiles.git` or
`git@gh-personal:YQuaresma/.dotfiles.git` — same key, same result.

### 4. PGP Configuration

This step lets you sign your commits so GitHub shows them as "Verified". It's
optional, but recommended.

**Create a PGP key.** This is a *different* kind of key, used to prove commits
really came from you (not the same as the SSH key from step 3):

```bash
gpg --full-generate-key
```

You'll be asked several questions — press Enter to accept every default, then
type your name, your email, and a password to protect the key when asked.

**Find your new key's ID** — a short code you'll need in the next two steps:

```bash
gpg --list-secret-keys --keyid-format=long
```

Look for a line like `sec   rsa4096/65588977C2DF620E`. The part after the slash
(`65588977C2DF620E` here — yours will be different) is your key ID.

**Give the public PGP key to GitHub.** Replace `65588977C2DF620E` with your own
key ID from the step above. Same reasoning as the SSH key above — this machine
generates its own distinct PGP key, so a machine-specific title (matching the
SSH naming from step 3) keeps multiple devices' keys distinguishable in GitHub's
key list instead of several identically-named entries:

```bash
gpg --armor --export 65588977C2DF620E | gh gpg-key add --title "gh-personal-mac"
```

```bash
gpg --armor --export 65588977C2DF620E | gh gpg-key add --title "gh-personal-ubuntu"
```

Prefer to do it by hand on the website instead? Print the key and copy it —
include the `-----BEGIN PGP PUBLIC KEY BLOCK-----` and `-----END...-----` lines:

```bash
gpg --armor --export 65588977C2DF620E
```

Then go to <https://github.com/settings/gpg/new>, paste it in, and click
**Add GPG key**.

**Tell git to use this key.** `symlinks/home/.gitconfig` is already created and
symlinked to `~/.gitconfig` by `sys-symlinks.sh` — it's the shared, repo-tracked
config. `~/.gitconfig_personal` is a separate file it `includeIf`-includes just
for the folders configured under [Git Identity](#git-identity); it holds only
your GPG key, full name, and email address for those folders. Run this to write
it — replace each `<...>` with your own values first (keep the key ID from above
for `<YOUR PGP KEY ID>`). This file is local-only (gitignore-matched, not tracked
by this repo):

```bash
cat > ~/.gitconfig_personal <<'EOF'
[user]
    name = <YOUR NAME>
    email = <YOUR EMAIL ADDRESS>
    signingkey = <YOUR PGP KEY ID>

[commit]
    gpgSign = true
EOF
```

That's it — commits made from `~/Developer/Repos/Personal/` (or anywhere under
`~/.dotfiles`) will now be signed automatically and pushed/pulled using the SSH
key if you switch a repo's remote to `git@gh-personal:<owner>/<repo>.git`.

## Re-running / Updating

`install/setup.sh` is idempotent — the same command both installs and updates:

```bash
cd ~/.dotfiles
bash install/setup.sh
```

Supports macOS and Ubuntu (auto-detected). Both are fully migrated to Nix + asdf. Stages run
sequentially without prompts:

| # | Stage | Script | Notes |
|---|-------|--------|-------|
| 1 | Symlink dotfiles; also creates `~/.config`, `~/Developer/Repos/Personal`, `~/Developer/Repos/Work`, etc. and the `~/.dotfiles → ~/Developer/Repos/dotfiles` symlink | `symlinks/home/bin/sys-symlinks.sh` | Runs before package installs below |
| 2 | Install packages | inline in `setup.sh` | apt: `build-essential`/`ca-certificates`/`software-properties-common` only (Ubuntu, one-time — no-op on macOS), Nix-managed rest (both OSes) |
| 3 | Install Nix, then hand off to `sys-update.sh` for a full update pass | `nix/nix-install.sh`, `symlinks/home/bin/sys-update.sh` | `sys-update.sh` bumps `nix/flake.lock` and switches (CLI utils, azure-cli, awscli2, google-cloud-sdk, azurite, claude-code, fonts, oh-my-zsh/theme/plugins, `asdf` itself), installs/updates asdf tools (`ASDF_PLUGINS` list, always latest), and runs a full OS package-manager upgrade (`apt full-upgrade` / `brew upgrade`) — same script routine maintenance uses |
| 4 | Set Zsh as default shell | inline | Both OSes — macOS via `chsh`, Ubuntu via `usermod` |

> **Both macOS and Ubuntu are fully migrated to Nix + asdf** — see the
> [Nix + asdf](#nix--asdf-macos--ubuntu) section below.
>
> **Azure Functions Core Tools is not part of this pipeline on either OS** — nixpkgs still
> can't produce a working build (missing ASP.NET Core runtime in the dependency closure), so
> it was dropped from automated setup rather than kept on Homebrew/apt indefinitely.
> `install/install-azure-functions.sh` / `install/remove-azure-functions.sh` remain for
> ad-hoc/manual installs.

### Optional: Python, Docker, GUI Apps, Ghostty

`setup.sh` doesn't run these automatically — install what you need manually:

```bash
bash ~/.dotfiles/install/install-python.sh    # Python interpreter, via Nix-managed uv
bash ~/.dotfiles/install/install-docker.sh    # Docker Engine (Ubuntu) / Docker Desktop (macOS)
bash ~/.dotfiles/install/install-apps-gui.sh  # GUI apps (browsers, editors, dev tools)
bash ~/.dotfiles/install/install-ghostty.sh   # Ghostty terminal (Homebrew cask / apt)
```

- **macOS**: `install-apps-gui.sh` installs Homebrew casks (VS Code, Chrome, Firefox, GitKraken, Postman, Notion, Rectangle, and more)
- **Ubuntu**: `install-apps-gui.sh` installs Snap packages (VS Code, Firefox, GitKraken, Postman, Notion, and more)

## Applying Dotfiles Only

```bash
# Symlink everything into $HOME (run from repo root)
cd ~/.dotfiles
bash symlinks/home/bin/sys-symlinks.sh
```

`sys-symlinks.sh` handles pre-flight checks before linking: ensures `~/.config`,
`~/Developer`, and `~/.ssh` (`chmod 700`) exist as real directories; also creates the
rest of the `~/Developer/` subtree (`Repos/Personal`, `Repos/Sandbox`, `Repos/Work`, `Support`, `Documents`,
`Docker/Volumes`) and the `~/.dotfiles → ~/Developer/Repos/dotfiles` convenience
symlink. Backs up any pre-existing non-symlink (or wrongly-targeted symlink) at a
destination to `<path>_bak` before replacing it. It's idempotent — re-running is a
no-op for anything already correctly linked. Once linked, it's also reachable as
`~/bin/sys-symlinks.sh` (or bare `sys-symlinks.sh` if `~/bin` is on `$PATH`).

## Symlinks Layout

Every path under `symlinks/home/` mirrors its target under `$HOME` exactly
(`symlinks/home/.zshrc` → `~/.zshrc`, `symlinks/home/bin/sys-update.sh` → `~/bin/sys-update.sh`,
etc.) — no package abstraction to look through. `symlinks/Developer/` is the one exception:
its one file lands under `~/Developer` instead of directly under `$HOME`.

| Path | Symlinks to |
|------|-------------|
| `symlinks/home/.zshrc`, `.zshrc.alias`, `.zshrc.private`, `.zprofile` | matching dotfile in `$HOME` |
| `symlinks/home/.bashrc`, `.bashrc.alias`, `.bashrc.private`, `.profile` | matching dotfile in `$HOME` (bash equivalent of `.zshrc`/`.zshrc.alias`/`.zshrc.private`; GUI session managers read `.profile` via `/bin/sh`, not `.zshrc`) |
| `symlinks/home/.gitconfig`, `.gitignore_global` | matching dotfile in `$HOME` |
| `symlinks/home/.fzf.zsh`, `.p10k.zsh` | matching dotfile in `$HOME` |
| `symlinks/home/.config/ghostty/config` | `~/.config/ghostty/config` |
| `symlinks/home/bin/` | `~/bin` (whole dir) |
| `symlinks/home/.agents/` | `~/.agents` (whole dir — skill packs; `ask-matt`, `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grill-me`, `grill-with-docs`, `grilling`, `implement`, `improve-codebase-architecture`, `prototype`, `research`, `resolving-merge-conflicts`, `setup-matt-pocock-skills`, `tdd`, `teach`, `to-questionnaire`, `to-spec`, `to-tickets`, `triage`, `wait-what`, `wayfinder`, `wizard`, `writing-for-agents` are sourced from [Matt Pocock's skills](https://github.com/mattpocock/skills); run `setup-matt-pocock-skills` once per repo before first use) |
| `symlinks/home/.agents/AGENTS.md` | Personal cross-project instructions, symlinked individually to `~/.omp/agent/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/.config/opencode/AGENTS.md`, `~/.copilot/copilot-instructions.md` |
| `symlinks/home/.agents/RULES.md` | `~/.omp/agent/RULES.md` (oh-my-pi's sticky-rule mechanism only — no equivalent in the other harnesses) |
| `symlinks/home/.githooks/` | `~/.githooks` (whole dir — see below) |
| `symlinks/Developer/Docker/docker-compose.yaml` | `~/Developer/Docker/docker-compose.yaml` (file — `~/Developer/Docker` stays real, holds untracked bind-mount data like `Volumes/`) |

`~/.ssh/config` and `~/.ssh/config.d/` are **not** repo-managed — real files/dir,
not symlinks, populated entirely by manual edits. `~/.ssh` itself still gets created
(`chmod 700`) by `sys-symlinks.sh`, but its contents are local-only.

`~/.config/gh` is not managed by `sys-symlinks.sh` at all — no folder, no symlink;
`gh` creates the directory itself on first `gh auth login` and writes secrets
(`hosts.yml`) into it.

`~/Developer/Docker/.env` is not repo-managed either — the local dev stack reads
`MSSQL_SA_PASSWORD` and `SEQ_PASSWORD` from it and `docker compose` fails fast if
they are unset, so no password ships in the tracked compose file. Every port is
bound to `127.0.0.1`; the short `"1433:1433"` form binds `0.0.0.0`, which would
publish SQL Server to the whole LAN. Create it once:

```bash
printf 'MSSQL_SA_PASSWORD=%s\nSEQ_PASSWORD=%s\n' \
  "$(openssl rand -base64 24)" "$(openssl rand -base64 24)" \
  > ~/Developer/Docker/.env && chmod 600 ~/Developer/Docker/.env
```

`~/.gitconfig_personal` is likewise **not** repo-managed — a real, gitignore-matched
file populated by manual edits (see [Git Identity](#git-identity)), not a symlink.

`~/.config`, `~/Developer`, and `~/.ssh` are real directories — other apps and
`~/Developer/Repos`/`~/Developer/Support` live alongside the symlinked entries above.
`~/bin` and `~/.agents` stay whole-directory symlinks (same as under Stow) since
nothing else lives there. `~/.claude` is real (Claude Code's own runtime state —
`history.jsonl`, `sessions/`, `plugins/`, `settings.json`, …); only its `skills`
subdirectory is repo-managed, symlinked to the same `symlinks/home/.agents/skills`
content `~/.agents/skills` points at — one canonical skill source, two mount points,
since Claude Code doesn't read `.agents/skills` itself (oh-my-pi's `agents` provider,
Codex, and OpenCode do).

`~/.omp`, `~/.codex`, `~/.gemini`, `~/.config/opencode`, and `~/.copilot` are
likewise real directories (each tool's own runtime state) — only the specific
`AGENTS.md`/`CLAUDE.md`/`GEMINI.md`/`RULES.md` file inside each gets symlinked
in, all pointing back at the same two canonical files under
`symlinks/home/.agents/`.

`~/.githooks` is set as `core.hooksPath` **globally** in `symlinks/home/.gitconfig`
(`[core] hooksPath = ~/.githooks`), so its `pre-commit` — branch protection
(blocks commits on `main`/`master`/`develop`) plus a secret/credential scanner
(private keys, cloud tokens, connection strings with embedded credentials,
personal emails, internal IPs, …) — runs in every repo on this machine,
**including this one**: this repo has no local `pre-commit` of its own, and
`sys-symlinks.sh` clears any leftover local `core.hooksPath` override so
nothing blocks fallback to the global hook. Bypass a false positive on a
single commit with `git commit --no-verify`.

## Uninstall Scripts

> These only ever covered brew/apt/curl-installer-managed tools. Both **macOS** and
> **Ubuntu** are now fully migrated to Nix + asdf — CLI utils/fonts/oh-my-zsh/azure-cli/
> azurite/claude-code go through `~/.dotfiles/nix/home/packages.nix` + `nix/nix-switch.sh`;
> Node/Go/Terraform/pnpm/.NET SDK go through `asdf uninstall <name> <version>` +
> `~/.tool-versions` (a real, local, untracked file — not repo-managed). Neither uses install/remove script pairs — see
> [Nix + asdf](#nix--asdf-macos--ubuntu) below. `install/install-azure-functions.sh` /
> `install/remove-azure-functions.sh` are kept on both OSes for ad-hoc/manual use only — Azure
> Functions Core Tools isn't installed by `setup.sh` on either platform (nixpkgs
> still can't produce a working build; not worth keeping on Homebrew/apt indefinitely for
> that reason alone). Docker stays apt/brew-managed permanently on both OSes (no working
> non-NixOS Nix path).

Each remaining `install-*.sh` in `install/` has a matching `remove-*.sh` that reverses its changes:

| Script | Reverses | Description |
|--------|----------|-------------|
| `remove-apps-gui.sh` | `install-apps-gui.sh` | Removes GUI apps (Homebrew casks / Snap packages) |
| `remove-ghostty.sh` | `install-ghostty.sh` | Removes Ghostty terminal (Homebrew cask / apt) — **ad-hoc only, not run by `setup.sh`** |
| `remove-omp.sh` | `install-omp.sh` | Removes omp (Oh My Pi) — **ad-hoc only, not run by `setup.sh`** |
| `remove-azure-functions.sh` | `install-azure-functions.sh` | Removes Azure Functions Core Tools — **ad-hoc only, not run by `setup.sh`** |
| `remove-docker.sh` | `install-docker.sh` | Removes Docker Engine and Docker Desktop |
| `remove-python.sh` | `install-python.sh` | Removes uv-managed Python versions (uv itself is Nix-managed, not removed here) |

**Deleted, no longer exist** (fully superseded by Nix/asdf on both OSes — see
[Nix + asdf](#nix--asdf-macos--ubuntu)): `install-ohmyzsh.sh`, `remove-ohmyzsh.sh`,
`install-fonts.sh`, `install-azure-cli.sh`, `remove-azure-cli.sh`, `install-claude-code.sh`,
`remove-claude-code.sh`, `install-node.sh`, `remove-node.sh`, `install-npm-tools.sh`,
`remove-npm-tools.sh`, `install-golang.sh`, `remove-golang.sh`, `install-terraform.sh`,
`remove-terraform.sh`, `install-dotnet.sh`, `remove-dotnet.sh`, `install-apps.sh`,
`remove-apps.sh` (folded into `install/setup.sh`'s `install_packages()` — apt:
`build-essential`/`ca-certificates`/`software-properties-common`, Ubuntu only, one-time;
reverse manually with `sudo apt remove -y build-essential ca-certificates
software-properties-common && sudo apt autoremove -y` if ever needed), `install-asdf.sh`
(folded into `symlinks/home/bin/sys-update.sh`'s `update_asdf()` — `ASDF_PLUGINS`/
`ASDF_PLUGIN_REPOS` now live there, single call site, no need for a separate script).

## Utility Scripts (`~/bin/`)

| Script | Description |
|--------|-------------|
| `sys-update.sh` | System update — apt/snap/firmware (Ubuntu) or Homebrew (macOS), plus Nix + asdf on both. Package steps run non-interactively; the two steps that would execute newly-fetched code are gated (see below). |
| `nix/nix-install.sh` | Installs Nix (Determinate Systems installer) — lives in `nix/`, not `~/bin`, not on `$PATH`. Warns that the installer escalates to root |
| `nix/nix-switch.sh` | Applies the Nix flake config (`darwin-rebuild switch` / `home-manager switch`) |
| `nix/nix-update.sh` | Updates flake inputs, shows which inputs moved, asks before re-applying, garbage-collects old generations |
| `nix/nix-doctor.sh` | Read-only health check for the Nix + asdf layer specifically |
| `sys-remove-dsstore.sh [path]` | Recursively remove `.DS_Store` files |
| `pi-check.sh [ip...]` | Verify Pi-hole blocking (read-only) |
| `pi-update.sh <ip>` | Update OS + Pi-hole on a Pi, reboot, wait for recovery |

### Update gates

`sys-update.sh` updates `~/.dotfiles` and then runs the scripts it just pulled —
`nix-update.sh` activates the new tree with `sudo` on macOS. An unattended merge
is therefore equivalent to remote root execution, so two points now ask first:

| Gate | Shows | Skips when | Override |
|---|---|---|---|
| dotfiles self-update | incoming commits + how many lack a good GPG signature | no tty, or you decline | `DOTFILES_UPDATE_ASSUME_YES=1` |
| Nix flake apply | which flake inputs moved (per-input revision diff) | no tty, or you decline | `NIX_UPDATE_ASSUME_YES=1` |

Both **fail closed**: with no terminal to answer on, nothing is applied. Set the
override only where accepting unreviewed upstream code is acceptable.

Unsigned incoming commits are reported, not rejected — GitHub web merges are
signed by GitHub's own key, which is usually absent from a local keyring.

## Pi-hole Scripts

### SSH Key Setup

Both Pi-hole scripts connect via SSH using a dedicated key at `~/.ssh/pihole`. This must be created and copied to each Pi before running either script:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/pihole -C "pihole"
ssh-copy-id -i ~/.ssh/pihole.pub pi@<pi-ip>
```

Repeat `ssh-copy-id` for each Pi-hole you manage. The default SSH user is `pi` — override with the `PI_USER` env var if yours differs.

### `pi-check.sh` — Verify Pi-hole Blocking

Tests DNS blocking against a set of known domains. Checks the local machine's system DNS first, then queries each Pi-hole directly.

There are no built-in default IPs — a LAN address is site-specific and does not
belong in a published repo. Pass them as arguments, or keep them in a local-only
config at `~/.config/pi-check/config` (untracked, sourced if present):

```bash
# ~/.config/pi-check/config
PI_IPS=<PI-HOLE-IP-1>,<PI-HOLE-IP-2>
PI_USER=pi
PI_CHECK_DOMAINS=doubleclick.net,google-analytics.com
```

```bash
# Use the local config
pi-check.sh

# Check specific IPs
pi-check.sh <PI-HOLE-IP-1> <PI-HOLE-IP-2>

# Override via env var
PI_IPS=<PI-HOLE-IP-1>,<PI-HOLE-IP-2> pi-check.sh

# Use a different SSH user
PI_USER=admin pi-check.sh
```

Both Pi scripts use `StrictHostKeyChecking=accept-new`: the Pi's host key is
pinned on first connection and a later change is refused. `pi-update.sh` drives
`sudo` commands over that connection, so accepting a *changed* key
(`StrictHostKeyChecking=no`) would hand a LAN-level MITM a root session.

### `pi-update.sh` — Update a Pi-hole

Runs `apt update`, `apt upgrade`, `apt autoremove`, and `pihole -up` on the target Pi, then reboots it and waits for it to come back online (up to 120s).

```bash
pi-update.sh <PI-HOLE-IP>

# Use a different SSH user
PI_USER=admin pi-update.sh <PI-HOLE-IP>
```

## Nix + asdf (macOS + Ubuntu)

Both **macOS** and **Ubuntu** are fully migrated off Homebrew/apt for CLI/dev tooling to
[Nix](https://nixos.org) (system/shell tools) + [asdf](https://asdf-vm.com)
(language/runtime versions).

| Layer | Owns | Config |
|-------|------|--------|
| Nix (home-manager, + nix-darwin on macOS) | CLI utils (`bat`, `eza`, `fzf`, `jq`, `zoxide`, …), `azure-cli`, `awscli2`, `google-cloud-sdk`, `azurite`, `claude-code`, Nerd Fonts, oh-my-zsh + Powerlevel10K + plugins, `asdf` itself | `nix/flake.nix`, `nix/home/packages.nix`, `nix/home/zsh.nix`, `nix/darwin/configuration.nix` (macOS fonts), `nix/home/fonts-linux.nix` (Ubuntu fonts) |
| asdf | Node.js, Go, Terraform, pnpm, .NET SDK | `symlinks/home/bin/sys-update.sh` (`ASDF_PLUGINS` list — source of truth, always latest) writes to `~/.tool-versions` directly (a real, local, untracked file — a record of what's installed, not hand-edited) |
| Homebrew / apt (unchanged, permanently) | GUI apps (`install-apps-gui.sh`), Docker Engine/Desktop | `install/install-apps-gui.sh`, `install/install-docker.sh` — Docker has no working non-NixOS Nix path (no systemd/daemon wiring), stays brew cask (macOS) / apt (Ubuntu) by design |
| Neither — ad-hoc only | Azure Functions Core Tools (nixpkgs closure is missing `Microsoft.AspNetCore.App`, no working build possible) | `install/install-azure-functions.sh` / `install/remove-azure-functions.sh`, run manually, never by `setup.sh` |
| Neither — ad-hoc only | omp (Oh My Pi) — not in nixpkgs; upstream brew tap/curl installer already auto-update, a Nix derivation would trade that for manual version+sha256 bumps per release | `install/install-omp.sh` / `install/remove-omp.sh`, run manually, never by `setup.sh` |
| Neither — ad-hoc only | Ghostty terminal — no working from-source nixpkgs derivation on either OS (macOS needs Swift 6/xcodebuild, unsupported; Ubuntu's Nix build's GTK/Mesa/libwayland stack breaks EGL context creation at runtime) | `install/install-ghostty.sh` / `install/remove-ghostty.sh` (brew cask on macOS, apt on Ubuntu), run manually, never by `setup.sh` |

```bash
# Apply changes after editing nix/home/packages.nix, nix/home/zsh.nix, or
# nix/darwin/configuration.nix
~/.dotfiles/nix/nix-switch.sh

# Update everything: flake inputs + asdf tools (always latest available release —
# see symlinks/home/bin/sys-update.sh)
sys-update.sh          # apt full-upgrade/snap/firmware (Ubuntu) or brew, plus Nix + asdf, non-interactive
~/.dotfiles/nix/nix-update.sh          # Nix only: flake update + switch + garbage collect

# Health check
~/.dotfiles/nix/nix-doctor.sh          # Nix + asdf layer specifically
```

`nix/` is **not** part of `symlinks/`'s symlink set — its scripts (`nix-install.sh`, `nix-switch.sh`,
`nix-update.sh`, `nix-doctor.sh`) are co-located with the flake and run in place from
`~/.dotfiles/nix`; they aren't on `$PATH`, invoke them by full path (Nix flakes only see
git-tracked files, so new files there need `git add` before `nix flake check`/
`nix-switch.sh` will pick them up).

## Git Identity

`~/.gitconfig` switches identity automatically via `includeIf`:

- `~/.dotfiles/`, `~/Developer/Repos/dotfiles/` (its real, non-symlinked location — `includeIf` needs
  both, since it matches on the `.git` dir actually resolved), and `~/Developer/Repos/Personal/` →
  personal email, GPG signing **on** (`~/.gitconfig_personal` — local-only, gitignore-matched,
  not tracked by this repo; create it manually on a new machine, see [PGP Configuration](#5-pgp-configuration))
- `~/Developer/Repos/Work/` → work email, GPG signing **off** (`~/.gitconfig_work` — local-only,
  gitignore-matched via `*[Ww][Oo][Rr][Kk]*`, not tracked by this repo; create it manually on a
  new machine):

```gitconfig
[user]
    name = Your Name
    email = you@work.example

[commit]
    gpgSign = false
```
