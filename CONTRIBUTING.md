# Contributing

Thanks for helping improve this EFI. It targets one machine (ASUS ROG Strix GL503GE), so reports are most useful when they say exactly what hardware and macOS version you tested.

## Reporting
- **Bug:** use the *Bug Report* template. Include macOS version, OpenCore version (1.0.8), BIOS version and the output of the relevant `scripts/check-*.sh`.
- **Different hardware** (Wi-Fi card, panel, BIOS): use the *Hardware Compatibility* template.
- **Never post** your serial, MLB, SystemUUID or ROM.

## Before you open a PR
1. Keep `EFI/OC/config.plist` sanitised: `SystemSerialNumber`/`MLB` stay `CHANGEME`. Real values belong in the gitignored `EFI/OC/config.personal.plist`.
2. Validate the config with `ocvalidate` from the matching [OpenCorePkg release](https://github.com/acidanthera/OpenCorePkg/releases) (1.0.8): `ocvalidate EFI/OC/config.plist`. CI runs the same check.
3. Scripts: run `bash -n` and `shellcheck` (CI lints them), keep the shared helpers in `scripts/lib/common.sh`, and support `--dry-run` for anything that writes.
4. Boot-test on the laptop and say which macOS version you used.

## Documentation rules
- Update the README, TROUBLESHOOTING and CHANGELOG together when behaviour changes; they have drifted before (kext count, boot-args, audio delay).
- State measured results only. If something is untested, say so.
- Wi-Fi works only on macOS Tahoe with the bundled `AirportItlwm` (Darwin 25); keep that consistent everywhere.
- Do not add Apple binaries beyond those already disclosed in the README legal notice.
