/*
 * ASUS ROG Strix GL503GE - Hardware Fan Boost Mode Hotpatch (Fn + F5)
 * Cycles hardware thermal policies: Normal (0x00) -> Overboost (0x01) -> Silent (0x02)
 *
 * Dispatches directly to ASUS WMI Device Set:
 *   - Handler:   \_SB.ATKD.WMNB
 *   - Method ID: 0x53564544 ("DEVS" - Device Set)
 *   - Device ID: 0x00110018 (ASUS_WMI_DEVID_FAN_BOOST_MODE)
 *   - Argument:  FMOD (0x00 = Balanced, 0x01 = Overboost, 0x02 = Silent)
 *
 * 100% Native on macOS Tahoe (Darwin 25/26) — Zero kexts, pure ACPI.
 */
DefinitionBlock ("", "SSDT", 2, "DRTNIA", "ASUS_FAN", 0x00001000)
{
    External (\_SB.PCI0.LPCB.EC0, DeviceObj)
    External (\_SB.PCI0.LPCB.EC0.XQAE, MethodObj)
    External (\_SB.ATKD.WMNB, MethodObj)

    Scope (\_SB.PCI0.LPCB.EC0)
    {
        Name (FMOD, 0x00) // 0x00 = Normal, 0x01 = Overboost (100%), 0x02 = Silent

        Method (_QAE, 0, NotSerialized)
        {
            If (_OSI ("Darwin"))
            {
                // Cycle: Normal (0) -> Overboost (1) -> Silent (2) -> Normal (0)
                If (LEqual (FMOD, 0x00))
                {
                    Store (0x01, FMOD)
                }
                Else
                {
                    If (LEqual (FMOD, 0x01))
                    {
                        Store (0x02, FMOD)
                    }
                    Else
                    {
                        Store (0x00, FMOD)
                    }
                }

                // Dispatch to ASUS WMI DEVS (Device Set) for Fan Boost Mode
                If (CondRefOf (\_SB.ATKD.WMNB))
                {
                    \_SB.ATKD.WMNB (0x53564544, 0x00110018, FMOD)
                }
            }
            Else
            {
                \_SB.PCI0.LPCB.EC0.XQAE ()
            }
        }
    }
}
