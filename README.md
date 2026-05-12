# tmux-session-picker

An interactive tmux session picker that runs automatically on SSH login. Instead of landing at a plain shell, you get a numbered menu of running sessions — pick one, create a new one, or jump directly to a named session from your SSH command.

```
  Active tmux sessions

   1)  ●  dev                    3 windows
   2)  ○  monitoring             1 window
   3)  ●  fintrack               2 windows

   n)  New session

›  _
```

## Requirements

- bash 4+
- tmux (any recent version)
- curl or wget (for the one-liner installer)

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/maximilianbuff/tmux-session-picker/main/install.sh)
```

This will:
1. Download `tmux-login.sh` to `~/.tmux-login.sh`
2. Add a trigger snippet to `~/.bashrc` that runs the picker on SSH login

**Reload your shell** (or log out and back in) for the change to take effect:

```bash
source ~/.bashrc
```

## Usage

### Interactive picker (default)

Just SSH in — the picker appears automatically:

```bash
ssh user@host
```

### Jump directly to a named session

```bash
ssh -t user@host '~/.tmux-login.sh myproject'
```

If the session doesn't exist yet, it will be created.

### Jump by number

```bash
ssh -t user@host '~/.tmux-login.sh 2'
```

Attaches to session #2 as shown in the picker list.

### Pass session via environment variable

You can pre-select a session without an interactive argument by setting `TMUX_SESSION` on your local machine. Requires `AcceptEnv TMUX_SESSION` in the server's `/etc/ssh/sshd_config`.

```bash
TMUX_SESSION=dev ssh user@host
```

**sshd_config** (server side):
```
AcceptEnv TMUX_SESSION
```

### SSH config shortcut (client side)

Add this to `~/.ssh/config` on your local machine to always jump to a specific session on a given host:

```
Host myserver
    HostName 1.2.3.4
    User maxbuff
    RequestTTY yes
    RemoteCommand ~/.tmux-login.sh dev
```

Then `ssh myserver` drops you straight into the `dev` session.

## How it works

The `.bashrc` snippet fires only when:
- You're connecting over SSH (`$SSH_TTY` is set)
- You're not already inside tmux (`$TMUX` is unset)
- The script file exists (`~/.tmux-login.sh`)

This means local terminal sessions are unaffected — the picker only runs on SSH logins.

The script itself:
1. Verifies tmux is installed and the server is reachable
2. If a target was provided (argument or `$TMUX_SESSION`), attaches or creates that session immediately
3. Otherwise renders the interactive picker

If anything goes wrong (tmux not installed, server crash, bad session name) it falls back gracefully to a plain bash login shell.

## Ghostty terminal

If you connect from [Ghostty](https://ghostty.org/), the script automatically remaps `$TERM` from `xterm-ghostty` to `xterm-256color` since remote servers typically don't have Ghostty's terminfo installed.

## Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/maximilianbuff/tmux-session-picker/main/uninstall.sh)
```

This removes `~/.tmux-login.sh` and cleans the snippet out of `~/.bashrc`.

## AI assistant usage

If you're asking Claude (or another AI assistant) to set this up on a server, paste this prompt:

> Install tmux-session-picker on this server:
> ```bash
> bash <(curl -fsSL https://raw.githubusercontent.com/maximilianbuff/tmux-session-picker/main/install.sh)
> ```
> Then confirm `~/.tmux-login.sh` exists and the `.bashrc` snippet is present.

## License

MIT
