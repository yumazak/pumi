# pumi

An iOS app and its bridge for the agents running on an [opencode](https://opencode.ai)
server, over Tailscale. Named after the Hungarian herding dog: it drives the flock
rather than gathering it.

## Layout

```
crates/pumi/        Rust bridge: opencode API pass-through, event relay, Web Push
crates/pumi/web/    PWA: Web Push subscription and notification deep links
ios/                SwiftUI app (XcodeGen, no Xcode UI required)
```

The bridge is the only thing that talks to opencode. The iOS app and the PWA talk to
the bridge.

## Bridge

```bash
cargo run -p pumi -- serve --port 7180
```

- `GET /api/sessions` — the cross-project list, with `active` and `pending` merged in
- `GET /api/sessions/{id}/messages` — newest page first, paged with `cursor`
- `POST /api/sessions/{id}/prompt` — `delivery: queue` holds it for the running turn
- `GET /api/sessions/{id}/inbox` — prompts waiting for the running turn
- `GET /api/events?session={id}` — SSE, forwarded from opencode

Publish the loopback port to your tailnet with `tailscale serve`; pumi binds
`127.0.0.1` only.

## iOS

See [ios/README.md](ios/README.md). The short version:

```bash
cd ios
xcodegen generate
./deploy.sh          # build, install and launch on the connected iPhone
```
