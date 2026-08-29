# Troubleshooting & Optimization Guide — ASUS ROG Strix GL503GE

This guide addresses common issues, optimizations, and post-installation tweaks for running macOS on the ASUS ROG Strix GL503GE.

---

## 1. 🔑 SMBIOS & Apple Services (iMessage / FaceTime / iCloud)

### Issue: "An error occurred during authentication" or Apple ID sign-in failure.
* **Cause:** The repository uses placeholder values (`CHANGEME`) under `PlatformInfo > Generic` in `config.plist`.
* **Fix:**
  1. Open [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS).
  2. Generate values for model **`MacBookPro16,4`**.
  3. Verify the generated `SystemSerialNumber` is marked as **"Purchase Date not validated"** on [Apple Check Coverage](https://checkcoverage.apple.com/). (Do not use a serial that corresponds to an active, real Mac).
  4. Paste `SystemSerialNumber`, `MLB`, `SystemUUID`, and `ROM` (MAC address in hex) into `PlatformInfo > Generic`.

---

## 2. 🖲️ Trackpad (I2C) Troubleshooting

### Issue: Trackpad is unresponsive, laggy, or gestures don't work.
* **Current Implementation:** The EFI uses `VoodooI2C.kext` + `VoodooI2CHID.kext` with the boot argument `-vi2c-force-polling`.
* **Fixes & Checks:**
  * **Polling Mode:** The boot arg `-vi2c-force-polling` ensures compatibility if GPIO interrupts are not perfectly aligned.
  * **GPIO Pinning (Advanced):** If you prefer native GPIO interrupt mode for lower CPU wakeups:
    1. Ensure `SSDT-GPI0.aml` is active.
    2. Check your DSDT `_CRS` method for the `ETPD` or `TPD0` device.
  * **Settings:** Enable **Tap to Click** in *System Settings > Trackpad*.

---

## 3. 🔊 Audio & 3.5mm Headphone Jack

### Issue: No sound from speakers, or headphone jack not switching automatically.
* **Codec:** Realtek ALC295 / ALC294
* **Current Layout:** `alcid=14`
* **Alternative Layouts to Test:**
  * Layout `13`, `14`, `15`, `21`, `22`, `28`
  * To test another layout, modify the `alcid=XX` argument in `config.plist` under `NVRAM > 7C436110-AB2A-4BBB-A880-FE41995C9F82 > boot-args`.
* **Headphone Jack Auto-Switching:** If the 3.5mm jack does not detect plugin/unplug events, install [ALCPlugFix-Swift](https://github.com/black-dragon-x/ALCPlugFix-Swift) to monitor jack status.

---

## 4. 🌐 Wi-Fi & Bluetooth (Intel AX210 / 9560)

### Issue: Wi-Fi toggle is greyed out on macOS Sonoma (14) or Sequoia (15).
* **Cause:** macOS 14+ removed legacy Wi-Fi drivers (`IO80211Family`).
* **Fix (OCLP Root Patching):**
  1. Ensure the following kexts are enabled in `config.plist`:
     * `IOSkywalkFamily.kext`
     * `IO80211FamilyLegacy.kext`
     * `AMFIPass.kext`
  2. Verify boot-args contains `-amfipassbeta`.
  3. Verify `csr-active-config` is set to `03080000` (or `AwoAAA==` in base64).
  4. Boot macOS, download [OpenCore Legacy Patcher (OCLP)](https://github.com/dortania/OpenCore-Legacy-Patcher), and run **Post-Install Root Patch**.
  5. Reboot after patching completes.

### Issue: Bluetooth fails to turn on or toggle.
* The EFI includes `IntelBluetoothFirmware.kext`, `IntelBTPatcher.kext`, and `BlueToolFixup.kext`.
* **Important:** Do **not** use `IntelBluetoothInjector.kext` on macOS Monterey and later (it was replaced by `BlueToolFixup.kext`).

---

## 5. 💤 Sleep / Wake & Battery Optimization

### Issue: Laptop wakes immediately after sleeping or drains battery when lid is closed.
Run the following terminal commands to optimize macOS laptop power management:

```bash
# Set hibernation mode to 0 (RAM only, fast sleep)
sudo pmset -a hibernatemode 0

# Disable sleep image writing to disk
sudo pmset -a autopoweroff 0
sudo pmset -a standby 0
sudo pmset -a powernap 0

# Disable network wakeups while sleeping
sudo pmset -a tcpkeepalive 0
sudo pmset -a womp 0

# Remove existing sleepimage to free disk space
sudo rm -f /var/vm/sleepimage
```

### Checking Wake Reasons:
To inspect what woke the laptop from sleep:
```bash
pmset -g log | grep -e "Wake.*due to"
```

---

## 6. 🔌 Custom USB Port Mapping

* The EFI includes `UTBDefault.kext` + `USBToolBox.kext`.
* For optimal USB 3.0 speeds, sleep stability, and Bluetooth internal routing:
  1. Boot into Windows (or macOS) and run the [USBToolBox tool](https://github.com/USBToolBox/tool).
  2. Discover all ports (plug a USB 2.0 device into every port, then a USB 3.0 device).
  3. Set internal ports (Webcam, Bluetooth, Card Reader) as **Internal (255)**.
  4. Set standard external ports as **USB 3.0 Type-A (3)** or **Type-C (9/10)**.
  5. Export `UTBMap.kext` and replace `UTBDefault.kext` in `EFI/OC/Kexts/`.

---

## 7. 🔆 Display Brightness & Backlight

* **Current Implementation:** Display backlight uses `SSDT-PNLF.aml` paired with `WhateverGreen.kext` and the boot-arg `-igfxblt`.
* **Keyboard Hotkeys:** `BrightnessKeys.kext` handles `Fn + F7` / `Fn + F8` (or dedicated brightness keys) natively.
* If brightness steps are uneven, ensure `applbkl=1` or `-igfxblt` is retained in `boot-args`.

---

## 8. 🔋 Discrete GPU (NVIDIA GTX 1050 Ti) Verification

* NVIDIA Pascal (GTX 10-series) GPUs have no metal graphics acceleration in modern macOS.
* The discrete GPU is safely powered down using `SSDT-Disable_GPU_PEG0.aml`.
* **Verify:** Check *System Information > Graphics/Displays*. Only **Intel UHD Graphics 630** should appear. If the NVIDIA GPU shows as an unaccelerated Display controller, verify `SSDT-Disable_GPU_PEG0.aml` is active under `ACPI > Add`.
