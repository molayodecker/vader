# Vader payment adapter contract

All amounts are integer minor currency units. For Ghana, the kiosk displays
GH₵ but sends GHS pesewas. Clients never specify an authoritative price.

## Paystack

1. Backend creates an order with server-priced products and a unique reference.
2. Backend initializes Paystack transaction using its secret key. Android sees
   only the authorization URL/access code, never the secret key.
3. Kiosk displays Paystack checkout or mobile money instructions.
4. On webhook or kiosk completion, the backend calls Paystack's server-side
   `GET /transaction/verify/:reference` endpoint. Check success, exact reference,
   amount, currency and the order account/business context.
5. Webhook signatures must be validated before processing; duplicate webhooks
   and retries must be idempotent using the unique reference.
6. Only then persist `paystack_settlements` and attempt to queue dispensing.
   A network timeout leaves payment pending reconciliation, not dispensing.

## Coins and notes

1. Machine bridge begins a uniquely identified session and reads MDB232
   events. Coin changer events are `coin`; banknote acceptor events are `note`.
2. Persist accepted credits with durable, unique peripheral-event identifiers.
   Never infer an accepted note from a button press or UI animation.
3. Do not mix Paystack and cash in the same initial order; settle or safely
   resolve one tender route before dispensing.
4. Track exact credit and change due. Confirm physical change payout before
   vending for overpayment. If change cannot be made, disable denominations
   or return/reconcile cash; do not silently vend with an unresolved balance.
5. On cancelled sessions, jam, door open, communications loss or reboot,
   handle accepted cash as a reconciliation liability until refund/return is
   confirmed. Keep an auditable operator review queue.

## Command dispatch

- The server creates a single attempt/outbox command transactionally.
- The bridge checks a fresh machine heartbeat, door and refrigeration state.
- A write acknowledgment is not proof of delivered product.
- Never repeat a possibly executed motor command after a timeout or reboot.
- Reconcile uncertain orders using physical delivery sensors and operator
  intervention. Do not automatically mark orders completed or refunded.

**Current status:** domain validation and database contract implemented.
No live Paystack HTTP client, webhook endpoint, MDB serial driver, machine
command dispatcher, or cash refund controller exists yet.
