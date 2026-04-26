# Architectural decisions

One paragraph per decision, dated. Records the *why* so the same call
doesn't get re-litigated.

## 2026-04-23 — `--permission-mode bypassPermissions`, not `--dangerously-skip-permissions`

Both flags exist on Claude Code 2.1.119+, but they serve different
roles. `--dangerously-skip-permissions` is a top-level switch;
`--permission-mode <mode>` takes one of several mode values, of which
`bypassPermissions` is the equivalent unattended mode. Mixing the two
produces undefined precedence, and the mode-form is the more explicit,
scriptable interface. Picked `--permission-mode bypassPermissions`.

## 2026-04-23 — `git init $HOME` to satisfy workspace trust

Claude Code's workspace-trust dialog blocks unattended boot of the
systemd unit, and systemd cannot answer the prompt. The cheapest
workaround is making `$HOME` a git repo (any git repo is auto-trusted).
The repo is intentionally a stray empty one — no commits, no remote.
Documented in the host CLAUDE.md so future agents don't try to "fix"
it by deleting `$HOME/.git`.

## 2026-04-25 — Ship a default `CLAUDE.md` with destructive-action denylist

A "tidy up" or "free disk" request can have the agent delete paths it
depends on for its own survival — `~/.ssh/authorized_keys`, the claude
binary, the systemd unit, the auth blob — leaving the box reachable
only via the provider's console. The runtime guard is a `CLAUDE.md` at
`$HOME` that the agent reads on every session, with explicit hard rules
against modifying those paths. `install.sh` writes this file on first
run; if a file already exists at `$HOME/CLAUDE.md`, the installer
preserves it and prints a reminder of the recommended rules.

## 2026-04-25 — Validate `SESSION_NAME` against a strict regex

`CLAUDE_SESSION_NAME` is a user-supplied environment variable that gets
substituted into the systemd unit text via `sed`. Without validation, a
crafted value containing `|`, `$`, newlines, or backticks could break
the unit or inject unintended directives. WAYS_OF_WORKING §3 requires
boundary validation. Restricted to `^[A-Za-z0-9_.-]{1,64}$` — covers
hostnames, common suffixes, and is unambiguous in unit-file syntax.

## 2026-04-25 — Single-tenant VPS assumption, documented not enforced

Multi-tenant adds complexity (privilege escalation, shared service
contention) that the kit isn't trying to address. Assumption stated in
`THREAT_MODEL.md`. Multi-user-aware deployment is a follow-on
project, not a fix to this one.

## 2026-04-26 — Pin to CLI v2.1.119+ subcommand form; do not support legacy

Claude Code 2.1.119 promoted `remote-control` to a subcommand and
removed `--persist` (sessions persist by default). The pre-v2.1.119
invocation `claude --remote-control <name> --persist` is silently
incompatible: systemd starts the unit, the binary errors with
"Input must be provided ... when using --print", and the auto-restart
loop ratchets up indefinitely because the failure looks transient.
A kit deployment to a Fasthosts VPS on 2026-04-24 hit this exact
failure and accumulated 18,000+ restarts before the user noticed,
disconnecting the agent for ~2 hours. The kit now emits the
subcommand form only and documents the symptoms in README. We
deliberately do *not* try to detect-and-rewrite the legacy form: the
syntactic divergence is broad (subcommand promotion, removed flag,
changed arity), the user population on <2.1.119 is small and
shrinking, and the fix on the user's side is one upgrade. `install.sh`
prints the detected Claude Code version on success so a future
regression in flag layout is visible at deploy time rather than at
the next restart-loop incident.

## 2026-04-26 — `git init $HOME` is no longer sufficient for workspace trust

The 2026-04-23 entry above documents `git init $HOME` as the cheap
workaround for Claude Code's workspace-trust dialog, which otherwise
blocks unattended systemd boot. As of the 2026-04-24 Fasthosts
deployment, this workaround is **no longer reliably effective** on
CLI 2.1.119: the directory is auto-recognised as a git repo, but
the trust prompt fires anyway on first run under the unit. The kit
installs cleanly, the binary launches, but `remote-control` never
reaches the `claude.ai/code` device list because trust never clears.

We are not going to ship a more invasive workaround — pre-seeding
the trust state file would couple the kit to undocumented internals
of Claude Code that the upstream may rename or restructure at any
time. The decision is to **wait for upstream to ship a documented
unattended-trust path**, mark the kit as broken-in-this-mode in
README and STATE, and provide the tmux fallback for users whose
real ask is "persistent claude on a remote box" rather than
"`claude.ai/code` web UX specifically".

When upstream lands a fix (e.g. `--trust-workspace`,
`CLAUDE_TRUST_WORKSPACE=1`, or a settings.json key that opts the
unit user into trust on its `WorkingDirectory`), revisit. Until
then: kit is paused.

## 2026-04-26 — Tmux fallback as a documented support contract

Users who reach for this kit usually want one of two things, and
the kit conflates them:

1. *A persistent `claude` they can SSH back into across reboots* —
   solvable today with `tmux` + `loginctl enable-linger`.
2. *Their VPS appearing in the `claude.ai/code` device list,
   reachable from the web app and the phone* — currently blocked
   upstream as documented above.

The tmux fallback in README is the answer for (1) when (2) is
unavailable. It's not a "lesser version" of the kit — it's a
different product with a different reach surface (SSH terminal,
not web). The README explicitly contrasts the two so users don't
expect the wrong one.

## 2026-04-26 — Manual three-file install path is load-bearing

The Apr 24 incident also exposed friction in the `scp`-from-laptop
deployment pattern: a two-hop copy
(source host → user's laptop → target VPS) lost the directory
structure on one attempt, leaving the user with
`cd: claude-agent-kit: No such file or directory` and no install. The
README's "Manual three-file install" section (paste-the-file blocks)
is preserved as a fallback for anyone whose target VPS lacks `scp`,
`rsync`, or working outbound SSH from the kit's source host. Treat
that section as a support contract, not optional polish — keep it
in sync with `install.sh`.
