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
6. **Git identity** — name and email for commits from this channel's agents (e.g. `Pangge, pangge@kuai.family`)
7. **GitHub PAT** — repo-level token for this project (Settings → Developer settings → Fine-grained tokens; scopes: Contents read/write, Pull requests read/write, Actions read)
8. **AWS access key ID** — per-project IAM key (PowerUserAccess recommended)
9. **AWS secret access key** — corresponding secret
10. **AWS region** — default region for this project (e.g. `ap-southeast-2`)

Do NOT ask for a Trello board ID — a new board is created automatically in Step 3.

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
> Project config: REPO=`{REPO}`, WORKSPACE=`{WORKSPACE}`
> Credentials: GH_TOKEN=`$GITHUB_TOKEN_{FOLDER_UPPER}`, AWS_ACCESS_KEY_ID=`$AWS_ACCESS_KEY_ID_{FOLDER_UPPER}`, AWS_SECRET_ACCESS_KEY=`$AWS_SECRET_ACCESS_KEY_{FOLDER_UPPER}`, AWS_DEFAULT_REGION=`$AWS_DEFAULT_REGION_{FOLDER_UPPER}`, TRELLO_BOARD_ID=`$TRELLO_BOARD_ID_{FOLDER_UPPER}`. Prefix all `gh`/`git push` commands with `GH_TOKEN=<value>`, all AWS/CDK commands with the AWS vars, and all `trello.sh` calls with `TRELLO_BOARD_ID=<value>`."

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
       cat {WORKSPACE}/CLARIFICATION.md 2>/dev/null
       ls {WORKSPACE}/QA_PLAN.md 2>/dev/null && echo exists || echo missing
       cat {WORKSPACE}/REVIEW_FEEDBACK.md 2>/dev/null
       cat {WORKSPACE}/SMOKE_TEST_RESULT.md 2>/dev/null
       cat {WORKSPACE}/PR_STATE.md 2>/dev/null

  3. Check GitHub for open and recently merged PRs — source of truth for PR state, independent of Trello:
       GH_TOKEN=$GITHUB_TOKEN_{FOLDER_UPPER} gh pr list --repo {REPO} \
         --state all --json number,title,headRefName,state,mergedAt --limit 10

     Use this to reconcile Trello state. If GitHub shows a PR was merged but the Trello card is not in Done:
     - Move the card to Done
     - Check if SMOKE_TEST_RESULT.md exists — if not, invoke Engineer (step 16: smoke test)

  4. Check for e2e test coverage of cards in Review:
       ls {WORKSPACE}/tests/e2e/*.spec.js 2>/dev/null || echo "none"

  5. Route to next agent:
       CLARIFICATION.md exists                        → STOP: send questions to user, wait for answers (see Clarification Flow below)
       Cards in "Done"        + no deploy confirmation                  → invoke Engineer (step 16: watch post-merge deploy)
       Cards in "Done"        + deploy confirmed + no SMOKE_TEST_RESULT.md → invoke Engineer (step 16: browser smoke test on live URL)
       Cards in "Done"        + SMOKE_TEST_RESULT.md = FAIL               → move card to In Progress, report failure to user
       Cards in "Review"      + no e2e spec for this card → invoke QA (Phase B, write e2e tests)
       Cards in "Review"      + e2e spec exists           → invoke Senior Reviewer
       Cards in "Ready"       + QA_PLAN.md exists         → invoke Engineer
       Cards in "Ready"       + no QA_PLAN.md             → invoke QA (Phase A, advisory plan)
       PR_STATE.md STEP=watching-deploy                   → invoke Engineer (step 16: resume deploy watch)
       PR_STATE.md STEP=waiting-ci                        → invoke Engineer (step 10: resume CI watch for PR in PR_STATE.md)
       Cards in "In Progress" + REVIEW_FEEDBACK.md        → invoke Engineer (rework)
       Cards in "In Progress" + no feedback + WIP commits on branch → invoke Engineer (resume interrupted work — pass PR_STATE.md contents if it exists)
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

  6. Invoke the agent, wait for it to complete
  7. Go to step 1
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

## Step 3 — Create Trello board and update tools.env

### 3a — Create Trello board

Use the shared `TRELLO_API_KEY` and `TRELLO_TOKEN` from `tools.env` to create a new board and the standard lists:

```bash
# Create board (returns JSON with .id)
BOARD_ID=$(curl -s -X POST "https://api.trello.com/1/boards/" \
  -d "name={PROJECT}&defaultLists=false&key=$TRELLO_API_KEY&token=$TRELLO_TOKEN" \
  | jq -r '.id')

# Create lists in order (Trello adds them bottom-up, so create in reverse)
for LIST in Done Review "In Progress" Ready Backlog; do
  curl -s -X POST "https://api.trello.com/1/lists" \
    -d "name=$LIST&idBoard=$BOARD_ID&key=$TRELLO_API_KEY&token=$TRELLO_TOKEN" > /dev/null
done

echo "Board ID: $BOARD_ID"
```

Save the board ID — it is used in the next step. Do NOT print or log the API key or token values.

### 3b — Write tools.env

`tools.env` lives at `/home/ben/Projects/nanoclaw/tools.env`. It is gitignored and never committed.

If it does **not exist yet**, create it with these entries:
```
# {PROJECT}
TRELLO_BOARD_ID_{FOLDER_UPPER}=<board-id from 3a>
GITHUB_TOKEN_{FOLDER_UPPER}=<github-pat>
AWS_ACCESS_KEY_ID_{FOLDER_UPPER}=<aws-key-id>
AWS_SECRET_ACCESS_KEY_{FOLDER_UPPER}=<aws-secret>
AWS_DEFAULT_REGION_{FOLDER_UPPER}=<aws-region>
```

If it already exists, append the same block for the new project.

**Security:** Never print, echo, or log any credential values. When confirming to the user, show only the variable names and mask secret values to `****<last4>`. These credentials are per-project — rotating one does not affect others.

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
- Trello board created with lists: Backlog → Ready → In Progress → Review → Done
- Group folder created: `groups/{folder}/CLAUDE.md`
- credentials written to `tools.env` (never show actual values)
- DB row inserted for channel `dc:<channelId>`
- nanoclaw restarted
- Next step: send a message in the Discord channel to verify the bot responds
