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
mapfile -t NAMES < <(echo "$SESSIONS" | cut -d'|' -f1)
mapfile -t WINS  < <(echo "$SESSIONS" | cut -d'|' -f2)
mapfile -t ATTS  < <(echo "$SESSIONS" | cut -d'|' -f3)

count=${#NAMES[@]}
sel=0  # 0..count-1 = session, count = "New session"

render() {
    echo -e "\n${BLD}${CYN}  Active tmux sessions${RST}\n"
    for ((i=0; i<count; i++)); do
        local wins="${WINS[$i]}"
        local suffix; [[ "$wins" -ne 1 ]] && suffix="s" || suffix=""
        local dot; [[ "${ATTS[$i]}" -gt 0 ]] && dot="${GRN}●${RST}" || dot="${DIM}○${RST}"
        if [[ $i -eq $sel ]]; then
            printf "  ${CYN}${BLD}▶${RST}  %b ${BLD}%-22s${RST} ${DIM}%d window%s${RST}\n" \
                "$dot" "${NAMES[$i]}" "$wins" "$suffix"
        else
            printf "     %b %-22s ${DIM}%d window%s${RST}\n" \
                "$dot" "${NAMES[$i]}" "$wins" "$suffix"
        fi
    done
    echo ""
    if [[ $sel -eq $count ]]; then
        echo -e "  ${CYN}${BLD}▶  New session${RST}"
    else
        echo -e "     ${DIM}New session${RST}"
    fi
    echo -e "\n  ${DIM}↑↓ navigate · Enter select · n new · q quit${RST}"
}

read_key() {
    local key seq
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.05 seq
        key+="$seq"
    fi
    printf '%s' "$key"
}

prompt_new_session() {
    echo ""
    read -rp "$(echo -e "${BLD}Session name (blank = default): ${RST}")" name
    if [[ -n "$name" ]]; then
        exec tmux new-session -s "$name" || die "new-session failed for '$name'"
    else
        exec tmux new-session || die "new-session failed"
    fi
}

tput sc
render

while true; do
    key=$(read_key)
    tput rc
    tput ed

    case "$key" in
        $'\x1b[A'|k)  # Up / vim-up
            sel=$(( (sel - 1 + count + 1) % (count + 1) ))
            ;;
        $'\x1b[B'|j)  # Down / vim-down
            sel=$(( (sel + 1) % (count + 1) ))
            ;;
        ''|$'\n'|$'\r')  # Enter
            if [[ $sel -eq $count ]]; then
                prompt_new_session
            else
                exec tmux attach-session -t "=${NAMES[$sel]}" || die "attach-session failed"
            fi
            ;;
        n|N)  prompt_new_session ;;
        q|Q)
            echo -e "${DIM}Cancelled.${RST}"
            exec bash --login
            ;;
        [1-9])
            idx=$((key - 1))
            if [[ $idx -lt $count ]]; then
                exec tmux attach-session -t "=${NAMES[$idx]}" || die "attach-session failed"
            fi
            ;;
    esac

    render
done
