# Workspace-trust dialog blocks unattended `claude remote-control` under systemd on 2.1.119+

> **For users:** this file is a ready-to-paste GitHub issue describing the
> blocker that keeps `claude-agent-kit` from delivering its headline UX on
> current CLI versions. Copy the body below into a new issue at
> <https://github.com/anthropics/claude-code/issues/new>. Once the issue
> exists, link it from the README "Known issue" banner so visitors can
> subscribe.

---

## Title

`claude remote-control` under systemd: workspace-trust dialog fires on first launch even when `$HOME` is a git repo (no unattended-trust path on 2.1.119)

## Summary

Running `claude remote-control` as a `systemd --user` service on a fresh VPS no longer reaches the `claude.ai/code` device list on Claude Code 2.1.119+, because the **workspace-trust prompt fires interactively on first launch** even when the documented workaround (`git init $HOME` so the directory is auto-recognised as a trusted workspace) is in place.

Systemd cannot answer an interactive prompt, so the unit launches the binary, the binary blocks waiting for trust, and the agent never appears as an attachable device. There is currently no documented unattended-trust path (no `--trust-workspace` flag, no env var, no settings.json key that opts the unit's `WorkingDirectory` into trust on first run).

This breaks the "deploy a Claude Code remote-control box on a VPS" use case, which a number of community kits (including `claude-agent-kit`) depend on.

## Environment

- Claude Code CLI: **2.1.119** (also reproduced on later 2.1.x releases)
- OS: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS (fresh VPS, no prior Claude state)
- Provider: Fasthosts VPS (also reproducible on a generic cloud VM)
- Install method: systemd `--user` unit, started at boot via `loginctl enable-linger`
- User: dedicated non-root `claude` user
- Plan: Claude Pro / Max (Remote Control eligible — confirmed by interactive `claude remote-control` working in the same shell)

## Reproduction

1. On a fresh VPS as a non-root user `claude`, install Claude Code 2.1.119+:
   ```bash
   curl -fsSL https://claude.ai/install.sh | sh
   claude --version    # 2.1.119 (Claude Code) or newer
   ```
2. Authenticate and capture Remote Control consent interactively (works fine):
   ```bash
   claude auth login
   claude remote-control --name my-vps --permission-mode bypassPermissions
   # Answer y / 1 / Ctrl-C
   ```
3. Apply the documented unattended-trust workaround:
   ```bash
   git -C "$HOME" init -q
   ```
4. Drop a systemd user unit at `~/.config/systemd/user/claude-agent.service`:
   ```ini
   [Unit]
   Description=Claude Code (Remote Control)
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=simple
   ExecStart=/usr/local/bin/claude remote-control --name my-vps --permission-mode bypassPermissions
   WorkingDirectory=/home/claude
   Restart=on-failure
   RestartSec=5
   Environment=PATH=/home/claude/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

   [Install]
   WantedBy=default.target
   ```
5. Enable linger and start the unit:
   ```bash
   sudo loginctl enable-linger claude
   systemctl --user daemon-reload
   systemctl --user enable --now claude-agent.service
   ```

### Expected

The unit comes up, `claude remote-control` connects, and `my-vps` appears in the `claude.ai/code` device list (the same way it does in step 2's interactive run).

### Actual

`systemctl --user status claude-agent` shows the unit as `active`, but the agent never appears in the `claude.ai/code` device list. `journalctl --user -u claude-agent -n 100` shows the binary blocked on a workspace-trust prompt that never receives input. The auto-restart loop ratchets up indefinitely (we hit 18,000+ restarts over ~2 hours before noticing).

## Workarounds tried

| Workaround | Result |
|---|---|
| `git -C $HOME init` (auto-trust git repos) | **Insufficient** on 2.1.119+ under systemd. Prompt still fires. |
| Pre-touching `$HOME/.git/HEAD` etc. | Same as above. |
| Running `claude remote-control` once interactively first to "warm" trust state | Trust granted in interactive run, but unit's first launch still re-prompts. (Different pid, different working-dir resolution path? Unclear.) |
| Setting `WorkingDirectory=` to `/tmp` (a non-git path) | Different prompt; doesn't help. |
| Type=forking, Type=oneshot, etc. | Doesn't change the prompt blocking — the issue is at binary level, not unit level. |

## What would unblock

Any one of these would let the kit deliver its headline UX on current CLI:

1. **`--trust-workspace` flag on `claude remote-control`** — explicit, scriptable, no env-var pollution.
2. **`CLAUDE_TRUST_WORKSPACE=1` env var** — cleanest for systemd users (`Environment=` in the unit).
3. **`workspaceTrust.allowedPaths: [...]`** key in `~/.claude/settings.json` — opts a specific path into trust on first launch.
4. **Documented "trust state file"** — a single file the kit could `touch` during install with a documented schema.

Option 2 or 3 would be the lowest friction.

## Why this matters

The "Claude Code on a remote box, reachable from the web app and phone" use case is the basis of every community deployment kit (`claude-agent-kit`, similar projects). Without an unattended-trust path, those kits all hit the same wall, and users are pushed to either:

- Run `claude` inside `tmux` over SSH (works, but loses the web-app/phone reach surface — different product).
- Maintain a long-lived interactive session (defeats the point of a VPS deployment).

## Logs / evidence

`journalctl --user -u claude-agent -n 100`:

```
Apr 24 14:45:21 ubuntu systemd[269637]: claude-agent.service: Failed with result 'exit-code'.
Apr 24 14:45:26 ubuntu systemd[269637]: claude-agent.service: Scheduled restart job, restart counter is at 53.
Apr 24 14:45:28 ubuntu claude[280455]: Error: Input must be provided either through stdin or as a prompt argument when using --print
```

(The `--print` reference in the error is misleading — the unit doesn't pass `--print`; the binary is internally falling back to a `--print`-equivalent path when interactive input isn't available, and reporting the error from there.)

## Reference

Community kit affected: <https://github.com/Product-nomad/claude-agent-kit> (see `INCIDENTS/2026-04-24-workspace-trust.md` and `DECISIONS.md`).
