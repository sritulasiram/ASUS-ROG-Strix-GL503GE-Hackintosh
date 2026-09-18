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

### Issue: Trackpad freezes for 2–3 minutes or cursor stops moving intermittently.
* **Root Cause of 2–3 Min Freeze (Polling Mode):** Using the `-vi2c-force-polling` boot argument forces VoodooI2C to poll the Intel DesignWare I2C0 bus (`pci8086,a368`) continuously at 60–100Hz. During CPU frequency scaling, Intel C-state shifts, or rapid multitouch gestures, an I2C transaction desynchronizes and deadlocks the controller FIFO in an abort state (`TX_ABRT` / bus busy). Without hardware interrupts to service the FIFO, the cursor remains stuck until the hardware controller watchdog timer expires (~120–180s, exactly 2–3 minutes) and forcibly resets the I2C bus.
* **Current Implementation:** The EFI runs `VoodooI2C.kext` + `VoodooI2CHID.kext` in **Native GPIO Interrupt Mode** via `VoodooGPIOCannonLakeH.kext` matching `INT3450` (`GPI0`), with `SSDT-GPI0.aml` and `SSDT-XOSI.aml`.
* **Verification Command:**
  Run in Terminal to verify that the trackpad is operating with direct hardware interrupts:
  ```bash
  ioreg -rc VoodooI2CDeviceNub -n "TPD0" | grep -i "Interrupt Mode"
  ```
  Expected output:
  ```text
  "Interrupt Mode" = "Interrupt"
  ```
* **Fallback / GPIO Pinning (If Device is Unpinned):**
  * If on specific BIOS revisions the trackpad does not respond without `-vi2c-force-polling`, the OEM DSDT is returning an APIC interrupt or `0x0000` pin in `_CRS`.
  * In that case, add the `TPD0 _CRS to XCRS Rename` patch and inject `SSDT-TPD0.aml` with the explicit Cannon Lake PCH GPIO Pin (`0x68` or `0x55`).
  * Avoid using `-vi2c-force-polling` permanently, as polling burns CPU cycles, degrades battery life, and causes the 2–3 minute watchdog freeze.
* **Trackpad Preferences:** Enable **Tap to Click** in *System Settings > Trackpad*.

---

## 3. 🔊 Audio & 3.5mm Headphone Jack

### Issue: No sound from speakers, or headphone jack not switching automatically.
* **Codec:** Realtek ALC295 / ALC294
* **Current Layout:** `alcid=14` (`layout-id` & `alc-layout-id: <data>DgAAAA==</data>`)
* **Alternative Layouts to Test:**
  * Layout `13`, `14`, `15`, `21`, `22`, `28`
  * To test another layout, modify the `alcid=XX` argument in `config.plist` under `NVRAM > 7C436110-AB2A-4BBB-A880-FE41995C9F82 > boot-args`.

### 🚨 Critical Note for macOS 26.x (Tahoe) Updates:
* **Why Audio Breaks After macOS 26.x Updates (e.g., 26.7):**
  1. **Apple Dropped AppleHDA:** In macOS 26 (Tahoe), Apple permanently removed `AppleHDA.kext` from the operating system because official Macs now route audio exclusively through T2/Apple Silicon chips. Because `AppleALC.kext` is a runtime patcher for `AppleHDA`, it cannot attach without `AppleHDA.kext` present in the OS.
  2. **Root Snapshot Overwrite:** Applying any macOS update (such as 26.7) replaces the root volume with Apple's newly sealed APFS update snapshot (`com.apple.os.update-...`), wiping all previous root patches.
  3. **DeviceProperties Data Type:** `layout-id` must be injected as 4-byte OSData (`<data>DgAAAA==</data>`), not integer, so `OSDynamicCast(OSData, ...)` in `AppleALC` succeeds.
* **Fix Procedure After macOS 26 Update:**
  1. Deploy the updated EFI with `layout-id` & `alc-layout-id` data type fixes:
     ```bash
     sudo ./scripts/deploy_to_esp.sh
     ```
  2. Download/open **[OCLP-Mod (OpenCore-Legacy-Patcher Mod)](https://github.com/lzhoang2801/OpenCore-Legacy-Patcher/releases)**.
  3. Click **Post-Install Root Patch**.
  4. Ensure both **Audio (AppleHDA)** and **Networking (Modern Wireless)** patches are applied.
  5. Reboot the laptop. Once booted, `AppleALC` will bind to the re-injected `AppleHDA` and restore full internal speakers, 3.5mm combo jack, and internal microphone.

* **Headphone Jack Auto-Switching:** If the 3.5mm jack does not detect plugin/unplug events, install [ALCPlugFix-Swift](https://github.com/black-dragon-x/ALCPlugFix-Swift) to monitor jack status.
* **Digital USB-C Alternative (Zero Setup):** The laptop's USB-C port is mapped as Type 10 (`HS09` / `HS11`) in `UTBDefault.kext`. Connecting **Apple USB-C EarPods** or USB-C DAC dongles bypasses the analog ALC295 codec completely, providing native 24-bit digital audio, inline mic, and volume controls out of the box without requiring any root patches.

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

## 6. 🔌 Custom USB Port Mapping & USB-C EarPods

* All 14 physical and internal logical ports of the ASUS ROG Strix GL503GE are mapped inside `UTBDefault.kext` (+ `USBToolBox.kext`):
  * **Internal (Type 255):** `HS07` (HD WebCam), `HS08` (ITE 8910 Aura Keyboard RGB), and `HS14` (Intel Bluetooth Controller). Marking internal headers eliminates `com.apple.usb.externaldevice` sleep prevention assertions.
  * **External USB 3.0 Type-A (Type 3):**
    * Left Rear: `HS01` / `SS01`
    * Left Middle: `HS02` / `SS02`
    * Right Bottom: `HS04` / `SS05`
  * **External USB 2.0 Type-A (Type 0):** Right Top `HS03`.
  * **External USB-C (Type 10 — Type-C without Switch):**
    * The physical USB-C port does not have an on-board hardware multiplexer. It routes to two separate logical ports per standard for dual-orientation support:
    * **USB 2.0 (HighSpeed):** `HS09` (Orientation 1) and `HS11` (Orientation 2). This provides native out-of-the-box support for **Apple USB-C EarPods**, USB-C audio dongles/DACs, and smartphone data transfer.
    * **USB 3.1 (SuperSpeed):** `SS03` (Orientation 1) and `SS04` (Orientation 2), delivering 5 Gbps in both plug orientations.
* Total port count is 14 (safely within macOS's 15-port limit), ensuring full dual-orientation SuperSpeed operation, audio accessory support, and clean S3 sleep states.

---

## 7. 🔆 Display, Graphics (Intel UHD 630) & Backlight

* **Display Panel:** Chi Mei Innolux `N156HHE-GA1` (15.6" 1080p @ **120.00Hz**, 285 MHz pixel clock).
* **VRAM Allocation:** Dynamic VRAM is boosted to **2048 MB** (`framebuffer-unifiedmem` = `<00000080>`), giving Metal 3 and high-refresh 120Hz frame buffers ample headroom.
* **Complete Modeset & Force Online (Black Screen Fix):** The 120Hz internal eDP panel transitions from 60Hz UEFI GOP to 120Hz WindowServer. To prevent intermittent black screens upon boot completion:
  * `complete-modeset` (`<data>AQAAAA==</data>`) forces WhateverGreen to fully retrain display link timings.
  * `complete-modeset-framebuffers` (`<data>AAAAAAAAAAE=</data>`) targets connector 0 (internal eDP).
  * `force-online` (`<data>AQAAAA==</data>`) and `force-online-framebuffers` (`<data>AAAAAAAAAAE=</data>`) ensure the panel is immediately recognized as online.
  * `igfxfw=2` (GuC firmware loading) is omitted: on mobile Coffee Lake and newer macOS releases, GuC firmware loading causes an asynchronous handshake race condition during the display server transition that leaves the screen dark.
* **Backlight Registers Fix (Instant Backlight Initialization):** The Coffee Lake backlight registers are initialized immediately upon driver attach using `enable-backlight-registers-fix` (`<data>AQAAAA==</data>`) and `-igfxblr` in `boot-args`. This completely eliminates the temporary dark screen delay before the login window appears (previously caused by `-igfxbls` / Backlight Smoother holding brightness at 0% during early boot).
* **Keyboard Hotkeys:** `BrightnessKeys.kext` handles `Fn + F7` / `Fn + F8` natively.
* **Color Profile Management:** The wide-gamut (94% NTSC) Chi Mei panel's ColorSync profile can be checked and switched instantly between Native EDID Wide-Gamut, standard sRGB, or Display P3 using the included helper script:
  ```bash
  ./scripts/set_color_profile.py --native    # Restores true wide-gamut EDID mapping (Recommended)
  ./scripts/set_color_profile.py --srgb      # Sets standard sRGB profile
  ./scripts/set_color_profile.py --status    # Displays current ColorSync active profile
  ```

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

---

## 10. 💽 SD Card Reader (Realtek RTS5229) & macOS Tahoe Compatibility

* **Hardware Controller:** Realtek RTS5229 PCIe Card Reader (`0x10EC:0x5229`).
* **Active Driver:** `Sinetek-rtsx.kext` (v9.0.0).
* **Why not `RealtekCardReader.kext` on macOS Tahoe (16.x)?:**
  * While `RealtekCardReader.kext` by 0xFireWolf offers native hotplugging on older macOS releases, it hooks into private kernel structures in `IOStorageFamily` and `IOPCIFamily`.
  * In **macOS Tahoe (Darwin 25.x)**, Apple refactored IOKit memory descriptors and internal storage APIs. Using `RealtekCardReader.kext` on macOS Tahoe triggers an **early kernel panic during PCIe probe, causing the system to fail to boot**.
* **Best Practices with `Sinetek-rtsx.kext`:**
  1. `Sinetek-rtsx.kext` relies on standard `IOPCIDevice` matching without deep kernel hooks, allowing macOS Tahoe to boot safely.
  2. **Card Insertion:** Insert the SD card *before booting* or *before waking* the laptop if hotplug detection does not mount the card automatically.
  3. **Sleep Precaution:** Do not leave an SD card inserted in the slot when placing the laptop into S3 sleep, as legacy block storage drivers can stall sleep transitions.
  4. If you do not use the SD card slot, you may safely disable `Sinetek-rtsx.kext` in `config.plist` under `Kernel > Add` to keep the kernel stack minimal.

