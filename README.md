# ASUS ROG Strix GL503GE Hackintosh

[![OpenCore](https://img.shields.io/badge/OpenCore-1.0.7-blue.svg?style=flat-square&logo=apple)](https://github.com/acidanthera/OpenCorePkg)
[![macOS Support](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia-success.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Model](https://img.shields.io/badge/ASUS-ROG%20Strix%20GL503GE-red.svg?style=flat-square&logo=asus)](https://rog.asus.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

OpenCore EFI configuration for running macOS on the **ASUS ROG Strix GL503GE** laptop. Built in accordance with the [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/), assisted by [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify), and powered by [Acidanthera](https://github.com/acidanthera) kexts and drivers.

> ⚠️ **Disclaimer:** Hackintoshing violates Apple's macOS EULA. This repository is for educational and personal research purposes only. Use at your own risk — the author takes no responsibility for any data loss, hardware damage, or warranty voidance.

---

## 💻 Hardware Specifications & Status

| Component | Hardware Details | Status | Notes |
| :--- | :--- | :---: | :--- |
| **CPU** | Intel Core i7-8750H (Coffee Lake-H, 6c/12t) | ✅ Working | Native Power Management (`SSDT-PLUG`) |
| **iGPU** | Intel UHD Graphics 630 | ✅ Working | Full QE/CI acceleration, HDMI 2.0 patched, `-igfxblt` |
| **dGPU** | NVIDIA GeForce GTX 1050 Ti (Mobile) | ❌ Disabled | Disabled via `SSDT-Disable_GPU_PEG0.aml` (no macOS driver support) |
| **RAM** | 16 GB DDR4 2666 MHz | ✅ Working | Dual-channel detected |
| **Storage** | Samsung 980 500GB NVMe SSD | ✅ Working | Power management managed via `NVMeFix.kext` |
| **Audio** | Realtek ALC (ALC295/294) | ✅ Working | `layout-id: 14` (`alcid=14`), Speakers & 3.5mm jack |
| **Ethernet** | Realtek RTL8111 Gigabit Ethernet | ✅ Working | Handled by `RealtekRTL8111.kext` |
| **Wi-Fi** | Intel AX210 / Intel Wireless | ✅ Working | Working via `AirportItlwm` & OCLP modern wireless patch |
| **Bluetooth** | Intel Wireless Bluetooth | ✅ Working | `IntelBluetoothFirmware` + `IntelBTPatcher` + `BlueToolFixup` |
| **Trackpad** | ASUS I2C Multi-Touch Trackpad | ✅ Working | `VoodooI2C` + `VoodooI2CHID` with `-vi2c-force-polling` |
| **Keyboard** | Built-in Backlit Keyboard | ✅ Working | Function & Brightness keys via `BrightnessKeys.kext` |
| **Keyboard Backlight** | Aura RGB Lighting | 🔄 Testing | Work in progress |
| **Webcam** | Built-in USB HD Camera | ✅ Working | Native UVC support |
| **Card Reader** | Realtek RTS5229 / PCIe SD Card Reader | 🔄 Testing | `Sinetek-rtsx.kext` included (untested) |
| **Battery Status** | ASUS Smart Battery | ✅ Working | Percentage & health reporting via `SMCBatteryManager.kext` |
| **HDMI Output** | HDMI 2.0 Port | ✅ Working | Video & Audio output |
| **Sleep / Wake** | S3 Sleep State | 🔄 Testing | Testing power assertions and sleep stability |

---

## ⚙️ OpenCore Configuration

* **OpenCore Version:** `1.0.7`
* **Target SMBIOS:** `MacBookPro16,4`
* **Active Boot Arguments:**
  ```text
  debug=0x100 alcid=14 keepsyms=1 -amfipassbeta -igfxblt -vi2c-force-polling
  ```

### 🧩 ACPI Patches (SSDTs)
* `SSDT-ALSD.aml` — Ambient Light Sensor dummy device.
* `SSDT-Disable_GPU_PEG0.aml` — Powers down the discrete NVIDIA GPU to save battery and reduce heat.
* `SSDT-EC.aml` — Embedded Controller fix for macOS.
* `SSDT-GPI0.aml` — GPIO controller enablement for I2C touchpad interrupts.
* `SSDT-MCHC.aml` — Memory Controller Hub fix.
* `SSDT-PLUG.aml` — Native CPU power management (`X86PlatformPlugin`).
* `SSDT-PMC.aml` — Native NVRAM support for 300-series chipsets.
* `SSDT-PNLF.aml` — Display backlight control for Coffee Lake mobile displays.
* `SSDT-SBUS.aml` — Fixes SMBus support.
* `SSDT-USBX.aml` — USB power properties injection.
* `SSDT-XOSI.aml` — Routes OS calls through ACPI to simulate Windows environment.

### 📦 Kernel Extensions (Kexts)

<details>
<summary><b>Click to expand full kext list (26 kexts)</b></summary>

| Kext | Purpose |
| :--- | :--- |
| `Lilu.kext` | Arbitrary kext and process patching engine (Requirement) |
| `VirtualSMC.kext` | Advanced Apple SMC emulator |
| `SMCProcessor.kext` | CPU temperature monitoring sensor |
| `SMCSuperIO.kext` | Fan speed and hardware sensor monitoring |
| `SMCBatteryManager.kext` | Battery status and percentage monitoring |
| `SMCLightSensor.kext` | Ambient light sensor emulator |
| `WhateverGreen.kext` | Graphics driver patches for Intel UHD 630 |
| `AppleALC.kext` | Native HD audio support |
| `BrightnessKeys.kext` | Dynamic brightness hotkey control |
| `RealtekRTL8111.kext` | Realtek Gigabit Ethernet driver |
| `AirportItlwm.kext` | Intel Wi-Fi driver |
| `IOSkywalkFamily.kext` | Modern wireless networking compatibility framework |
| `IO80211FamilyLegacy.kext` | Legacy wireless support for modern macOS |
| `AMFIPass.kext` | AppleMobileFileIntegrity compatibility shim |
| `IntelBluetoothFirmware.kext` | Firmware uploader for Intel Bluetooth modules |
| `IntelBTPatcher.kext` | Intel Bluetooth subsystem patches |
| `BlueToolFixup.kext` | macOS Bluetooth stack compatibility wrapper |
| `VoodooI2C.kext` | Intel I2C controller driver |
| `VoodooI2CHID.kext` | I2C HID precision trackpad driver |
| `USBToolBox.kext` | USB mapping driver |
| `UTBDefault.kext` | USB default port definition |
| `XHCI-unsupported.kext` | USB 3.0 XHCI controller injector |
| `NVMeFix.kext` | NVMe power management and stability fixes |
| `Sinetek-rtsx.kext` | Realtek PCIe SD card reader driver |
| `RestrictEvents.kext` | System event suppressor and memory UI patcher |
| `ForgedInvariant.kext` | TSC invariant timing fix for Coffee Lake |

</details>

### 🔌 UEFI Drivers
* `OpenRuntime.efi` — Mandatory runtime driver for OpenCore memory management.
* `OpenCanopy.efi` — High-resolution graphical boot menu interface.
* `HfsPlus.efi` — HFS+ file system driver for macOS installers and recovery partitions.
* `ResetNvramEntry.efi` — NVRAM reset helper in the OpenCore boot picker.
* `apfs_aligned.efi` — APFS file system driver.

---

## 🔧 BIOS Configuration

> **BIOS Version:** ASUS 319 (or latest available)

### Recommended BIOS Settings:
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
> The `config.plist` in this repository has its serial numbers sanitized with placeholders (`CHANGEME`). **You must generate your own unique SMBIOS values before booting:**

1. Download and run [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS).
2. Select option `1` to fetch MacSerial, then option `3` to generate SMBIOS for `MacBookPro16,4`.
3. Open `EFI/OC/config.plist` with [ProperTree](https://github.com/corpnewt/ProperTree) or [OCAuxiliaryTools](https://github.com/ic005k/OCAuxiliaryTools).
4. Navigate to `PlatformInfo > Generic` and paste your generated values:
   * `SystemSerialNumber`
   * `MLB` (Board Serial Number)
   * `SystemUUID`
   * `ROM` (use your network MAC address or a generated 12-digit hex string)

### 2. Prepare USB Installer
1. Create a bootable macOS USB installer using standard Apple terminal tools.
2. Mount the EFI partition of the USB drive (e.g. using `MountEFI` or `diskutil`).
3. Copy the entire `EFI` directory from this repository to the root of the EFI partition.
4. Boot from the USB, open BIOS to ensure the settings above are set, and proceed with installation.

### 3. Post-Installation (Wi-Fi Root Patching)
If installing macOS Sonoma (14) or macOS Sequoia (15):
1. Complete the macOS setup assistant.
2. Download and launch [OpenCore Legacy Patcher (OCLP)](https://github.com/dortania/OpenCore-Legacy-Patcher).
3. Select **Post-Install Root Patch** and install the **Networking: Modern Wireless** patches.
4. Reboot the system to enable full Wi-Fi support.

---

## 🤝 Credits

* [Apple](https://www.apple.com) for macOS.
* [Dortania](https://github.com/dortania) for the OpenCore Install Guide.
* [Acidanthera](https://github.com/acidanthera) for OpenCorePkg, Lilu, VirtualSMC, AppleALC, WhateverGreen, and companion kexts.
* [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify) for configuration generation tooling.
* [corpnewt](https://github.com/corpnewt) for GenSMBIOS and ProperTree.
* [alexandred](https://github.com/alexandred) & [VoodooI2C Team](https://github.com/VoodooI2C/VoodooI2C) for trackpad drivers.
* [sinetek](https://github.com/sinetek/Sinetek-rtsx) for Realtek SD card reader driver.
