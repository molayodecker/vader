# Refrigerated vending kiosk — offline-first prototype

Android replacement prototype for the photographed six-row spiral vending machine.

## Assumptions (not hardware facts)

- An Android touch computer drives the vertical kiosk display.
- Products are selected by a shelf/slot identifier, e.g. `A1`.
- A separate dispensing controller receives serial commands; its protocol is **unknown**.
- An MDB232 interface handles some cash peripherals; its exact command set is **unknown**.
- Refrigeration is independently regulated; Android only reads verified temperature telemetry.

## Safety boundary

The application uses `SimulatedDispenser` only. It **never opens a serial/USB port**, charges a card, accepts cash, or switches a compressor. The sample environment is explicitly marked `DEMO`.

Do not replace or disable the vendor app until the device configuration, dispensing controller, cold-chain safeguards and rollback path are validated on the physical machine.

## Run

Open this folder in Android Studio. Install an Android SDK and JDK 17, then build the `app` module. The prototype uses plain Android Views, with no third-party runtime libraries.

With a configured Android SDK and Gradle:

```bash
gradle :app:testDebugUnitTest :app:assembleDebug
```

Unit tests cover payment gating, duplicate order IDs, single dispense attempts, serial timeouts, and active-order concurrency. The demo app now saves attempted order IDs synchronously in private Android preferences before simulated dispensing. A production ledger must also record payment, order and delivery states transactionally and reconcile uncertain outcomes across devices and the backend.

Android compile SDK: API 35. Minimum supported API: 24 (provisional; confirm from device Settings).

## Version 0.2 grocery interface

- Portrait grocery-style catalog with category filters and illustrated placeholder product cards.
- Visible slot numbers, sample stock counts, multi-item cart and quantity controls.
- Simulated mobile money/card/cash payment selection and simulated vending confirmation.
- Product data and stock are demo-only and reset when the app restarts.
- `NOURISH` is a provisional product name. Emoji are placeholders for licensed product photography.

## Milestones

1. **Now:** catalog, simulated payment, exactly-once vend request, audit/status feedback.
2. **After device data:** ADB inventory, package version, screen dimensions, USB VID/PID, serial interface, controller board name.
3. **Hardware lab:** passive trace of known-good vendor vend; model command/response, checksum, timeouts and fault codes.
4. **Bench:** read-only status adapter, then authorized one-slot test with empty chute, independent safety supervision.
5. **Production:** processor-side payment confirmation, idempotent order ledger, online/offline reconciliation, refrigeration alarm gating, remote management, secure OTA and rollback.

Do not interpret a serial write acknowledgment as successful delivery. Actual success requires a verified controller or drop-sensor confirmation.
