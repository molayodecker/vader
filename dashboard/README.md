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

## Optional local read-only PostgreSQL API

Apply both database migrations, then create a separate SELECT-only Postgres
user with access to catalog_products, machine_slots, and machine_heartbeats.
Run with Node 22+ and a local PostgreSQL database:

```bash
cd dashboard
npm install
export DATABASE_URL='postgresql://vader_dashboard:REPLACE@127.0.0.1:5432/vader_dev'
export VADER_OPERATOR_TOKEN='REPLACE_WITH_RANDOM_32_PLUS_CHARACTER_TOKEN'
npm start
```

Open http://127.0.0.1:8080 and click **Connect local API**. This token is
used only for the request and never saved by the dashboard. All database-backed
controls are read-only until a proper audited operator write API is built.
The server binds to localhost, not the public network. Do not deploy this
development access scheme to production without TLS, user sessions, authorization,
audit logs, and rate limiting.
