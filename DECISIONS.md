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

A "tidy up" command on a Fasthosts VPS bricked the box by deleting
`~/.ssh/` and the claude binary on 2026-04-24. The runtime guard
against this is a `CLAUDE.md` at `$HOME` that the agent reads on every
session, with explicit hard rules against modifying paths the agent
depends on for its own survival. `install.sh` writes this file on first
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
