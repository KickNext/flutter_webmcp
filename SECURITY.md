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
discovery with `exposedTo` and use HTTPS. For pages that must never expose
WebMCP, serve `Permissions-Policy: tools=()`. It disables WebMCP for the
document and all descendant frames, both same-origin and cross-origin, before
page scripts run. This is defense in depth, not a replacement for authorization.

WebMCP also requires an origin-keyed agent cluster. If the browser does not
enable this by default, serve `Origin-Agent-Cluster: ?1` consistently across
the origin. Registration errors retain the browser cause: `SecurityError`
can indicate a cluster restriction and `NotAllowedError` a policy restriction.

Do not expose passwords, OTPs, PINs, card security codes, authentication
secrets, or sensitive identifiers in model-visible input schemas or results.
Use normal user-mediated UI to collect required secrets. Return only the
information needed for the task, and recheck input, authorization, and current
preconditions inside each handler.

Unregistration and scope disposal do not cancel executing handlers. Guard
widget-bound work with application lifetime state and use the invocation's
execution context for caller cancellation.

`WebMcp.logger` can receive tool inputs, outputs, errors, and stack traces. Do
not send these diagnostics to telemetry without redacting secrets and personal
data.
