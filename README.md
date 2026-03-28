# smux

One-command tmux setup with sensible defaults and cross-pane communication.

<video src="[https://github.com/ShawnPana/tmux-config/releases/download/v0.0.0-assets/tmux-bridge.mp4](https://github.com/user-attachments/assets/9d5463ba-5972-4bbd-a07e-b585f1178011)" controls autoplay muted loop width="100%"></video>

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ShawnPana/smux/main/install.sh | bash
```

This installs:
- **tmux** if not already installed (via Homebrew, apt, dnf, pacman, or apk)
- **tmux.conf** with Option-key bindings, mouse support, pane labels, and a minimal status bar
- **tmux-bridge** CLI for cross-pane communication between AI agents

Everything lives in `~/.smux/`.

## Keybindings

All keybindings use **Option (Alt)** with no prefix required.

### Panes

| Key | Action |
|---|---|
| `Option+i/k/j/l` | Navigate up/down/left/right (no wrap) |
| `Option+n` | New pane (split + auto-tile) |
| `Option+w` | Close pane |
| `Option+o` | Cycle layouts |
| `Option+g` | Mark pane |
| `Option+y` | Swap with marked pane |

### Windows

| Key | Action |
|---|---|
| `Option+m` | New window |
| `Option+u` | Next window |
| `Option+h` | Previous window |

### Scrolling

| Key | Action |
|---|---|
| `Option+Tab` | Toggle scroll mode |
| `i/k` | Scroll up/down |
| `Shift+I/K` | Half-page up/down |
| `q` or `Escape` | Exit scroll mode |

### Mouse

- Click to select panes
- Drag to select text (auto-copies to clipboard)
- Scroll wheel to scroll

## tmux-bridge

A CLI for cross-pane communication between AI agents. Any tool that can run bash can use it.

| Command | Description |
|---|---|
| `tmux-bridge list` | Show all panes |
| `tmux-bridge type <target> <text>` | Type text into a pane |
| `tmux-bridge read <target> [lines]` | Read pane output |
| `tmux-bridge keys <target> <key>...` | Send special keys |
| `tmux-bridge name <target> <label>` | Label a pane |
| `tmux-bridge id` | Print this pane's ID |

See the [smux skill](skills/smux/SKILL.md) for full documentation.

## Update

```bash
smux update
```

## Uninstall

```bash
smux uninstall
```

## AI Agent Skills

Skills for Claude Code and other AI agents are available via [skills.sh](https://skills.sh):

```bash
npx skills add ShawnPana/smux
```

## Requirements

- macOS (requires [Homebrew](https://brew.sh)) or Linux
- tmux 3.2+ (installed automatically)
