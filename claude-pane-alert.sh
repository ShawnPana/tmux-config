#!/bin/bash
# Changes/resets tmux pane background color for Claude Code approval prompts.
# Uses $TMUX_PANE env var (set by tmux) to target the correct pane.
action="${1:-set}"
pane="${TMUX_PANE:-}"
if [ -z "$pane" ]; then exit 0; fi

if [ "$action" = "set" ]; then
  tmux set-option -p -t "$pane" window-style 'bg=colour52'
elif [ "$action" = "reset" ]; then
  tmux set-option -p -t "$pane" window-style 'bg=default'
fi
