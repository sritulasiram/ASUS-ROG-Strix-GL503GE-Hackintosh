#!/usr/bin/env python3
"""
ASUS ROG Strix GL503GE - Display Color Profile Manager
Allows switching between Native EDID Wide-Gamut (94% NTSC), sRGB, and Display P3.
"""

import sys
import os
import argparse
import ctypes
from ctypes import c_void_p, c_uint32, c_char_p, c_bool, CFUNCTYPE

cs = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ColorSync.framework/ColorSync")
cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
cg = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")

cg.CGMainDisplayID.restype = c_uint32
cs.CGDisplayCreateUUIDFromDisplayID.argtypes = [c_uint32]
cs.CGDisplayCreateUUIDFromDisplayID.restype = c_void_p

cf.CFStringCreateWithCString.argtypes = [c_void_p, c_char_p, c_uint32]
cf.CFStringCreateWithCString.restype = c_void_p

cf.CFURLCreateWithFileSystemPath.argtypes = [c_void_p, c_void_p, ctypes.c_long, c_bool]
cf.CFURLCreateWithFileSystemPath.restype = c_void_p

cf.CFDictionaryCreate.argtypes = [c_void_p, c_void_p, c_void_p, ctypes.c_long, c_void_p, c_void_p]
cf.CFDictionaryCreate.restype = c_void_p

cs.ColorSyncDeviceSetCustomProfiles.argtypes = [c_void_p, c_void_p, c_void_p]
cs.ColorSyncDeviceSetCustomProfiles.restype = c_bool

cs.ColorSyncDeviceCopyDeviceInfo.argtypes = [c_void_p, c_void_p]
cs.ColorSyncDeviceCopyDeviceInfo.restype = c_void_p

cf.CFShow.argtypes = [c_void_p]

def get_display_uuid():
    main_id = cg.CGMainDisplayID()
    return cs.CGDisplayCreateUUIDFromDisplayID(main_id)

def get_device_class():
    return cf.CFStringCreateWithCString(None, b"mntr", 0x08000100)

def get_current_profile_info():
    uuid = get_display_uuid()
    mntr = get_device_class()
    
    current_info = {}
    CALLBACK = CFUNCTYPE(c_bool, c_void_p, c_void_p)
    
    def cb(info_dict, user_info):
        # We check if it is current
        # Inspect via python
        # Get values from dictionary
        # Let CFShow or parse
        return True

    # Get device info directly
    info = cs.ColorSyncDeviceCopyDeviceInfo(mntr, uuid)
    return info

def set_profile(profile_path=None):
    """
    If profile_path is None, reset to factory (EDID) profile.
    Otherwise, set custom profile to the specified path.
    """
    uuid = get_display_uuid()
    mntr = get_device_class()
    key_1 = cf.CFStringCreateWithCString(None, b"1", 0x08000100)
    
    if profile_path is None or profile_path.lower() == "native":
        kCFNull = c_void_p.in_dll(cf, "kCFNull")
        val = kCFNull
    else:
        if not os.path.exists(profile_path):
            print(f"Error: Profile path does not exist: {profile_path}")
            return False
        path_str = cf.CFStringCreateWithCString(None, profile_path.encode("utf-8"), 0x08000100)
        val = cf.CFURLCreateWithFileSystemPath(None, path_str, 0, False)
    
    keys = (c_void_p * 1)(key_1)
    values = (c_void_p * 1)(val)
    dict_ref = cf.CFDictionaryCreate(None, keys, values, 1, None, None)
    
    success = cs.ColorSyncDeviceSetCustomProfiles(mntr, uuid, dict_ref)
    return success

def show_status():
    uuid = get_display_uuid()
    mntr = get_device_class()
    info = cs.ColorSyncDeviceCopyDeviceInfo(mntr, uuid)
    print("==================================================================")
    print(" ASUS ROG Strix GL503GE - Current Display ColorSync Status")
    print("==================================================================")
    if info:
        cf.CFShow(info)
    else:
        print("Could not retrieve ColorSync device info.")

def main():
    parser = argparse.ArgumentParser(description="Manage display color profile on ASUS ROG Strix GL503GE")
    parser.add_argument("--status", action="store_true", help="Show current ColorSync profile information")
    parser.add_argument("--native", action="store_true", help="Set to Native Factory EDID profile (Chi Mei N156HHE-GA1 94% NTSC)")
    parser.add_argument("--srgb", action="store_true", help="Set to standard sRGB Profile")
    parser.add_argument("--p3", action="store_true", help="Set to Display P3 Profile")
    parser.add_argument("--custom", type=str, help="Set to a custom .icc profile file path")
    
    args = parser.parse_args()
    
    if args.native:
        print("Switching display profile to: Native Factory EDID (Chi Mei N156HHE-GA1)...")
        if set_profile(None):
            print("✅ Successfully restored Native EDID Wide-Gamut profile!")
        else:
            print("❌ Failed to set profile.")
        show_status()
    elif args.srgb:
        srgb_path = "/System/Library/ColorSync/Profiles/sRGB Profile.icc"
        print(f"Switching display profile to: sRGB ({srgb_path})...")
        if set_profile(srgb_path):
            print("✅ Successfully set display profile to sRGB!")
        else:
            print("❌ Failed to set profile.")
        show_status()
    elif args.p3:
        p3_path = "/System/Library/ColorSync/Profiles/DCI(P3) RGB.icc"
        print(f"Switching display profile to: Display P3 ({p3_path})...")
        if set_profile(p3_path):
            print("✅ Successfully set display profile to Display P3!")
        else:
            print("❌ Failed to set profile.")
        show_status()
    elif args.custom:
        print(f"Switching display profile to custom: {args.custom}...")
        if set_profile(args.custom):
            print("✅ Successfully set custom profile!")
        else:
            print("❌ Failed to set profile.")
        show_status()
    else:
        show_status()

if __name__ == "__main__":
    main()
