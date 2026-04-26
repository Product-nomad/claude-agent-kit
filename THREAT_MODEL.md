# claude-agent-kit — Threat Model

Phase: **Frame** (this document is one of the gate artefacts).

## Scope

The systemd unit, install script, and runtime posture of a Claude Code
agent installed via `claude-agent-kit` on a single-tenant Linux VPS.

## Trust boundary

One-line model: **the agent is trusted; the prompts and data it
processes are not.**

- **Trusted:** the user's account on the VPS, the user's Claude account,
  the systemd unit, its `WorkingDirectory`, and the `claude` binary.
- **Untrusted:** every prompt sent through the remote-control channel,
  every file the agent reads, every tool result it ingests.

## Assumptions

1. Hardened Ubuntu 22.04+ with SSH key-only auth (password auth disabled).
2. The user's Claude account has 2FA enabled.
3. The install user has `sudo` (passwordless or otherwise) — required
   only for `loginctl enable-linger` during install.
4. Outbound network access to Anthropic's API.
5. **Single tenant** — no other users have shell access to this box.

If any of these don't hold, this kit is the wrong fit.

## In-scope risks and mitigations

| Risk | Mitigation |
|---|---|
| Destructive agent command on `~/.ssh/` locks the user out | `CLAUDE.md.template` denies modifications under `~/.ssh/**`; installer drops it at `$HOME/CLAUDE.md` so every session reads it |
| Agent deletes the `claude` binary | `CLAUDE.md.template` denies modifications under `/usr/local/bin/claude*`, `/usr/bin/claude*`, `~/.local/bin/claude*` |
| Agent deletes the systemd unit, breaking auto-restart | `CLAUDE.md.template` denies modifications under the unit paths |
| `bypassPermissions` allows arbitrary tool calls if Claude account is compromised | 2FA on the Claude account is a **prerequisite** (Assumptions §2). Compensating control: the unit runs as a non-root user; cleanup denylist limits self-harm even given a compromise |
| Workspace-trust prompt blocks unattended boot | `git init $HOME` in `install.sh` auto-grants trust |
| Remote-control disconnect leaves orphan processes | `Restart=on-failure` in the unit; systemd ownership ensures clean lifecycle |
| Malicious `CLAUDE_SESSION_NAME` injects into systemd unit text | `install.sh` validates `SESSION_NAME` against `^[A-Za-z0-9_.-]{1,64}$` before substituting |

## Out of scope

- Multi-tenant hosts (kit assumes single-user box).
- Air-gapped deployment (kit requires Anthropic API connectivity).
- Hardware/firmware-level threats.
- Compromise of the Anthropic API itself.
- Lateral movement from a compromised neighbour service on the same box.

## Known gaps

- No cryptographic verification of the `claude` binary on install. The
  user trusts their installation channel.
- `bypassPermissions` is intentionally permissive — the kit trades
  prompt-level safety for unattended operation. Users uncomfortable
  with this should run claude in a less-permissive mode.
- The denylist in `CLAUDE.md.template` is advisory to the agent, not
  enforced by the kernel. A determined or buggy agent can still call
  `rm -rf` on forbidden paths. A defence-in-depth follow-up is to add
  matching `permissions.deny` rules to `~/.claude/settings.json`.

## Reporting

See [`SECURITY.md`](SECURITY.md).
