# tmux + Claude Code Config

Tmux configuration, Claude Code settings, and `tmux-bridge` — an agent-agnostic CLI for cross-pane communication. Includes a hook that turns your tmux pane red when Claude Code needs approval.

## Setup

Clone the repo and create symlinks:

```bash
git clone https://github.com/ShawnPana/tmux-config.git ~/Projects/tmux-config

# Tmux config
ln -sf ~/Projects/tmux-config/.tmux.conf ~/.config/tmux/tmux.conf

# Claude Code settings
ln -sf ~/Projects/tmux-config/claude-settings.json ~/.claude/settings.json

# Pane alert script
mkdir -p ~/.config/tmux
ln -sf ~/Projects/tmux-config/scripts/claude-pane-alert.sh ~/.config/tmux/claude-pane-alert.sh

# tmux-bridge CLI (global PATH)
ln -sf ~/Projects/tmux-config/scripts/tmux-bridge /usr/local/bin/tmux-bridge

# Skills (Claude Code)
mkdir -p ~/.claude/skills/tmux ~/.claude/skills/tmux-bridge
ln -sf ~/Projects/tmux-config/skills/tmux/SKILL.md ~/.claude/skills/tmux/skill.md
ln -sf ~/Projects/tmux-config/skills/tmux-bridge/SKILL.md ~/.claude/skills/tmux-bridge/skill.md

# Skills (agents)
mkdir -p ~/.agents/skills/tmux ~/.agents/skills/tmux-bridge
ln -sf ~/Projects/tmux-config/skills/tmux/SKILL.md ~/.agents/skills/tmux/SKILL.md
ln -sf ~/Projects/tmux-config/skills/tmux-bridge/SKILL.md ~/.agents/skills/tmux-bridge/SKILL.md
```

Add the `rename` helper to your `.zshrc`:

```bash
rename() {
  if [ $# -eq 2 ]; then
    tmux rename-window -t "$1" "$2"
  elif [ $# -eq 1 ]; then
    tmux rename-window "$1"
  fi
}
```

Reload tmux config:

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

Restart any running Claude Code sessions to pick up the new hooks.

## Usage

All keybindings use **Option (Alt)** with no prefix required.

### Panes

| Key | Action |
|---|---|
| `Option+i/k/j/l` | Navigate up/down/left/right (no wrap) |
| `Option+n` | New pane (split + auto-tile) |
| `Option+w` | Kill current pane |
| `Option+o` | Cycle through layouts |
| `Option+g` | Mark current pane |
| `Option+y` | Swap marked pane with current |

### Windows

| Key | Action |
|---|---|
| `Option+m` | New window |
| `Option+u` | Next window |
| `Option+h` | Previous window |

Rename windows from the shell:

```bash
rename myname        # rename current window
rename 0 myname      # rename window by index
```

(Requires the `rename` function in your `.zshrc` — see Setup)

### Scrolling

| Key | Action |
|---|---|
| `Option+Tab` | Toggle scroll mode |
| `i/k` | Scroll up/down |
| `Shift+i/k` | Half-page up/down |
| `q` or `Escape` | Exit scroll mode |

Mouse scroll also works and auto-enters copy mode.

### Mouse

- Click to select panes
- Drag to select text (auto-copies to clipboard on release)
- Scroll wheel to scroll

### Claude Code pane alert

When Claude Code shows a permission prompt, the tmux pane background turns red. It resets when you approve or when Claude finishes responding. Only the relevant pane is affected.

## How the pane alert works

Three hooks in `claude-settings.json`:

| Event | Action |
|---|---|
| `PermissionRequest` | Pane turns red |
| `PostToolUse` | Pane resets (approved, tool ran) |
| `Stop` | Pane resets (fallback) |

The script uses `$TMUX_PANE` to target only the correct pane — no interference with other panes.

## tmux-bridge

An agent-agnostic CLI for cross-pane communication. Any AI agent (Claude Code, Codex, Gemini CLI, etc.) that can run bash can use it to talk to other panes.

### Commands

| Command | Description |
|---|---|
| `tmux-bridge list` | Show all panes with target, pid, command, size, label |
| `tmux-bridge send <target> <msg>` | Type text + Enter into a pane |
| `tmux-bridge type <target> <text>` | Type text without pressing Enter |
| `tmux-bridge read <target> [lines]` | Read last N lines (default 50) |
| `tmux-bridge keys <target> <key>...` | Send special keys (Enter, Escape, C-c, etc.) |
| `tmux-bridge name <target> <label>` | Label a pane (visible in tmux border) |
| `tmux-bridge resolve <label>` | Print pane target for a label |
| `tmux-bridge id` | Print this pane's ID |

Targets can be tmux native (`%3`, `shared:0.1`) or a label set via `name`. Labels are resolved automatically.

### Agent-to-agent example

```bash
# Agent A labels itself
tmux-bridge name "$(tmux-bridge id)" claude

# Agent A sends a task to Codex
tmux-bridge send codex "Please review src/auth.ts"

# Agent A reads the response
tmux-bridge read codex 100
```
