# Kitchen Display POS Integration

This is the POS implementation of `KITCHEN_DISPLAY_API.md`. KDS traffic stays
on the outlet LAN; Laravel Cloud is only used for display configuration and
operator-approved pairing.

## Architecture

```text
KDS Android app -- persistent ws://POS-IP:PORT/kds --> POS LAN listener
                                                        |
                                                        +-- pairing confirmation
                                                        +-- department routing
                                                        +-- order retry until ack

POS Settings -- HTTPS --> Laravel API
                         pairing start/confirm, list, update, delete only

Existing kitchen print job --> physical printer
                          --> structured kitchen_order to matching KDS sockets
```

There are no KDS ticket, status, test, access-token, or Reverb endpoints.

## Pairing flow

1. POS starts its local WebSocket listener during application startup. In
   Settings, **Pair Display** shows its LAN IP and port.
2. KDS connects to `ws://{pos-ip}:{port}/kds` and sends `pair.challenge` with
   its stable display ID, name, nonce, code, and capabilities.
3. POS shows the code and lets the operator select existing Department Printer
   departments.
4. POS sends the pairing start request to Laravel using the POS listener IP
   and port. After Laravel confirms the code, POS sends `pair.confirmed` on
   the same KDS socket. Its `display_id` is the Laravel kitchen-display record
   ID, not the KDS installation UUID from `pair.challenge`.
5. That socket remains open for kitchen orders. Updating departments or the
   enabled switch updates the in-memory routing immediately. Disabling or
   deleting a display closes the matching socket.

The pairing challenge expires after 10 minutes. The KDS must not accept an
order until it receives `pair.confirmed` for its current socket.

## KDS app integration

### Connection state

Implement the KDS connection as this small state machine:

```text
disconnected -> connecting -> waitingForPairConfirmation -> paired
      ^                                                |
      +---------------- reconnect on socket close -----+
```

On every new socket, create a fresh random `nonce` and 4–32 character `code`,
show the code to the operator, and send `pair.challenge`. The KDS can reconnect
automatically, but a new connection must complete the documented nonce/code
pairing before it is trusted. There is intentionally no KDS bearer token or
cloud ticket endpoint.

Persist these values on the KDS device:

| Value | Why |
| --- | --- |
| Installation UUID | Sent as `pair.challenge.display_id`; stable for the app installation. |
| Laravel display ID | Received in `pair.confirmed`; useful for local diagnostics. |
| Order cards and their latest revision | Restores the kitchen screen after an app restart. |
| Processed `message_id` values | Makes a POS retry safe. |
| Local dismissal state | Dismissal stays on the KDS and is never sent upstream. |

The installation UUID and Laravel display ID are different values. Do not
replace the installation UUID with the ID in `pair.confirmed`.

### Pairing messages

Send this immediately after the socket opens:

```json
{
  "type": "pair.challenge",
  "display_id": "stable-kds-installation-uuid",
  "name": "Main Kitchen",
  "nonce": "new-random-value-for-this-attempt",
  "code": "483921",
  "capabilities": {
    "app_version": "1.0.0",
    "protocol": "kitchen-order.v1"
  }
}
```

Wait for this response on the same socket:

```json
{
  "type": "pair.confirmed",
  "display_id": "kitchen-display-id",
  "protocol": "kitchen-order.v1"
}
```

Validate `protocol == "kitchen-order.v1"`, persist `display_id`, then change
the local connection state to `paired`. A closed socket, malformed message, or
unexpected protocol returns the app to `disconnected`; do not treat it as a
paired session.

## Order delivery

The existing kitchen/void print job remains the source of truth for grouping:
its `DepartmentPrinter` already provides the department and filtered items.
POS sends one `kitchen_order` message per job with the stable print-cache ID as
`message_id`, an `upsert` action for kitchen jobs, or `cancel` for void jobs.

Each enabled display assigned to that department receives the same structured
message. POS queues the message for configured displays, retries every three
seconds, and stops after a matching acknowledgement or three attempts. A KDS
that pairs during that retry window receives the queued message. Delivery logs
include the message, sale, department, display, attempt, send/ack timestamps,
and a disconnection error where relevant.

### Receiving and acknowledging an order

Handle only `kitchen_order` messages while the socket is `paired`.

1. Validate `protocol`, `message_id`, `sale_id`, `department_id`, `revision`,
   `action`, and the items array.
2. In one local database transaction, check `message_id` and the current card
   revision for `(sale_id, department_id)`.
3. A duplicate `message_id` changes nothing. An older revision changes
   nothing. In both cases, acknowledge it again.
4. For `action: "upsert"`, create or replace the card only when the revision is
   newer. For `action: "cancel"`, remove that department card when the revision
   is not older.
5. Save the processed message ID before sending the acknowledgement. Do not
   acknowledge an order that failed to save.

Reply on the same socket:

```json
{
  "type": "kitchen_order.received",
  "message_id": "the-message-id-received",
  "received_at": "2026-10-29T10:30:01+08:00"
}
```

An acknowledgement is delivery/storage confirmation only. Never send
`preparing`, `ready`, `served`, dismissal, or any other kitchen workflow state
to POS or Laravel.

## Code map

```text
lib/features/kitchen_display/
  data/remote/kitchen_display_repository_impl.dart  Laravel admin APIs
  domain/models/kitchen_display_pairing.dart         pairing request/result
  presentation/services/kds_pairing_server.dart      LAN WebSocket + ack retry
  presentation/screens/kitchen_display_setup_screen.dart
                                                     Settings pairing/admin UI

lib/data/services/printer_job_service.dart           existing printer job hook
```

## Verification

Focused Flutter tests cover backend-ID pairing, acknowledgement ownership,
retry cancellation, and delivery queued before pairing:

```text
flutter test test/features/kitchen_display
```

## Operational notes

- POS and KDS must be on the same Wi-Fi/LAN and the POS listener port must be
  reachable from the KDS device.
- POS must stay running to accept connections and deliver orders.
- KDS should reconnect with exponential backoff, then generate a new pairing
  nonce/code for that socket. Do not reuse a stale pairing confirmation.
- KDS should deduplicate by `message_id`; POS can resend an unacknowledged
  order during its three-attempt retry window.
- Laravel migrations and the updated five administration endpoints must be
  deployed separately before pairing is tested.
- The KDS Android source is not part of this repository. It needs only a local
  WebSocket client and local card/message storage; it must never call Laravel
  or store POS credentials.
