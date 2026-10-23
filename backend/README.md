# Vader backend: order lifecycle domain

This is an **Elixir domain prototype plus a PostgreSQL schema**, not yet a
networked Phoenix API, Paystack integration, or machine driver.

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

Apply to a disposable local PostgreSQL database:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f priv/sql/001_vending_orders.sql
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
