# claude-agent-kit — STATE

**Goal**: One-shot installer to replicate this VPC's Claude Code remote-control
setup on a fresh Ubuntu VPS.
**CPMAI phase**: IV — Model Development, **paused at the workspace-trust blocker** (see Lessons learned + DECISIONS.md 2026-04-26 entries).
**Status**: kit installs cleanly but cannot deliver `claude.ai/code` remote-control unattended on CLI 2.1.119 because workspace trust is not auto-granted under the systemd unit even with the `git init $HOME` workaround. Tmux fallback works for SSH-only persistence. Awaiting upstream fix.
**Last touched**: 2026-04-26.

## What's done
- Repo published at `git@github.com:Product-nomad/claude-agent-kit.git`.
- `install.sh` and `claude-agent.service.template` use the CLI 2.1.119+
  subcommand form. Verified on this host (2026-04-25).
- Tested on a fresh Ubuntu 24.04 VPS on 2026-04-24. Initial install used
  the pre-v2.1.119 flag form and entered an 18,000+ restart loop —
  subsequent fix to the subcommand form is what now ships. See the
  `Lessons learned` section below and the 2026-04-26 entries in
  `CHANGELOG.md` and `DECISIONS.md`.
- (2026-04-25) Conformed to `~/WAYS_OF_WORKING.md`:
  - `THREAT_MODEL.md`, `SECURITY.md`, `DECISIONS.md`, `CHANGELOG.md` added.
  - README declares CPMAI phase and links the new docs.
  - `CLAUDE.md.template` ships hard-rule denylist for `~/.ssh`, the claude
    binary, the systemd unit, and `~/.claude/` credentials. `install.sh`
    drops it at `$HOME/CLAUDE.md` on first run.
  - `install.sh` validates `CLAUDE_SESSION_NAME` against
    `^[A-Za-z0-9_.-]{1,64}$` before sed-substituting it into the unit.

## What's next (blocked on upstream)
- **File the workspace-trust issue with Anthropic.** The kit needs a
  documented unattended-trust path (e.g. `--trust-workspace`,
  `CLAUDE_TRUST_WORKSPACE=1`, or a `settings.json` key that opts the
  unit's `WorkingDirectory` into trust on first launch). Without
  that, the kit's headline UX is unreachable.
- **Re-test on every CLI release** until upstream lands a fix.
  `install.sh` already prints the detected version on success — when
  re-testing, use that as the version-of-record for any new
  bug-report attachments.
- **Tmux-based fallback unit.** Ship a sibling systemd unit that
  runs `claude` under tmux with `loginctl enable-linger`, so users
  who only need SSH-reachable persistence (not the web UX) have a
  one-shot install. Currently documented but not packaged.

## What's next (deferred — Phase V gate, unblocked once upstream resolves)
- **Automated test suite.** Bats or shellspec smoke tests for: root-refusal,
  SESSION_NAME validation, idempotent rerun, CLAUDE.md preservation when
  one already exists. Real install path needs a containerised harness.
- **Golden-set bootstrap test.** Run install.sh inside a fresh Ubuntu
  Docker container and assert the unit comes up. Wire to GitHub Actions.
- **Defence-in-depth via `~/.claude/settings.json`** — add
  `permissions.deny` rules that mirror the CLAUDE.md denylist, so the
  guard is enforced by the Claude Code permission system, not just by
  the agent reading the doc.
- Cross-link from `agentaudit` once that project starts watching this
  unit's logs.

## Open questions / blockers
- Where to run the containerised test? GitHub Actions runners are fine
  for the install-in-Docker path. Confirm `loginctl enable-linger`
  works inside the runner's container model.

## Lessons learned (post-2026-04-24 incident)

Three failure modes bit us in the field, in order of severity:

1. **(Currently blocking) Workspace-trust regression on CLI 2.1.119.**
   The 2026-04-23 `git init $HOME` workaround stopped being reliably
   sufficient: under the systemd unit, the trust prompt fires on
   first launch even though `$HOME/.git` exists, so `claude
   remote-control` never reaches the `claude.ai/code` device list.
   This is the *real* reason the Apr 24 deployment failed; the flag
   fix below was a prerequisite, not the final fix. Mitigation: kit
   marked broken-in-this-mode in README and STATE; tmux fallback
   documented; awaiting upstream fix.
2. **Silent CLI flag breakage (v2.1.119, fixed in tree).** When the
   underlying CLI changes flag layout (as v2.1.119 did with
   `remote-control` → subcommand and removal of `--persist`),
   systemd starts the unit, the binary refuses input with
   `Error: Input must be provided ... when using --print`, and the
   auto-restart loop ratchets indefinitely because the failure looks
   transient. The Apr 24 incident hit 18,000+ restarts before the
   user noticed. `install.sh` and `claude-agent.service.template`
   now emit the subcommand form and `install.sh` prints the
   detected CLI version on success.
3. **Multi-hop `scp` losing structure.** Copying via the user's
   laptop (source-host → laptop → target VPS) lost the
   `claude-agent-kit/` directory in one Apr 24 attempt, leaving the
   user with `cd: No such file or directory`. The "Manual
   three-file install" section in README is the documented
   fallback.

Mitigations now in tree:
- README leads with the workspace-trust **Known issue** banner so
  users don't waste an hour on a kit that can't deliver its
  headline UX today.
- README "Troubleshooting" covers the restart-loop symptom (with
  the exact `journalctl` line to look for), the
  live-process-holds-the-name conflict, and the workspace-trust
  regression.
- README "Tmux fallback" documents the working alternative for
  users whose real ask is "persistent claude on a remote box, not
  the `claude.ai/code` web UX specifically".
- `DECISIONS.md` (2026-04-26) records: the pin to the v2.1.119+
  subcommand form; the workspace-trust workaround being no longer
  sufficient and the decision to wait for upstream; the tmux
  fallback as a documented support contract; the manual-install
  path's load-bearing status.
- `install.sh` prints the detected Claude Code version on success
  — a future flag-layout regression should be visible at deploy
  time, not at the next restart-loop incident.

## Key files
- `install.sh` — main installer.
- `claude-agent.service.template` — systemd unit template.
- `CLAUDE.md.template` — runtime safety doc dropped at `$HOME` on install.
- `THREAT_MODEL.md`, `SECURITY.md`, `DECISIONS.md`, `CHANGELOG.md` —
  governance artefacts per `WAYS_OF_WORKING.md`.
