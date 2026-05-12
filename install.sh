#!/usr/bin/env bash
set -euo pipefail

REPO="maximilianbuff/tmux-session-picker"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
SCRIPT_URL="${RAW_BASE}/tmux-login.sh"
INSTALL_PATH="${HOME}/.tmux-login.sh"

BASHRC="${HOME}/.bashrc"

GRN='\033[0;32m'
YLW='\033[1;33m'
RED='\033[0;31m'
BLD='\033[1m'
DIM='\033[2m'
RST='\033[0m'

info()    { echo -e "  ${GRN}✔${RST}  $*"; }
warn()    { echo -e "  ${YLW}!${RST}   $*"; }
error()   { echo -e "  ${RED}✖${RST}  $*" >&2; }
section() { echo -e "\n${BLD}$*${RST}"; }

# ── Preflight ─────────────────────────────────────────────────────────────────
section "tmux-session-picker installer"

if ! command -v tmux &>/dev/null; then
    warn "tmux is not installed."
    echo -e "  ${DIM}Install it first:  sudo apt-get install -y tmux${RST}"
    echo -e "  ${DIM}                   brew install tmux${RST}"
    echo -e "  ${DIM}Then re-run this installer.${RST}"
    exit 1
fi

# ── Download script ───────────────────────────────────────────────────────────
section "Downloading tmux-login.sh"

if command -v curl &>/dev/null; then
    curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
elif command -v wget &>/dev/null; then
    wget -qO "$INSTALL_PATH" "$SCRIPT_URL"
else
    error "Neither curl nor wget found. Install one and retry."
    exit 1
fi

chmod +x "$INSTALL_PATH"
info "Installed to ${INSTALL_PATH}"

# ── Patch .bashrc ─────────────────────────────────────────────────────────────
section "Patching ${BASHRC}"

MARKER="# tmux-session-picker"
SNIPPET=$(cat <<'EOF'

# tmux-session-picker
if [[ -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]] && [[ -f ~/.tmux-login.sh ]]; then
    exec ~/.tmux-login.sh "${TMUX_SESSION:-}"
fi
EOF
)

if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    warn "Snippet already present in ${BASHRC} — skipping."
else
    echo "$SNIPPET" >> "$BASHRC"
    info "Snippet added to ${BASHRC}"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "Done!"
echo -e "  Next SSH login will drop you into the session picker."
echo -e "  ${DIM}To jump directly into a session:${RST}"
echo -e "  ${DIM}  ssh -t user@host '~/.tmux-login.sh myproject'${RST}"
echo -e "  ${DIM}  TMUX_SESSION=myproject ssh user@host  (requires AcceptEnv TMUX_SESSION in sshd_config)${RST}"
echo -e ""
echo -e "  ${DIM}To uninstall: bash <(curl -fsSL ${RAW_BASE}/uninstall.sh)${RST}"
