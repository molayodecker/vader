# Vader backend: order lifecycle domain

This is now a **Phoenix JSON API wrapping the existing Elixir domain modules
and PostgreSQL schema**. It exposes read-only fleet endpoints. It does not yet
implement Paystack settlement, a machine driver, or an outbox dispatcher.

## Phoenix API

Run migrations 001 through 005, in numeric order, on your own PostgreSQL
database. Migration 005 records the observed Zhongda profile for M19265359
without inventing unknown control-board or MDB versions.

Use Elixir 1.16+ and PostgreSQL. In development:

```bash
cd backend
mix deps.get
export DATABASE_URL='postgresql://USER:YOUR_PASSWORD@localhost:5432/vader'
export VADER_OPERATOR_TOKEN='REPLACE_WITH_A_RANDOM_32_PLUS_CHARACTER_SECRET'
export SECRET_KEY_BASE='REPLACE_WITH_A_RANDOM_64_PLUS_CHARACTER_SECRET'
mix phx.server
```

The following endpoints require `Authorization: Bearer <VADER_OPERATOR_TOKEN>`:

- `GET /api/v1/snapshot` — machines, products, slots, and recent orders
- `GET /api/v1/machines` — registered devices and recent heartbeat status
- `GET /api/v1/machines/19265359/inventory` — slot inventory
- `GET /api/v1/orders` — last 50 order summaries

Invalid or missing tokens return 401; database failure returns 503.
All endpoints are read-only; none accept client-supplied payment assertions,
motor commands, temperature safety overrides, or cash events.

Set `PHOENIX_API_URL` and `VADER_OPERATOR_TOKEN` **server-side** in the
Next.js Vader Cloud deployment. Its `/api/vader/snapshot` route forwards the
request to Phoenix without exposing the bearer token to the browser.
Until those values and a reachable Phoenix deployment exist, the UI remains
in demo mode. For production, use TLS, user sessions and machine-scoped roles;
the single operator token is an interim development boundary.

It models the sequence `awaiting_payment → paid → dispensing → complete`, with `needs_review` for uncertain hardware outcomes and `cancelled` only before payment.

The `verified: true` payment field is an internal trusted-adapter assertion, **not an acceptable client input**. A real provider webhook adapter must validate authenticity, amount, currency, replay protection, and settlement before calling `confirm_payment/2`.

The machine safety fields are also trusted-adapter inputs. The backend cannot independently certify food safety through a client request. The real refrigeration controller must remain independent.

`VaderBackend.Tender` explicitly models **Paystack**, **MDB coins**, and **MDB
banknotes**. Coins and notes accumulate as cash credit. Underpayment never
authorizes dispensing; overpayment requires confirmed physical change payout.
Paystack confirmation is only accepted from a trusted server-side verification
adapter. `verified: true` and `authenticated: true` are *internal assertions*,
not proof when supplied by an Android app or public API.

`VaderBackend.PaystackVerification` checks the decoded provider verify response
against the backend-owned order's reference, amount and currency. It has no
network access or secrets; wiring `GET /transaction/verify/:reference` and
signed webhook verification to a server HTTP adapter is still required.

`priv/sql/001_vending_orders.sql` supplies persistent order, Paystack settlement,
cash event, safety telemetry, attempt, and outbox tables. It also supplies
`queue_dispense(order_uuid, attempt_uuid)` to atomically check settlement and
fresh safety telemetry, create **one** attempt, and enqueue **one** command.
The queue is inert: there is no hardware bridge or outbox dispatcher yet.

`priv/sql/002_catalog_inventory.sql` adds product records, machine-specific
slot assignments, operator-entered stock, capacities, and machine heartbeats.
`reserve_order_inventory(order_uuid)` checks price and inventory, locks the
selected slots, deducts stock, and marks the order reserved atomically. The
`cancel_unpaid_reserved_order(order_uuid)` path restores stock only when no
payment events have been accepted. Never invoke these SQL functions from an
untrusted Android client; use backend-only credentials and authorization.

Apply to a disposable local PostgreSQL database:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f priv/sql/001_vending_orders.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f priv/sql/002_catalog_inventory.sql
```

Before production: restrict DB privileges; verify Paystack via its secret-key
server endpoint and authenticate webhook signatures; implement a real MDB232
bridge with durable event IDs, payout verification, refunds and escrow handling;
make outbox dispatch ambiguous-result-safe; validate the refrigeration and
delivery sensors. Never retry a physical vend after an uncertain delivery.

Run tests with:

```bash
mix test
```
