# Vader Cloud — Next.js fleet dashboard

This is the management dashboard for Vader, in the same repository as the
Phoenix backend and Android kiosk. The design draws on the workflows of
Zhongda Cloud but is an independent implementation.

## Local development

```bash
cd cloud
npm install
cp .env.example .env.local
npm run dev
```

Set `PHOENIX_API_URL` to the reachable backend origin and
`VADER_OPERATOR_TOKEN` to the same secret used by Phoenix. Both variables
must stay **server-side**. The Next.js route `/api/vader/snapshot` calls
`/api/v1/snapshot` on Phoenix; the browser never receives the token.

Until Phoenix and the PostgreSQL migrations are running, the dashboard
displays clearly labeled demo data. The sample charts, transactions, and
replenishment actions do not issue physical vending or payment commands.
Machine, product, and stock records switch to database data when available.

## Production gates

- Deploy Phoenix over TLS and configure database access.
- Replace the shared development token with user sessions, scoped operator
  authorization, audit logs, and rate limits.
- Add server-side credential handling, authentication, and CSRF protection for
  any future mutating actions.
- Obtain reliable telemetry from the actual machine before enabling safety
  decisions or remote commands.

The dashboard is read-only with respect to vending hardware.
