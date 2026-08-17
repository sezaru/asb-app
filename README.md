# asb-app

The companion app for Emacs [`agent-shell`](https://github.com/xenodium/agent-shell)
(and its [bridge](https://github.com/sezaru/agent-shell-bridge)) — mirror live
agent sessions to a phone and drive them back, over an **end-to-end-encrypted,
serverless** transport (iroh), with faithful structured rendering.

Codename `asb-app`. See the design spec and plan in the agent-shell-bridge repo
under `docs/specs/` and `docs/plans/`.

## Status

**Plan 1 (Rust core) — done.** The headless transport is complete and tested:

- `crates/asb-protocol` — wire message model (structured payloads with
  `seq`/`turn`), ndjson (Emacs) + CBOR (phone) codecs, a durable per-session
  replay log, ed25519 identity, the iroh endpoint + framing, symmetric roster,
  PAKE-over-iroh pairing, and the reusable `PhoneClient`.
- `crates/asb-sidecar` — the daemon: unix-socket ndjson server for N Emacs
  instances, a session registry that owns `seq`, an iroh server gated by the
  roster, client presence, a `PushSender` seam (FCM later), and the `run`/`pair`
  CLI.

The walking skeleton is proven headlessly (`phone_mirrors_and_injects`): pair
over real iroh+PAKE → mirror a scripted session to a phone client → inject a
prompt back → it surfaces as an Emacs `inject`.

**Next:** Plan 2 — the `agent-shell-bridge-app.el` provider that drives the unix
socket. Plan 3 — the Flutter client (`flutter_rust_bridge` wrapping
`asb-protocol`), **built on charmander** (arm64 can't).

## Build & test

```sh
nix develop -c cargo test        # all unit + loopback integration tests
```

Native on any Linux host (aarch64 fine); no Android toolchain needed for the core.

## Run

```sh
nix develop -c cargo run -p asb-sidecar -- run     # resident daemon
nix develop -c cargo run -p asb-sidecar -- pair    # pair a device (stop the daemon first)
```

State lives under `$XDG_STATE_HOME/asb` (identity, roster, per-session logs); the
Emacs socket is `$XDG_RUNTIME_DIR/asb.sock`.

> v1 limitation: `pair` binds its own endpoint on the device identity, so the
> daemon must be stopped while pairing (one endpoint per identity). A
> socket-triggered in-daemon pairing mode is a follow-up.
