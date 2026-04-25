# Changelog

All notable user-visible changes. Format: [Keep a Changelog](https://keepachangelog.com/).

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

### Note
- `install.sh` and `claude-agent.service.template` already used the
  Claude Code 2.1.119+ subcommand form
  (`claude remote-control --name X --permission-mode bypassPermissions`),
  so no CLI changes were needed for the new flag layout.
