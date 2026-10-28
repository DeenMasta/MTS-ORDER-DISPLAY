# Kitchen Display POS Integration

This document describes the Kitchen Display System (KDS) integration completed
in the POS application. It is intended as a practical handoff for the KDS app
team and for future POS maintenance.

## Status

Completed in POS:

- Kitchen Display Settings entry and display management UI.
- Backend-backed display listing, editing, enable/disable, test, and unpair.
- Temporary POS LAN pairing server.
- Authenticated backend pairing start and confirmation.
- One-time KDS credential handoff over the local pairing server.
- Outlet realtime subscription for Kitchen Display diagnostics.

Postponed:

- Real POS-to-KDS device testing on the same Wi-Fi network. This requires the
  KDS Android app to be available.

## Architecture

```text
POS Settings UI
    |
    +-- KitchenDisplayRepository -- HTTPS --> Kitchen Display API
    |                                      |
    |                                      +-- pairing, display configuration,
    |                                          tickets, and realtime broadcasts
    |
    +-- KdsPairingServer -- outlet LAN --> KDS Android app
    |                                      |
    |                                      +-- receives a pairing challenge
    |                                      +-- polls once for confirmation
    |
    +-- Reverb/Pusher <---- private-outlet-{outletId} ---- Backend
           |
           +-- refreshes POS display diagnostics only
```

The POS does not send kitchen tickets directly to a KDS device. After pairing,
the KDS communicates with the backend itself using its display-scoped token.
Kitchen ticket state is independent from printer retries and `PrintReceiptCache`.

## POS feature layout

```text
lib/features/kitchen_display/
  data/
    model/kitchen_display_model.dart
    remote/kitchen_display_repository_impl.dart
  domain/
    models/kitchen_display_pairing.dart
    repositories/kitchen_display_repository.dart
    usecases/
      start_kds_pairing_usecase.dart
      confirm_kds_pairing_usecase.dart
  presentation/
    providers/kitchen_display_providers.dart
    screens/kitchen_display_setup_screen.dart
    services/
      kds_pairing_server.dart
      kitchen_display_realtime_handler.dart
```

The Kitchen Display feature is deliberately separate from the generic printer,
pending-sync, and print-cache features. Configuration changes go directly to
the Kitchen Display API.

## Pairing flow

1. An operator opens **Settings → Kitchen Display** and selects **Pair Display**.
2. POS starts a temporary HTTP server on the outlet LAN and displays
   `{pos-lan-ip}:{temporary-port}`.
3. KDS sends a challenge to POS:

   ```http
   POST /v1/kds/pair/challenge
   Content-Type: application/json
   ```

   ```json
   {
     "display_id": "kds-installation-id",
     "name": "Main Kitchen",
     "host": "192.168.1.50",
     "port": 8080,
     "nonce": "random-unguessable-value",
     "code": "483921",
     "capabilities": {
       "api_version": 1,
       "realtime": true
     }
   }
   ```

4. POS validates the challenge and shows the KDS name, address, and short code.
5. The operator verifies that the code matches the KDS screen, chooses the
   departments, and selects **Confirm Pairing**.
6. POS calls the backend with normal POS authentication and the active
   `pos-device-id` header:

   ```text
   POST /api/v2/kitchen-displays/pair/start
   POST /api/v2/kitchen-displays/{displayId}/pair/confirm
   ```

7. POS keeps the backend confirmation only in memory and exposes it one time
   to the same KDS pairing attempt:

   ```http
   GET /v1/kds/pair/result?nonce={nonce}
   ```

8. The result has `state: "confirmed"` and includes the display credential and
   backend connection values. POS immediately clears this data and stops the
   temporary pairing server after sending the response.

9. KDS stores the credential in Android secure storage and begins its own
   backend ticket sync and Reverb subscription.

## KDS app requirements

The KDS app should:

- Generate a new random nonce and short code for every pairing attempt.
- Call the POS challenge endpoint using the operator-provided POS LAN address.
- Poll the result endpoint with the same nonce until it is confirmed, rejected,
  or expired.
- Verify `state == "confirmed"` before reading the credential.
- Store `access_token` in Android Keystore-backed encrypted storage only.
- Use the returned backend settings (`api_base_url`, `broadcast_auth_url`,
  `channel_name`, and `echo_channel`) for backend communication.
- Delete the stored credential and return to pairing after a backend `401`, or
  a `403` indicating that the display token is inactive.

The KDS must not send tickets to POS over the LAN pairing connection. The LAN
connection is only for the short-lived pairing exchange.

## KDS ticket delivery

After pairing, KDS uses the display token for:

```text
GET   /api/v2/kitchen-tickets
PATCH /api/v2/kitchen-tickets/{ticketId}/status
POST  /api/v2/kitchen-tickets/{ticketId}/ack
```

KDS subscribes to the private channel returned during pairing, normally:

```text
private-kitchen-display-{displayId}
```

Treat these Reverb events as wake-up signals, not complete ticket records:

- `kitchen-ticket.created`
- `kitchen-ticket.updated`
- `kitchen-ticket.cancelled`
- `kitchen-display.test`

On a ticket event, KDS should fetch the authoritative cursor feed from
`GET /api/v2/kitchen-tickets` and apply it locally before saving the returned
cursor. It should also perform a repair poll every 30–60 seconds.

## POS outlet realtime behavior

POS retains its existing shift subscription and additionally subscribes to:

```text
private-outlet-{outletId}
```

For the four Kitchen Display event names above, POS refreshes Kitchen Display
list/diagnostic state only. It does not create tickets, alter ticket state, or
touch printer retry data.

## Security and lifecycle rules

- POS sends its normal bearer token and `pos-device-id` header for both pairing
  backend requests.
- POS never persists or logs a KDS access token, nonce, code, or pairing
  payload.
- The local POS pairing server accepts only the documented challenge and result
  routes, keeps state in memory, limits payload size, and expires attempts
  after ten minutes.
- The confirmation payload can be retrieved once. It is then discarded and the
  local server closes.
- Cancelling pairing, leaving the POS settings page, expiry, or a failed local
  session clears all in-memory pairing state.

## Device-test checklist (pending KDS app)

1. Put POS and KDS on the same Wi-Fi network.
2. Start POS pairing and enter its displayed IP address and port in KDS.
3. Confirm the KDS name, host/port, and code shown in POS match KDS.
4. Select departments and confirm pairing in POS.
5. Confirm KDS receives the one-time response and can load its first ticket
   snapshot.
6. Create, update, and cancel an order; confirm KDS cursor sync responds to
   realtime wake-up events.
7. Use **Send Test** in POS and confirm the KDS visibly renders the test.
8. Unpair in POS and verify KDS can no longer use its credential.

## Related documents

- `docs/KITCHEN_DISPLAY_API.md` — backend and KDS API contract.
- `docs/KITCHEN_DISPLAY_POS_INTEGRATION_PLAN.md` — original POS delivery plan.
