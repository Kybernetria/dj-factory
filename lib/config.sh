#!/usr/bin/env bash
# lib/config.sh

# =================================================
# 1. CONTAINER SETTINGS
# =================================================
BOX_NAME="${BOX_NAME:-Ustembox}"
# Long-term support preference and policy-friendly Ubuntu Toolbox images.
UBUNTU_LTS_VERSION="${UBUNTU_LTS_VERSION:-24.04}"
BOX_IMAGE="${BOX_IMAGE:-quay.io/toolbx-images/ubuntu-toolbox:${UBUNTU_LTS_VERSION}}"
# Fallback order:
# 1) LTS Toolbox images under quay.io/toolbx-images (usually preferred on secureblue policy)
# 2) broad policy-compatible Ubuntu dev image kept only as a compatibility fallback
BOX_IMAGE_FALLBACKS="${BOX_IMAGE_FALLBACKS:-$BOX_IMAGE quay.io/toolbx-images/ubuntu-toolbox:22.04 quay.io/toolbx-images/ubuntu-toolbox:latest docker.io/rocm/dev-ubuntu-24.04}"
USE_DISTROBOX="${USE_DISTROBOX:-1}"

# =================================================
# 2. SYSTEM DETECTION
# =================================================
if command -v xdg-user-dir >/dev/null 2>&1; then
    SYSTEM_MUSIC_DIR="$(xdg-user-dir MUSIC 2>/dev/null || true)"
fi

if [[ -z "${SYSTEM_MUSIC_DIR:-}" || "$SYSTEM_MUSIC_DIR" == "$HOME" ]]; then
    SYSTEM_MUSIC_DIR="$HOME/Music"
fi

# =================================================
# 3. DEFAULT USER PATHS (SUGGESTIONS)
# =================================================
DEFAULT_INPUT_DIR="$SYSTEM_MUSIC_DIR/Input_Folder"
DEFAULT_TIDAL_DIR="$DEFAULT_INPUT_DIR"
DEFAULT_OUTPUT_DIR="$SYSTEM_MUSIC_DIR/Finalized_Pipeline"

mkdir -p "$SYSTEM_MUSIC_DIR" "$DEFAULT_INPUT_DIR" "$DEFAULT_TIDAL_DIR" "$DEFAULT_OUTPUT_DIR"

# =================================================
# 4. INTERNAL APPLICATION PATHS
# =================================================
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$LIB_DIR/.." && pwd)"

SCRIPT_DIR="$ROOT_DIR/scripts"
BIN_DIR="$ROOT_DIR/bin"
CACHE_DIR="$ROOT_DIR/.cache"
STATE_DIR="$ROOT_DIR/.state"
LOG_DIR="$ROOT_DIR/logs"
TMP_DIR="$ROOT_DIR/tmp"
VENV_STEMGEN="$ROOT_DIR/stemgen-venv"
VENV_TIDAL="$ROOT_DIR/tidal-venv"

TIDAL_URL_FILE="$SCRIPT_DIR/tidal_playlist.txt"
ONETAGGER_CONF="$SCRIPT_DIR/onetagger.json"
SETUP_MARKER="$STATE_DIR/setup-complete"

mkdir -p "$BIN_DIR" "$CACHE_DIR" "$STATE_DIR" "$LOG_DIR" "$TMP_DIR" "$SCRIPT_DIR"

# =================================================
# 5. AUDIO & PROCESSING RULES
# =================================================
TARGET_I="-14"
STEM_MODEL="htdemucs_ft"
STEM_DEVICE="${STEM_DEVICE:-cpu}"

CORES="$(nproc 2>/dev/null || echo 1)"
THREADS=$((CORES - 1))
if [[ "$THREADS" -lt 1 ]]; then
    THREADS=1
fi

# =================================================
# 6. VISUAL STYLES
# =================================================
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# =================================================
# 7. EXPORTS
# =================================================
export BOX_NAME BOX_IMAGE BOX_IMAGE_FALLBACKS UBUNTU_LTS_VERSION USE_DISTROBOX
export ROOT_DIR LIB_DIR SCRIPT_DIR BIN_DIR CACHE_DIR STATE_DIR LOG_DIR TMP_DIR
export VENV_STEMGEN VENV_TIDAL TIDAL_URL_FILE ONETAGGER_CONF SETUP_MARKER
export DEFAULT_INPUT_DIR DEFAULT_TIDAL_DIR DEFAULT_OUTPUT_DIR SYSTEM_MUSIC_DIR
export TARGET_I STEM_MODEL STEM_DEVICE THREADS
export GREEN CYAN RED YELLOW NC
