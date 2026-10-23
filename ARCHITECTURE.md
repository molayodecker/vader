# Design notes

## Proposed boundaries

`Kiosk UI -> Order service -> Payment confirmation -> Dispense coordinator -> Hardware adapter`

- Transaction service: idempotent order and payment records, server-authoritative confirmation; never trust client payment callbacks alone.
- Dispense coordinator: exactly one in-flight vend per controller; synchronous local attempt journal before invoking a dispenser; no blind retry after timeout. The current `SharedPreferences` journal is only a prototype layer, not a production-grade durable order ledger.
- Hardware adapters: simulator, serial motor board (TBD), MDB232 payments (TBD), verified temperature telemetry (TBD).
- Inventory: physical slot map and reconciliation after confirmed vend only.
- Safety: hold sales on stale/out-of-range temperature, door/fault alarms; refrigeration controller remains independently operational.
- Operational: offline queue, event/audit logs, watchdog, remote support, signed app updates, rollback.

## Important limits of this prototype

The demo transaction controller is **in memory**; it does not persist attempts across restarts. Its payment verifier always returns true and the dispenser always succeeds. Those two stubs must not be used in a production build. Replace them with verified payment and hardware implementations plus a durable journal and transaction recovery policy.

## Required data from machine

- Android version, CPU architecture, RAM, resolution, package name, USB debugging access.
- Motor-driver board model, actual transport/baud rate/pinout and passively observed command frames.
- MDB232 exact manufacturer/firmware and linked cash hardware.
- Temperature controller and food product temperature limits.
- Original app backup and reversible installation procedure.
