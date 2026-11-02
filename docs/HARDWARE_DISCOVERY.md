# Vader hardware discovery checklist (machine overseas)

Vader remains **simulation only**. We know the original Android software is
`3.1.90`, the management UI labels motors as **3-wire feedback**, and an MDB232
board is visible. We do **not** know the firmware protocol, serial baud rates,
motor board revision, or temperature sensor wiring. Empty "control board
version" and "MDB version" fields in the cloud dashboard are *not* versions.

Zhongda Cloud identifies machine `M19265359` (number `19265359`) as an Android
screen vending device, with upper-software version `3.1.90`, a reported goods
shelf amount of 100, and `3线单反馈电机` (3-wire single-feedback motors). These are
cloud-side observations, **not** verified physical specifications. The device
was shown offline with a `-39.00°C` reading, which must not be treated as valid
cold-chain evidence. `ZhongdaMachineProfile` records only these observations.

`MachineHardware` is the future hardware boundary. `SimulatedMachineHardware`
implements it without opening ports or sending frames; the existing
`VendController` uses its boolean adapter. A timeout, disconnection, or other
uncertain result fails closed. The simulator's local duplicate-ID set is only
an additional guard; the persistent attempt journal remains mandatory. Do not
enable live vending based on these classes or the vendor's cloud controls.

## Ask the on-site operator for

1. Photos of the full machine and its manufacturer/rating plate.
2. Clear front/back board labels of the **motor control board** and MDB232;
   record any firmware stickers. Do not expose payment keys or passwords.
3. One overview photo of the Android-to-motor-board cable and one of the
   Android-to-MDB232 cable; closeups of connector labels (RS232, USB, TTL).
4. Android `Settings → About device`: Android version, board model/build number.
5. Operator-safe screenshot of machine diagnostics and current temperature,
   including sensor errors. The cloud value `-39.00°C` must be investigated.
6. Manufacturer's protocol/manual if available. Request the *host-to-controller*
   serial protocol and the MDB232 *host interface* (not only generic MDB docs).

## Optional read-only Android developer diagnostics

Only with the machine owner/operator's permission, and without changing the
operating app or disrupting refrigeration:

```bash
adb devices -l
adb shell getprop ro.build.version.release
adb shell getprop ro.product.model
adb shell getprop ro.hardware
adb shell ls -l /dev/ttyS0 /dev/ttyS1 /dev/ttyS2 /dev/ttyS3 /dev/ttyS4
```

Capture output securely after removing serial numbers, credentials, tokens,
phone numbers, and other private identifiers. A missing `ttyS*` node is normal
on some Android boards. Do not modify permissions, attempt root access, or
transmit guessed serial bytes to discover commands.

## Integration gates

- **Gate A — identification:** boards/ports/protocol and power levels identified.
- **Gate B — observation:** receive only, timestamp incoming frames, match
  observed coin/note/sensor events against operator actions.
- **Gate C — bench:** manufacturer documented motor commands, isolated bench
  fixture, no products or customers, operator supervising.
- **Gate D — pilot:** real payment verified by backend, exact one-vend journal,
  change/refund reconciliation, verified temperature and delivery feedback.

`BoardDiagnostics` implements a bounded in-memory **inbound-only** recorder.
It is not yet connected to hardware or logs and never transmits a command.
