# ASUS ROG Strix GL503GE Hackintosh

OpenCore EFI for running macOS on the ASUS ROG Strix GL503GE. Built following the [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/), assembled with [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify), and using kexts/drivers from [Acidanthera](https://github.com/acidanthera).

> ⚠️ Hackintoshing violates Apple's macOS EULA. This repo is provided for educational purposes and personal use only. Use at your own risk — I take no responsibility for data loss or hardware damage.

## Hardware

| Component | Spec | Status |
|---|---|---|
| CPU | Intel Core i7-8750H (Coffee Lake-H, 6c/12t) | ✅ Working |
| iGPU | Intel UHD Graphics 630 | ✅ Working (QE/CI, HDMI 2.0 patched) |
| dGPU | NVIDIA GTX 1050 Ti | ❌ Disabled (no macOS driver support) |
| RAM | 16GB DDR4 2600MHz | ✅ Working |
| Storage | Samsung 980 500GB NVMe SSD | ✅ Working (NVMeFix applied) |
| Ethernet | Realtek RTL8111 | ✅ Working |
| WiFi | Intel AX210 | ✅ Working via OCLP WiFi mod |
| Bluetooth | — fill in exact card model — | ✅ Working via IntelBluetoothFirmware/BlueToolFixup |
| Audio | Realtek ALC (layout-id 14) | ✅ Working |
| Trackpad | I2C HID | ✅ Via VoodooI2C (`-vi2c-force-polling`) |
| Card reader | Realtek | ✅ Via Sinetek-rtsx |
| USB | Mapped | ✅ Via USBToolBox |
| HDMI | — | ✅ Working |
| Microphone | — | ✅ Working |
| Camera | — | ✅ Working |
| Battery status | — | ✅ Via SMCBatteryManager |
| Keyboard backlight | — | 🔄 In progress / testing |
| Sleep/Wake | — | 🔄 In progress / testing |

## macOS Version

Built and tested for **macOS Tahoe (26)**.

## OpenCore Version

**1.0.7**

## BIOS Settings

- BIOS version: **ASUS 319**
- Secure Boot: **Disabled**
- Secure Boot (UEFI) re-enablement: 🔄 in progress — not yet working with this EFI

## What's Working / Not Working

**Working:**
- Boot via OpenCore
- iGPU acceleration (UHD 630)
- Ethernet
- WiFi (via OpenCore Legacy Patcher WiFi mod — see Notes below)
- Bluetooth
- Audio
- Trackpad (I2C)
- Card reader
- HDMI
- Microphone
- Camera
- NVMe storage

**Not Working / Disabled:**
- Discrete GPU (GTX 1050 Ti) — disabled via `SSDT-Disable_GPU_PEG0.aml`, no macOS NVIDIA Pascal driver exists post-Mojave

**In Progress / Needs Testing:**
- Sleep/wake
- Keyboard backlight control

## Notes

- **WiFi** (Intel AX210) is handled via an [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) WiFi mod rather than the stock `AirportItlwm` path.
- **USB ports** are mapped using [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify)'s auto-mapping rather than a hand-built USBToolBox port map. Works, but if you hit inconsistent USB 3.0 speeds or a port not showing up, a manual map is the next step to try.
- **Secure Boot** is currently disabled in BIOS; re-enabling it while keeping this EFI bootable is still a work in progress.

## OpenCore Configuration

- **SMBIOS:** `MacBookPro16,4`
- **ACPI:** Standard Dortania laptop SSDT set — `SSDT-EC`, `SSDT-PLUG`, `SSDT-PMC`, `SSDT-USBX`, `SSDT-XOSI`, `SSDT-PNLF`, `SSDT-ALSD`, `SSDT-GPI0`, `SSDT-MCHC`, `SSDT-SBUS`, plus `SSDT-Disable_GPU_PEG0` to disable the dGPU
- **Kexts:** Lilu, VirtualSMC + SMC plugins, AppleALC, WhateverGreen, AirportItlwm, IntelBluetoothFirmware, VoodooI2C + VoodooI2CHID, RealtekRTL8111, Sinetek-rtsx, NVMeFix, USBToolBox, BrightnessKeys, RestrictEvents, AMFIPass, ForgedInvariant
- **Boot-args:** `alcid=14 keepsyms=1 -amfipassbeta -igfxblt -vi2c-force-polling` (remove `keepsyms=1` and any `debug=` flags once stable)

## Installation

1. Create a bootable macOS Tahoe USB installer.
2. Format the target drive as APFS/GUID.
3. Copy the `EFI` folder from this repo to the EFI partition of your USB installer.
4. Update `PlatformInfo > Generic` in `config.plist` with your own `SystemSerialNumber`, `MLB`, `SystemUUID`, and `ROM` — never reuse the values in this repo. Generate your own with [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS).
5. Boot from the USB via OpenCore and install macOS.
6. Copy the `EFI` folder to your internal drive's EFI partition once installed.

## Credits

- [Dortania](https://github.com/dortania) — OpenCore Install Guide
- [Acidanthera](https://github.com/acidanthera) — OpenCore, Lilu, and companion kexts
- [OpenCore Simplify](https://github.com/lzhoang2801/OC-Simplify) — EFI generation tooling
- [corpnewt](https://github.com/corpnewt) — GenSMBIOS and companion tools

## License

MIT — see [LICENSE](LICENSE).
