# claude-agent-kit

Install Claude Code as a **systemd user service** on a Linux VPS. Survives SSH logout, terminal close, and reboot. Attach from anywhere via <https://claude.ai/code> or the Claude app.

Tested against Claude Code **2.1.119+** (subcommand-style CLI). Handles every gotcha we hit deploying this in production — see the comments in `install.sh` for the full reasoning.

> **CPMAI phase:** IV — Model Development. The install path is implemented and tested manually on Ubuntu 22.04 + 24.04 VPSes. Phase V gates (automated test suite, golden-set bootstrap test) are outstanding; tracked in `STATE.md`.

**Read these before installing on a real box:**
- [`THREAT_MODEL.md`](THREAT_MODEL.md) — trust boundary, assumptions, in-scope risks, known gaps.
- [`SECURITY.md`](SECURITY.md) — vulnerability disclosure process.
- [`DECISIONS.md`](DECISIONS.md) — why the kit makes the choices it does.

## What it sets up

- A `claude-agent.service` systemd unit under `~/.config/systemd/user/`.
- `loginctl` linger so the service starts at boot without a login session.
- Workspace trust (via `git init $HOME`) so the service doesn't trip the trust dialog.
- Auto-restart on failure.

## Prerequisites

1. **A non-root user.** Claude Code ≥ 2.1.119 refuses bypass-permissions mode as root. Create one on a fresh VPS:
   ```sh
   adduser --disabled-password --gecos "" claude
   # Optional: give sudo (not required for the agent itself)
   usermod -aG sudo claude
   ```
2. **Claude Code CLI** installed on PATH. See <https://docs.claude.com/en/docs/claude-code/setup>.
3. **A Claude account** with Remote Control available on your plan. The installer will prompt for login and one-time consent.

## Install

From a shell logged in as the non-root user:

```sh
cd ~/claude-agent-kit
./install.sh
```

Optional: override the session name (defaults to the box's short hostname):

```sh
CLAUDE_SESSION_NAME=fasthosts ./install.sh
```

The installer walks you through two interactive prompts:

- **`claude auth login`** — opens a web flow (or device code) to authenticate this user with your Claude account. Skipped if already logged in.
- **`claude remote-control`** consent — first time on an account, Claude asks "Enable Remote Control? (y/n)" and "spawn mode [1/2]". Answer `y` then `1`, then Ctrl-C to exit. Consent persists — subsequent runs (including the systemd launch) skip these prompts.

After those, the installer writes the unit, drops a runtime safety
`CLAUDE.md` at `$HOME` (skipped if you already have one — see Safety
below), and brings the service up.

## Safety

The installer ships a `CLAUDE.md.template` and writes it to `$HOME/CLAUDE.md`
on first run. The agent reads `$HOME/CLAUDE.md` on every session start;
the template adds **hard rules** denying destructive operations on:

- `~/.ssh/**` — deleting `authorized_keys` locks SSH out.
- `/usr/local/bin/claude*`, `/usr/bin/claude*`, `~/.local/bin/claude*`
  — the CLI binary.
- `~/.claude/auth.json`, `~/.claude/settings.json`, `~/.claude/keychain*`
  — auth and settings the agent needs to start.
- `/etc/systemd/system/claude-agent.service`,
  `~/.config/systemd/user/claude-agent.service` — the unit.

This is a runtime guard against the failure mode that bricked one of
our VPSes when an agent was asked to "tidy up" the disk. The denylist is
advisory to the agent (read every session, enforced by the agent's
behaviour). Defence-in-depth via `~/.claude/settings.json`'s `permissions.deny`
list is the recommended next layer — already populated by the host's
default settings on this kit's reference deployment.

If you already have a `$HOME/CLAUDE.md`, the installer leaves it alone
and reminds you to merge in the rules from `CLAUDE.md.template`.

## Copying the kit to a new VPS

The simplest approaches:

```sh
# Option A — scp directly between your boxes (if SSH is configured both ways)
scp -r user@source-host:~/claude-agent-kit/ ~/

# Option B — via your laptop
scp -r user@source-host:~/claude-agent-kit/ /tmp/
scp -r /tmp/claude-agent-kit/ user@new-vps:~/

# Option C — paste the three files (README, template, install.sh) as heredocs
#           directly on the new box. See the end of this file.
```

## Bootstrapping a totally fresh Ubuntu VPS

From the root shell of a new VPS:

```sh
# 1. Create the non-root user
adduser --disabled-password --gecos "" claude
loginctl enable-linger claude

# 2. Install Claude Code (per your preferred method — example:)
# curl -fsSL https://claude.ai/install.sh | sh      # or whatever
# Make the binary available on PATH for the 'claude' user.

# 3. Drop the kit into the new user's home
mkdir -p /home/claude/claude-agent-kit
cp -r /path/to/kit/* /home/claude/claude-agent-kit/
chown -R claude:claude /home/claude/claude-agent-kit

# 4. Switch into that user's shell (machinectl preserves the user systemd bus)
machinectl shell claude@
# ...or: sudo -u claude -i

# 5. Run the installer
cd ~/claude-agent-kit && ./install.sh
```

## Verify

```sh
systemctl --user status claude-agent
journalctl --user -u claude-agent -f
```

From another box (or your phone): <https://claude.ai/code> → you should see the environment listed.

## Day-to-day use

- SSH in and out freely — the service stays up.
- `systemctl --user restart claude-agent` if it ever gets wedged.
- Update Claude Code on the host (`curl … | sh` or package manager), then `systemctl --user restart claude-agent`.

## Update the running service

Rerunning `./install.sh` overwrites the unit, reloads, and restarts cleanly. Prerequisite checks short-circuit if already done.

## Uninstall

```sh
systemctl --user disable --now claude-agent
rm ~/.config/systemd/user/claude-agent.service
# Optional (only if you don't use other user services):
sudo loginctl disable-linger "$USER"
```

## Troubleshooting

- **"Failed to connect to bus: No medium found"** when running `systemctl --user` after `su -` — the session doesn't have a dbus. Fix:
  ```sh
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
  ```
  Or always switch users with `machinectl shell user@` instead of `su -`.

- **"Workspace not trusted"** in the journal — the installer runs `git init` in `$HOME`, which should prevent it. If you see this anyway, check whether `$HOME/.git` exists and whether Claude's runtime user matches the unit's `WorkingDirectory`.

- **"cannot be used with root/sudo privileges"** — you're running as root. Create a non-root user (see Prerequisites).

- **"Enable Remote Control? (y/n)" in the journal** — the interactive consent wasn't completed. Rerun `./install.sh` and answer the prompt when it comes up, or run `claude remote-control --name <NAME> --permission-mode bypassPermissions` manually and answer `y`.

- **"Remote Control eligibility"** — your Claude plan may not include Remote Control. Check plan, or fall back to running plain `claude` inside tmux/screen as an alternative persistence pattern.

## Sunset criteria

Archive this kit if any of these become true:

- Anthropic ships a first-party "remote-control as a service" deployment
  story that covers the same gotchas (auth, workspace trust, linger,
  unattended boot).
- Claude Code drops the `remote-control` subcommand or replaces the
  systemd-friendly invocation pattern in a way that can't be patched
  with a one-line install.sh change.
- The threat model becomes untenable for the configurations users
  actually run (e.g. multi-tenant becomes the default, requiring a
  rewrite rather than a kit update).

## Manual three-file install (paste into new VPS)

If scp isn't available, paste these three blocks on the target box as the non-root user:

```sh
mkdir -p ~/claude-agent-kit && cd ~/claude-agent-kit
```

Then paste the contents of `claude-agent.service.template` and `install.sh` from this kit into files of those names (`cat > filename <<'EOF'` … `EOF`), `chmod +x install.sh`, and `./install.sh`.
