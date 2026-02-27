#!/usr/bin/env bash
# Interactive installer for infra services.
#
# Usage:
#   ./setup.sh                          # fully interactive
#   ./setup.sh --infra-dir PATH         # use pre-filled .env files from local infra checkout
#   ./setup.sh --dry-run                # show what would be deployed, no changes
#   INFRA_DIR=/path/to/infra ./setup.sh # same as --infra-dir via env var

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bin/lib/common.sh"

# ============================================================================
# Args
# ============================================================================
INFRA_DIR="${INFRA_DIR:-}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --infra-dir) INFRA_DIR="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
done

# ============================================================================
# Banner
# ============================================================================
echo ""
echo "  ┌─────────────────────────────────────┐"
echo "  │           automa  setup              │"
echo "  │   interactive infrastructure deploy  │"
echo "  └─────────────────────────────────────┘"
echo ""

# ============================================================================
# Prerequisites (skipped in dry-run)
# ============================================================================
check_prerequisites() {
    log_info "Checking prerequisites..."
    local missing=0
    for cmd in curl wget systemctl envsubst; do
        if ! command -v "$cmd" &>/dev/null; then
            log_warn "  missing: $cmd"
            missing=1
        fi
    done
    if [[ "$missing" -eq 1 ]]; then
        log_error "Install missing tools before continuing."
        exit 1
    fi
    log_info "Prerequisites OK."
}

[[ "$DRY_RUN" -eq 0 ]] && check_prerequisites

# ============================================================================
# Infra dir resolution
# ============================================================================
if [[ -n "$INFRA_DIR" ]]; then
    if [[ ! -d "$INFRA_DIR" ]]; then
        log_error "INFRA_DIR does not exist: $INFRA_DIR"
        exit 1
    fi
    log_info "Using infra dir: $INFRA_DIR"
else
    echo ""
    echo "  No --infra-dir specified."
    echo "  Point to a local infra checkout (with pre-filled .env files) for auto-config,"
    echo "  or leave blank to enter all values interactively."
    echo ""
    read -rp "  Path to local infra repo [blank = interactive mode]: " infra_input
    if [[ -n "$infra_input" ]]; then
        infra_input="${infra_input/#\~/$HOME}"
        if [[ -d "$infra_input" ]]; then
            INFRA_DIR="$infra_input"
            log_info "Using infra dir: $INFRA_DIR"
        else
            log_warn "Directory not found, continuing in interactive mode."
        fi
    fi
fi

# ============================================================================
# Module discovery
# Parallel arrays indexed by position: MODULES[i], ROLES[i], DESCS[i]
# MENU_MODS[menu_number] = module_path  (1-based; index 0 = "")
# ============================================================================
MODULES=()
ROLES=()
DESCS=()
MENU_MODS=("")  # index 0 unused — menu numbers start at 1

discover_modules() {
    while IFS= read -r deploy; do
        local mod env_ex role desc r d
        mod="$(dirname "$deploy" | sed "s|^$SCRIPT_DIR/services/||")"
        env_ex="$SCRIPT_DIR/services/$mod/.env.example"

        role="any"
        desc="$mod"

        if [[ -f "$env_ex" ]]; then
            # grep returns 1 if no match — use || true to avoid pipefail exit
            r="$(grep '^# role:' "$env_ex" | head -1 | sed 's/^# role: *//' || true)"
            d="$(grep '^# description:' "$env_ex" | head -1 | sed 's/^# description: *//' || true)"
            [[ -n "$r" ]] && role="$r"
            [[ -n "$d" ]] && desc="$d"
        fi

        MODULES+=("$mod")
        ROLES+=("$role")
        DESCS+=("$desc")
    done < <(find "$SCRIPT_DIR/services" -name "deploy.sh" | sort)
}

discover_modules

# ============================================================================
# Interactive menu (grouped by role)
# Populates MENU_MODS as a side effect.
# ============================================================================
print_menu() {
    local printed_any=0

    for role_group in "vps" "homeserver" "any"; do
        local label header_printed=0
        case "$role_group" in
            vps)        label="VPS services" ;;
            homeserver) label="Home server services" ;;
            any)        label="Any machine" ;;
        esac

        for i in "${!MODULES[@]}"; do
            [[ "${ROLES[$i]}" != "$role_group" ]] && continue

            if [[ "$header_printed" -eq 0 ]]; then
                echo "  $label:"
                header_printed=1
                printed_any=1
            fi

            local menu_idx=${#MENU_MODS[@]}
            MENU_MODS+=("${MODULES[$i]}")
            printf "    [%2d] %-30s %s\n" "$menu_idx" "${MODULES[$i]}" "${DESCS[$i]}"
        done

        [[ "$header_printed" -eq 1 ]] && echo ""
    done

    if [[ "$printed_any" -eq 0 ]]; then
        log_error "No deployable modules found."
        exit 1
    fi
}

print_menu

echo "  Enter module numbers to deploy (space-separated, e.g. \"1 3\")."
echo "  Press Enter to select all, or type \"none\" to exit."
echo ""
read -rp "  > " selection

if [[ "$selection" == "none" ]]; then
    echo "  Exiting."
    exit 0
fi

SELECTED_MODULES=()

if [[ -z "$selection" ]]; then
    SELECTED_MODULES=("${MODULES[@]}")
else
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] \
            && [[ "$num" -gt 0 ]] \
            && [[ "$num" -lt "${#MENU_MODS[@]}" ]]; then
            SELECTED_MODULES+=("${MENU_MODS[$num]}")
        else
            log_warn "Unknown module number: $num (skipped)"
        fi
    done
fi

if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
    log_error "No valid modules selected."
    exit 1
fi

echo ""
log_info "Selected: ${SELECTED_MODULES[*]}"

# ============================================================================
# Env resolution
# Priority:
#   1. $INFRA_DIR/services/$mod/.env        (pre-filled, use as-is)
#   2. $INFRA_DIR/services/$mod/.env.example (prompt, fill from infra template)
#   3. $SCRIPT_DIR/services/$mod/.env.example (prompt, fill from automa template)
# Prints the resolved .env path to stdout.
# ============================================================================
fill_env_interactive() {
    # All user-visible output → stderr so caller can capture stdout for the path.
    local env_example="$1"
    local output="$2"

    printf "" > "$output"
    echo "  Fill in values (Enter = accept default shown in [brackets]):" >&2
    echo "" >&2

    while IFS= read -r line; do
        if [[ "$line" =~ ^#\ (role|description): ]]; then
            continue
        fi
        if [[ -z "$line" ]]; then
            continue
        fi
        if [[ "$line" =~ ^# ]]; then
            printf "  %s\n" "$line" >&2
            continue
        fi

        local key default hint val
        key="${line%%=*}"
        default="${line#*=}"
        hint=""

        if [[ -n "$default" && "$default" != "your-"* && "$default" != "x.x.x.x" ]]; then
            hint=" [$default]"
        fi

        read -rp "    $key$hint: " val <&0
        printf "%s=%s\n" "$key" "${val:-$default}" >> "$output"
    done < "$env_example"
}

resolve_env_for_module() {
    # Prints resolved .env path to stdout; all messages → stderr.
    local mod="$1"
    local dry_run="${2:-0}"
    local infra_mod_dir=""

    if [[ -n "$INFRA_DIR" ]]; then
        infra_mod_dir="$INFRA_DIR/services/$mod"
    fi

    # Case 1: pre-filled .env in infra — use directly
    if [[ -n "$infra_mod_dir" && -f "$infra_mod_dir/.env" ]]; then
        log_info "  Using pre-filled .env from infra" >&2
        printf "%s" "$infra_mod_dir/.env"
        return 0
    fi

    # Determine .env.example template source
    local env_example=""
    if [[ -n "$infra_mod_dir" && -f "$infra_mod_dir/.env.example" ]]; then
        env_example="$infra_mod_dir/.env.example"
    elif [[ -f "$SCRIPT_DIR/services/$mod/.env.example" ]]; then
        env_example="$SCRIPT_DIR/services/$mod/.env.example"
    else
        log_error "  No .env.example found for: $mod" >&2
        return 1
    fi

    # Dry-run: skip interactive fill, just return path to the example
    if [[ "$dry_run" -eq 1 ]]; then
        printf "%s" "$env_example"
        return 0
    fi

    local tmp_env
    tmp_env="$(mktemp /tmp/automa-env-XXXXXX)"
    fill_env_interactive "$env_example" "$tmp_env"
    printf "%s" "$tmp_env"
}

# ============================================================================
# Deployment
# ============================================================================
DEPLOYED=()
FAILED=()

for mod in "${SELECTED_MODULES[@]}"; do
    echo ""
    echo "  ── $mod ──"

    local_env=""
    if ! local_env="$(resolve_env_for_module "$mod" "$DRY_RUN")"; then
        FAILED+=("$mod")
        continue
    fi

    deploy_script="$SCRIPT_DIR/services/$mod/deploy.sh"
    if [[ ! -x "$deploy_script" ]]; then
        log_error "  deploy.sh not found or not executable: $deploy_script"
        FAILED+=("$mod")
        continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "  [dry-run] $mod  →  $deploy_script  (env: $local_env)"
        DEPLOYED+=("$mod")
        continue
    fi

    if INFRA_DIR="$(dirname "$local_env")" bash "$deploy_script"; then
        DEPLOYED+=("$mod")
    else
        log_error "  Deployment failed: $mod"
        FAILED+=("$mod")
    fi
done

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "  ┌─────────────────────────────────────┐"
echo "  │              Summary                 │"
echo "  └─────────────────────────────────────┘"

if [[ ${#DEPLOYED[@]} -gt 0 ]]; then
    echo ""
    log_info "Deployed (${#DEPLOYED[@]}):"
    for m in "${DEPLOYED[@]}"; do echo "    ✓ $m"; done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    log_error "Failed (${#FAILED[@]}):"
    for m in "${FAILED[@]}"; do echo "    ✗ $m"; done
    exit 1
fi

echo ""
log_info "Done."
