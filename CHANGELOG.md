# Changelog

All notable user-visible changes. Format: [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased] — 2026-04-26

### Known issue (kit currently broken on CLI 2.1.119)
- **Workspace-trust gate blocks unattended boot.** The `git init $HOME`
  workaround documented in `DECISIONS.md` (2026-04-23) is no longer
  reliably sufficient under the systemd unit on Claude Code 2.1.119:
  the unit installs cleanly and the binary launches, but workspace
  trust is not granted unattended, so `claude remote-control` never
  reaches the `claude.ai/code` device list. This is the actual blocker
  exposed by the Apr 24 Fasthosts deployment — the v2.1.119 flag-form
  fix below was a prerequisite, not the final fix. Until upstream
  ships an unattended-trust path, the kit's promised UX
  (`claude.ai/code` web app remote-control) cannot be delivered on a
  fresh install. README now leads with this and points users at the
  Tmux fallback for SSH-only persistence.

### Added
- **`install-tmux.sh` + `claude-agent-tmux.service.template`.** One-shot
  installer for the tmux fallback path: long-lived `claude` running
  inside a `tmux` session under a `systemd --user` unit, reachable via
  `ssh -t box tmux attach`. Same root-refusal, linger, and auth
  hand-shake as the supervised installer; auto-installs `tmux` via apt
  if missing. Different UX (terminal, not web), but it's the working
  alternative on CLI 2.1.119+ until upstream fixes the trust gate.
- **`INCIDENTS/2026-04-24-workspace-trust.md`.** Self-contained
  incident write-up describing the workspace-trust blocker. Filed
  upstream on 2026-04-26 as [anthropics/claude-code#53606](https://github.com/anthropics/claude-code/issues/53606)
  and linked from the README "Known issue" banner so visitors can
  subscribe.
- **Tmux fallback section in README** with side-by-side comparison of
  the two paths and packaged-install instructions.

### Documentation
- README "Troubleshooting" expanded with three failure modes seen in
  the field: the v2.1.119 restart-loop symptom (and exactly which
  `journalctl` line to look for), the live-process-already-holds-the-
  name conflict on `systemctl start`, and the workspace-trust
  regression on first boot under the systemd unit.
- `DECISIONS.md` records (a) the post-mortem decision to pin to the
  v2.1.119+ subcommand form and not try to support the legacy
  `--remote-control <name> --persist` invocation, and (b) the
  manual three-file install path's load-bearing status.
- `STATE.md` corrected — the kit is **paused at the workspace-trust
  blocker**, not "active, manually tested" — and adds a Lessons
  learned section linking the doc updates.

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
