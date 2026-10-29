.0# Kitchen Display LAN Integration

**Protocol:** `kitchen-order.v1`

**Clients:** POS application and Kitchen Display System (KDS) application

**Backend prefix:** `/api/v2`

**Last updated:** 29 October 2026

The KDS is a screen output for the existing kitchen-order printing flow. It shows
orders only; it does not manage `preparing`, `ready`, `served`, or other kitchen
workflow states.

## Architecture

```text
Laravel backend                     Outlet LAN
+------------------+       +------------------+       +------------------+
| Display settings |<----->|     POS app      |<------|     KDS app      |
| and pairing only | HTTPS | Kitchen routing  |  WS   | Displays orders |
+------------------+       +--------+---------+       +------------------+
                                   |
                                   +----------------> Kitchen printer
```

Rules:

- KDS opens the LAN connection to the POS IP address.
- POS reuses the existing kitchen printing trigger and `DepartmentPrinter`
  category routing.
- The printer receives its normal print payload.
- KDS receives structured order JSON, never printer-formatted `print_data`.
- Laravel Cloud does not deliver orders and does not track kitchen status.
- `PrintReceiptCache` remains a printer/cross-print retry concern and is not the
  KDS API.

## Backend authentication and responses

Only the POS calls Laravel. Every display-administration request uses the existing
staff/POS Sanctum token:

```http
Authorization: Bearer {pos-token}
Accept: application/json
Content-Type: application/json
```

Pairing requests also require:

```http
pos-device-id: {active-pos-device-id}
```

The POS device must be active and belong to the selected outlet. KDS never receives
or stores a Laravel bearer token.

Backend responses use this envelope:

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": {},
  "errors": null
}
```

## 1. Pairing

Pairing records the display and its department assignment in Laravel. The local
connection remains the actual order-delivery path.

### 1.1 KDS connects to POS

The operator enters or discovers the POS LAN address. KDS opens a persistent
WebSocket connection:

```text
ws://{pos-ip}:{pos-port}/kds
```

For production outlet networks, use `wss://` when the POS can provide a locally
trusted certificate. If plain `ws://` is used, restrict the listener to the outlet
LAN and require the pairing nonce/code before accepting orders.

KDS sends:

```json
{
  "type": "pair.challenge",
  "display_id": "stable-kds-installation-uuid",
  "name": "Main Kitchen",
  "nonce": "random-unguessable-value",
  "code": "483921",
  "capabilities": {
    "app_version": "1.0.0",
    "protocol": "kitchen-order.v1"
  }
}
```

The code is shown on the KDS screen. Generate a new nonce and code for every
pairing attempt.

### 1.2 POS starts backend pairing

```http
POST /api/v2/kitchen-displays/pair/start
Authorization: Bearer {pos-token}
pos-device-id: {active-pos-device-id}
Content-Type: application/json
```

```json
{
  "display_id": "stable-kds-installation-uuid",
  "name": "Main Kitchen",
  "host": "192.168.1.10",
  "port": 8080,
  "outlet_id": "outlet-id",
  "department_ids": ["department-id"],
  "nonce": "random-unguessable-value",
  "code": "483921",
  "capabilities": {
    "app_version": "1.0.0",
    "protocol": "kitchen-order.v1"
  }
}
```

`host` and `port` identify the POS LAN service to which the KDS connected.

Validation:

- `display_id`: required string, maximum 128 characters
- `name`: required string, maximum 120 characters
- `host`: required IPv4 or IPv6 address
- `port`: required integer from 1 to 65535
- `outlet_id`: required existing outlet available to the staff user
- `department_ids`: required non-empty array of departments belonging to the staff company
- `nonce`: required string, maximum 255 characters
- `code`: required string, 4 to 32 characters
- `capabilities`: optional JSON object

Success: `201 Created`

```json
{
  "is_success": true,
  "status_code": 201,
  "message": null,
  "data": {
    "id": "kitchen-display-id",
    "pairing_status": "pending",
    "expires_at": "2026-10-29T10:10:00Z"
  },
  "errors": null
}
```

The challenge expires after 10 minutes.

### 1.3 POS confirms pairing

After the operator verifies the code:

```http
POST /api/v2/kitchen-displays/{displayId}/pair/confirm
Authorization: Bearer {pos-token}
pos-device-id: {active-pos-device-id}
Content-Type: application/json
```

```json
{
  "code": "483921",
  "nonce": "random-unguessable-value"
}
```

The same active POS device that started pairing must confirm it.

Success:

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": {
    "display_id": "kitchen-display-id",
    "pairing_status": "paired",
    "delivery": {
      "transport": "pos-lan",
      "direction": "kds-connects-to-pos",
      "protocol": "kitchen-order.v1"
    }
  },
  "errors": null
}
```

POS replies on the existing WebSocket connection:

```json
{
  "type": "pair.confirmed",
  "display_id": "kitchen-display-id",
  "protocol": "kitchen-order.v1"
}
```

No display bearer token is issued because KDS does not call the Laravel ticket API.
Deployments must run the included migrations once to revoke display tokens issued by
the retired cloud-ticket flow.

## 2. Order delivery

The POS hooks into the same successful action that creates a kitchen print job.
For each routed department:

1. Group sale items using the existing `DepartmentPrinter.categories` mapping.
2. Send the existing print job to the physical printer when configured.
3. Send one structured KDS message to every connected display assigned to that
   department.
4. Retry until KDS returns a receipt acknowledgement or the configured retry limit
   is reached.

### 2.1 Order message

```json
{
  "type": "kitchen_order",
  "protocol": "kitchen-order.v1",
  "message_id": "unique-message-uuid",
  "sale_id": "sale-id",
  "department_id": "department-id",
  "revision": 1,
  "action": "upsert",
  "order_number": 104,
  "table_name": "Table 12",
  "order_name": "Walk-in",
  "staff_name": "Syad",
  "remarks": "No peanuts",
  "created_at": "2026-10-29T10:30:00+08:00",
  "items": [
    {
      "sale_item_id": "sale-item-id",
      "item_id": "item-id",
      "name": "Chicken Rice",
      "quantity": 2,
      "comments": "One without chilli",
      "modifiers": [],
      "variant_options": []
    }
  ]
}
```

Contract rules:

- `message_id` uniquely identifies one delivery attempt group and is used for
  acknowledgement/deduplication.
- `(sale_id, department_id)` identifies the order card.
- `revision` increases whenever the routed order content changes.
- `action: upsert` creates or replaces the card when the revision is newer.
- `action: cancel` removes the card because the sale/department was voided or
  cancelled. It is an order correction, not a kitchen workflow status.
- `staff_name` is the staff member recorded on the sale and is displayed as
  “Ordered by” on KDS.
- KDS ignores duplicate `message_id` values and revisions older than its stored
  revision.

### 2.2 Receipt acknowledgement

After storing the message in its local database, KDS replies:

```json
{
  "type": "kitchen_order.received",
  "message_id": "unique-message-uuid",
  "received_at": "2026-10-29T10:30:01+08:00"
}
```

This only confirms transport and local storage. It does not mean the kitchen has
prepared or completed the order.

### 2.3 Retry behavior

- POS keeps the outbound message until it receives the matching `message_id`.
- Retry on reconnect and after a short backoff.
- KDS acknowledgement is idempotent; acknowledging the same message again is safe.
- Reuse the existing cross-print retry timing where practical, but keep KDS JSON
  separate from `PrintReceiptCache.print_data`.
- KDS stores processed message IDs so a POS retry does not create another card.

## 3. Local display behavior

- KDS displays orders assigned to its configured departments.
- Kitchen staff may dismiss a card locally.
- Local dismissal is not sent to POS or Laravel.
- A newer revision of a dismissed order appears again because it contains changed
  kitchen instructions.
- Store cards, revisions, and processed message IDs locally so an app restart does
  not duplicate orders.

## 4. Display administration APIs

These endpoints use the existing POS/staff bearer token. There is no KDS ticket API.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/api/v2/kitchen-displays/pair/start` | Store a pending LAN pairing |
| `POST` | `/api/v2/kitchen-displays/{id}/pair/confirm` | Confirm the nonce/code |
| `GET` | `/api/v2/kitchen-displays?outlet_id={id}` | List configured displays |
| `PATCH` | `/api/v2/kitchen-displays/{id}` | Rename, enable, or change departments/LAN endpoint |
| `DELETE` | `/api/v2/kitchen-displays/{id}` | Permanently delete the paired display |

### 4.1 List displays

```http
GET /api/v2/kitchen-displays?outlet_id={outletId}
Authorization: Bearer {pos-token}
```

`outlet_id` is optional. The response only includes outlets available to the
authenticated staff user.

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": [
    {
      "id": "kitchen-display-id",
      "outlet_id": "outlet-id",
      "pos_device_id": "pos-device-id",
      "paired_by_user_id": 123,
      "device_id": "stable-kds-installation-uuid",
      "name": "Main Kitchen",
      "host": "192.168.1.10",
      "port": 8080,
      "department_ids": ["department-id"],
      "pairing_status": "paired",
      "pairing_expires_at": "2026-10-29T10:10:00Z",
      "paired_at": "2026-10-29T10:00:00Z",
      "last_seen_at": null,
      "is_enabled": true,
      "capabilities": {
        "app_version": "1.0.0",
        "protocol": "kitchen-order.v1"
      },
      "created_at": "2026-10-29T10:00:00Z",
      "updated_at": "2026-10-29T10:00:00Z"
    }
  ],
  "errors": null
}
```

`last_seen_at` is a legacy cloud-delivery field and is not updated by LAN order
delivery. POS should use its live WebSocket connection state for KDS availability.

### 4.2 Update a display

```http
PATCH /api/v2/kitchen-displays/{displayId}
Authorization: Bearer {pos-token}
Content-Type: application/json
```

Send only changed fields:

```json
{
  "name": "Cold Kitchen",
  "host": "192.168.1.10",
  "port": 8080,
  "is_enabled": true,
  "department_ids": ["cold-kitchen-department-id"]
}
```

Validation:

- `name`: string, maximum 120 characters
- `host`: IPv4 or IPv6 address
- `port`: integer from 1 to 65535
- `is_enabled`: boolean
- `department_ids`: non-empty array of departments belonging to the staff company

Success returns the updated display object in `data`. POS must immediately update
its live connection routing after changing departments or `is_enabled`.

### 4.3 Delete a paired display

```http
DELETE /api/v2/kitchen-displays/{displayId}
Authorization: Bearer {pos-token}
```

Success:

```json
{
  "is_success": true,
  "status_code": 200,
  "message": null,
  "data": null,
  "errors": null
}
```

The backend permanently deletes the display, its legacy display tokens, and any
historical cloud-ticket rows/events associated with it. This cannot be undone. POS
must close the matching LAN connection and stop sending orders to it. Pairing the
same physical KDS later creates a new display record.

### 4.4 Backend errors

| Status | Meaning | Client action |
| --- | --- | --- |
| `401` | POS token is missing or invalid | Reauthenticate the POS |
| `403` | Staff cannot access the outlet/display, or a retired display token was used | Do not retry unchanged |
| `404` | Display ID does not exist | Refresh the display list |
| `422` | Validation failed or pairing challenge is invalid/expired | Show `message`/`errors` and correct the request |
| `429` | Pairing rate limit exceeded | Wait and retry with backoff |

Removed cloud-delivery endpoints:

```text
GET   /api/v2/kitchen-tickets
PATCH /api/v2/kitchen-tickets/{id}/status
POST  /api/v2/kitchen-tickets/{id}/ack
POST  /api/v2/kitchen-displays/{id}/test
```

Existing kitchen-ticket rows are retained as historical data until their paired
display is deleted; the backend no longer creates or serves them.

## 5. Logging and diagnostics

Laravel Cloud can show pairing and display-administration requests, but it cannot
prove that a LAN order reached KDS.

POS should log these fields locally:

```text
message_id, sale_id, department_id, display_id, sent_at, acknowledged_at, attempts, last_error
```

Successful delivery means the POS received `kitchen_order.received` for the same
`message_id`.

## 6. POS checklist

- [ ] Host the authenticated local KDS WebSocket endpoint.
- [ ] Reuse the existing kitchen-print trigger and department/category routing.
- [ ] Send structured JSON, not printer commands.
- [ ] Increment the revision when routed order content changes.
- [ ] Retain messages until receipt acknowledgement.
- [ ] Retry after reconnect without creating a new `message_id`.
- [ ] Log delivery attempts locally.

## 7. KDS checklist

- [ ] Generate and persist a stable installation UUID.
- [ ] Connect to the POS LAN address and complete nonce/code pairing.
- [ ] Persist the display ID returned by pairing.
- [ ] Validate `protocol` and required message fields.
- [ ] Store the order before acknowledging it.
- [ ] Deduplicate by `message_id` and compare revisions.
- [ ] Keep local dismissal state without sending kitchen status to the backend.
- [ ] Reconnect automatically and acknowledge safe retries.
