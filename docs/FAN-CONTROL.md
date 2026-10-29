# Fan Control on macOS — Findings & Options

Status as of **2026-10-26** (macOS 26.7.1 Tahoe, OpenCore 1.0.8).

> **TL;DR:** `Fn + F5` does **not** change the fan mode on macOS. `SSDT-FAN.aml` never runs, because the key is delivered over USB, not by the embedded controller (EC). The fans still work normally on the EC's automatic curve. Changing the fan mode needs either a fixed SSDT setting (no kext, no hotkey) or a small kext called from the ROG Gaming Center app.

---

## 1. How Windows does it

1. The ITE 8910 keyboard (`0x0B05:0x1869`) sends `Fn + F5` as a USB HID vendor report.
2. The ASUS software (ROG Gaming Center / Armoury Crate) receives the key.
3. It calls the BIOS's ASUS WMI method:
   - Method: `\_SB.ATKD.WMNB (Arg0 = 0, Arg1 = 0x53564544 "DEVS", Arg2 = Buffer { DWORD device_id, DWORD value })`
   - Fan boost device ID: `0x00110018` (some models use `0x00120075` instead)
   - Values: `0` = Balanced, `1` = Overboost, `2` = Silent
4. The EC still drives the fans; Windows only picks which built-in profile the EC uses. As far as we know this 2018 model has these three modes only, with no custom fan curves.

Related IDs used by the Linux `asus-wmi` driver, which are worth trying later:

| ID | Purpose | Call |
| :--- | :--- | :--- |
| `0x00110018` | Fan boost mode | `DEVS` (set), `DSTS` (presence + supported-mode mask) |
| `0x00120075` | Throttle thermal policy (newer models) | `DEVS` / `DSTS` |
| `0x00110013` | CPU fan RPM | `DSTS` |
| `0x00110014` | GPU fan RPM | `DSTS` |

`DSTS` = `0x53545344`. On some firmware the fan boost ID is write-only, so the current mode cannot be read back.

---

## 2. Live test: why `SSDT-FAN.aml` never fires

`SSDT-FAN.aml` replaces the EC query method `_QAE` (with the `_QAE → XQAE` rename in `config.plist`) and calls `WMNB` from there. It assumes `Fn + F5` raises EC query `0xAE`.

A probe recorded the ASUS keyboard's HID input reports and the kernel's ACPI interrupt counters (`ACPI Statistics` → `SciCount` / `GpeCount` on `AppleACPIPlatformExpert`) while the keys were pressed:

| Key | HID report (ITE 8910) | ACPI SCI / GPE during the press |
| :--- | :--- | :--- |
| `Fn + F5` (7 presses) | `5A 99` on press, `5A 00` on release | **none** |
| `Fn + F7` (control) | `5A 10` | none |

The idle background rate is about 2 EC events every few seconds (battery polling); none of them lined up with a key press.

**Conclusion:** on this laptop, `Fn + F5` never reaches the EC, so `_QAE` (and the SSDT's `FMOD` cycle) never runs. Linux hit the same issue on ROG N-Key keyboards and needed a driver patch to forward the HID key to `asus-wmi` ([LKML, Jan 2026](https://lkml.iu.edu/2601.0/07623.html)).

The probe's source is in [Appendix A](#appendix-a-fn-key-probe). Re-run it after BIOS or OpenCore changes.

---

## 3. Audit of the current implementation

### `SSDT-FAN.aml` / `config.plist`
1. **It never runs** (section 2).
2. **The rename may hijack an unrelated EC event.** Nothing shows that query `0xAE` means "fan key" on this BIOS. If it's something else, that event now silently changes the fan mode and loses its original handler. The rename's search pattern is only the 4 bytes `_QAE` (Count 1), which is fragile.
3. **BIOS support for `0x00110018` is unverified.** macOS 26 no longer exposes the ACPI tables in IORegistry, and no DSDT dump has been made yet.
4. **The `FMOD` state drifts.** It resets to 0 every boot, is never read back from the firmware, and gives no on-screen feedback. The first press always goes to Overboost.
5. **Minor:** the method creates named fields (`CreateDWordField`), so it should be `Serialized`. The README call signature `WMNB(0x53564544, 0x00110018, FMOD)` doesn't match the code (instance `0` + 8-byte buffer).

### Docs that currently claim it works
- `README.md`: hardware table (Fans & Cooling) and "Fan Control & Hardware Thermal Architecture"
- `TROUBLESHOOTING.md` §11
- `CHANGELOG.md` (2026-10-10 entry)
- `scripts/monitor-thermals.sh` footer line

### `scripts/monitor-thermals.sh`
It works: package plus 6 core temperatures via `SMCProcessor`, clean piped output, and unknown flags rejected.
- Its footer says `Fn + F5` cycles the fan modes, which isn't true.
- `--watch 0` redraws in a tight loop; the interval should be at least 1.

---

## 4. Why there's no app-only route

- Only kernel code can evaluate ACPI methods on macOS. DriverKit has no ACPI access.
- `AppleACPIPlatformExpert` publishes an `AppleACPIPlatformUserClient`, but it rejects opening from a normal process (`IOServiceOpen` → `0xe00002c2`, bad argument). Its interface is undocumented, and probing it risks a kernel panic.
- Port I/O, CMOS and EC access from user space all need a kext (for example DirectHW).
- SMC writes go to VirtualSMC, and no installed plugin turns them into ACPI calls.
- No existing community kext does ASUS fan modes. `AsusSMC` panics on Tahoe and never did fan modes.

---

## 5. Options

### Option A — No kext, no hotkey (SSDT only)
The SSDT can call `WMNB` at moments macOS triggers itself:
- **Boot / wake (`_INI`, `_WAK`):** always apply one mode. Changing it means editing the config and rebooting.
- **AC plug/unplug:** hook the AC adapter's EC event, for example Overboost on the charger and Silent on battery. This needs the DSDT to find the right query method.

Also the cheapest **support test**: set Overboost at boot and listen for the fans. If they don't ramp up, neither option can work on this BIOS.

### Option B — Hotkey + app control (small kext)
- The kext attaches to `ATKD` and exposes a user client with *get status* (`DSTS`) and *set mode* (`DEVS`), plus fan RPM.
- ROG Gaming Center maps HID `0x99` (already decoded as `.fan`) to "cycle mode", shows the HUD, remembers the mode and reapplies it after boot and wake.
- **Boot safety:**
  - Test from a **USB copy of the EFI** first, so the internal EFI stays untouched.
  - Keep the kext passive: no work in `start()`, no kernel patching, ACPI calls only when the app asks.
  - Add an off switch: a boot-arg such as `-asusfanoff` makes it do nothing.

### Suggested order
1. Get a DSDT dump: Linux live USB → `sudo acpidump -b` → `iasl -d dsdt.dat`. Check what `_QAE` really is, whether `WMNB` → `DEVS` handles `0x00110018` / `0x00120075`, and find the AC adapter query method.
2. Run the Option A boot-time Overboost test from a USB EFI.
3. If it works, choose A (AC-based automatic modes) or B (hotkey + app).
4. Either way, remove the `_QAE → XQAE` rename and the current `SSDT-FAN.aml`, and fix the docs listed in section 3.

---

## Appendix A: Fn-key probe

Logs every HID input report from ASUS devices (`0x0B05`) plus changes in the ACPI SCI/GPE counters, every 100 ms. The keyboard's normal key reports (report ID `0x01`) are logged too; filter them out afterwards.

```bash
swiftc -O main.swift -o fnprobe
./fnprobe 120 > capture.log          # seconds to record; press the keys meanwhile
grep -v "id=0x1 " capture.log        # hide normal typing
```

```swift
// Fn-key path probe: logs ASUS (0x0B05) HID input reports and ACPI SCI/GPE counter deltas.
import Foundation
import IOKit
import IOKit.hid

setvbuf(stdout, nil, _IONBF, 0)
let start = Date()
func ts() -> String { String(format: "%7.2fs", Date().timeIntervalSince(start)) }

func acpiStats() -> (sci: Int, gpe: Int)? {
    let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleACPIPlatformExpert"))
    guard svc != 0 else { return nil }
    defer { IOObjectRelease(svc) }
    guard let d = IORegistryEntryCreateCFProperty(svc, "ACPI Statistics" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [String: Any] else { return nil }
    return ((d["SciCount"] as? Int) ?? -1, (d["GpeCount"] as? Int) ?? -1)
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x0B05] as CFDictionary)
IOHIDManagerRegisterInputReportCallback(manager, { _, _, _, _, reportID, report, length in
    let bytes = UnsafeBufferPointer(start: report, count: min(length, 8)).map { String(format: "%02X", $0) }
    print("\(ts()) HID report id=0x\(String(reportID, radix: 16)) len=\(length) bytes=\(bytes.joined(separator: " "))")
}, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
let rc = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("\(ts()) IOHIDManagerOpen rc=0x\(String(UInt32(bitPattern: rc), radix: 16)) devices=\((IOHIDManagerCopyDevices(manager) as? Set<AnyHashable>)?.count ?? 0)")

var last = acpiStats()
print("\(ts()) ACPI start sci=\(last?.sci ?? -1) gpe=\(last?.gpe ?? -1)")
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    guard let now = acpiStats(), let prev = last else { return }
    if now.sci != prev.sci || now.gpe != prev.gpe {
        print("\(ts()) ACPI SCI +\(now.sci - prev.sci) GPE +\(now.gpe - prev.gpe)")
    }
    last = now
}
let duration = Double(CommandLine.arguments.dropFirst().first ?? "120") ?? 120
DispatchQueue.main.asyncAfter(deadline: .now() + duration) { print("\(ts()) done"); exit(0) }
CFRunLoopRun()
```

## References
- [HID: asus: Implement Fn+F5 fan control key handler (LKML, 2026)](https://lkml.iu.edu/2601.0/07623.html)
- [platform/x86: asus-wmi: Switch fan boost mode (LKML, 2019)](https://lkml.iu.edu/1904.1/03209.html)
- [asus_wmi: Support fan boost mode on FX505DY/FX705DY](https://lkml.rescloud.iu.edu/1911.0/02338.html)
- [asus-wmi: throttle thermal policy `0x00120075`](https://patchwork.kernel.org/comment/23006613)
