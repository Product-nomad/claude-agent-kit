# Changelog

All notable user-visible changes. Format: [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased] — 2026-04-26

### Documentation
- README "Troubleshooting" expanded with two failure modes seen in the
  field: the v2.1.119 restart-loop symptom (and exactly which
  `journalctl` line to look for), and the live-process-already-holds-
  the-name conflict on `systemctl start`.
- `DECISIONS.md` records the post-mortem decision to pin to the
  v2.1.119+ subcommand form and not try to support the legacy
  `--remote-control <name> --persist` invocation.
- `STATE.md` notes the lessons learned.

## [Unreleased] — 2026-04-25

### Added
- `CLAUDE.md.template` — runtime safety guard installed at
  `$HOME/CLAUDE.md` on first run. Hard rules against destructive
  operations on `~/.ssh/**`, the claude binary, `~/.claude/auth.json`,
  and the systemd unit paths. Prevents the failure mode where a
  "tidy up" or "free disk" command deletes paths the agent depends
  on for its own survival.
- `THREAT_MODEL.md` — trust boundary, assumptions, in-scope risks,
  known gaps. Required by `WAYS_OF_WORKING.md` §3.
- `SECURITY.md` — vulnerability disclosure process.
- `DECISIONS.md` — material architectural decisions.
- README declares its CPMAI phase per `WAYS_OF_WORKING.md` §9.
- `install.sh` validates `CLAUDE_SESSION_NAME` against a strict regex
  before substituting it into the systemd unit (`THREAT_MODEL.md` row).
- `install.sh` writes `$HOME/CLAUDE.md` from the template on first run
  (skipped if a file or symlink already exists at that path).

### Fixed
- **CLI v2.1.119 flag breakage (2026-04-24 incident).** The
  pre-v2.1.119 invocation `claude --remote-control <name> --persist`
  stopped working when `remote-control` was promoted to a subcommand
  and `--persist` was removed (sessions persist by default in
  v2.1.119+). A kit deployment to a Fasthosts VPS on 2026-04-24
  booted the systemd unit with the old form, hit
  `Error: Input must be provided either through stdin or as a prompt
  argument when using --print`, and entered an auto-restart loop
  (counter passed 18,000) before the user noticed. The agent
  disconnected from the user's Mac at ~16:43 UTC. `install.sh` and
  `claude-agent.service.template` now emit the subcommand form
  (`claude remote-control --name <name> --permission-mode bypassPermissions`)
  and no longer reference `--persist`. See README "Troubleshooting"
  for symptom recognition and `DECISIONS.md` (2026-04-26) for the
  rationale on not trying to support the legacy flag form.
