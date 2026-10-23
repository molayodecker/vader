# Vader inventory operations — prototype

An operator needs to maintain catalog products separately from machine slot
assignments. For example, a 500 ml water product can appear in slots A1 and B4,
but stock quantity and capacity are different per machine and per slot.

## Data sources

| Record | Source | Trust level |
| --- | --- | --- |
| Product title, price, active flag | Operator/backend | Trusted after authorization |
| Slot product, capacity, reported quantity | Operator | Estimate until sensors confirmed |
| Machine heartbeat and software version | Authenticated kiosk | Health signal, not product safety proof |
| Temperature and door state | Machine sensor bridge | Needs verified hardware integration |
| Paid status | Paystack verify or MDB cash events | Backend-verified only |

## Minimum operator experience (next API/UI iteration)

1. Register a machine and select its operating currency.
2. Add or edit products and their images, price, and active status.
3. Assign a product and capacity to each machine slot.
4. Refill and reconcile stock with operator identity and audit timestamps.
5. Disable unavailable or faulty slots without deleting order history.
6. Inspect machine connectivity, board firmware when known, sensor health,
   stock shortages, unsettled tenders, and dispense attempts needing review.

## Sale path

1. Backend receives a proposed basket and calculates prices from catalog.
2. Backend creates an immutable priced order with the selected slot list.
3. `reserve_order_inventory` serializes reservations and prevents overselling.
4. Kiosk presents Paystack / coins / banknotes, with a session deadline.
5. Only verified full settlement and fresh machine safety can enqueue vending.
6. Upon confirmed delivery, mark order complete; uncertain outcomes go to
   operator review. Cancellation can restore reserved stock only before any
   tender has been accepted.

**Not built yet:** REST endpoints, operator authentication, refill audit ledger,
per-machine SKU mapping API, stock reconciliation worker, and device telemetry
ingestion. PostgreSQL integration tests exercise the reservation rules now.
