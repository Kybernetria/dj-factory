#!/usr/bin/env bash
# main.sh

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT_DIR/lib"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/dj-factory-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

if command -v tee >/dev/null 2>&1; then
    exec > >(tee -a "$LOG_FILE") 2>&1
else
    exec >>"$LOG_FILE" 2>&1
fi

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

die() {
    echo "$1" >&2
    exit 1
}

recursive_child_pids() {
    local parent_pid="$1"
    local child_pid

    for child_pid in $(pgrep -P "$parent_pid" 2>/dev/null || true); do
        printf '%s\n' "$child_pid"
        recursive_child_pids "$child_pid"
    done
}

terminate_descendants() {
    local pids=()
    local pid

    if [[ -n "${ACTIVE_CHILD_PID:-}" ]] && kill -0 "$ACTIVE_CHILD_PID" 2>/dev/null; then
        kill -TERM "-$ACTIVE_CHILD_PID" 2>/dev/null || true
        kill -TERM "$ACTIVE_CHILD_PID" 2>/dev/null || true
    fi

    while IFS= read -r pid; do
        [[ -n "$pid" ]] && pids+=("$pid")
    done < <(recursive_child_pids "$$" | awk '!seen[$0]++')

    if [[ ${#pids[@]} -gt 0 ]]; then
        kill "${pids[@]}" 2>/dev/null || true
        sleep 1
        if [[ -n "${ACTIVE_CHILD_PID:-}" ]] && kill -0 "$ACTIVE_CHILD_PID" 2>/dev/null; then
            kill -KILL "-$ACTIVE_CHILD_PID" 2>/dev/null || true
            kill -KILL "$ACTIVE_CHILD_PID" 2>/dev/null || true
        fi
        kill -9 "${pids[@]}" 2>/dev/null || true
    fi
}

acquire_run_lock() {
    LOCK_FILE="$STATE_DIR/run.lock"
    mkdir -p "$STATE_DIR"

    if [[ -f "$LOCK_FILE" ]]; then
        local existing_pid
        local existing_cmd=""
        existing_pid="$(<"$LOCK_FILE")"

        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            existing_cmd="$(ps -p "$existing_pid" -o args= 2>/dev/null || true)"
            if [[ "$existing_cmd" == *"$ROOT_DIR/main.sh"* || "$existing_cmd" == *"distrobox enter $BOX_NAME"* ]]; then
                die "dj-factory is already running (PID $existing_pid). Stop it with: kill $existing_pid"
            fi
            echo "Removing stale dj-factory lock for reused PID $existing_pid ($existing_cmd)."
        fi

        rm -f "$LOCK_FILE"
    fi

    printf '%s\n' "$$" > "$LOCK_FILE"
}

if [[ "$(uname -s)" != "Linux" ]]; then
    die "DJ_Factory currently supports Linux only."
fi

for required_file in "$LIB_DIR/config.sh" "$LIB_DIR/bootstrap.sh" "$LIB_DIR/processing.sh"; do
    [[ -r "$required_file" ]] || die "Missing required file: $required_file"
done

source "$LIB_DIR/config.sh"

ensure_distrobox() {
    if command_exists distrobox; then
        return 0
    fi

    echo -e "\033[0;33m⚠️  Distrobox not found. Installing locally...\033[0m"
    command_exists curl || die "Distrobox is required, and curl was not found for local installation."
    curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix "$HOME/.local"
    export PATH="$HOME/.local/bin:$PATH"
    command_exists distrobox || die "Distrobox installation failed."
}

ensure_container_runtime() {
    if command_exists podman || command_exists docker; then
        return 0
    fi
    die "Distrobox requires podman or docker on the host."
}

enter_distrobox_if_needed() {
    if [[ "${USE_DISTROBOX:-1}" != "1" ]]; then
        return 0
    fi

    if [[ -f /run/.containerenv || "${CONTAINER_ID:-}" == "$BOX_NAME" ]]; then
        return 0
    fi

    echo -e "\033[0;36m🔌 HOST DETECTED: routing through Distrobox '$BOX_NAME'...\033[0m"

    ensure_distrobox
    ensure_container_runtime

    create_distrobox_if_missing() {
        local image
        local tried=0
        local stdout_file
        local stderr_file
        stdout_file="$(mktemp)"
        stderr_file="$(mktemp)"

        for image in $BOX_IMAGE_FALLBACKS; do
            if ((tried > 0)); then
                echo -e "\033[0;33m↪ Trying fallback image: $image\033[0m"
            fi
            tried=$((tried + 1))
            if distrobox create -n "$BOX_NAME" -i "$image" --yes \
                >"$stdout_file" 2>"$stderr_file"; then
                BOX_IMAGE="$image"
                cat "$stdout_file"
                echo -e "\033[0;32m✓ Created '$BOX_NAME' from ${BOX_IMAGE}\033[0m"
                rm -f "$stdout_file" "$stderr_file"
                return 0
            fi
            echo "distrobox create failed for $image"
            cat "$stderr_file"
        done

        rm -f "$stdout_file" "$stderr_file"
        return 1
    }

    if ! distrobox list 2>/dev/null | grep -Eq "(^|[[:space:]])${BOX_NAME}([[:space:]]|$)"; then
        echo -e "\033[0;33m⚠️  Container '$BOX_NAME' missing. Trying supported Ubuntu images...\033[0m"
        if ! create_distrobox_if_missing; then
            if ! distrobox list 2>/dev/null | grep -Eq "(^|[[:space:]])${BOX_NAME}([[:space:]]|$)"; then
                die "Failed to create Distrobox container '$BOX_NAME'. Set BOX_IMAGE (or BOX_IMAGE_FALLBACKS) to an image accepted by your host's container policy."
            fi
        fi
    fi

    echo -e "\033[0;32m🚀 Entering $BOX_NAME...\033[0m"
    exec distrobox enter "$BOX_NAME" -- "$ROOT_DIR/main.sh"
}

enter_distrobox_if_needed

source "$LIB_DIR/bootstrap.sh"
source "$LIB_DIR/processing.sh"

cleanup() {
    local exit_code=$?

    terminate_descendants

    if [[ -n "${RUN_TMP_DIR:-}" && -d "${RUN_TMP_DIR:-}" ]]; then
        rm -rf "$RUN_TMP_DIR"
    fi

    if [[ -n "${LOCK_FILE:-}" && -f "${LOCK_FILE:-}" ]]; then
        local lock_pid
        lock_pid="$(<"$LOCK_FILE" 2>/dev/null || true)"
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$LOCK_FILE"
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo -e "\n${GREEN}✨ Session finished.${NC}"
    else
        echo -e "\n${RED}❌ dj-factory exited with status ${exit_code}.${NC}"
        echo -e "${YELLOW}Log:${NC} $LOG_FILE"
        if [[ -t 0 ]]; then
            read -r -p "Press Enter to close..." _
        fi
    fi
}

handle_signal() {
    exit 130
}

trap cleanup EXIT
trap handle_signal INT TERM

acquire_run_lock

echo -e "${CYAN}🧱 DJ_Factory Linux bootstrap${NC}"
echo -e "${YELLOW}Repo:${NC} $ROOT_DIR"
echo -e "${YELLOW}Log :${NC} $LOG_FILE"
if [[ "${USE_DISTROBOX:-1}" == "1" ]]; then
    echo -e "${YELLOW}Mode:${NC} distrobox"
else
    echo -e "${YELLOW}Mode:${NC} local"
fi

setup_environment
create_desktop_shortcut
show_menu
run_pipeline

read -r -p "Press Enter to close..."
