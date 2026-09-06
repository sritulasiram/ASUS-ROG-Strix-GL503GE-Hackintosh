# ASUS ROG Strix GL503GE Hackintosh

[![OpenCore](https://img.shields.io/badge/OpenCore-1.0.7-blue.svg?style=flat-square&logo=apple)](https://github.com/acidanthera/OpenCorePkg)
[![macOS Support](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia%20%7C%20Tahoe-success.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Model](https://img.shields.io/badge/ASUS-ROG%20Strix%20GL503GE-red.svg?style=flat-square&logo=asus)](https://rog.asus.com/)
[![Theme](https://img.shields.io/badge/OpenCanopy-Blackosx%20BsxM1-9cf.svg?style=flat-square)](https://github.com/blackosx/OpenCanopy-Icons)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

An optimized, production-ready OpenCore EFI configuration for running macOS (**Sonoma 14.x**, **Sequoia 15.x**, and **Tahoe 16.x**) on the **ASUS ROG Strix GL503GE** gaming laptop.

Built following the [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/), assisted by [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify), and powered by [Acidanthera](https://github.com/acidanthera) kexts and drivers.

> ⚠️ **Disclaimer:** Hackintoshing violates Apple's macOS EULA. This repository is provided solely for educational and personal research purposes. Use at your own risk — the author takes no responsibility for any data loss, hardware damage, or warranty voidance.

---

## 💻 Hardware Specifications & Status

| Component | Hardware Details | Status | Notes / Drivers |
| :--- | :--- | :---: | :--- |
| **CPU** | Intel Core i7-8750H (Coffee Lake-H, 6c/12t) | ✅ Working | Native Power Management (`SSDT-PLUG`, `X86PlatformPlugin`) |
| **iGPU** | Intel UHD Graphics 630 | ✅ Working | Full QE/CI acceleration, HDMI 2.0 patched, `-igfxblt` |
| **dGPU** | NVIDIA GeForce GTX 1050 Ti (Mobile) | ❌ Disabled | Disabled via `SSDT-Disable_GPU_PEG0.aml` to save power and prevent heat |
| **RAM** | 16 GB DDR4 2666 MHz | ✅ Working | Dual-channel detected & operational |
| **Storage** | Samsung 980 500GB NVMe SSD | ✅ Working | Native APFS trim, power management via `NVMeFix.kext` |
| **Audio** | Realtek ALC (ALC295/294) | ✅ Working | `layout-id: 14` (`alcid=14`), speakers, 3.5mm combo jack, HDMI audio |
| **Boot Chime** | UEFI Audio Output | ✅ Working | Native startup chime via `AudioDxe.efi` (`OCEFIAudio_VoiceOver_Boot.wav`) |
| **Ethernet** | Realtek RTL8111 Gigabit Ethernet | ✅ Working | Handled by `RealtekRTL8111.kext` |
| **Wi-Fi** | Intel AX210 / Wireless-AC 9560 | ✅ Working | Supported via **OCLP-Mod** root patching (`IOSkywalkFamily` + `AMFIPass`) |
| **Bluetooth** | Intel Wireless Bluetooth | ✅ Working | `IntelBluetoothFirmware` + `IntelBTPatcher` + `BlueToolFixup` |
| **Trackpad** | ASUS I2C Multi-Touch Trackpad | ✅ Working | Smooth multi-touch gestures via `VoodooI2C` + `VoodooI2CHID` (`-vi2c-force-polling`) |
| **Keyboard** | Built-in Backlit Keyboard | ✅ Working | Function, volume & brightness keys via `BrightnessKeys.kext` |
| **RGB Lighting** | Aura 4-Zone RGB Lighting | ✅ Supported | Controlled via [ROG Gaming Center for macOS](https://github.com/sritulasiram/rog-gaming-center-hackintosh) |
| **Webcam** | Built-in USB HD Camera | ✅ Working | Native macOS UVC support |
| **Card Reader** | Realtek RTS5229 PCIe SD Card Reader | 🔄 Testing | Driver included (`Sinetek-rtsx.kext`) |
| **Battery Status** | ASUS Smart Battery | ✅ Working | Real-time percentage & AC health via `SMCBatteryManager.kext` |
| **Display** | 15.6" Full HD 120Hz IPS Display | ✅ Working | Native brightness slider, 120Hz refresh rate |
| **HDMI Output** | HDMI 2.0 Port | ✅ Working | 4K video & audio output |
| **Sleep / Wake** | S3 Sleep State | ✅ Working | Sleep, lid close, and wake operational |

---

## 📂 Repository Structure

```text
.
├── .github/
│   └── workflows/              # Automated GitHub Actions build & release workflows
├── EFI/
│   ├── BOOT/
│   │   └── BOOTx64.efi         # OpenCore initial UEFI bootloader
│   └── OC/
│       ├── ACPI/               # 11 optimized DSDT/SSDT patches
│       ├── Drivers/            # UEFI drivers (AudioDxe, OpenCanopy, OpenRuntime, etc.)
│       ├── Kexts/              # 26 kernel extensions for hardware enablement
│       ├── Resources/          # Audio chimes, fonts, OpenCanopy themes & labels
│       │   ├── Audio/          # Startup chime WAV files
│       │   ├── Font/           # Boot picker typography
│       │   ├── Image/          # Icons (Acidanthera & Blackosx BsxM1 modern theme)
│       │   └── Label/          # Entry label bitmaps
│       └── config.plist        # Complete OpenCore configuration (sanitized)
├── LICENSE                     # MIT License
├── README.md                   # This documentation
└── TROUBLESHOOTING.md          # In-depth post-install and troubleshooting guide
```

---

## ⚙️ OpenCore Configuration

* **OpenCore Version:** `1.0.7`
* **Target SMBIOS:** `MacBookPro16,4`
* **Boot Arguments:**
  ```text
  debug=0x100 alcid=14 keepsyms=1 -amfipassbeta -igfxblt -vi2c-force-polling
  ```
* **Boot Argument Breakdown:**
  * `alcid=14` — Selects AppleALC layout-id 14 for the Realtek ALC295 codec.
  * `-igfxblt` — Fixes display backlight level initialization at boot.
  * `-vi2c-force-polling` — Forces polling mode on VoodooI2C for reliable touchpad input.
  * `-amfipassbeta` — Allows AMFIPass to work on modern beta/new macOS versions.
  * `debug=0x100 keepsyms=1` — Retains kernel symbols and prevents auto-reboot on kernel panic.

### 🎨 Graphical Boot Picker (OpenCanopy)
* **Mode:** `External`
* **Theme:** `Blackosx\BsxM1` (Modern Apple-style dark icons)
* **Attributes:** `144` (Enables high-resolution icons and direct label rendering)

### 🔊 UEFI Boot Chime (AudioDxe)
* **Driver:** `AudioDxe.efi`
* **Audio Device:** `PciRoot(0x0)/Pci(0x1f,0x3)`
* **Audio Codec:** `0`
* **Setup Delay:** `500 ms`
* **Audio File:** `OCEFIAudio_VoiceOver_Boot.wav` (Native Mac startup chime)

### 🧩 ACPI Patches (SSDTs)
* `SSDT-ALSD.aml` — Ambient Light Sensor dummy device.
* `SSDT-Disable_GPU_PEG0.aml` — Shuts down the discrete NVIDIA GTX 1050 Ti GPU.
* `SSDT-EC.aml` — Embedded Controller compatibility patch for macOS.
* `SSDT-GPI0.aml` — Enables GPIO controller for touchpad hardware interrupt routing.
* `SSDT-MCHC.aml` — Fixes Memory Controller Hub recognition.
* `SSDT-PLUG.aml` — Enables native CPU power management (`X86PlatformPlugin`).
* `SSDT-PMC.aml` — Provides native NVRAM support for Intel 300-series chipsets.
* `SSDT-PNLF.aml` — Adds Coffee Lake backlight control device.
* `SSDT-SBUS.aml` — Fixes System Management Bus (SMBus) recognition.
* `SSDT-USBX.aml` — Injects proper USB power properties (USB sleep/wake current).
* `SSDT-XOSI.aml` — Emulates Windows 10/11 environment for ASUS ACPI tables.

### 📦 Kernel Extensions (Kexts)

<details open>
<summary><b>Full Kext List (26 kexts)</b></summary>

| Kext | Purpose |
| :--- | :--- |
| `Lilu.kext` | Core kext patcher & hooking engine (Essential) |
| `VirtualSMC.kext` | Advanced Apple SMC chip emulator |
| `SMCProcessor.kext` | Real-time CPU temperature and core monitoring |
| `SMCSuperIO.kext` | Fan speed and hardware sensor telemetry |
| `SMCBatteryManager.kext` | ASUS laptop battery percentage and charging state |
| `SMCLightSensor.kext` | Ambient light sensor emulation |
| `WhateverGreen.kext` | Intel UHD 630 framebuffer patching and HDMI 2.0 enablement |
| `AppleALC.kext` | Realtek ALC295 native audio patcher |
| `BrightnessKeys.kext` | Maps ASUS keyboard brightness function keys |
| `RealtekRTL8111.kext` | Realtek Gigabit Ethernet driver |
| `AirportItlwm.kext` | Intel Wi-Fi driver |
| `IOSkywalkFamily.kext` | Modern wireless networking compatibility framework |
| `IO80211FamilyLegacy.kext` | Legacy wireless support for modern macOS |
| `AMFIPass.kext` | AppleMobileFileIntegrity compatibility shim |
| `IntelBluetoothFirmware.kext` | Firmware loader for Intel Bluetooth |
| `IntelBTPatcher.kext` | Intel Bluetooth subsystem kernel patches |
| `BlueToolFixup.kext` | macOS Bluetooth stack compatibility wrapper |
| `VoodooI2C.kext` | Intel I2C controller driver |
| `VoodooI2CHID.kext` | Precision multi-touch trackpad gestures |
| `USBToolBox.kext` | Custom USB port management engine |
| `UTBDefault.kext` | ASUS GL503GE USB port mapping definitions |
| `XHCI-unsupported.kext` | Intel 300-series XHCI USB controller injector |
| `NVMeFix.kext` | NVMe power management, APST tables, and stability |
| `Sinetek-rtsx.kext` | Realtek PCIe SD card reader driver |
| `RestrictEvents.kext` | System event suppression & CPU branding patcher |
| `ForgedInvariant.kext` | Fixes TSC invariant timing on Coffee Lake |

</details>

### 🔌 UEFI Drivers
* `AudioDxe.efi` — UEFI audio protocol driver for boot chime sound.
* `OpenCanopy.efi` — High-resolution graphical boot menu interface.
* `OpenRuntime.efi` — Mandatory runtime memory management driver for OpenCore.
* `HfsPlus.efi` — High-performance HFS+ file system driver.
* `apfs_aligned.efi` — APFS file system driver.
* `ResetNvramEntry.efi` — Adds convenient NVRAM reset option to boot menu.

---

## 🔧 BIOS Configuration

> **Tested BIOS Version:** ASUS GL503GE BIOS 319 (or latest official)

### Recommended Settings:
* **Disable:**
  * ❌ Fast Boot
  * ❌ Secure Boot
  * ❌ Intel SGX (Software Guard Extensions)
  * ❌ CSM / Legacy Boot
* **Enable:**
  * ✅ Intel Virtualization Technology (VT-x)
  * ✅ VT-d
  * ✅ SATA Operation: **AHCI**
  * ✅ XHCI Hand-off
  * ✅ Above 4G Decoding (if option present)

---

## 🚀 Installation & Setup Guide

### 1. Generate Your Own SMBIOS (Required!)
> [!IMPORTANT]
> The `config.plist` in this repository has placeholder values (`CHANGEME`) for serial numbers to prevent conflicts. **You must generate your own unique SMBIOS values before booting:**

1. Download and run [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS).
2. Select option `1` to download MacSerial, then option `3` to generate SMBIOS for `MacBookPro16,4`.
3. Open `EFI/OC/config.plist` with [ProperTree](https://github.com/corpnewt/ProperTree) or [OCAuxiliaryTools](https://github.com/ic005k/OCAuxiliaryTools).
4. Navigate to `PlatformInfo > Generic` and fill in:
   * `SystemSerialNumber`
   * `MLB` (Board Serial Number)
   * `SystemUUID`
   * `ROM` (Use your laptop Ethernet MAC address without colons, e.g. `112233445566`)

### 2. Prepare USB Installer
1. Create a bootable macOS USB installer using standard Apple tools:
   ```bash
   sudo /Applications/Install\ macOS\ Sequoia.app/Contents/Resources/createinstallmedia --volume /Volumes/MyUSB
   ```
2. Mount the EFI partition of your USB drive (using `MountEFI` or `diskutil mount diskXs1`).
3. Copy the entire `EFI` folder from this repository to the root of the EFI partition.
4. Reboot, enter BIOS (hold `F2` at startup), verify BIOS settings above, and boot from USB (`F8` or `Esc`).

### 3. Post-Installation: Intel Wi-Fi via OCLP-Mod
On macOS Sonoma (14) and Sequoia (15):
1. Complete the macOS setup assistant.
2. Download **[OCLP-Mod (OpenCore-Legacy-Patcher Mod)](https://github.com/lzhoang2801/OpenCore-Legacy-Patcher/releases)**.
3. Launch OCLP-Mod and click **Post-Install Root Patch**.
4. Install the **Networking: Modern Wireless** patch set.
5. Reboot your laptop. Native Wi-Fi management and Control Center networking will now be active.

### 4. Keyboard Backlight & Telemetry: ROG Gaming Center
To configure Aura 4-Zone RGB keyboard lighting, fan profiles, and hardware telemetry on macOS:
* Download and install **[ROG Gaming Center for macOS](https://github.com/sritulasiram/rog-gaming-center-hackintosh)**.

---

## 📖 Troubleshooting & Optimizations

For additional troubleshooting and optimization guides, see [**TROUBLESHOOTING.md**](TROUBLESHOOTING.md):
* **iCloud, iMessage, and FaceTime Activation**
* **Touchpad Polling vs GPIO Pinning Tuning**
* **Audio Headphone Auto-Switching**
* **Sleep / Wake Optimization & Hibernation Disabling**
* **USB Port Customization**

---

## 🤝 Credits & Acknowledgements

* [Apple](https://www.apple.com) for macOS.
* [Dortania](https://github.com/dortania) for the OpenCore Install Guide.
* [Acidanthera](https://github.com/acidanthera) for OpenCorePkg, Lilu, VirtualSMC, AppleALC, WhateverGreen, and companion kexts.
* [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify) by @lzhoang2801.
* [Blackosx](https://github.com/blackosx/OpenCanopy-Icons) for the BsxM1 OpenCanopy icon theme.
* [corpnewt](https://github.com/corpnewt) for GenSMBIOS, ProperTree, and MountEFI.
* [alexandred](https://github.com/alexandred) & the [VoodooI2C Team](https://github.com/VoodooI2C/VoodooI2C) for trackpad drivers.
* [sinetek](https://github.com/sinetek/Sinetek-rtsx) for the Realtek SD card reader driver.
