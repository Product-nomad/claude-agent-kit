# claude-agent-kit — STATE

**Goal**: One-shot installer to replicate this VPC's Claude Code remote-control
setup on a fresh Ubuntu VPS.
**Status**: active, partially tested
**Last touched**: 2026-04-25

## What's done
- Repo published at `git@github.com:Product-nomad/claude-agent-kit.git`.
- `install.sh` and `claude-agent.service.template` exist.
- README written.
- Tested on a Fasthosts VPS (2026-04-24) — kit installed and ran successfully there.

## What's next
- The `install.sh` should be reviewed against the corrected systemd unit
  in `/etc/systemd/system/claude-agent.service` on this host (the CLI flag
  changed from `--remote-control <name> --persist` to
  `claude remote-control --name <NAME> --permission-mode bypassPermissions` in
  CLI v2.1.119+). Verify the kit's template uses the new syntax.
- Add a README section on the Fasthosts incident gotcha (cleanup commands
  that delete SSH keys — see `~/projects/fasthosts-recovery/STATE.md`).

## Open questions / blockers
- None right now.

## Key files
- `install.sh` — main installer.
- `claude-agent.service.template` — systemd unit template.
