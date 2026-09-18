# server

Backend services live here.

Relay call ICE issuance envs:
- `SECRETLY_RELAY_ICE_POLICY`: `p2p_preferred`, `relay_preferred`, or `relay_only`
- `SECRETLY_RELAY_ICE_STUN_URLS`: comma-separated STUN URLs under your control
- `SECRETLY_RELAY_ICE_TURN_URLS`: comma-separated TURN/TURNS URLs under your control
- `SECRETLY_RELAY_TURN_SHARED_SECRET`: coturn REST shared secret for short-lived credentials
- `SECRETLY_RELAY_TURN_TTL_SECONDS`: TURN credential TTL in seconds, clamped to `60..3600`

Relay calls readiness endpoint:
- `GET /health/calls`: returns `200` only when relay has a usable TURN path for calls; returns `503` when TURN URLs or TURN secret are missing
