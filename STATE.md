# claude-agent-kit — STATE

**Goal**: One-shot installer to replicate this VPC's Claude Code remote-control
setup on a fresh Ubuntu VPS.
**CPMAI phase**: IV — Model Development (advancing to V).
**Status**: active, manually tested.
**Last touched**: 2026-04-25.

## What's done
- Repo published at `git@github.com:Product-nomad/claude-agent-kit.git`.
- `install.sh` and `claude-agent.service.template` use the CLI 2.1.119+
  subcommand form. Verified on this host (2026-04-25).
- Tested on a Fasthosts VPS on 2026-04-24 — kit installed and ran there.
- (2026-04-25) Conformed to `~/WAYS_OF_WORKING.md`:
  - `THREAT_MODEL.md`, `SECURITY.md`, `DECISIONS.md`, `CHANGELOG.md` added.
  - README declares CPMAI phase and links the new docs.
  - `CLAUDE.md.template` ships hard-rule denylist for `~/.ssh`, the claude
    binary, the systemd unit, and `~/.claude/` credentials. `install.sh`
    drops it at `$HOME/CLAUDE.md` on first run.
  - `install.sh` validates `CLAUDE_SESSION_NAME` against
    `^[A-Za-z0-9_.-]{1,64}$` before sed-substituting it into the unit.

## What's next (Phase V gate)
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

## Key files
- `install.sh` — main installer.
- `claude-agent.service.template` — systemd unit template.
- `CLAUDE.md.template` — runtime safety doc dropped at `$HOME` on install.
- `THREAT_MODEL.md`, `SECURITY.md`, `DECISIONS.md`, `CHANGELOG.md` —
  governance artefacts per `WAYS_OF_WORKING.md`.
