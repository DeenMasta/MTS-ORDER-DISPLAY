# Kitchen Display Development Plan

## Purpose and scope

This is the implementation plan for the **Kitchen Display System (KDS)** Android
application. It turns the API and POS-integration documents in this directory into
an incremental delivery plan for this repository.

The KDS is a standalone client after pairing:

1. It initiates a short-lived LAN pairing exchange with the POS.
2. It receives a display-scoped backend credential once.
3. It loads, stores, displays, acknowledges, and updates kitchen tickets directly
   with the backend.
4. It uses Reverb/Pusher events as a reason to synchronize, never as the ticket
   source of truth.

Android is the first release target. Windows and web runners can remain useful for
development, but they are not part of the first production milestone.

## Architecture

Keep the application intentionally small:

- Use Flutter `ChangeNotifier` controllers for screen state.
- Construct dependencies once in the app composition root; pass them to the
  controllers explicitly.
- Use one local SQLite database for durable ticket state, the synchronization
  cursor, and pending outbound actions.
- Store only the display credential/session bundle in Android Keystore-backed secure
  storage.
- Keep API, persistence, pairing, and realtime code separate from widgets.
- Do not add broad Clean Architecture layers, generic repositories, or use-case
  classes for every endpoint.

```text
lib/
  main.dart
  app/
    app.dart                         # MaterialApp, navigation, theme
    app_config.dart                  # non-secret deployment configuration
    app_dependencies.dart            # dependency composition root
    session_controller.dart          # boot, paired/unpaired routing, expiry
  core/
    network/api_client.dart          # backend envelope/error handling
    storage/app_database.dart        # SQLite migrations and transactions
    storage/credential_store.dart    # secure display session storage
  features/
    pairing/
      pairing_models.dart
      pairing_client.dart            # POS-LAN calls only
      pairing_controller.dart
      pairing_screen.dart
    kitchen/
      models/
      data/
      sync/
      presentation/
    settings/
      settings_screen.dart
```

`PairingClient` must be separate from the authenticated backend client so a display
token can never be sent to the POS LAN endpoints.

## Local data

Persist the following data:

| Record | Purpose |
| --- | --- |
| Secure display session | Display access token, expiry, backend display ID, API/channel configuration. |
| Installation ID | A stable UUID used as the KDS `display_id`; separate from the backend display ID. |
| Tickets | Backend ticket ID, revision, status, timestamps, and ticket payload. |
| Sync state | Cursor and last successful synchronization time. |
| Pending actions | Durable ticket acknowledgements and intended status changes awaiting backend acceptance. |

Ticket records are keyed by backend `ticket.id`, not `sale_id`. A sale can produce
multiple tickets across departments and revisions.

Commit ticket upserts/removals and `next_cursor` in one database transaction. Advance
the cursor only after every change in that response is safely stored. Send a ticket
acknowledgement only after its ticket is committed locally.

## Delivery phases

### Phase 0 — Contract and development environment

1. Set Android as the initial target and document API/Reverb deployment values.
2. Obtain a backend test environment, POS test device, and a real example ticket
   including modifiers and variants.
3. Select the smallest viable package set: HTTP, SQLite, Android secure storage,
   UUID, and a Pusher/Reverb-compatible realtime client.
4. Record the agreed user workflow: pairing, active ticket board, ticket actions,
   connection feedback, and re-pairing.

**Done when:** the team can pair an Android device against a reachable test POS and
backend, and the contract questions below have owners or agreed assumptions.

### Phase 1 — Foundation and safe startup

1. Replace the starter counter screen with the app shell and a simple theme suitable
   for a kitchen tablet.
2. Add app configuration, dependency composition, startup routing, and common typed
   API failures.
3. Add Android internet support and the explicit local-HTTP configuration required
   for the documented POS-LAN pairing endpoint.
4. Add secure storage plus SQLite schema/migrations.
5. Implement `SessionController` to restore a paired session at startup or route to
   pairing when no valid session exists.
6. Ensure logs and error reporting never include access tokens, nonces, pairing
   codes, or complete sensitive ticket payloads.

**Done when:** the app starts predictably, survives restart with its local session and
database intact, and `flutter analyze` plus automated tests pass.

### Phase 2 — POS LAN pairing

1. Create the pairing screen: KDS name, POS IP/port, visible short code, pending,
   failure, cancellation, and expiry states.
2. Generate a fresh cryptographically secure nonce and short code for every attempt.
3. Send the documented challenge to
   `POST /v1/kds/pair/challenge` and poll
   `GET /v1/kds/pair/result?nonce={nonce}` until confirmed, rejected, cancelled, or
   expired.
4. Send the exact received nonce/code to the POS/backend flow and commit the returned
   display session to secure storage only after a confirmed result.
5. Clear temporary pairing state after success, cancellation, leaving the screen, or
   ten-minute expiry.
6. On `401`, or the explicitly identified inactive-display-token `403`, stop active
   workers, clear the secure session, and route back to pairing.

**Done when:** a clean Android KDS pairs with a real POS over the same Wi-Fi, does not
persist sensitive pairing data, and handles cancellation, expiry, and restart safely.

### Phase 3 — Durable ticket synchronization and board

1. Implement the authenticated `GET /api/v2/kitchen-tickets` client and response
   envelope parsing.
2. Build a serialized cursor-drain service:
   - Initial request establishes the baseline.
   - Incremental requests use the saved cursor and repeat immediately while
     `has_more` is true.
   - A failed request leaves the existing cursor untouched.
3. Persist active tickets and remove/archive `served` or `cancelled` tickets from the
   active board.
4. Send `POST /ack` only for tickets already stored durably.
5. Build the board with loading, empty, offline/cached, synchronization, and failure
   states, plus readable ticket cards and a ticket-detail view.

**Done when:** initial load, ticket amendments, cancellations, multiple departments,
and an app restart reproduce the backend’s current ticket feed without skipped cursor
events.

### Phase 4 — Kitchen actions and offline queue

1. Add the approved status actions using
   `PATCH /api/v2/kitchen-tickets/{ticketId}/status`.
2. Store status intentions in a durable, per-ticket ordered queue before sending them.
3. Show pending and retry/error feedback without presenting a local intent as confirmed
   backend state.
4. Use capped exponential backoff for transient failures and respect `Retry-After`.
5. On conflicts or terminal-state rejection, synchronize first and resolve visible
   invalid actions rather than retrying forever.
6. Never replay an action for a served/cancelled ticket or onto a replacement revision.

**Done when:** pending actions survive process death and network loss, recover after
reconnect, and cannot incorrectly update cancelled or replaced tickets.

### Phase 5 — Realtime synchronization and recovery

1. Authenticate and subscribe to the paired display’s private Reverb/Pusher channel.
2. Treat `kitchen-ticket.created`, `kitchen-ticket.updated`, and
   `kitchen-ticket.cancelled` as cursor-sync wake-ups only.
3. Coalesce event bursts so at most one cursor drain operates at a time; retain a wake
   request that arrives during a drain.
4. Run a repair poll every 45 seconds and synchronize after app start, app resume,
   network recovery, and realtime reconnect.
5. Render a visible notification for `kitchen-display.test`.

**Done when:** missed broadcasts, websocket reconnects, pagination, and event bursts
all converge on the authoritative REST feed; POS receives backend-published kitchen
status changes.

### Phase 6 — Device hardening and release

1. Tune tablet typography, contrast, touch targets, long remarks, modifiers, and
   large-ticket layouts.
2. Add a compact settings/diagnostics screen showing display identity, connection
   health, token expiry, app version, and a deliberate reset/re-pair action.
3. Decide and implement foreground/screen-awake behavior appropriate for the outlet.
4. Run end-to-end tests for Wi-Fi loss, backend outage, app restart, expired token,
   disabled/unpaired display, large backlog, revision cancellation, and test message.
5. Produce a signed Android release and an operational deployment/runbook.

**Done when:** the complete integration checklist in `KITCHEN_DISPLAY_API.md` has been
executed with real POS, backend, and Android devices.

## Test strategy

Add tests with each phase:

- Unit tests for API-envelope parsing, error mapping, pairing state transitions, and
  credential invalidation.
- Database tests proving cursor/ticket changes are atomic and recover after failure.
- Sync tests for pagination, event coalescing, reconnect, and repair polling.
- Queue tests for ordered status writes, retries, conflicts, and terminal tickets.
- Widget tests for pairing, loading, empty, offline, pending-action, long-ticket, and
  error states.
- Device integration tests for pairing and the backend/POS workflows.

Run these quality gates before each handoff:

```sh
flutter analyze
flutter test
flutter run -d <android-device>
```

## Contract points to resolve

The implementation should begin with the POS implementation document’s concrete
challenge/result polling endpoints. Before completing Phase 2, resolve these items:

1. The pairing result example does not echo the nonce. Confirm that querying the
   nonce-bound URL is the accepted binding, or add the nonce to the response.
2. The challenge requires KDS `host` and `port`, although the KDS does not host a LAN
   server. Confirm the required metadata values; do not add a KDS listener merely to
   populate them.
3. Pairing returns backend URLs/channel names but does not define the complete Reverb
   connection values such as host, app key, and TLS settings. Provide them through
   deployment configuration.
4. Define the machine-readable inactive-token `403` error and complete allowed status
   transition rules.
5. Confirm invalid/expired cursor recovery and whether a no-cursor snapshot is ever
   paginated.
6. Confirm the desired first-launch/offline experience: a previously synchronized
   board may be shown with a stale indicator; a newly paired display should wait for
   its first successful snapshot.

## Planned repository changes

The first implementation phases will modify or add:

- `pubspec.yaml` — minimal production dependencies.
- `android/app/src/main/AndroidManifest.xml` and Android network configuration —
  network support for backend and local POS pairing.
- `lib/main.dart` — bootstrap only after the app shell exists.
- `lib/app/`, `lib/core/`, and `lib/features/` — application implementation.
- `test/` — mirrored unit and widget tests.

The existing API and POS implementation documents remain the contract references;
this file is the delivery plan.
