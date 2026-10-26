# Audited inventory changes

Migration 003 adds manager and viewer identities and an append-only stock-adjustment journal. The `operator_set_slot_stock` function locks the shelf, checks the manager role, validates capacity and reason, rejects changes when stock is reserved for unsettled orders, and writes an audit row in the same database transaction. Retried request keys are idempotent.

This is a **backend-only database primitive**, not a public API. The operator ID must come from an authenticated server session. Do not expose this function to kiosks, web clients, or the read-only dashboard credential. Enable audited write endpoints only after implementing user sessions and per-machine authorization.

## Machine-scoped authorization (migration 004)

A global `manager` role is not enough to change every machine. The backend must provision an active `operator_machine_access` row with `permission = 'stock_manager'` for each machine the operator may refill. `viewer` grants are read-only. Revoking the row disables new changes, including retries of previously successful request keys. The stock mutation still checks capacity, pending reservations, idempotency, and its append-only audit log.

This is **not** an end-user session implementation. Do not expose the operator ID as a trusted client parameter. Before enabling a write API, authenticate each human operator, derive identity server-side, enforce HTTPS/session expiration and CSRF protections where applicable, and scope reads as well as writes to explicit machine memberships. Keep the customer-facing Android kiosk entirely read-only toward this operator surface.
