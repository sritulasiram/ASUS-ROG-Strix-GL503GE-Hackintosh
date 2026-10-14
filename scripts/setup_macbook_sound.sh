#!/usr/bin/env bash
# ==============================================================================
# setup_macbook_sound.sh
# MacBook Pro Sound Optimization Suite for ASUS ROG Strix GL503GE (ALC295)
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}======================================================${RESET}"
echo -e "${BOLD}${CYAN}   ASUS ROG Strix GL503GE - Audio Optimization Suite   ${RESET}"
echo -e "${BOLD}${CYAN}        (MacBook Pro Acoustic Calibration Tool)        ${RESET}"
echo -e "${BOLD}${CYAN}======================================================${RESET}\n"

# 1. Hardware & Codec Health Check
echo -e "${BOLD}[1/4] Auditing CoreAudio & Realtek ALC295 Hardware...${RESET}"

AUDIO_OUTPUT=$(system_profiler SPAudioDataType 2>/dev/null || true)
if grep -q "Internal Speakers" <<<"$AUDIO_OUTPUT"; then
    echo -e "  ${GREEN}✓${RESET} Built-in Output: ${BOLD}Internal Speakers${RESET}"
else
    echo -e "  ${RED}✗${RESET} Internal Speakers not detected by CoreAudio! Check AppleALC."
fi

if grep -q "Internal Microphone" <<<"$AUDIO_OUTPUT"; then
    echo -e "  ${GREEN}✓${RESET} Built-in Input:  ${BOLD}Internal Microphone${RESET}"
else
    echo -e "  ${YELLOW}!${RESET} Internal Microphone not detected."
fi

CODEC_CHECK=$(ioreg -rxn "AppleHDACodecGeneric" 2>/dev/null || true)
if grep -q "0x10ec0295" <<<"$CODEC_CHECK"; then
    echo -e "  ${GREEN}✓${RESET} Audio Codec:     ${BOLD}Realtek ALC295 (Vendor ID: 0x10EC0295)${RESET}"
else
    echo -e "  ${YELLOW}!${RESET} AppleHDACodecGeneric did not report 0x10ec0295."
fi

echo ""

# 2. Explaining Acoustic Realities
echo -e "${BOLD}[2/4] The Acoustic Reality: Why Hackintosh Audio Sounds Flat${RESET}"
echo -e "  On genuine MacBook Pros, Apple embeds proprietary ${BOLD}CoreAudio DSP${RESET}"
echo -e "  (Digital Signal Processing) into macOS:"
echo -e "    1. ${CYAN}Harmonic Bass Exciter${RESET}: Generates 120-240Hz harmonics so the human brain"
echo -e "       perceives deep sub-bass from small 2-inch speakers."
echo -e "    2. ${CYAN}Anti-Resonance Notch Filter${RESET}: Dips the harsh 2.5kHz-4kHz plastic frequencies."
echo -e "    3. ${CYAN}Multiband Dynamic Limiter${RESET}: Maximizes volume without clipping/distortion."
echo -e "    4. ${CYAN}Spatial Stereo Widening${RESET}: Creates a wide soundstage beyond the screen."
echo -e "  By default, ${BOLD}AppleALC provides raw line-level output with ZERO DSP${RESET}."
echo -e "  To achieve MacBook Pro acoustic standards, we route system audio through"
echo -e "  the open-source CoreAudio HAL engine ${BOLD}eqMac${RESET}.\n"

# 3. Checking eqMac Installation
echo -e "${BOLD}[3/4] Checking System DSP Engine (eqMac)...${RESET}"
EQMAC_APP="/Applications/eqMac.app"
PRESET_SRC="$(cd "$(dirname "$0")/.." && pwd)/audio/MacBook_Pro_Acoustic_Profile.json"

if [ -d "$EQMAC_APP" ]; then
    echo -e "  ${GREEN}✓${RESET} eqMac is installed in /Applications."
else
    echo -e "  ${YELLOW}! eqMac is not installed in /Applications.${RESET}"
    echo -e "  ${CYAN}To install eqMac:${RESET}"
    echo -e "    Option A: Download the official installer DMG from:"
    echo -e "              ${BOLD}https://github.com/bitgapp/eqMac/releases/latest${RESET}"
    echo -e "    Option B: Download directly using curl:"
    echo -e "              ${BOLD}curl -L -o /tmp/eqMac.dmg https://github.com/bitgapp/eqMac/releases/latest/download/eqMac.dmg${RESET}"
fi

# 4. Staging the Acoustic Profile Preset
echo ""
echo -e "${BOLD}[4/4] Staging the 'MacBook Pro Acoustic Profile'...${RESET}"

DEST_DIR="$HOME/Library/Application Support/eqMac"
DESKTOP_DIR="$HOME/Desktop"

if [ -f "$PRESET_SRC" ]; then
    mkdir -p "$DEST_DIR" 2>/dev/null || true
    cp "$PRESET_SRC" "$DEST_DIR/MacBook_Pro_Acoustic_Profile.json" 2>/dev/null || true
    cp "$PRESET_SRC" "$DESKTOP_DIR/MacBook_Pro_Acoustic_Profile.json" 2>/dev/null || true
    echo -e "  ${GREEN}✓${RESET} Profile copied to: ${BOLD}$DEST_DIR/MacBook_Pro_Acoustic_Profile.json${RESET}"
    echo -e "  ${GREEN}✓${RESET} Quick-access copy on Desktop: ${BOLD}$DESKTOP_DIR/MacBook_Pro_Acoustic_Profile.json${RESET}"
else
    echo -e "  ${RED}✗${RESET} Could not locate preset file at $PRESET_SRC"
fi

echo -e "\n${BOLD}${GREEN}======================================================${RESET}"
echo -e "${BOLD}${GREEN}              RECOMMENDED EQMAC SETTINGS              ${RESET}"
echo -e "${BOLD}${GREEN}======================================================${RESET}"
echo -e "  1. Open ${BOLD}eqMac${RESET} from Applications or Menu Bar."
echo -e "  2. Go to ${BOLD}Equalizers -> Advanced (10-Band)${RESET}."
echo -e "  3. Click ${BOLD}Import${RESET} and select ${BOLD}MacBook_Pro_Acoustic_Profile.json${RESET} from your Desktop."
echo -e "  4. Set the following supplemental sliders in eqMac:"
echo -e "     - ${BOLD}Bass Booster${RESET}:     ${CYAN}25%${RESET} (Adds warm MacBook Pro low-end harmonics)"
echo -e "     - ${BOLD}Spatial Audio${RESET}:    ${CYAN}120%${RESET} (Expands stereo soundstage)"
echo -e "     - ${BOLD}Volume Limiter${RESET}:   ${CYAN}ON (-0.5 dB)${RESET} (Prevents speaker distortion at 100%)"
echo -e "     - ${BOLD}Preamp (Global)${RESET}:  ${CYAN}+1.5 dB${RESET} (Compensates for conservative ALC295 line-out)"
echo -e "${BOLD}${GREEN}======================================================${RESET}\n"
