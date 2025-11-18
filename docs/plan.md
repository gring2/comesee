# Implementation Plan

## 0) Foundations
- Set up Flutter/Dart project hygiene: lint fixed, null-safety on, fastlane/CI skeleton, env configs (dev/prod).
- Define feature flags for transport selection (BLE discovery; Wi‑Fi Direct / LAN P2P).
- Add minimal shared models: PhotoItem(id, localId, uri, width, height, isLivePhoto:false), Session(id, hostId, peers, state), TransportConfig.

## 1) Photos scope (photos only)
- Permissions: request iOS Photos read-only (limited library support), surface rationale UI; never request video write.
- Fetch/query: list photos only; exclude videos/Live Photos or treat Live as still frame; no originals persisted.
- Filtering: apply mediaType == image, map to PhotoItem, downscale to display resolution for send.

## 2) Proximity discovery & transport
- BLE beacon: advertise host session UUID + friendly name + capacity; scan when not in session; debounce notifications.
- P2P data channel: prefer Wi‑Fi Direct (local-only) fallback to same-LAN TCP sockets; abstract transport behind interface.
- Security: encrypt channel (TLS/DTLS over socket); ephemeral session key exchange; no backend.
- Capacity handling: enforce max peers (target 6–8); reject with reason code when full.

## 3) Session + privacy buffer
- Host flow: start session -> advertise -> accept joins -> stream photos.
- Guest flow: receive discovery notification -> tap join -> connect transport -> receive current photo pointer.
- Privacy delay: configurable (default 2s); timer per photo; cancel action prevents send.
- Fast scrub logic: coalesce rapid swipes; send only latest stable frame.
- Session end: host stops or all guests leave; ensure cleanup (advertising, sockets, cache).

## 4) UI/UX
- Screens: Home (Host/Join), Gallery picker (photo-only), Session viewer (host controls, guest view), Permissions prompt, Error states.
- States: discovering, connecting, in-session, ended; show toasts/banners for join/leave/denied/full.
- Guest during buffer: placeholder or last photo; host cancel feedback.
- Accessibility/localization hooks; dark mode support.

## 5) Sync, perf, and data handling
- Image pipeline: fetch -> downscale/compress -> chunked binary send -> render; cap size/resolution.
- Latency budget: target 300–500ms host swipe to guest render (buffer excluded); measure with instrumentation logs.
- Caching: in-memory/disk temp during session; purge on end; no originals stored.
- Error handling: retries/backoff for drops; reconnect flow if host remains active.

## 6) Security & abuse controls
- Auth-lite: ephemeral session IDs; optional session PIN if multiple hosts nearby.
- Host controls: kick/ban guest (TBD), stop sharing; guest decline flow.
- Privacy: never send photo metadata (location, EXIF) unless explicitly allowed; strip before send.

## 7) Testing & tooling
- Unit: photo filtering, delay logic, transport interface (mock), coalescing of scrubs.
- Integration: host/guest happy path, late join, cancel within buffer, session full/deny.
- Perf tests: measure end-to-end latency and bandwidth usage on target devices.
- QA checklist: permissions flows, airplane mode, BLE off/Wi‑Fi off edge cases.

## 8) Delivery
- Build flavors (dev/internal/release); minimal release notes.
- Telemetry (optional): local-only logs with opt-in; no remote analytics.
- Store readiness: icon/splash, onboarding for permission rationale, privacy statement (local-only data).
