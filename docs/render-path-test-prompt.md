# asb-app render-path exercise prompt

Paste the block below as a **single prompt** into an agent-shell / Claude ACP
session that the phone is mirroring. In one turn it walks Claude through every
render path the app draws, so you can eyeball each on-device.

## What each step verifies (payload → UI)

| Step | Payload / event | On-phone render to check |
|------|-----------------|--------------------------|
| reasoning aloud | `Thought` | thought row **expands while working**, auto-collapses when the turn ends |
| the plan | `Plan` (pending/in_progress/completed) | plan card with a check / active-dot / hollow-dot per status |
| `ls`, `cat` via Bash | `ToolCall{kind:command}` | command tool row shows the **command** + streamed output, status pending→running→done |
| Grep/Glob | `ToolCall{kind:search}` | search tool row |
| Read | `ToolCall{kind:read}` + `Content::FileRef` | read tool row with the file path |
| Edit / Write | `ToolCall{kind:edit}` + `Content::Diff` | edit row with a **diff block** |
| a failing command | `ToolCallUpdate{status:failed}` | tool row goes to the failed state |
| markdown answer | `AgentMessage` | headings / list / **bold** / `inline code` / fenced code all render |
| (end of turn) | `Usage` + `Status:idle` | token pill updates; composer send-button returns (interrupt → send) |
| approval (see note) | `PermissionReq` | permission bar with the option buttons |

**Permission bar:** it only appears if the session's permission mode actually
gates tool use. If you're on an auto-approve mode you won't see it — switch the
mode picker (top bar) to the default / "ask" mode first, then the `Edit` step
below will prompt.

## The prompt

```
Work entirely inside a fresh scratch dir so nothing real is touched. Do all of
this in ONE turn, thinking out loud as you go so I can watch your reasoning:

1. First, use your extended thinking to reason about the plan before acting.
2. Create a TODO plan with about five items and keep its statuses updated
   (mark items in-progress then completed) as you work through the steps.
3. Run: mkdir -p /tmp/asb-render-test && cd /tmp/asb-render-test
4. Write a file story.txt containing three short lines of text.
5. cat story.txt so I can see it.
6. Read story.txt back with your Read tool.
7. Use Grep (or Glob) to search /tmp/asb-render-test for the word "the".
8. Edit story.txt: change one word on the first line (produces a diff).
9. Run a command that fails on purpose: cat /tmp/asb-render-test/does-not-exist.txt
10. Finally, summarise what you did as markdown with: a level-2 heading, a
    bulleted list, one **bold** phrase, one piece of `inline code`, and a short
    fenced code block. Then stop.

Keep it quick — the point is to exercise each kind of step, not to be thorough.
```

Rebuild/restart the sidecar and reconnect the phone first if you haven't since
the attachments change — the new `FsList`/`Upload` wire variants need the
current daemon.
