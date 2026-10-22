# Security Policy

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private vulnerability reporting:

<https://github.com/yumazak/pumi/security/advisories/new>

We aim to acknowledge reports within a few days.

## Supported versions

Only the latest release is supported.

## Scope

- pumi binds `127.0.0.1` only; the front door is `tailscale serve`.
- The opencode Basic-auth credentials are read by pumi and never sent to the browser.
- `tailscale funnel` is not supported.
