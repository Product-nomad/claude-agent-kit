# Security policy

## Reporting a vulnerability

Email **randumpunta@gmail.com** with subject `[claude-agent-kit] security`.
Please do **not** open a public GitHub issue for security reports.

If a finding involves Claude Code CLI behaviour we depend on (rather
than this kit's own logic), I'll loop in Anthropic's security team
before publishing.

## Expected response

| Stage | Target |
|---|---|
| Acknowledge receipt | within 7 days |
| Triage + remediation timeline | within 14 days of acknowledgement |
| Public disclosure | once a fix is shipped, or 90 days from the report — whichever comes first |

## In and out of scope

See [`THREAT_MODEL.md`](THREAT_MODEL.md). In particular, the following
are **not** vulnerabilities in this kit:

- Issues that stem from `bypassPermissions` being permissive — that is
  the explicit tradeoff this kit documents.
- Issues that require a multi-user VPS — the kit assumes a single-tenant
  box.
- Issues in the upstream Claude Code CLI itself — please report those
  to Anthropic directly.
