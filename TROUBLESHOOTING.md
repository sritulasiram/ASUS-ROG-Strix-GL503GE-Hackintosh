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
  4. Obtain your physical Ethernet MAC address from Terminal:
     ```bash
     ifconfig en0 | awk '/ether/{print $2}' | tr -d ':'
     ```
  5. Paste `SystemSerialNumber`, `MLB`, and `SystemUUID` into `PlatformInfo > Generic`.
  6. Paste the 12-character hex Ethernet MAC address into `ROM` (as Data/hex). **Do not use a random MAC or Wi-Fi MAC**, as Apple ID tokens bind to `en0`.

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
* **Cause:** macOS 14+ removed the legacy `IO80211Family` Wi-Fi stack. Official OpenCore Legacy Patcher targets Broadcom cards, whereas **Intel Wi-Fi** cards require **[OCLP-Mod (OpenCore-Legacy-Patcher Mod)](https://github.com/lzhoang2801/OpenCore-Legacy-Patcher/releases)**.
* **Fix (OCLP-Mod Root Patching):**
  1. Ensure the following kexts are enabled in `config.plist`:
     * `IOSkywalkFamily.kext`
     * `IO80211FamilyLegacy.kext`
     * `AMFIPass.kext`
     * `AirportItlwm.kext`
  2. Verify boot-args contains `-amfipassbeta`.
  3. Verify `csr-active-config` is set to `03080000` (`<data>AwoAAA==</data>`).
  4. Boot into macOS, download **[OCLP-Mod](https://github.com/lzhoang2801/OpenCore-Legacy-Patcher/releases)**, and click **Post-Install Root Patch**.
  5. Select **Networking: Modern Wireless** to patch the Intel Wi-Fi drivers into the system snapshot.
  6. Reboot when prompted.

### Issue: Bluetooth fails to turn on or toggle.
* The EFI includes `IntelBluetoothFirmware.kext` (v2.5.1), `IntelBTPatcher.kext` (v2.5.1), and `BlueToolFixup.kext`.
* **Important:** Do **not** use `IntelBluetoothInjector.kext` on macOS Monterey and later (it was replaced by `BlueToolFixup.kext`).
* On macOS Sequoia (15.x) and Tahoe (16.x), `IntelBTPatcher.kext` v2.5.1+ is required to prepare and complete HCI memory descriptors in IOKit; earlier versions fail to initialize or toggle Bluetooth.

---

## 5. 💤 Sleep / Wake & Battery Optimization

### Issue: Laptop wakes immediately after sleeping (`due to XDCI CNVW/`) or cycles in DarkWake.
* **Instant Wake Root Cause:** The ASUS ACPI tables route `XDCI` (USB device controller), `CNVW` (Intel Wi-Fi/Bluetooth), and `XHC` to GPE `0x6D`. When entering sleep, unpatched firmware signals wake immediately.
* **EFI ACPI Fix:** The EFI includes `SSDT-GPRW.aml` and the `GPRW to XPRW` ACPI rename patch in `config.plist`, which intercepts `0x6D` and `0x0D` GPE events and suppresses spurious wakeups while preserving power button and lid wake.
* **DarkWake Suppression:** `darkwake=0` is included in `boot-args` to prevent display-off maintenance wakeups.

### Quick Fix Script:
Run the repository helper script to set all recommended macOS laptop power parameters:
```bash
./scripts/fix_sleep_pmset.sh
```

Or apply them manually via Terminal:
```bash
# Set hibernation mode to 0 (pure S3 RAM sleep)
sudo pmset -a hibernatemode 0

# Disable deep standby timer and autopoweroff
sudo pmset -a autopoweroff 0
sudo pmset -a standby 0
sudo pmset -a powernap 0

# Disable network keepalive wakeups while asleep (prevents DarkWake loops on Intel Wi-Fi)
sudo pmset -a tcpkeepalive 0
sudo pmset -a womp 0
sudo pmset -a proximitywake 0

# Remove existing sleepimage to reclaim disk space
sudo rm -f /var/vm/sleepimage
```

### Checking Wake Reasons:
To inspect what woke the laptop from sleep:
```bash
pmset -g log | grep -e "Wake.*due to"
```

---

## 6. 🔌 Custom USB Port Mapping

* All 12 physical and internal ports of the ASUS ROG Strix GL503GE are mapped inside `UTBDefault.kext` (+ `USBToolBox.kext`):
  * **Internal (Type 255):** `HS07` (HD WebCam), `HS08` (ITE 8910 Aura Keyboard RGB), and `HS14` (Intel Bluetooth Controller). Marking these as internal eliminates `com.apple.usb.externaldevice` sleep prevention assertions.
  * **External USB 3.0 Type-A (Type 3):** `HS01`/`SS01`, `HS02`/`SS02`, `HS03`/`SS03`.
  * **External USB-C (Type 9):** `HS04`/`SS04`.
  * **External USB 2.0 (Type 0):** `HS05`.
* Total port count is 12 (safely within macOS's 15-port limit), ensuring full USB 3.0 (5 Gbps) SuperSpeed operation and proper sleep states.

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

---

## 9. ⌨️ Keyboard Function Keys (F1–F12) & Backlight Brightness

### 1. Function Row Keys (F1 to F12):
The physical function keys on the ASUS ROG Strix GL503GE can be mapped to native macOS media controls:
* **F1:** Audio Mute
* **F2:** Previous Track
* **F3:** Play / Pause
* **F4:** Next Track
* **F5:** Mission Control (Exposé)
* **F6:** Launchpad (App Grid)
* **F7:** Screen Brightness Down
* **F8:** Screen Brightness Up
* **F9:** Spotlight Search
* **F10:** Audio Mute
* **F11:** Volume Down
* **F12:** Volume Up

**Quick Installation:**
Run the included post-install script from your terminal:
```bash
./scripts/setup_function_keys.sh
```
This installs a lightweight LaunchAgent at `~/Library/LaunchAgents/com.local.KeyMapping.plist` that activates the mapping automatically on every login.

---

### 2. Keyboard Backlight (`Fn + Up Arrow` / `Fn + Down Arrow`):
* **Why EFI cannot control it:** On ASUS ROG laptops with Aura RGB keyboards, the backlight is managed by an internal USB microcontroller (**ITE 8910**, `0x0B05:0x1869`), not by motherboard ACPI.
* **Control Software:** Use [**ROG Gaming Center for macOS**](https://github.com/sritulasiram/rog-gaming-center-hackintosh).
* The app intercepts the hardware `0x00C4` / `0x00C5` HID reports when you press `Fn + Up / Down`, steps the physical LED brightness (0–3), and triggers macOS's native backlight HUD bezel.

