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
  "Interrupt Mode" = "GPIO"
  ```
* **Fallback / GPIO Pinning (If Device is Unpinned):**
  * If on specific BIOS revisions the trackpad does not respond without `-vi2c-force-polling`, the OEM DSDT is returning an APIC interrupt or `0x0000` pin in `_CRS`.
  * In that case, add the `TPD0 _CRS to XCRS Rename` patch and inject `SSDT-TPD0.aml` with the explicit Cannon Lake PCH GPIO Pin (`0x68` or `0x55`).
  * Avoid using `-vi2c-force-polling` permanently, as polling burns CPU cycles, degrades battery life, and causes the 2–3 minute watchdog freeze.
  * *(Verified working natively on ASUS ROG Strix GL503GE BIOS 319 without extra pinning SSDT).*
* **Trackpad Preferences:** Enable **Tap to Click** in *System Settings > Trackpad*.

---

## 3. 🔊 Audio & 3.5mm Headphone Jack

### Issue: No sound from speakers, or headphone jack not switching automatically.
* **Codec:** Realtek ALC295 / ALC294
* **Current Layout:** `alcid=14` (`layout-id` & `alc-layout-id: <data>DgAAAA==</data>`)
* **Alternative Layouts to Test:**
  * Layout `13`, `14`, `15`, `21`, `22`, `28`
  * **Important:** In `AppleALC`, entries under `DeviceProperties` take precedence over `alcid=XX` in `boot-args`. If testing an alternative layout via `alcid=XX` in `boot-args`, you must also update (or temporarily remove) `layout-id` and `alc-layout-id` under `DeviceProperties > PciRoot(0x0)/Pci(0x1f,0x3)` in `config.plist`.

### 🔊 Sound Optimization: Reaching "MacBook Pro" Audio Standards

#### 1. Why do real MacBook Pros sound so rich while PC Hackintoshes sound flat?
* **Acoustic Hardware Differences:**
  * **MacBook Pro 15"/16":** Features a 6-speaker sound system with dual force-cancelling woofers mounted in precision-milled aluminum acoustic resonance cavities, preventing vibration and distortion while reproducing bass down to ~80 Hz.
  * **ASUS ROG Strix GL503GE:** Equipped with two 3.5W side-firing oval speakers enclosed in a hollow polycarbonate (plastic) laptop chassis. The plastic chamber naturally resonates between 2 kHz and 4 kHz (causing a "tinny" telephone quality) and lacks physical bass extension below 150 Hz.
* **Apple's Secret Weapon — Proprietary CoreAudio DSP:**
  * In genuine Macs, macOS runs real-time **Digital Signal Processing (DSP)** specifically calibrated to the chassis:
    1. **Harmonic Bass Excitation:** Generates 2nd and 3rd harmonics (120 Hz–240 Hz) tricking the human brain into perceiving deep sub-bass from small 2-inch speakers (psychoacoustic bass).
    2. **Multiband Dynamic Limiting:** Compresses volume peaks so speakers play significantly louder without crackling or blowing out.
    3. **Plastic Resonance Notch Filter:** Cuts the harsh 2.5 kHz–4 kHz midrange.
    4. **Spatial Stereo Expansion:** Phase-shifts ambient frequencies to project sound past the display edges.
* **Why AppleALC sounds flat by default:**
  * On Windows, ASUS bundles **ASUS Sonic Studio III / ICEPower / Realtek Audio Effects APO** to provide this DSP in software.
  * Under macOS via `AppleALC`, macOS treats the ALC295 as a generic flat DAC with **zero DSP and zero dynamic compression**.

#### 2. Recreating the MacBook Pro Sound Profile on ASUS GL503GE
The repository includes a dedicated calibration suite:
* **Preset Profile:** [`audio/MacBook_Pro_Acoustic_Profile.json`](file:///Users/sritulasiram/Documents/Projects/efi/audio/MacBook_Pro_Acoustic_Profile.json)
* **Setup Script:** Run the helper script to audit your codec and stage the profile:
  ```bash
  ./scripts/setup_macbook_sound.sh
  ```

#### 3. Recommended DSP Calibration Settings:
Install the free, open-source CoreAudio engine **[eqMac](https://github.com/bitgapp/eqMac/releases)** (uses a native CoreAudio HAL driver with zero latency):
1. Launch **eqMac** from Applications or Menu Bar.
2. Navigate to **Equalizers > Advanced (10-Band)**.
3. Click **Import** and select `MacBook_Pro_Acoustic_Profile.json` (saved to your Desktop or `audio/`).
4. Apply the recommended supplementary controls:
   * **Bass Booster:** `25%` (Adds warm MacBook Pro low-end harmonics).
   * **Spatial Audio:** `120%` (Expands stereo soundstage beyond the laptop screen).
   * **Volume Limiter:** `ON (-0.5 dB)` (Guarantees zero speaker distortion/clipping at 100% volume).
   * **Preamp (Global):** `+1.5 dB` (Compensates for conservative ALC295 hardware gain).

| Frequency Band | Gain Adjustment | Purpose |
| :--- | :---: | :--- |
| **32 Hz** | **-3.0 dB** | Subsonic cut to prevent speaker cone rattling / thermal overload |
| **64 Hz** | **+1.0 dB** | Upper sub-bass foundation |
| **125 Hz** | **+4.5 dB** | Psychoacoustic bass punch and warm low-end body |
| **250 Hz** | **+2.0 dB** | Vocal warmth and fullness (removes the hollow laptop sound) |
| **500 Hz** | **-1.5 dB** | Plastic cabinet de-boxifier |
| **1 kHz** | **0.0 dB** | Neutral reference vocal intelligibility |
| **2 kHz** | **-2.5 dB** | ALC295 harshness suppression |
| **4 kHz** | **-3.5 dB** | **Critical:** Eliminates piercing high-mid plastic chassis resonance |
| **8 kHz** | **+2.5 dB** | Crisp dialogue & acoustic guitar presence |
| **16 kHz** | **+3.5 dB** | Retina air shimmer & open soundstage |

---

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
  3. Verify `csr-active-config` is set to `030A0000` (`<data>AwoAAA==</data>`).
  4. Boot into macOS, download **[OCLP-Mod](https://github.com/lzhoang2801/OpenCore-Legacy-Patcher/releases)**, and click **Post-Install Root Patch**.
  5. Select **Networking: Modern Wireless** to patch the Intel Wi-Fi drivers into the system snapshot.
  6. Reboot when prompted.

### Issue: Universal Clipboard (Copy on iPhone, Paste on Mac) does not work.
* **Why it fails on Intel Wi-Fi / Bluetooth:**
  1. **Two-Stage Continuity Protocol:** Universal Clipboard requires two separate protocols:
     * **Discovery (Bluetooth LE):** Announces that new clipboard content is available.
     * **Payload Transfer (Apple Wireless Direct Link — AWDL):** When you click "Paste" on macOS, the system attempts to establish a direct, high-speed, peer-to-peer Wi-Fi connection directly between the Mac and iPhone via **AWDL** to stream the copied data across the air.
  2. **Intel Hardware Lacks AWDL:** The Intel Wi-Fi hardware and drivers (`AirportItlwm` / `itlwm`) only support standard 802.11 infrastructure networking. They **completely lack Apple's proprietary AWDL microcode and frame-injection capabilities**.
  3. Because macOS cannot establish the AWDL direct peer-to-peer Wi-Fi tunnel to download the clipboard data from your iPhone, the paste operation times out and the "Paste" menu option never appears.
* **What works vs. what fails on Intel:**
  * **Basic Handoff (URLs/Apps):** ⚠️ Partial — A Safari webpage icon may occasionally appear on the Mac Dock if Bluetooth LE is active, because small URLs can fit inside the BLE discovery beacon without needing AWDL.
  * **Universal Clipboard:** ❌ Unsupported — Payload transfer strictly requires Apple AWDL.
  * **AirDrop & Universal Control:** ❌ Unsupported — Strictly require Apple AWDL.
* **Recommended Workarounds for Instant Copy/Paste:**
  * **iCloud Notes:** Paste text into a pinned note on iPhone; it syncs via standard internet connection to macOS within seconds.
  * **[LocalSend](https://localsend.org/):** Free, open-source, zero-cloud local LAN file and clipboard sharing app that works seamlessly between iOS, macOS, Windows, and Android over standard Wi-Fi router connections without needing AWDL.

### Issue: Bluetooth fails to turn on, toggles off automatically, or shows "Address: NULL".
* **Root Cause — Kext Load Order Race Condition:**
  In OpenCore, the Bluetooth kext stack must be loaded in exact sequential order:
  1. `IntelBluetoothFirmware.kext` (uploads the microcode firmware to the controller).
  2. `IntelBTPatcher.kext` (hooks IntelBluetoothFirmware memory descriptors and HCI buffers).
  3. `BlueToolFixup.kext` (interfaces `bluetoothd` with the initialized device).
  *If `BlueToolFixup` or `IntelBTPatcher` is loaded ahead of `IntelBluetoothFirmware`, the controller handshake desynchronizes at boot, causing Bluetooth to report `Address: NULL` and `State: Off`.*
* **EFI Fix:** The kext order in `Kernel > Add` has been corrected in both `config.plist` and `config.personal.plist`. Deploy the updated EFI to your ESP:
  ```bash
  sudo ./scripts/deploy_to_esp.sh
  ```
* **Quick Daemon & Cache Reset Script:**
  If Bluetooth daemon preferences or NVRAM controller variables become stale:
  ```bash
  sudo ./scripts/reset_bluetooth.sh
  ```
* **Important:** Do **not** use `IntelBluetoothInjector.kext` on macOS Monterey and later (it was replaced by `BlueToolFixup.kext`).

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

### Checking Sleep & Wake Logs:
To inspect recent sleep transitions and wake events:
```bash
pmset -g log | grep -E "(Entering Sleep|Wake from)" | tail -n 10
```
Expected healthy output:
```text
Entering Sleep state due to 'Software Sleep pid=...': Using ...
Wake from Normal Sleep [CDNVA] : due to PWRB/UserActivity Assertion
```
*(Notice `[CDNVA]` indicates all Clamshell, Display, Network, Video, and Audio subsystems resumed cleanly).*

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
* **Native MacBook Pro Display Settings & Retina HiDPI Scaling (Zero Background Apps):**
  By default, macOS treats the internal 1080p panel as a non-Retina 1x display, which causes thin/aliased text rendering since font smoothing was removed in macOS Mojave. You can natively configure macOS System Settings to identify the internal screen as a **"Built-in Retina Display"**, assign the authentic **MacBook Pro laptop clamshell icon**, and enable **2× supersampled Retina HiDPI vector scaling** (`1920x1080 HiDPI`, `1680x945 HiDPI`, `1600x900 HiDPI`, `1424x802 HiDPI`, `1280x720 HiDPI`) without installing any third-party background apps:
  ```bash
  sudo ./scripts/setup_native_macbook_display.sh
  ```
  * **To Revert:** Restore default macOS display configuration at any time:
    ```bash
    sudo ./scripts/setup_native_macbook_display.sh --disable
    ```

### 🚨 Troubleshooting: "I can't see the HiDPI settings"
If the HiDPI resolution options do not appear in *System Settings > Displays* after running the setup script, follow these steps:
1. **Re-run the updated setup script:**
   ```bash
   sudo ./scripts/setup_native_macbook_display.sh
   ```
   *(This ensures `DisplayResolutionEnabled = true` is registered with the macOS WindowServer preference daemon and old display caches are purged).*
2. **Reboot your laptop:**
   ```bash
   sudo reboot
   ```
   *macOS only loads `scale-resolutions` into the graphics driver during early boot link training. Changes cannot take effect while the system is running without a clean reboot.*
3. **Unhide Scaled Resolutions in Modern macOS (Ventura, Sonoma, Sequoia, Tahoe):**
   * Open **System Settings > Displays**.
   * Scroll down to the bottom and click **Advanced...**.
   * Turn **ON** the toggle: **"Show resolutions as list"**, then click **Done**.
   * Back on the main Displays page, turn **ON** the toggle: **"Show all resolutions"** *(or right-click / Control-click anywhere inside the resolution list)*.
   * All **(HiDPI)** modes will now be visible and selectable.

* **Fixed 120.00 Hz Refresh Rate & TCON Architecture:**
  * The internal panel is a dedicated esports-grade **Chi Mei Innolux N156HHE-GA1**.
  * The panel's hardware Timing Controller (TCON) is hardwired strictly for **120Hz refresh cycles (8.33 ms frame times)** at a fixed 285.05 MHz pixel clock.
  * **Do not force 60Hz:** Attempting to force a 60Hz timing block causes the TCON to desynchronize, resulting in a black screen or severe liquid crystal polarity inversion flicker.
  * Running at a fixed 120Hz provides the smooth motion and cursor tracking of an Apple **ProMotion** display natively across all macOS UI animations.

* **Color Profile Management:** The wide-gamut (94% NTSC / D65) Chi Mei panel's ColorSync profile can be checked and switched instantly between Native EDID Wide-Gamut, standard sRGB, or Display P3 using the included helper script:
  ```bash
  ./scripts/set_color_profile.py --native    # Restores true wide-gamut EDID mapping (Recommended)
  ./scripts/set_color_profile.py --p3        # Sets Apple Display P3 profile
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
* **Why not `RealtekCardReader.kext` on macOS Tahoe (26.x)?:**
  * While `RealtekCardReader.kext` by 0xFireWolf offers native hotplugging on older macOS releases, it hooks into private kernel structures in `IOStorageFamily` and `IOPCIFamily`.
  * In **macOS Tahoe (Darwin 25.x)**, Apple refactored IOKit memory descriptors and internal storage APIs. Using `RealtekCardReader.kext` on macOS Tahoe triggers an **early kernel panic during PCIe probe, causing the system to fail to boot**.
* **Best Practices with `Sinetek-rtsx.kext`:**
  1. `Sinetek-rtsx.kext` relies on standard `IOPCIDevice` matching without deep kernel hooks, allowing macOS Tahoe to boot safely.
  2. **Card Insertion:** Insert the SD card *before booting* or *before waking* the laptop if hotplug detection does not mount the card automatically.
  3. **Sleep Precaution:** Do not leave an SD card inserted in the slot when placing the laptop into S3 sleep, as legacy block storage drivers can stall sleep transitions.
  4. If you do not use the SD card slot, you may safely disable `Sinetek-rtsx.kext` in `config.plist` under `Kernel > Add` to keep the kernel stack minimal.

