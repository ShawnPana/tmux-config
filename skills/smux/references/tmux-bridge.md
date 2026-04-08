---
name: tmux-bridge
description: Agent-agnostic CLI for cross-pane communication — type text, send keys, read output, and interact between tmux panes.
metadata:
  { "openclaw": { "emoji": "🌉", "os": ["darwin", "linux"], "requires": { "bins": ["tmux", "tmux-bridge"] } } }
---

# tmux-bridge

A single CLI that lets any AI agent (Claude Code, Codex, Gemini CLI, etc.) interact with any other tmux pane. Works via plain bash — any tool that can run shell commands can use it.

Every command is **atomic**: `type` types text (no Enter), `keys` sends special keys, `read` captures pane content. There is no compound "send" command — you control each step and verify between them.

## DO NOT WAIT OR POLL — EVER

**Other panes have agents that will reply to you via tmux-bridge.** When you send a message to another agent, their reply will appear directly in YOUR pane as a `[tmux-bridge from:...]` message. You do NOT need to:

- Sleep or wait after sending
- Poll the target pane for a response
- Read the target pane to check if they replied
- Loop or retry to see output

**Type your message, press Enter, and move on.** The other agent will type their reply back into your pane. You'll see it arrive.

The ONLY time you need to read a target pane is:
- **Before** interacting with it (enforced — see Read Guard below)
- **After typing** to verify your text landed correctly before pressing Enter
- When interacting with a **non-agent pane** (plain shell, running process) where there's no agent to reply back

## Read Guard — Enforced by CLI

The CLI **enforces** read-before-act. You cannot `type` or `keys` to a pane unless you have read it first.

**How it works:**
1. `tmux-bridge read <target>` marks the pane as "read"
2. `tmux-bridge type/keys <target>` checks for that mark — **errors if you haven't read**
3. After a successful `type`/`keys`, the mark is **cleared** — you must read again before the next interaction

This enforces the **read-act-read** cycle at the CLI level. If you skip the read, the command fails:

```
$ tmux-bridge type codex "hello"
error: must read the pane before interacting. Run: tmux-bridge read codex
```

## When to Use

**USE this skill when:**

- Sending messages to another agent running in a tmux pane
- Reading output from another pane
- Labeling and discovering panes by name
- Any cross-pane interaction between agents

## When NOT to Use

**DON'T use this skill when:**

- Running one-off shell commands in the current pane
- Tasks that don't involve other tmux panes
- You need raw tmux commands → use the `tmux` skill directly

## Command Reference

| Command | Description | Example |
|---|---|---|
| `tmux-bridge list` | Show all panes with target, pid, command, size, label | `tmux-bridge list` |
| `tmux-bridge type <target> <text>` | Type text without pressing Enter | `tmux-bridge type codex "hello"` |
| `tmux-bridge message <target> <text>` | Type text with auto sender info and reply target | `tmux-bridge message codex "review src/auth.ts"` |
| `tmux-bridge read <target> [lines]` | Read last N lines (default 50) | `tmux-bridge read codex 100` |
| `tmux-bridge keys <target> <key>...` | Send special keys | `tmux-bridge keys codex Enter` |
| `tmux-bridge name <target> <label>` | Label a pane (visible in tmux border) | `tmux-bridge name %3 codex` |
| `tmux-bridge resolve <label>` | Print pane target for a label | `tmux-bridge resolve codex` |
| `tmux-bridge id` | Print this pane's ID | `tmux-bridge id` |

## Socket Selection

`tmux-bridge` talks to one tmux server at a time. By default it auto-detects the server from the current tmux environment, which means it may miss panes running on a different socket such as `tmux -L gui`.

Use `TMUX_BRIDGE_SOCKET` to point the bridge at a non-default server:

```bash
export TMUX_BRIDGE_SOCKET="$(tmux -L gui display-message -p '#{socket_path}')"
tmux-bridge list
tmux-bridge read claude 20
```

If a target exists in another tmux server, prefer switching the bridge to that socket over dropping immediately to raw `tmux` commands.

## Target Resolution

Targets can be:
- **tmux native**: `session:window.pane` (e.g. `shared:0.1`), pane ID (`%3`), or window index (`0`)
- **label**: Any string set via `tmux-bridge name` — resolved automatically

This means `tmux-bridge type codex "hello"` works directly if the pane was labeled `codex`.

Bridge labels are stored with `tmux-bridge name` as pane metadata. They are not the same as tmux pane titles set with `tmux select-pane -T ...`.

## Messaging Convention

The `message` command auto-prepends sender info and location:

```
[tmux-bridge from:claude pane:%4 at:3:0.0] Please review src/auth.ts
```

The receiver gets: who sent it (`from`), the exact pane to reply to (`pane`), and the session/window location (`at`). When you see this header, reply using tmux-bridge to the pane ID from the header.

`tmux-bridge message` requires the sender to be inside tmux so it can include `TMUX_PANE` in the reply header. If you are running outside tmux, `message` will fail with `not running inside a tmux pane`.

In that case, use `type` plus `Enter` instead:

```bash
tmux-bridge read claude 20
tmux-bridge type claude 'Test from Codex via tmux-bridge on the gui socket.'
tmux-bridge read claude 20
tmux-bridge keys claude Enter
```

This still delivers the message, but it does not include an automatic reply target.

### Receiving messages — IMPORTANT

**When you see a message prefixed with `[tmux-bridge from:<sender> pane:%N at:...]`, you MUST reply using tmux-bridge to the pane ID in the header:**

```bash
tmux-bridge read %4 20
tmux-bridge message %4 "your response here"
tmux-bridge read %4 20
tmux-bridge keys %4 Enter
```

This sends your reply directly into the sender's pane so they see it immediately. **Do not just respond in your own pane** — the sender won't see it unless you send it back via tmux-bridge.

Keep replies concise (1-3 sentences). They will be typed into the sender's terminal as a single line.

### Example conversation

**Agent A (claude) sends:**
```bash
tmux-bridge read codex 20       # 1. READ — satisfy read guard
tmux-bridge message codex 'What is the test coverage for src/auth.ts?'
                                 # 2. MESSAGE — auto-prepends sender info, no Enter yet
tmux-bridge read codex 20       # 3. READ — verify text landed
tmux-bridge keys codex Enter    # 4. KEYS — press Enter to submit
# Done. Do NOT wait, poll, or read codex for the response.
# Agent B will reply via tmux-bridge and it will appear in your pane.
```

**Agent B (codex) sees in their prompt:**
```
[tmux-bridge from:claude pane:%4 at:3:0.0] What is the test coverage for src/auth.ts?
```

**Agent B replies:**
```bash
tmux-bridge read %4 20          # 1. READ — satisfy read guard
tmux-bridge message %4 'src/auth.ts has 87% line coverage. Missing coverage on the OAuth refresh token path (lines 142-168).'
                                 # 2. MESSAGE — auto-prepends sender info, no Enter yet
tmux-bridge read %4 20          # 3. READ — verify text landed
tmux-bridge keys %4 Enter       # 4. KEYS — press Enter to submit
# Done. The reply appears in Agent A's pane automatically.
```

## Read-Act-Read Cycle

Every interaction with another pane MUST follow the **read → act → read** cycle. The CLI enforces this — `type`/`keys` will error if you haven't read first, and each action clears the read mark.

The full cycle for sending a message:

1. **Read** the target pane (satisfies read guard)
2. **Type** your message text (clears read mark)
3. **Read** again (verify text landed, re-satisfy read guard)
4. **Keys** Enter (submit the message, clears read mark)
5. **Read** again if you need to see the result (non-agent panes)

### Example: sending a message to an agent

```bash
# 1. READ — check the pane and satisfy read guard
tmux-bridge read codex 20

# 2. MESSAGE — type the message (no Enter)
tmux-bridge message codex 'Please review the changes in src/auth.ts'

# 3. READ — verify the text landed correctly
tmux-bridge read codex 20

# 4. KEYS — press Enter to submit
tmux-bridge keys codex Enter

# STOP. Do NOT read codex to check for a reply.
# The other agent will reply via tmux-bridge into YOUR pane.
```

### Example: approving a prompt (non-agent pane)

```bash
# 1. READ — see what the prompt is asking
tmux-bridge read worker 10

# 2. TYPE — type the answer
tmux-bridge type worker "y"

# 3. READ — verify it landed
tmux-bridge read worker 10

# 4. KEYS — press Enter to submit
tmux-bridge keys worker Enter

# 5. READ — for non-agent panes, you DO need to read to see the result
tmux-bridge read worker 20
```

## Agent-to-Agent Workflow

### Step 1: Label yourself

```bash
tmux-bridge name "$(tmux-bridge id)" claude
```

### Step 2: Discover other panes

```bash
tmux-bridge list
```

### Step 3: Read, type, read, Enter

```bash
tmux-bridge read codex 20
tmux-bridge message codex 'Please review the changes in src/auth.ts and suggest improvements'
tmux-bridge read codex 20
tmux-bridge keys codex Enter
# Done. Wait for the reply to appear in your pane.
```

## Tips

- **Read guard is enforced** — you MUST read before every `type`/`keys`. The CLI will error otherwise.
- **Every action clears the read mark** — after `type`, you must `read` again before `keys`.
- **Never wait or poll** — agent panes reply to you via tmux-bridge. The response appears in YOUR pane.
- **Label panes early** — it makes cross-agent communication much easier than using `%N` IDs
- **Set `TMUX_BRIDGE_SOCKET` for non-default tmux servers** — especially for `tmux -L <name>` sessions
- **`tmux-bridge name` labels are not pane titles** — `select-pane -T` does not make a bridge label
- **`message` needs a tmux sender pane** — outside tmux, use `type` plus `Enter`
- **`type` uses literal mode** — it uses `-l` so special characters are typed as-is
- **`read` defaults to 50 lines** — pass a higher number for more context
- **Non-agent panes** (shells, processes) are the exception — you DO need to read them to see output
