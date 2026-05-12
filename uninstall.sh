#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="${HOME}/.tmux-login.sh"
BASHRC="${HOME}/.bashrc"
MARKER="# tmux-session-picker"

GRN='\033[0;32m'
YLW='\033[1;33m'
RED='\033[0;31m'
BLD='\033[1m'
DIM='\033[2m'
RST='\033[0m'

info()    { echo -e "  ${GRN}✔${RST}  $*"; }
warn()    { echo -e "  ${YLW}!${RST}   $*"; }
section() { echo -e "\n${BLD}$*${RST}"; }

section "tmux-session-picker uninstaller"

# Remove script
if [[ -f "$INSTALL_PATH" ]]; then
    rm -f "$INSTALL_PATH"
    info "Removed ${INSTALL_PATH}"
else
    warn "${INSTALL_PATH} not found — already removed?"
fi

# Remove .bashrc snippet (the marker line + the 3 lines that follow it)
if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    # Portable removal: works on both Linux (GNU sed) and macOS (BSD sed)
    TMP=$(mktemp)
    awk "
        /^[[:space:]]*${MARKER//\//\\/}/ { skip=4 }
        skip > 0 { skip--; next }
        { print }
    " "$BASHRC" > "$TMP" && mv "$TMP" "$BASHRC"
    info "Removed snippet from ${BASHRC}"
else
    warn "Snippet not found in ${BASHRC} — already removed?"
fi

section "Done."
echo -e "  ${DIM}tmux-session-picker has been uninstalled.${RST}"
