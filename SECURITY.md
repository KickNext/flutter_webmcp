# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Send a private
security report through the repository's GitHub Security Advisory page.

Include the affected package version, browser version, a minimal reproduction,
and the expected security impact. Please avoid including real credentials or
personal data.

## Security model

WebMCP tools execute inside the application page and have the same authority as
that page's Dart code. Applications are responsible for authentication,
authorization, confirmation of destructive actions, input validation, and
protecting sensitive results.

Tool annotations are hints to agents, not access controls. Restrict cross-origin
discovery with `exposedTo`, use HTTPS, and apply an appropriate
`Permissions-Policy` header where WebMCP must be disabled.

`WebMcp.logger` can receive tool inputs, outputs, errors, and stack traces. Do
not send these diagnostics to telemetry without redacting secrets and personal
data.
