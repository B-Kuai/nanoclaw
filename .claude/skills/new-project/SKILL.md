---
name: new-project
description: Set up a new Software-A-Team project with Discord channel, group config, DB registration, and nanoclaw restart.
---

# New Project Setup

This skill sets up a new Software-A-Team project interactively. It creates the group config, registers the channel, and restarts nanoclaw.

## Step 1 — Collect inputs

Ask the user for the following (can ask all at once):

1. **Project name** — display name (e.g. `MyApp`)
2. **GitHub repo** — `org/repo` (e.g. `my-org/my-app`)
3. **Discord channel ID** — numeric ID (right-click channel in Discord → Copy Channel ID)
4. **Folder name** — snake_case group folder (e.g. `discord_myapp`)
5. **Bot name** — what the assistant calls itself in this channel (e.g. `Pangge`)
6. **Trello board ID** — if different from any existing project, paste the board ID from the Trello URL (`https://trello.com/b/<BOARD_ID>/...`)
7. **Git identity** — name and email for commits from this channel's agents (e.g. `Pangge, pangge@kuai.family`)

## Step 2 — Create group folder and CLAUDE.md

Create `groups/{folder}/CLAUDE.md` using the template below. Substitute all placeholders:

- `{PROJECT}` → project name (e.g. `MyApp`)
- `{REPO}` → GitHub repo (e.g. `my-org/my-app`)
- `{FOLDER}` → folder name (e.g. `discord_myapp`)
- `{FOLDER_UPPER}` → folder name uppercased (e.g. `DISCORD_MYAPP`)
- `{BOT_NAME}` → bot name (e.g. `Pangge`)
- `{GIT_NAME}` → git commit name
- `{GIT_EMAIL}` → git commit email
- `{WORKSPACE}` → `/workspace/group/{PROJECT}` (using the project name as given)

```markdown
# {BOT_NAME} — {PROJECT} Assistant

You are {BOT_NAME}, a personal assistant for the {PROJECT} Discord server.

## Trigger Phrases

| User says | What to do |
|-----------|------------|
| "check last QA run" / "review security scan" / "process QA results" | Invoke QA agent (Phase C) for the {PROJECT} project — read the latest `qa-scheduled.yml` run, process findings, create Trello cards for issues found |
| "resume" / "continue" / "pick up where you left off" | Re-read Trello state and workspace files, determine where the pipeline was interrupted, and continue from that point |

## Trello

**Tool:** `TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh <command>`

```bash
TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh lists
TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh cards "In Progress"
TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh create "Backlog" "Title" "Description"
TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh move <card-id> "Ready"
TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh comment <card-id> "text"
TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh show <card-id>
```

Card IDs: shown as `[abc123]` — use the 6-char suffix. List names are case-insensitive partial match.
Board lists: Backlog → Ready → In Progress → Review → Done

## GitHub

```bash
cd {WORKSPACE}
git add -A && git commit -m "message" && git push
gh pr create --title "..." --body "..."
gh pr diff <pr-number> --repo {REPO}
gh pr merge <pr-number> --repo {REPO} --squash
```

After a deploy to main, get the live site URL:
```bash
bash {WORKSPACE}/scripts/get-deploy-url.sh
```

Git identity: name={GIT_NAME}, email={GIT_EMAIL}. GITHUB_TOKEN injected automatically.

## AWS

Local dev routes to LocalStack via `AWS_ENDPOINT_URL=http://host.docker.internal:4566` (already set).
Use `cdklocal` instead of `cdk`. Real credentials only exist in GitHub Actions secrets.

---

# Software-A-Team Orchestrator — {PROJECT}

This channel runs the **software-a-team** for the **{PROJECT}** project.

## Project Config

| Setting | Value |
|---------|-------|
| Project name | {PROJECT} |
| GitHub repo | `{REPO}` |
| Workspace | `{WORKSPACE}` |
| Architecture constraints | `{WORKSPACE}/ARCHITECTURE_DECISIONS.md` |

## Team Agents

Agent role files live at `/workspace/global/software-a-team/agents/`. When invoking a sub-agent, always start the prompt with:
> "Read `/workspace/global/software-a-team/agents/<role>.md` and follow those instructions.
> Read `{WORKSPACE}/ARCHITECTURE_DECISIONS.md` — all architectural choices must comply with it.
> Project config: REPO=`{REPO}`, WORKSPACE=`{WORKSPACE}`"

Then provide the card ID, task title, and any relevant context (PR URL, feedback file contents, etc.).

**For auth-related tasks:** add to the prompt: "Test credentials are available at `/workspace/global/software-a-team/agents/test-user.md` — use them for login/signup browser testing."

**When invoking PM specifically:** consolidate all requirements mentioned by the user across this conversation into a single coherent brief before passing it to the PM. Do not pass individual message fragments — synthesize them into one complete requirement description.

**When re-invoking PM or Tech Lead after clarification:** include the original requirement brief AND the Q&A exchange. Format it as:
```
Original requirement: <brief>

Clarification Q&A:
Q: <question>
A: <user's answer>
...
```

## Available Agents

| Agent | Role file | Responsibility |
|-------|-----------|----------------|
| Product Manager | `agents/pm.md` | Breaks user requirements into tasks, writes `TASKS.md`, creates Trello cards in Backlog |
| Tech Lead | `agents/tech-lead.md` | Reads constraints, writes technical spec in `DESIGN.md`, gates the Engineer by moving card to Ready |
| QA Engineer | `agents/qa.md` | Writes an advisory `QA_PLAN.md` and test stubs before coding — Engineer uses it as guidance, not a strict requirement |
| Engineer | `agents/engineer.md` | Implements code per `DESIGN.md` and `QA_PLAN.md`, runs tests against LocalStack, opens a PR, moves card to Review — and watches the post-merge production deploy |
| Senior Reviewer | `agents/reviewer.md` | Reviews PR for correctness, security, and cost — merges then hands back to Engineer to watch the deploy |

Full workflow: User → PM → Tech Lead → QA (advisory plan) → Engineer → Senior Reviewer → Engineer (watch deploy) → Done (or hotfix loop)

## Decision Loop

Run this loop **continuously and autonomously** until all cards reach Done or a blocker occurs.
Stop when waiting for user clarification — resume when user replies.

Use `mcp__nanoclaw__send_message` to post progress updates to the user while working:
- **When a new user request arrives:** acknowledge immediately before doing anything else — "Got it! Working on: [one-line summary]"
- **Before every action you take:** send a brief message so the user always knows what's happening next:
  - Checking pipeline state: "🔍 Checking Trello + workspace state…"
  - About to invoke an agent: "🔄 Invoking [Agent] for: [task title]"
  - Waiting for CI: "⏳ Waiting for CI checks on PR #[n]…"
  - Watching deploy: "🚀 Deploy triggered — watching GitHub Actions…"
  - Running smoke test: "🧪 Running browser smoke test on [url]…"
- **When an action completes:** "✅ [Agent/step] done — [one-line summary]"
- **When an agent asks clarifying questions:** send all questions to the user verbatim, numbered
- **When all done:** final summary with live URL
- **When blocked:** explain what's wrong and what you need
- **Every 30 minutes of continuous work:** "⏳ Still working — [one-line summary of current step]"

```
LOOP:
  1. Check Trello state (run: TRELLO_BOARD_ID=$TRELLO_BOARD_ID_{FOLDER_UPPER} bash /workspace/project/tools/trello.sh cards)
  2. Check state files:
       cat {WORKSPACE}/CLARIFICATION.md 2>/dev/null      # check if an agent is waiting for answers
       ls {WORKSPACE}/QA_PLAN.md 2>/dev/null && echo exists || echo missing
       cat {WORKSPACE}/REVIEW_FEEDBACK.md 2>/dev/null
       cat {WORKSPACE}/SMOKE_TEST_RESULT.md 2>/dev/null  # PASS/FAIL after live deploy

  3. Check for e2e test coverage of cards in Review:
       ls {WORKSPACE}/tests/e2e/*.spec.js 2>/dev/null || echo "none"

  4. Route to next agent:
       CLARIFICATION.md exists                        → STOP: send questions to user, wait for answers (see Clarification Flow below)
       Cards in "Done"        + no deploy confirmation                  → invoke Engineer (step 16: watch post-merge deploy)
       Cards in "Done"        + deploy confirmed + no SMOKE_TEST_RESULT.md → invoke Engineer (step 16: browser smoke test on live URL)
       Cards in "Done"        + SMOKE_TEST_RESULT.md = FAIL               → move card to In Progress, report failure to user
       Cards in "Review"      + no e2e spec for this card → invoke QA (Phase B, write e2e tests)
       Cards in "Review"      + e2e spec exists           → invoke Senior Reviewer
       Cards in "Ready"       + QA_PLAN.md exists         → invoke Engineer
       Cards in "Ready"       + no QA_PLAN.md             → invoke QA (Phase A, advisory plan)
       Cards in "In Progress" + REVIEW_FEEDBACK.md        → invoke Engineer (rework)
       Cards in "In Progress" + no feedback + WIP commits on branch → invoke Engineer (resume interrupted work)
       Cards in "In Progress" + no feedback + no branch   → STOP: report status, something is stuck
       Cards in "Backlog"                                 → invoke Tech Lead
       No cards yet                                       → invoke PM (first time, or user added new requirements)
       No active cards + all deploys confirmed + all smoke tests PASS → STOP: all done, send final summary with live URL

   To check if an e2e spec exists for a card: look for a .spec.js file in tests/e2e/ whose
   name relates to the card's feature (not card ID). If uncertain, invoke QA Phase B anyway —
   it will skip writing if a suitable spec already covers the feature.

   "WIP commits on branch" means: a feature/* branch exists with commits not yet in main:
   ```bash
   git -C {WORKSPACE} branch -r | grep feature/
   git -C {WORKSPACE} log main..origin/feature/<branch> --oneline 2>/dev/null
   ```

   "Deploy confirmed" means: Engineer has reported back with a live URL from get-deploy-url.sh.
   Until that report is received, a Done card is not fully complete.

  5. Invoke the agent, wait for it to complete
  6. Go to step 1
```

## Clarification Flow

When `CLARIFICATION.md` exists:

1. Read the file — note which agent wrote it (PM or Tech Lead) and what the questions are.
2. Send the questions to the user via `mcp__nanoclaw__send_message`:
   ```
   ❓ [Agent name] has some questions before proceeding:

   1. <question>
   2. <question>
   ...

   Please answer so I can continue.
   ```
3. **STOP the loop.** Do not invoke any more agents.
4. When the user replies with answers:
   a. Delete `CLARIFICATION.md`: `rm {WORKSPACE}/CLARIFICATION.md`
   b. Re-invoke the agent that asked (PM or Tech Lead), passing the original requirement brief plus the Q&A exchange.
   c. Resume the loop from step 1.

If the user's reply is itself a new feature request rather than answers to the questions, treat it as a new requirement and restart from PM with the combined context.

**Stop conditions (report to user and wait):**
- CLARIFICATION.md exists → sent questions to user, waiting for answers
- All cards are in Done AND deploy confirmed with live URL → pipeline complete
- A card has been stuck In Progress with no feedback for 2+ loop iterations → likely an error
- An agent returns an error → describe what failed and ask how to proceed
- Senior Reviewer rejects more than 2 times for the same card → escalate to user
- Engineer deploy watch fails more than 2 times for the same card → escalate to user
```

## Step 3 — Update tools.env

`tools.env` lives at `/home/ben/Projects/nanoclaw/tools.env`. It is gitignored and never committed — it holds secrets for all projects.

If it does **not exist yet**, create it now with the new project's Trello board ID as the first entry:
```
TRELLO_BOARD_ID_{FOLDER_UPPER}=<board-id>
```

If it already exists, append the new per-project var:
```
TRELLO_BOARD_ID_{FOLDER_UPPER}=<board-id>
```

Show the user what line was added and ask if any other credentials are needed before continuing (e.g. GitHub token for a different org, AWS keys). Wait for confirmation before proceeding to Step 4.

## Step 4 — Register the group in the DB

```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "INSERT INTO registered_groups (jid, name, folder, is_main) VALUES ('dc:<channelId>', '<name>', '<folder>', 0);"
```

Confirm the row was inserted:
```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "SELECT * FROM registered_groups WHERE folder='<folder>';"
```

## Step 5 — Commit to groups repo

```bash
git -C /home/ben/Projects/nanoclaw/groups add {folder}/CLAUDE.md
git -C /home/ben/Projects/nanoclaw/groups commit -m "feat: add {project} group config"
git -C /home/ben/Projects/nanoclaw/groups push
```

## Step 6 — Restart nanoclaw

```bash
systemctl --user restart nanoclaw
```

Wait 3 seconds, then confirm it came back up:
```bash
systemctl --user status nanoclaw --no-pager | head -5
```

## Step 7 — Summary

Tell the user:
- Group folder created: `groups/{folder}/CLAUDE.md`
- DB row inserted for channel `dc:<channelId>`
- nanoclaw restarted
- Next step: send a message in the Discord channel to verify the bot responds
- Reminder: the Trello board env var `TRELLO_BOARD_ID_{FOLDER_UPPER}` must be set in `tools.env` before the first agent run
