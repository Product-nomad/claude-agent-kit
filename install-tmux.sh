#!/usr/bin/env bash
# Install Claude Code as a persistent tmux session under a systemd --user
# service. The fallback path for environments where the supervised
# `claude remote-control` install (./install.sh) can't deliver
# claude.ai/code remote-control — currently blocked upstream by the
# workspace-trust regression on 2.1.119+ (see README "Known issue" and
# INCIDENTS/2026-04-24-workspace-trust.md).
#
# What this gives you:
#   • A long-lived `claude` session you can attach to via SSH:
#       ssh -t user@box tmux attach -t claude
#   • Survives SSH logout, terminal close, and reboot (with linger).
#
# What this does NOT give you (vs ./install.sh):
#   • Reach via claude.ai/code web app or the Claude mobile app.
#     This is a terminal-only persistence pattern.
#
# Idempotent. Safe to rerun.

set -euo pipefail

# ── 0. Refuse root ────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  cat >&2 <<'EOF'
✖ Do not run this installer as root.

Claude Code refuses bypass-permissions mode for uid 0. Create a non-root
user first, then run this as that user:

  adduser --disabled-password --gecos "" claude
  loginctl enable-linger claude
  sudo -u claude -i
  cd ~/claude-agent-kit && ./install-tmux.sh

EOF
  exit 1
fi

SESSION_NAME="${CLAUDE_SESSION_NAME:-claude}"
# Validate at the boundary: this value is sed-substituted into a systemd
# unit file. Allow only chars that are unambiguous in unit-file syntax.
if [[ ! "$SESSION_NAME" =~ ^[A-Za-z0-9_.-]{1,64}$ ]]; then
  echo "✖ SESSION_NAME '$SESSION_NAME' is invalid." >&2
  echo "  Allowed: letters, digits, underscore, dot, hyphen (1–64 chars)." >&2
  echo "  Override with CLAUDE_SESSION_NAME=<safe-name>." >&2
  exit 1
fi
SERVICE_NAME="claude-agent-tmux"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/${SERVICE_NAME}.service"
TEMPLATE="$(dirname "$(readlink -f "$0")")/claude-agent-tmux.service.template"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

echo "── Claude Agent (tmux fallback) installer ──"
echo "  User:           $USER"
echo "  Home:           $HOME"
echo "  tmux session:   $SESSION_NAME  (override with CLAUDE_SESSION_NAME=...)"
echo "  Unit path:      $UNIT_FILE"
echo
echo "  Note: this is the SSH-only fallback. For the claude.ai/code web UX"
echo "        run ./install.sh instead — though see README 'Known issue'"
echo "        if you're on CLI 2.1.119+."
echo

# ── 1. Locate the claude binary ──────────────────────────────────────────
if ! CLAUDE_BIN="$(command -v claude)"; then
  echo "✖ 'claude' not found on PATH. Install Claude Code first:" >&2
  echo "  https://docs.claude.com/en/docs/claude-code/setup" >&2
  exit 1
fi
CLAUDE_VERSION="$("$CLAUDE_BIN" --version 2>/dev/null | head -1)"
echo "✓ claude binary: $CLAUDE_BIN ($CLAUDE_VERSION)"

# ── 2. Locate or install tmux ────────────────────────────────────────────
if ! TMUX_BIN="$(command -v tmux)"; then
  echo "→ tmux not found. Installing via apt (requires sudo)..."
  sudo apt-get update -qq && sudo apt-get install -y tmux
  TMUX_BIN="$(command -v tmux)"
fi
echo "✓ tmux binary: $TMUX_BIN ($($TMUX_BIN -V))"

# ── 3. Enable linger ─────────────────────────────────────────────────────
if ! loginctl show-user "$USER" --property=Linger 2>/dev/null | grep -q "Linger=yes"; then
  echo "→ Enabling linger for $USER (requires sudo; one-time)..."
  sudo loginctl enable-linger "$USER"
fi
echo "✓ Linger enabled for $USER"

# ── 4. Ensure Claude is authenticated ────────────────────────────────────
echo
echo "→ Checking Claude authentication. If prompted, follow the login flow."
echo "  (If already authed, this will be a no-op.)"
echo
"$CLAUDE_BIN" auth login || {
  echo "✖ Auth failed. Rerun this installer after resolving." >&2
  exit 1
}
echo "✓ Authenticated."

# ── 5. Workspace trust hand-shake (interactive, one-time) ────────────────
# Even in tmux mode, claude prompts for workspace trust on first launch
# in a fresh $HOME. Do it once interactively here so the systemd unit's
# detached tmux session won't block on it later.
if [[ ! -d "$HOME/.git" ]]; then
  echo "→ Running 'git init' in $HOME to auto-trust the workspace..."
  git -C "$HOME" init -q
fi
echo "✓ $HOME is a git repo."
echo
echo "→ Launching 'claude' once interactively to clear any first-run prompts"
echo "  (workspace trust, etc). When the prompt appears, press Ctrl-C to exit."
echo "  Press Enter to continue..."
read -r
("$CLAUDE_BIN" --permission-mode bypassPermissions) || true
echo
echo "✓ First-run prompts cleared."

# ── 6. Write the systemd unit ────────────────────────────────────────────
mkdir -p "$UNIT_DIR"
sed \
  -e "s|__SESSION_NAME__|$SESSION_NAME|g" \
  -e "s|__CLAUDE_BIN__|$CLAUDE_BIN|g" \
  -e "s|__TMUX_BIN__|$TMUX_BIN|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$UNIT_FILE"
echo "✓ Wrote $UNIT_FILE"

# ── 7. Reload, enable, restart ───────────────────────────────────────────
# If a tmux session with this name already exists, kill it so the unit
# re-creates a clean one. Otherwise the ExecStart fails with "duplicate session".
"$TMUX_BIN" kill-session -t "$SESSION_NAME" 2>/dev/null || true

systemctl --user daemon-reload
systemctl --user enable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
systemctl --user restart "${SERVICE_NAME}.service"
sleep 2

# ── 8. Verify ────────────────────────────────────────────────────────────
if "$TMUX_BIN" has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo
  echo "✓ tmux session '$SESSION_NAME' is up."
  echo
  echo "Useful commands:"
  echo "  systemctl --user status ${SERVICE_NAME}"
  echo "  systemctl --user restart ${SERVICE_NAME}"
  echo "  tmux attach -t ${SESSION_NAME}             # local"
  echo "  ssh -t ${USER}@<box> tmux attach -t ${SESSION_NAME}   # remote"
  echo "  systemctl --user disable --now ${SERVICE_NAME}        # uninstall"
  echo
  echo "Detach from tmux with Ctrl-b then d. Session keeps running."
else
  echo
  echo "✖ tmux session '$SESSION_NAME' did not come up. Check:" >&2
  echo "    systemctl --user status ${SERVICE_NAME} --no-pager" >&2
  echo "    journalctl --user -u ${SERVICE_NAME} -n 30 --no-pager" >&2
  exit 1
fi
