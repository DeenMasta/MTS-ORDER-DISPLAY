# Kitchen Display API and App Integration Guide

**Backend API prefix:** `/api/v2`

**Clients:** POS application and Kitchen Display System (KDS) Android application

**Last updated:** 28 October 2026

This document is the integration contract for connecting the existing POS application,
the backend, and the new KDS application. It covers pairing over the outlet LAN,
display setup, ticket synchronization, realtime notifications, and ticket status.

## 1. Architecture

```text
                 Outlet LAN (pairing only)
┌─────────────┐  KDS opens connection to POS  ┌─────────────┐
│  KDS app    │ ─────────────────────────────> │   POS app   │
└──────┬──────┘                                └──────┬──────┘
       │                                              │
       │ Display token + HTTPS/Reverb                 │ POS token + HTTPS/Reverb
       │                                              │
       └──────────────────┐        ┌──────────────────┘
                          ▼        ▼
                      ┌────────────────┐
                      │    Backend     │
                      │ REST + Reverb  │
                      └────────────────┘
```

Important rules:

- The **KDS initiates the local connection to the POS IP address**. The backend never
  attempts to connect to a private outlet IP.
- The local connection is used only for pairing and securely handing the display
  credential to the KDS.
- After pairing, tickets travel through backend REST and Reverb, not directly from
  the POS to the KDS.
- The REST cursor feed is authoritative. Realtime events tell clients when to sync.
- KDS tickets are independent of `PrintReceiptCache` and printer retry handling.

## 2. Authentication and headers

| Client | Credential | Used for |
| --- | --- | --- |
| POS | Existing staff/POS Sanctum bearer token | Pairing and display administration |
| KDS | Display-scoped bearer token returned by pairing confirmation | Ticket feed, acknowledgement, status, and broadcast authentication |

### POS request headers

```http
Authorization: Bearer {pos-access-token}
Accept: application/json
Content-Type: application/json
pos-device-id: {active-pos-device-id}
```

The `pos-device-id` header is required by pairing endpoints. Confirmation must be
performed by the same POS device that started the pairing.

### KDS request headers

```http
Authorization: Bearer {display-access-token}
Accept: application/json
Content-Type: application/json
```

The KDS token is scoped to one display. It cannot access normal POS endpoints or
tickets belonging to another display.

## 3. Common response envelope

Successful and failed backend responses use this envelope:

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": {},
  "errors": null
}
```

For validation errors, `is_success` is `false`, `data` is normally `null`, and
`errors` contains field-level validation messages.

## 4. Pairing sequence

The complete pairing sequence is:

1. The operator opens the pairing screen on the KDS.
2. The KDS generates a cryptographically random nonce and short code, displays the
   code, and opens a temporary connection to the POS device's entered/discovered IP.
3. The KDS sends its pairing challenge to the POS over that local connection.
4. The POS sends the challenge to `POST /api/v2/kitchen-displays/pair/start`.
5. The POS shows the KDS name and code for operator verification.
6. The operator confirms, and the POS calls
   `POST /api/v2/kitchen-displays/{id}/pair/confirm`.
7. The POS sends the confirmation response to the KDS over the existing local
   connection.
8. The KDS stores the display token in Android secure storage and closes the temporary
   pairing connection.
9. The KDS loads the initial ticket snapshot and connects to Reverb.

The backend pairing challenge expires after **10 minutes**. Pairing endpoints are
rate-limited to **10 requests per minute**.

### 4.1 Suggested local KDS-to-POS contract

The local endpoints are implemented by the POS application, not this backend. Both app
teams should use the following contract unless an existing app transport already
provides the same fields.

#### Send pairing challenge to POS

```http
POST http://{pos-ip}:{pos-pairing-port}/v1/kds/pair/challenge
Content-Type: application/json
```

```json
{
  "display_id": "android-installation-uuid",
  "name": "Main Kitchen",
  "host": "192.168.1.50",
  "port": 8080,
  "nonce": "random-unguessable-value",
  "code": "483921",
  "capabilities": {
    "app_version": "1.0.0",
    "api_version": 1,
    "realtime": true
  }
}
```

Suggested POS response while operator confirmation is pending:

```json
{
  "accepted": true,
  "state": "pending",
  "pairing_request_id": "01J..."
}
```

#### Return the completed pairing to KDS

The POS can either respond on the existing socket/connection or expose a polling
endpoint such as:

```http
GET http://{pos-ip}:{pos-pairing-port}/v1/kds/pair/result?nonce={nonce}
```

Pending:

```json
{
  "state": "pending"
}
```

Confirmed:

```json
{
  "state": "confirmed",
  "display_id": "01J...",
  "access_token": "plain-text-token-shown-once",
  "expires_at": "2027-01-26T10:00:00Z",
  "api_base_url": "https://api.example.com/api/v2",
  "broadcast_auth_url": "https://api.example.com/broadcasting/auth",
  "channel_name": "private-kitchen-display-01J...",
  "echo_channel": "kitchen-display-01J..."
}
```

Security requirements for the local flow:

- Generate a new nonce and code for every attempt.
- Do not log the display access token.
- Match the result to the original nonce before accepting it.
- Keep the result only until the KDS confirms receipt or the pairing expires.
- Store the display token using Android Keystore-backed encrypted storage.

## 5. POS-facing backend APIs

These endpoints require the normal POS bearer token.

### 5.1 Start pairing

```http
POST /api/v2/kitchen-displays/pair/start
```

Request:

```json
{
  "display_id": "android-installation-uuid",
  "name": "Main Kitchen",
  "host": "192.168.1.50",
  "port": 8080,
  "outlet_id": "01HOUTLET...",
  "department_ids": ["01HDEPT-HOT...", "01HDEPT-COLD..."],
  "nonce": "random-unguessable-value",
  "code": "483921",
  "capabilities": {
    "app_version": "1.0.0",
    "api_version": 1,
    "realtime": true
  }
}
```

Validation:

- `display_id`: required string, maximum 128 characters
- `name`: required string, maximum 120 characters
- `host`: required IPv4 or IPv6 address
- `port`: required integer from 1 to 65535
- `outlet_id`: required existing outlet
- `department_ids`: required non-empty array of existing department IDs
- `nonce`: required string, maximum 255 characters
- `code`: required string, 4 to 32 characters
- `capabilities`: optional object

Success: `201 Created`

```json
{
  "is_success": true,
  "status_code": 201,
  "message": null,
  "data": {
    "id": "01JKITCHENDISPLAY...",
    "pairing_status": "pending",
    "expires_at": "2026-10-28T10:10:00Z"
  },
  "errors": null
}
```

### 5.2 Confirm pairing

```http
POST /api/v2/kitchen-displays/{displayId}/pair/confirm
```

Request:

```json
{
  "code": "483921",
  "nonce": "random-unguessable-value"
}
```

Success: `200 OK`

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": {
    "display_id": "01JKITCHENDISPLAY...",
    "access_token": "plain-text-token-shown-once",
    "expires_at": "2027-01-26T10:00:00Z",
    "handoff": {
      "transport": "existing-kds-to-pos-ip-connection",
      "api_base_url": "https://api.example.com/api/v2",
      "broadcast_auth_url": "https://api.example.com/broadcasting/auth",
      "channel_name": "private-kitchen-display-01JKITCHENDISPLAY...",
      "echo_channel": "kitchen-display-01JKITCHENDISPLAY..."
    }
  },
  "errors": null
}
```

The plain-text `access_token` is returned only at confirmation. The POS must forward
it to the KDS immediately and must not persist it in logs or application telemetry.
The token expires after **90 days**. Re-pair the display before or after expiry to
issue a new token.

Pairing confirmation also reconciles current open orders so the newly paired display
receives relevant tickets immediately.

### 5.3 List displays for an outlet

```http
GET /api/v2/kitchen-displays?outlet_id={outletId}
```

Use this endpoint for the POS Settings page. Each item contains the display identity,
name, host/port, departments, pairing state, enabled state, and last-seen information.

### 5.4 Update a display

```http
PATCH /api/v2/kitchen-displays/{displayId}
```

All fields are optional; send only changed fields:

```json
{
  "name": "Dessert Station",
  "host": "192.168.1.51",
  "port": 8080,
  "is_enabled": true,
  "department_ids": ["01HDEPT-DESSERT..."]
}
```

Changing departments immediately reconciles open orders. Tickets for removed
departments are cancelled, and newly selected departments receive their current
eligible tickets. Disabling a display cancels its active tickets.

### 5.5 Unpair a display

```http
DELETE /api/v2/kitchen-displays/{displayId}
```

This revokes the display tokens, disables the display, and cancels active tickets.
The KDS must delete its local credential if it later receives `401 Unauthorized` or
the `403` inactive-display-token response.

### 5.6 Send a test message

```http
POST /api/v2/kitchen-displays/{displayId}/test
```

The display must be paired and enabled. The backend emits
`kitchen-display.test` on the display's private channel. The POS can use
`last_seen_at` from the display record alongside this test; delivery of a realtime
message does not by itself prove that the screen rendered it.

## 6. KDS-facing backend APIs

These endpoints require the display-scoped bearer token.

### 6.1 Initial ticket load

```http
GET /api/v2/kitchen-tickets
Authorization: Bearer {display-access-token}
```

Example response:

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": {
    "tickets": [
      {
        "id": "01JTICKET...",
        "display_id": "01JKITCHENDISPLAY...",
        "sale_id": "01JSALE...",
        "department_id": "01HDEPT-HOT...",
        "revision": 1,
        "status": "queued",
        "acknowledged_at": null,
        "created_at": "2026-10-28T10:01:00Z",
        "updated_at": "2026-10-28T10:01:00Z",
        "payload": {
          "sale_id": "01JSALE...",
          "outlet_id": "01HOUTLET...",
          "department_id": "01HDEPT-HOT...",
          "department_name": "Hot Kitchen",
          "order": {
            "running_number": "A-104",
            "table_name": "Table 12",
            "name": "Walk-in",
            "remarks": "No peanuts",
            "order_option": {
              "id": "01HOPTION...",
              "name": "Dine In"
            },
            "created_at": "2026-10-28T10:00:00Z",
            "updated_at": "2026-10-28T10:01:00Z"
          },
          "items": [
            {
              "sale_item_id": "01JSALEITEM...",
              "item_id": "01HITEM...",
              "item_name": "Chicken Rice",
              "category_id": "01HCATEGORY...",
              "quantity": 2,
              "comments": "One without chilli",
              "modifier_json": [],
              "variant_option_json": [],
              "updated_at": "2026-10-28T10:01:00Z"
            }
          ]
        }
      }
    ],
    "events": [],
    "next_cursor": "18542",
    "has_more": false
  },
  "errors": null
}
```

The first request returns active tickets plus a cursor baseline. Persist
`next_cursor` only after the response has been applied successfully.

### 6.2 Incremental ticket synchronization

```http
GET /api/v2/kitchen-tickets?cursor={nextCursor}&limit=50
Authorization: Bearer {display-access-token}
```

The cursor is the append-only `kitchen_ticket_events.id`. It is not a page number or
timestamp.

The incremental response contains:

- `tickets`: the latest version of each changed ticket
- `events`: ordered event references with `id`, `event`, and `ticket_id`
- `next_cursor`: the last event processed by this response
- `has_more`: whether another request is required immediately

Incremental results include `served` and `cancelled` tickets so the KDS can remove
stale cards after reconnecting.

Recommended sync algorithm:

```text
1. Load the locally persisted cursor.
2. GET /kitchen-tickets?cursor={cursor}&limit=50.
3. In a local database transaction, upsert every ticket by ticket ID.
4. Remove or archive cards whose latest status is served or cancelled.
5. Persist next_cursor only after all ticket updates succeed.
6. If has_more is true, repeat immediately with next_cursor.
7. Otherwise wait for a realtime event or the repair-poll interval.
```

Run this cursor sync:

- immediately after pairing
- whenever the app starts or regains network connectivity
- after every ticket realtime event
- every **30–60 seconds**, even when realtime is connected

The periodic request repairs missed broadcasts and refreshes the display's
`last_seen_at` value.

### 6.3 Update ticket status

```http
PATCH /api/v2/kitchen-tickets/{ticketId}/status
Authorization: Bearer {display-access-token}
Content-Type: application/json
```

```json
{
  "status": "preparing"
}
```

Allowed states:

| Status | Meaning |
| --- | --- |
| `queued` | Ticket was generated and awaits kitchen action |
| `acknowledged` | Kitchen staff accepted the ticket |
| `preparing` | Preparation is in progress |
| `ready` | Items are ready for service or pickup |
| `served` | Ticket is completed and can leave the active board |
| `cancelled` | Ticket was cancelled by the order lifecycle or kitchen |

Rules:

- Repeating the current state is idempotent.
- `served` and `cancelled` are terminal states.
- Status writes are serialized by the backend to prevent competing updates.
- The backend broadcasts the changed ticket to both the display and POS outlet.
- On a conflict or terminal-state rejection, sync the ticket feed before retrying.

### 6.4 Acknowledge delivery

```http
POST /api/v2/kitchen-tickets/{ticketId}/ack
Authorization: Bearer {display-access-token}
```

This records that the application received the ticket. It is separate from kitchen
acceptance (`acknowledged` status) and is idempotent. Call it after the ticket has been
durably stored in the KDS local database, not merely when a realtime event arrives.

## 7. Realtime integration

Realtime transport uses the backend's Laravel Reverb/Pusher-compatible connection.
Connection values such as host, port, TLS, app key, and cluster should come from the
environment configuration supplied to each app.

### KDS subscription

| Setting | Value |
| --- | --- |
| Broadcast authentication | `POST /broadcasting/auth` |
| Authentication | Display bearer token |
| Raw Pusher channel | `private-kitchen-display-{displayId}` |
| Laravel Echo channel | `kitchen-display-{displayId}` |

KDS events:

| Event | Action |
| --- | --- |
| `kitchen-ticket.created` | Start cursor synchronization |
| `kitchen-ticket.updated` | Start cursor synchronization |
| `kitchen-ticket.cancelled` | Start cursor synchronization |
| `kitchen-display.test` | Show a visible test notification and optionally report locally to the POS connection |

Ticket event payload:

```json
{
  "ticket_id": "01JTICKET...",
  "display_id": "01JKITCHENDISPLAY...",
  "revision": 2,
  "status": "queued",
  "updated_at": "2026-10-28T10:05:00Z"
}
```

Do not build or mutate a complete ticket from this event. Treat it as a wake-up signal
and fetch the authoritative cursor feed.

### POS subscription

| Setting | Value |
| --- | --- |
| Authentication | Existing POS bearer token |
| Raw Pusher channel | `private-outlet-{outletId}` |
| Laravel Echo channel | `outlet-{outletId}` |

The POS can use outlet events to update order and kitchen-status views without polling
after the KDS changes a ticket state.

## 8. Ticket routing and revision behavior

The backend owns ticket routing and lifecycle:

- Sale items are routed through the configured department/category mapping.
- A ticket belongs to one display, sale/order, department, and revision.
- Creating the same logical revision again is idempotent.
- When relevant order content changes, the old active revision is cancelled and a new
  revision is created.
- Voided items are excluded.
- Charging/deleting the sale, disabling the display, removing its department, or
  leaving no eligible items cancels the active ticket.
- Pairing a display or changing its departments reconciles existing uncharged orders.
- Ticket creation locks the display routing record so concurrent order changes do not
  create duplicate revisions.

The KDS must key local records by backend `ticket.id`. Do not assume that `sale_id` is
unique because one sale can produce multiple department/display tickets and revisions.

## 9. Error handling

| HTTP status | Client action |
| --- | --- |
| `400` | Show the operation failure; inspect `message` |
| `401` | Token is absent or cannot be authenticated; KDS deletes the credential and returns to pairing |
| `403` | Credential lacks access; if the message says the display token is no longer active, KDS deletes it and returns to pairing |
| `404` | Resource no longer exists or is outside the credential scope; refresh local state |
| `409` | Display is not active or another state conflict occurred; sync before retry |
| `422` | Validation, invalid/expired pairing challenge, or terminal ticket transition; correct fields or refresh state |
| `429` | Apply exponential backoff and respect `Retry-After` when present |
| `500`–`599` | Preserve local state and retry with capped exponential backoff |

Retry guidance:

- Retry safe GET requests with exponential backoff and jitter.
- Status and acknowledgement calls are idempotent for the same intended state.
- Never discard the current cursor because of a failed request.
- Keep outbound KDS actions in a durable local queue until the backend accepts them or
  returns a non-retryable error.
- Never log bearer tokens, pairing codes, nonces, or complete sensitive ticket data.

## 10. POS implementation checklist

- [ ] Provide a Settings screen to list, pair, rename, configure, disable, test, and
      unpair displays.
- [ ] Include the active `pos-device-id` on pairing requests.
- [ ] Accept the KDS-initiated local pairing challenge.
- [ ] Let the operator choose outlet departments and verify the displayed short code.
- [ ] Start and confirm pairing with the exact nonce/code received from the KDS.
- [ ] Deliver the confirmation handoff to the same local KDS connection.
- [ ] Do not persist or log the display access token.
- [ ] Subscribe to `private-outlet-{outletId}` for kitchen status updates.
- [ ] Show paired/enabled state and `last_seen_at` in display settings.
- [ ] Treat a test broadcast and last-seen value as diagnostics, not a guaranteed
      rendered-screen acknowledgement.

## 11. KDS implementation checklist

- [ ] Create a stable installation UUID for `display_id`.
- [ ] Generate a fresh secure nonce and short pairing code for every attempt.
- [ ] Initiate the connection to the POS device over its LAN IP.
- [ ] Match the returned pairing result to the original nonce.
- [ ] Store the display token using Android Keystore-backed encrypted storage.
- [ ] Persist tickets and the cursor in a transactional local database.
- [ ] Complete the initial snapshot before rendering the active board.
- [ ] Connect to the display's private Reverb channel with the display token.
- [ ] Trigger cursor sync from realtime events and every 30–60 seconds.
- [ ] Acknowledge only after a ticket is stored durably.
- [ ] Queue offline status changes and retry idempotently.
- [ ] Remove/archive `served` and `cancelled` tickets from the active board.
- [ ] On `401`, or the `403` inactive-display-token response, erase the invalid token
      and return to the pairing screen.
- [ ] Never call ordinary POS APIs using the display credential.

## 12. Deployment and integration verification

Before releasing both apps:

- [ ] Run backend database migrations for all four kitchen-display tables.
- [ ] Confirm the public API base URL is reachable from the KDS network.
- [ ] Confirm Reverb WebSocket and `/broadcasting/auth` are reachable from the KDS.
- [ ] Confirm the POS firewall permits the selected local pairing port.
- [ ] Pair a clean KDS installation and verify the token is delivered only once.
- [ ] Create an order with items routed to two departments and verify correct splitting.
- [ ] Amend quantities/comments and verify old revision cancellation plus new revision.
- [ ] Disconnect the KDS, change an order, reconnect, and verify cursor recovery.
- [ ] Change KDS status and verify the POS receives the outlet update.
- [ ] Disable/unpair the display and verify the old token can no longer access tickets.
- [ ] Verify printer receipt retry behavior remains independent of KDS tickets.

## 13. Endpoint summary

| Method | Endpoint | Client | Purpose |
| --- | --- | --- | --- |
| `POST` | `/api/v2/kitchen-displays/pair/start` | POS | Register pairing challenge |
| `POST` | `/api/v2/kitchen-displays/{id}/pair/confirm` | POS | Confirm and issue display token |
| `GET` | `/api/v2/kitchen-displays` | POS | List outlet displays |
| `PATCH` | `/api/v2/kitchen-displays/{id}` | POS | Update display configuration |
| `DELETE` | `/api/v2/kitchen-displays/{id}` | POS | Unpair and revoke display |
| `POST` | `/api/v2/kitchen-displays/{id}/test` | POS | Send realtime test message |
| `GET` | `/api/v2/kitchen-tickets` | KDS | Initial or cursor-based ticket sync |
| `PATCH` | `/api/v2/kitchen-tickets/{id}/status` | KDS | Change kitchen ticket state |
| `POST` | `/api/v2/kitchen-tickets/{id}/ack` | KDS | Record durable ticket receipt |
