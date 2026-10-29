#!/usr/bin/env python3
"""
ASUS ROG Strix GL503GE - Display Color Profile Manager
Switches between the panel's native EDID profile, sRGB, Display P3 or a custom ICC.
The panel is ~100% sRGB, so sRGB is the closest accurate generic profile.
"""

import sys
import os
import argparse
import ctypes
from ctypes import c_void_p, c_uint32, c_char_p, c_bool, c_int32

cs = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ColorSync.framework/ColorSync")
cf = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
cg = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")

cg.CGMainDisplayID.restype = c_uint32
cg.CGDisplayIsBuiltin.argtypes = [c_uint32]
cg.CGDisplayIsBuiltin.restype = c_int32
cg.CGGetOnlineDisplayList.argtypes = [c_uint32, ctypes.POINTER(c_uint32), ctypes.POINTER(c_uint32)]
cg.CGGetOnlineDisplayList.restype = c_int32
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
cf.CFRelease.argtypes = [c_void_p]

# Standard CFType callbacks so the dictionary retains/releases its keys and values properly
KEY_CALLBACKS = ctypes.addressof(ctypes.c_char.in_dll(cf, "kCFTypeDictionaryKeyCallBacks"))
VALUE_CALLBACKS = ctypes.addressof(ctypes.c_char.in_dll(cf, "kCFTypeDictionaryValueCallBacks"))

def release(*objs):
    for obj in objs:
        if obj:
            cf.CFRelease(obj)

def get_target_display_id():
    """Built-in panel if present (even when an external monitor is main), else main display."""
    ids = (c_uint32 * 16)()
    count = c_uint32(0)
    if cg.CGGetOnlineDisplayList(16, ids, ctypes.byref(count)) == 0:
        for i in range(count.value):
            if cg.CGDisplayIsBuiltin(ids[i]):
                return ids[i]
    return cg.CGMainDisplayID()

def get_display_uuid():
    return cs.CGDisplayCreateUUIDFromDisplayID(get_target_display_id())

def get_device_class():
    return cf.CFStringCreateWithCString(None, b"mntr", 0x08000100)

def set_profile(profile_path=None):
    """
    If profile_path is None, reset to factory (EDID) profile.
    Otherwise, set custom profile to the specified path.
    """
    if profile_path is not None and not os.path.exists(profile_path):
        print(f"Error: Profile path does not exist: {profile_path}")
        return False

    uuid = get_display_uuid()
    mntr = get_device_class()
    key_1 = cf.CFStringCreateWithCString(None, b"1", 0x08000100)
    created = [uuid, mntr, key_1]

    if profile_path is None:
        val = c_void_p.in_dll(cf, "kCFNull")  # shared constant, never released
    else:
        path_str = cf.CFStringCreateWithCString(None, profile_path.encode("utf-8"), 0x08000100)
        val = cf.CFURLCreateWithFileSystemPath(None, path_str, 0, False)
        created += [path_str, val]

    keys = (c_void_p * 1)(key_1)
    values = (c_void_p * 1)(val)
    dict_ref = cf.CFDictionaryCreate(None, keys, values, 1, KEY_CALLBACKS, VALUE_CALLBACKS)
    created.append(dict_ref)

    try:
        return bool(cs.ColorSyncDeviceSetCustomProfiles(mntr, uuid, dict_ref))
    finally:
        release(*created)

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
    release(info, mntr, uuid)

def apply(label, path):
    print(f"Switching display profile to: {label}...")
    ok = set_profile(path)
    print(f"✅ Display profile set to {label}." if ok else "❌ Failed to set profile.")
    show_status()
    return 0 if ok else 1

def main():
    parser = argparse.ArgumentParser(description="Manage display color profile on ASUS ROG Strix GL503GE")
    parser.add_argument("--status", action="store_true", help="Show current ColorSync profile information")
    parser.add_argument("--native", action="store_true", help="Reset to the panel's factory EDID profile (Chi Mei N156HHE-GA1)")
    parser.add_argument("--srgb", action="store_true", help="Set to standard sRGB profile (closest match for this panel)")
    parser.add_argument("--p3", action="store_true", help="Set to Display P3 Profile (panel is ~sRGB, so colours will look inaccurate; prefer --srgb)")
    parser.add_argument("--custom", type=str, help="Set to a custom .icc profile file path")

    args = parser.parse_args()

    if args.native:
        return apply("Native Factory EDID", None)
    if args.srgb:
        return apply("sRGB", "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
    if args.p3:
        print("Note: this panel is ~100% sRGB, so Display P3 colours will look inaccurate. --srgb is closer.")
        return apply("Display P3", "/System/Library/ColorSync/Profiles/Display P3.icc")
    if args.custom:
        return apply(f"custom ({args.custom})", args.custom)
    show_status()
    return 0

if __name__ == "__main__":
    sys.exit(main())
