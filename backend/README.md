# Vader backend: order lifecycle domain

This is a **pure Elixir domain module**, not yet a networked Phoenix API or payment integration.

It models the sequence `awaiting_payment → paid → dispensing → complete`, with `needs_review` for uncertain hardware outcomes and `cancelled` only before payment.

The `verified: true` payment field is an internal trusted-adapter assertion, **not an acceptable client input**. A real provider webhook adapter must validate authenticity, amount, currency, replay protection, and settlement before calling `confirm_payment/2`.

The machine safety fields are also trusted-adapter inputs. The backend cannot independently certify food safety through a client request. The real refrigeration controller must remain independent.

`authorize_dispense/2` only creates a command identity. Later, a PostgreSQL transaction must atomically persist an attempt and an outbox command before hardware dispatch; delivery acknowledgments alone cannot mark fulfillment complete.

Run tests with:

```bash
mix test
```
