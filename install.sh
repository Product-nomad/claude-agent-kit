#!/usr/bin/env bash
# Install Claude Code as a systemd --user service. Works on Claude Code
# 2.1.119+; handles every blocker we hit setting this up in production:
#
#   1. Refuses to run as root (2.1.119 bans --dangerously-skip-permissions
#      for uid 0 and this setting relies on it).
#   2. Enables loginctl linger so the service starts at boot without a login.
#   3. git init's $HOME so Claude's workspace-trust check auto-passes.
#   4. Walks you through the one-time interactive prompts: `claude auth
#      login` (browser flow) and `claude remote-control` opt-in (y + spawn
#      mode). Systemd can't answer prompts; you answer once, consent is saved.
#   5. Writes the unit with the correct subcommand form (`claude
#      remote-control --name X`), not the old --remote-control flag form.
#   6. Drops a runtime safety CLAUDE.md at $HOME on first run. Hard rules
#      against deleting ~/.ssh, the claude binary, or the systemd unit —
#      see CLAUDE.md.template. Skipped if a file already exists at
#      $HOME/CLAUDE.md (your edits are preserved).
#
# Idempotent. Safe to rerun.

set -euo pipefail

# ── 0. Refuse root ────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  cat >&2 <<'EOF'
✖ Do not run this installer as root.

Claude Code 2.1.119+ refuses bypass-permissions mode for uid 0. Create a
non-root user first, then run this as that user:

  adduser --disabled-password --gecos "" claude
  loginctl enable-linger claude
  # copy this kit to /home/claude/ then:
  sudo -u claude -i
  # inside that shell:
  cd ~/claude-agent-kit && ./install.sh

EOF
  exit 1
fi

SESSION_NAME="${CLAUDE_SESSION_NAME:-$(hostname -s)}"
# Validate at the boundary: this value is sed-substituted into a systemd
# unit file. Allow only chars that are unambiguous in unit-file syntax.
if [[ ! "$SESSION_NAME" =~ ^[A-Za-z0-9_.-]{1,64}$ ]]; then
  echo "✖ SESSION_NAME '$SESSION_NAME' is invalid." >&2
  echo "  Allowed: letters, digits, underscore, dot, hyphen (1–64 chars)." >&2
  echo "  Override with CLAUDE_SESSION_NAME=<safe-name>." >&2
  exit 1
fi
SERVICE_NAME="claude-agent"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/${SERVICE_NAME}.service"
TEMPLATE="$(dirname "$(readlink -f "$0")")/claude-agent.service.template"

# When invoked from `su - user`, there's no user systemd bus unless this
# is set. machinectl shell / direct SSH set it automatically.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

echo "── Claude Agent installer ──"
echo "  User:          $USER"
echo "  Home:          $HOME"
echo "  Session name:  $SESSION_NAME  (override with CLAUDE_SESSION_NAME=...)"
echo "  Unit path:     $UNIT_FILE"
echo

# ── 1. Locate the claude binary ──────────────────────────────────────────
if ! CLAUDE_BIN="$(command -v claude)"; then
  echo "✖ 'claude' not found on PATH. Install Claude Code first:" >&2
  echo "  https://docs.claude.com/en/docs/claude-code/setup" >&2
  exit 1
fi
CLAUDE_VERSION="$("$CLAUDE_BIN" --version 2>/dev/null | head -1)"
echo "✓ claude binary: $CLAUDE_BIN ($CLAUDE_VERSION)"

# ── 2. Enable linger ─────────────────────────────────────────────────────
if ! loginctl show-user "$USER" --property=Linger 2>/dev/null | grep -q "Linger=yes"; then
  echo "→ Enabling linger for $USER (requires sudo; one-time)..."
  sudo loginctl enable-linger "$USER"
fi
echo "✓ Linger enabled for $USER"

# ── 3. Workspace trust via git init ──────────────────────────────────────
# Claude auto-trusts any directory that's a git repo. This is cheaper than
# the interactive trust dialog (which systemd can't answer).
if [[ ! -d "$HOME/.git" ]]; then
  echo "→ Running 'git init' in $HOME to auto-trust the workspace..."
  git -C "$HOME" init -q
fi
echo "✓ $HOME is a git repo (workspace trust auto-granted)"

# ── 4. Ensure Claude is authenticated ────────────────────────────────────
# The cleanest check: run 'claude auth login'. If already logged in, it
# exits quickly. If not, the user follows the web flow.
echo
echo "→ Checking Claude authentication. If prompted, follow the login flow."
echo "  (If already authed, this will be a no-op.)"
echo
"$CLAUDE_BIN" auth login || {
  echo "✖ Auth failed. Rerun this installer after resolving." >&2
  exit 1
}
echo "✓ Authenticated."

# ── 5. One-time Remote Control consent ───────────────────────────────────
# First time on an account, `claude remote-control` asks:
#   Enable Remote Control? (y/n)    → answer y
#   Choose spawn mode [1/2]         → 1 (same-dir) is fine for most cases
# After answering, you're connected — hit Ctrl-C to exit. Consent persists
# on the account so subsequent non-interactive launches skip these prompts.
echo
echo "→ Running 'claude remote-control' once interactively to capture account"
echo "  consent (one-time). When it prompts:"
echo "    • Enable Remote Control? → answer y"
echo "    • Spawn mode → 1"
echo "    • Once it prints '✔︎ Connected', press Ctrl-C to exit."
echo
echo "  Press Enter to continue..."
read -r
# Run in a subshell so Ctrl-C exits the claude process but not this script.
(
  "$CLAUDE_BIN" remote-control --name "$SESSION_NAME" --permission-mode bypassPermissions
) || true
echo
echo "✓ Remote Control consent captured."

# ── 6. Write the systemd unit ────────────────────────────────────────────
mkdir -p "$UNIT_DIR"
sed \
  -e "s|__SESSION_NAME__|$SESSION_NAME|g" \
  -e "s|__CLAUDE_BIN__|$CLAUDE_BIN|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$UNIT_FILE"
echo "✓ Wrote $UNIT_FILE"

# ── 6b. Install the runtime safety CLAUDE.md ─────────────────────────────
# Hard rules denying destructive ops on ~/.ssh, the claude binary, and the
# systemd unit. The agent reads $HOME/CLAUDE.md on every session start.
# Prevents the agent from deleting paths it depends on for its own
# survival during cleanup operations (see DECISIONS.md).
TEMPLATE_CLAUDE_MD="$(dirname "$(readlink -f "$0")")/CLAUDE.md.template"
HOME_CLAUDE_MD="$HOME/CLAUDE.md"
if [[ -e "$HOME_CLAUDE_MD" ]]; then
  echo "✓ $HOME_CLAUDE_MD already exists — leaving it alone."
  echo "  Verify it contains the destructive-action guards from"
  echo "  $TEMPLATE_CLAUDE_MD, or merge them in."
else
  cp "$TEMPLATE_CLAUDE_MD" "$HOME_CLAUDE_MD"
  echo "✓ Installed runtime safety CLAUDE.md at $HOME_CLAUDE_MD"
fi

# ── 7. Reload, enable, restart ───────────────────────────────────────────
systemctl --user daemon-reload
systemctl --user enable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
systemctl --user restart "${SERVICE_NAME}.service"
sleep 3

# ── 8. Verify ────────────────────────────────────────────────────────────
if systemctl --user is-active --quiet "${SERVICE_NAME}.service"; then
  echo
  echo "✓ ${SERVICE_NAME}.service is active."
  echo
  systemctl --user status "${SERVICE_NAME}.service" --no-pager | head -8
  echo
  echo "Useful commands:"
  echo "  systemctl --user status ${SERVICE_NAME}"
  echo "  systemctl --user restart ${SERVICE_NAME}"
  echo "  journalctl --user -u ${SERVICE_NAME} -f"
  echo "  systemctl --user disable --now ${SERVICE_NAME}    # uninstall"
  echo
  echo "The service now survives SSH logout and reboots. Attach from the"
  echo "web at https://claude.ai/code or the Claude mobile app."
else
  echo
  echo "✖ ${SERVICE_NAME}.service did not come up. Check:" >&2
  echo "    journalctl --user -u ${SERVICE_NAME} -n 30 --no-pager" >&2
  exit 1
fi
