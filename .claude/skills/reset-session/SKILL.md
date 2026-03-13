---
name: reset-session
description: Clear a group's session ID so the next message starts a fresh Claude Code session, picking up any CLAUDE.md changes. Use after editing a group's CLAUDE.md or when a session is stuck.
---

# Reset Agent Session

Clears the stored session ID for a group so the next message starts a fresh session. This is the correct way to pick up CLAUDE.md changes — killing the container alone is not enough, because the session ID is reused from the database.

## Step 1 — Identify the group

If the user didn't specify a group, list all current sessions so they can pick one:

```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "SELECT group_folder, session_id FROM sessions;"
```

Ask the user which group to reset if it's not clear from context.

## Step 2 — Clear the session

```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "DELETE FROM sessions WHERE group_folder = '<folder>';"
```

Confirm the row is gone:

```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "SELECT group_folder FROM sessions WHERE group_folder = '<folder>';"
```

If the query returns nothing, the session was cleared successfully.

## Step 3 — Confirm

Tell the user:
- Session cleared for `<folder>`
- The next message to that channel will start a fresh session and load the current CLAUDE.md from disk
- No nanoclaw restart needed
