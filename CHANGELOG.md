# Changelog

All notable changes to this EFI. Format follows [Keep a Changelog](https://keepachangelog.com/); dates are YYYY-MM-DD.

> After updating, re-apply your own SMBIOS values (`PlatformInfo > Generic`) and keep a backup of your working EFI.

## [Unreleased] — 2026-10-14
### Added
- `scripts/check-apple.sh`: read-only Apple feature check (SMBIOS, iCloud/iMessage prerequisites, Bluetooth, Wi-Fi, AWDL, AirPlay Receiver, Continuity Camera, Metal, `--deep` for IDS log scan and hardware decode test).
- `scripts/display.sh`: single display manager (`setup`, `revert`, `look`, `profile`, `status`) replacing `setup_native_macbook_display.sh`; `look` applies dark mode, reduced transparency and sRGB to hide IPS backlight glow. `lib/colorsync.py` remains as its helper.
- `CPUFriendDataProvider.kext` and enabled `CPUFriend.kext`: LFM 800 MHz, EPP `0x40`, PerfBias 5.
- `NoTouchID.kext` v1.0.3 (removes the Touch ID lookup delay on the `MacBookPro16,4` SMBIOS).
- CI: the release workflow now validates `config.plist` with `ocvalidate` (OpenCore 1.0.8).

### Removed
- The non-functional MacBook Pro acoustic preset (`audio/MacBook_Pro_Acoustic_Profile.json` was empty) and the unverified eqMac instructions; `check-audio.sh` is now a read-only audio health check.
- `SSDT-ALSD.aml` and its `_STA` rename patch (no light-sensor kext is bundled), the disabled `AirPortBrcmNIC` plugin and its kext entry, the disabled "macOS to hacOS" booter patch, and the AMD-only `agdpmod` property on the iGPU.

### Changed
- Docs: Wi-Fi row now names the actual driver (`AirportItlwm`/itlwm, up to 802.11ac in macOS) and the AX210 PCI ID; iGPU row lists hardware decode support; note on intermittent Bluetooth `NULL` address.
- Script overhaul: shared `scripts/lib/common.sh`; `setup-sleep.sh` gains `--revert`/`--status`/`--dry-run`, saves your previous `pmset` values and warns about the hibernation trade-off; `deploy-efi.sh` gains `--dry-run`, `ocvalidate`, automatic restore on failure, backup pruning and no longer guesses the disk (it lists internal ESPs when ambiguous); `reset-bluetooth.sh` backs up preferences, verifies the controller address and has a read-only `--check`; `setup-fnkeys.sh` is table-driven, merges with other hidutil mappings and `--reset` removes only F1-F12; `display.sh status` detects a stale installed override and shows profile/transparency, override plist moved to `lib/display-override.plist`; `monitor-thermals.sh` caches its compiled reader and gains `--watch`; `check-audio.sh` gains `--quiet` and reports the layout; `lib/colorsync.py` releases CoreFoundation objects. New CI workflow `lint-scripts.yml`.
- Scripts renamed to a consistent `verb-noun` scheme: `deploy-efi.sh`, `setup-sleep.sh`, `reset-bluetooth.sh`, `monitor-thermals.sh`, `setup-fnkeys.sh`, `check-audio.sh`; `set_color_profile.py` moved to `scripts/lib/colorsync.py`.
- **OpenCore 1.0.8**: updated `BOOTx64.efi`, `OpenCore.efi` and the UEFI drivers; added `HideVerbose` keys to the `config.plist` driver entries.
- Kexts refreshed: `AppleALC` 1.9.8, `VirtualSMC` / `SMCProcessor` / `SMCSuperIO` / `SMCBatteryManager` 1.3.8, `WhateverGreen` 1.7.1.
- `SSDT-FAN`: the ASUS `WMNB` call now uses the correct instance / method / buffer layout.
- Scripts hardened: `deploy-efi.sh` (requires `config.personal.plist`, refuses placeholder SMBIOS), safer Bluetooth reset (confirmation prompt, `--yes` to skip), fixed Display P3 profile in `lib/colorsync.py`, more accurate output in the thermal, sound, display and function-key scripts.
- Script audit fixes: wrong 1x modes (1344x756, 1280x720) in the display override; `deploy-efi.sh` now validates SMBIOS before touching the ESP and uses FAT-safe `rsync` flags; `lib/colorsync.py` targets the built-in panel and returns proper exit codes; the display setup no longer resets the colour profile; sleep, thermal and function-key scripts no longer abort or misapply on edge cases.
- Docs: the panel is described as ~100% sRGB (not a wide-gamut P3 display); `--srgb` is the recommended profile.
- Docs: fixed stale README and TROUBLESHOOTING content, then a follow-up audit adding a Security & Quirks section, a corrected Sidecar row, a full troubleshooting index, fan/thermal and recovery guides, and this changelog.

## 2026-10-10 — Fan control
### Added
- `SSDT-FAN.aml` (+ `.dsl` source): ACPI fan boost on `Fn + F5` (Normal / Overboost / Silent).
- `monitor-thermals.sh` thermal telemetry script.

## 2026-10-01 — Polish
### Changed
- Audio tuning, native MacBook Pro display profile and HiDPI scaling, Continuity matrix, function key mapping.

## 2026-09-23 — Power & battery
### Added
- `CPUFriend.kext`, `ECEnabler.kext` (1% battery granularity).
### Changed
- `RealtekRTL8111.kext` updated to v3.0.4.
### Removed
- `SMCLightSensor.kext`.

## 2026-09-17 / 09-18 — Graphics, audio, trackpad fixes
### Fixed
- Audio `layout-id` now injected as data (macOS 26 Tahoe audio documented).
- Intermittent boot black screen: `complete-modeset` / `force-online`, removed `igfxfw`.
- Backlight delay at login: `-igfxblr`.
- Trackpad 2–3 minute freezes: removed `-vi2c-force-polling`; now native GPIO interrupt mode.

## 2026-09-13 / 09-14 — Hardware refinements
### Added
- Function keys script, sleep/wake fix, Bluetooth updates, display color profile manager.
### Changed
- UHD 630 framebuffer tuning, 14-port USB-C mapping, cleaned Broadcom spoof, unused NIC kext disabled.

## 2026-09-06 — Boot experience
### Added
- `AudioDxe.efi` boot chime, Blackosx BsxM1 OpenCanopy theme, `config.personal.plist` gitignored, USB map and Continuity docs.

## 2026-08-29 / 08-30 — Initial release (v1.0.0)
### Added
- OpenCore EFI for macOS Tahoe, README, TROUBLESHOOTING, issue templates, release workflow.
- Intel Wi-Fi documented via OCLP-Mod root patching.
