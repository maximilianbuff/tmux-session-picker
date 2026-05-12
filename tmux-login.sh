#!/usr/bin/env bash
# ~/.tmux-login.sh — tmux session picker for SSH logins
#
# Usage:
#   ~/.tmux-login.sh [session-name-or-number]
#   TMUX_SESSION=dev ssh user@host          (with AcceptEnv in sshd_config)
#   ssh -t user@host "~/.tmux-login.sh dev" (direct invocation)

GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
RED='\033[0;31m'
BLD='\033[1m'
DIM='\033[2m'
RST='\033[0m'

# Already inside tmux — nothing to do
[[ -n "$TMUX" ]] && exit 0

# Ghostty ships its own terminfo that servers won't have; fall back to xterm-256color
[[ "$TERM" == "xterm-ghostty" ]] && export TERM=xterm-256color

if ! command -v tmux &>/dev/null; then
    echo -e "${RED}tmux is not installed.${RST} Dropping to plain shell." >&2
    echo -e "${DIM}  To install: sudo apt-get install -y tmux${RST}" >&2
    exec bash --login
fi

# Verify the tmux server is reachable (catches a dead socket / failed server start)
if ! tmux start-server 2>/tmp/tmux-start-err; then
    echo -e "${RED}tmux server failed to start:${RST}" >&2
    cat /tmp/tmux-start-err >&2
    echo -e "${DIM}Dropping to plain shell.${RST}" >&2
    exec bash --login
fi

TARGET="${1:-${TMUX_SESSION:-}}"

die() {
    echo -e "${RED}tmux error:${RST} $*" >&2
    echo -e "${DIM}Dropping to plain shell.${RST}" >&2
    exec bash --login
}

attach_or_create() {
    local name="$1"
    if tmux has-session -t "=$name" 2>/dev/null; then
        exec tmux attach-session -t "=$name" || die "attach-session failed for '$name'"
    else
        echo -e "${GRN}Creating new session '${name}'...${RST}"
        exec tmux new-session -s "$name" || die "new-session failed for '$name'"
    fi
}

# Fetch sessions: name|windows|attached_count
SESSIONS=$(tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}" 2>/dev/null)

# ── No sessions running ───────────────────────────────────────────────────────
if [[ -z "$SESSIONS" ]]; then
    if [[ -n "$TARGET" ]]; then
        echo -e "${GRN}No sessions found. Creating '${TARGET}'...${RST}"
        exec tmux new-session -s "$TARGET" || die "new-session failed for '$TARGET'"
    fi
    echo -e "${YLW}No active tmux sessions.${RST}"
    read -rp "$(echo -e "${BLD}New session name (blank = default): ${RST}")" name
    if [[ -n "$name" ]]; then
        exec tmux new-session -s "$name" || die "new-session failed for '$name'"
    else
        exec tmux new-session || die "new-session failed"
    fi
fi

# ── Target provided — connect or create without prompting ────────────────────
if [[ -n "$TARGET" ]]; then
    if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
        name=$(echo "$SESSIONS" | cut -d'|' -f1 | sed -n "${TARGET}p")
        if [[ -n "$name" ]]; then
            exec tmux attach-session -t "=$name" || die "attach-session failed for '$name'"
        else
            echo -e "${YLW}No session #${TARGET}. Creating it as a named session...${RST}"
            exec tmux new-session -s "$TARGET" || die "new-session failed for '$TARGET'"
        fi
    else
        attach_or_create "$TARGET"
    fi
fi

# ── Interactive picker ────────────────────────────────────────────────────────
echo -e "\n${BLD}${CYN}  Active tmux sessions${RST}\n"

i=1
declare -a NAMES
while IFS='|' read -r name wins att; do
    NAMES+=("$name")
    [[ "$att" -gt 0 ]] && dot="${GRN}●${RST} " || dot="${DIM}○${RST} "
    printf "  ${BLD}%2d)${RST}  %b%-22s ${DIM}%d window%s${RST}\n" \
        "$i" "$dot" "$name" "$wins" "$( [[ "$wins" -ne 1 ]] && echo s )"
    ((i++))
done <<< "$SESSIONS"

echo -e "   ${BLD}n)${RST}  New session\n"

while true; do
    read -rp "$(echo -e "${BLD}› ${RST}")" choice
    case "$choice" in
        n|N)
            read -rp "$(echo -e "${BLD}Session name (blank = default): ${RST}")" name
            if [[ -n "$name" ]]; then
                exec tmux new-session -s "$name" || die "new-session failed for '$name'"
            else
                exec tmux new-session || die "new-session failed"
            fi
            ;;
        "")
            continue
            ;;
        [0-9]*)
            name="${NAMES[$((choice - 1))]}"
            if [[ -n "$name" ]]; then
                exec tmux attach-session -t "=$name" || die "attach-session failed for '$name'"
            else
                echo -e "${RED}  No session #${choice} — try again${RST}"
            fi
            ;;
        *)
            attach_or_create "$choice"
            ;;
    esac
done
