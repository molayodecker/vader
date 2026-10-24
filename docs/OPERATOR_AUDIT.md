# Audited inventory changes

Migration 003 adds manager and viewer identities and an append-only stock-adjustment journal. The `operator_set_slot_stock` function locks the shelf, checks the manager role, validates capacity and reason, rejects changes when stock is reserved for unsettled orders, and writes an audit row in the same database transaction. Retried request keys are idempotent.

This is a **backend-only database primitive**, not a public API. The operator ID must come from an authenticated server session. Do not expose this function to kiosks, web clients, or the read-only dashboard credential. Enable audited write endpoints only after implementing user sessions and per-machine authorization.
