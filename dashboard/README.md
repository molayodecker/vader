# Vader Fleet Console — local preview

A responsive browser-only operator dashboard for the Vader refrigerated vending
machine platform. **This is a local demo**, not an authenticated administration
service. It does not connect to PostgreSQL, the physical machine, Paystack, or
the MDB cash modules. Browser `localStorage` holds demo changes; do not enter
customer information, credentials, or operationally sensitive data.

## Run on your MacBook Pro

From the repository root:

```bash
cd dashboard
python3 -m http.server 8080
```

Open <http://localhost:8080> in your browser. Use `Ctrl+C` to stop the server.
The simple HTTP server is for **localhost development only**; do not expose
it publicly. The font uses Google Fonts when available and falls back locally.

To run the dashboard's model tests:

```bash
node dashboard/model.test.mjs
```

Features: machine overview, stock alerts, machine selection, per-slot stock
adjustments, enabling/disabling shelves, catalog and price editing. Prices are
stored in integer pesewas. The real device `M19265359` is **unverified**;
`DEMO-002` is a purely fictional machine. All stock counts are illustrations.

## Before connecting real data

- Implement authenticated, role-authorized operator API endpoints.
- Enforce server-side price validation, stock reservations, and refill auditing.
- Add device identity, signed heartbeat ingestion, and per-machine access.
- Expose payment and dispense information read-only with appropriate PII limits.
- Never trust dashboard-supplied inventory, sensor data, or payment status to
  authorize physical vending without backend verification.
