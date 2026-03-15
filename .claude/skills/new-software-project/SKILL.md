---
name: new-software-project
description: Set up a new Software-A-Team project with Discord channel, group config, DB registration, and nanoclaw restart.
---

# New Project Setup

This skill is split into two parts:
- **Part 1 (manual):** Things you must set up in external services before running this skill
- **Part 2 (automated):** What this skill does once you have everything ready

---

## Part 1 — Prerequisites (do these before running the skill)

Ask the user: **"What type of project is this?"**

Options: `web` | `ios` | `android` | `saas` | `library`

Then show the relevant checklist and ask them to confirm everything is ready before continuing.

---

### Universal (all project types)

- [ ] **GitHub** — Create the repo (public or private). Generate a fine-grained PAT:
  - Settings → Developer settings → Fine-grained personal access tokens
  - Scopes: Contents (read/write), Pull requests (read/write), Actions (read)
  - Set expiry and note the rotation date

- [ ] **AWS** — Create a dedicated IAM user for this project:
  1. IAM → Users → Create user (e.g. `myapp-agent`)
  2. Attach managed policy: `PowerUserAccess`
  3. Add inline policy for CDK role management:
     ```json
     {
       "Effect": "Allow",
       "Action": ["iam:CreateRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
                  "iam:DeleteRole", "iam:PassRole", "iam:GetRole", "iam:ListRolePolicies",
                  "iam:ListAttachedRolePolicies"],
       "Resource": "arn:aws:iam::*:role/{project}-*"
     }
     ```
     Replace `{project}` with the project name prefix (e.g. `myapp-*`).
  4. Security credentials → Create access key → Application running outside AWS → save key ID + secret

- [ ] **Google Cloud** — Create one dedicated GCP project per app (isolates billing, quotas, and credentials):
  1. console.cloud.google.com → New Project → name it after the app (e.g. `myapp-prod`) → note the **Project ID**
  2. Enable APIs under APIs & Services → Library — enable all that apply to your project type:
     - **All types:** reCAPTCHA Enterprise API
     - **Web/SaaS (Google Sign-In):** Google Identity API
     - **iOS/Android:** Firebase services are enabled automatically when you add Firebase below
     - **Android:** Google Play Android Developer API
  3. Create a **service account** for the agent:
     - IAM & Admin → Service Accounts → Create → name it `agent` (e.g. `agent@myapp-prod.iam.gserviceaccount.com`)
     - Grant roles (add all that apply to your project type):
       - **All types:** `reCAPTCHA Enterprise Admin`
       - **iOS/Android:** `Firebase Admin` (`roles/firebase.admin`)
       - **Android:** grant "Release Manager" in Google Play Console separately (see Android adds below)
     - Keys → Add Key → JSON → download and save the JSON file securely
  4. **Google Sign-In / OAuth (web/saas only):** set up OAuth credentials for "Sign in with Google":
     - APIs & Services → OAuth consent screen → External → fill in app name, support email, developer email → Save
     - APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID → Web application
     - Add authorised redirect URIs (e.g. `https://www.myapp.com/auth/google/callback`)
     - Note the **Client ID** (public) and **Client Secret** (private)
  5. **Firebase (iOS/Android only):** go to console.firebase.google.com → Add project → select the GCP project you just created (do NOT create a new Firebase project — link to the existing one). Add iOS/Android app, download config files.

- [ ] **Discord** — Create the channel in the server. Enable Developer Mode (User Settings → Advanced), right-click the channel → Copy Channel ID.

---

### Web / SaaS adds

- [ ] **Cloudflare** — Add the domain to Cloudflare. Create an API token:
  - My Profile → API Tokens → Create Token → Custom token
  - Permissions: Zone / Zone / Read + Zone / DNS / Edit + (if using Pages/Workers) Account / Cloudflare Pages / Edit
  - Scope: your specific zone
  - Save the token, **Account ID** (right sidebar of the Cloudflare dashboard), and **Zone ID** (right sidebar when viewing the domain)

- [ ] **Email sending** — Choose one: Sendgrid, Resend, or Postmark.
  - Create account, verify sending domain, generate API key
  - Note: AWS SES is an option if keeping everything in AWS — verify domain in SES console

---

### iOS adds

- [ ] **Apple Developer** — Create App ID at developer.apple.com (Certificates → Identifiers)
- [ ] **App Store Connect API key** — Users and Access → Integrations → App Store Connect API → Generate key. Download the `.p8` file (can only be downloaded once). Note the Issuer ID and Key ID.
- [ ] **Firebase config file** — from the Firebase project created above: download `GoogleService-Info.plist` for the iOS app

---

### Android adds

- [ ] **Google Play Console** — Create the app. Then link it to your GCP project:
  - Setup → API access → Link to existing Google Cloud project → select the GCP project you created above
  - Grant the `agent` service account "Release Manager" role in Play Console (IAM → Service accounts → find `agent@...` → grant role)
- [ ] **Firebase config file** — from the Firebase project created above: download `google-services.json` for the Android app
- [ ] **Signing keystore** — Generate on the host machine:
  ```bash
  keytool -genkey -v -keystore myapp.jks -alias myapp -keyalg RSA -keysize 2048 -validity 10000
  ```
  Store the `.jks` file, alias, key password, and store password securely.

---

### SaaS adds (in addition to web)

- [ ] **Stripe** — Create account at stripe.com. Developers → API keys → copy secret key. Set up webhook endpoint and copy webhook secret.
- [ ] **Sentry** — Create project at sentry.io. Settings → Projects → Client Keys → copy DSN. Settings → Auth Tokens → create token for the agent.

---

## Part 2 — Skill execution (automated)

Once the user confirms prerequisites are done, proceed with the steps below.

---

## Step 1 — Collect inputs

Ask for all of the following (can ask in one message):

**Universal:**
1. **Project name** — display name (e.g. `MyApp`)
2. **GitHub repo** — `org/repo` (e.g. `my-org/my-app`)
3. **Discord channel ID** — copied in prerequisites
4. **Folder name** — snake_case group folder (e.g. `discord_myapp`)
5. **Bot name** — what the assistant calls itself (e.g. `Pangge`)
6. **Git identity** — name and email for agent commits (e.g. `Pangge, pangge@kuai.family`)
7. **GitHub PAT** — from prerequisites
8. **AWS access key ID** — from prerequisites
9. **AWS secret access key** — from prerequisites
10. **AWS region** — default region (e.g. `ap-southeast-2`)

**Universal adds (all types):**
11. **Google Cloud project ID** — from prerequisites
12. **GCP service account JSON path** — path on host machine to the downloaded JSON key file

**Web / SaaS adds:**
13. **Cloudflare API token** — from prerequisites
14. **Cloudflare account ID** — from prerequisites (dashboard right sidebar)
15. **Cloudflare zone ID** — from prerequisites (domain right sidebar)
16. **Email API key** — Sendgrid / Resend / Postmark key from prerequisites
17. **Google OAuth client ID** — from prerequisites (if using Google Sign-In)
18. **Google OAuth client secret** — from prerequisites (if using Google Sign-In)

**iOS adds:**
13. **App Store Connect Issuer ID**
14. **App Store Connect Key ID**
15. **App Store Connect p8 file path** — path on host machine to the `.p8` file
16. **Firebase config file path** — path to `GoogleService-Info.plist`

**Android adds:**
13. **Keystore path + alias + passwords**
14. **Firebase config file path** — path to `google-services.json`

**SaaS adds:**
13. **Stripe secret key**
14. **Stripe webhook secret**
15. **Sentry DSN**
16. **Sentry auth token**

Do NOT ask for a Trello board ID — it is created automatically in Step 3.

---

## Step 2 — Create group folder and CLAUDE.md

Create `groups/{folder}/CLAUDE.md` using the template below. Substitute all placeholders:

- `{PROJECT}` → project name
- `{REPO}` → GitHub repo
- `{FOLDER}` → folder name
- `{FOLDER_UPPER}` → folder name uppercased
- `{BOT_NAME}` → bot name
- `{GIT_NAME}` → git commit name
- `{GIT_EMAIL}` → git commit email
- `{WORKSPACE}` → `/workspace/group/{PROJECT}`

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
Board lists: Backlog → Ready → In Progress → Review → Deploying → Smoke Test → Done

## GitHub

```bash
cd {WORKSPACE}
GH_TOKEN=$GITHUB_TOKEN_{FOLDER_UPPER} git add -A && git commit -m "message" && git push
GH_TOKEN=$GITHUB_TOKEN_{FOLDER_UPPER} gh pr create --title "..." --body "..."
GH_TOKEN=$GITHUB_TOKEN_{FOLDER_UPPER} gh pr diff <pr-number> --repo {REPO}
GH_TOKEN=$GITHUB_TOKEN_{FOLDER_UPPER} gh pr merge <pr-number> --repo {REPO} --squash
```

After a deploy to main, get the live site URL:
```bash
bash {WORKSPACE}/scripts/get-deploy-url.sh
```

Git identity: name={GIT_NAME}, email={GIT_EMAIL}.

## AWS

Local dev routes to LocalStack via `AWS_ENDPOINT_URL=http://host.docker.internal:4566` (already set).
Use `cdklocal` instead of `cdk`. Real credentials only exist in GitHub Actions secrets.

Prefix all AWS/CDK commands with the scoped credentials:
```bash
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_{FOLDER_UPPER} \
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_{FOLDER_UPPER} \
AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION_{FOLDER_UPPER} \
cdklocal deploy
```

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

Each invocation handles **one step** of the pipeline, then hands control back to nanoclaw.
Do not loop — check state, invoke one agent, write the requeue IPC, then exit.
When waiting for user input (clarification, all done, blocked), exit without requeueing.

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
- **Every 10 minutes of continuous work:** "⏳ Still working — [one-line summary of current step]"

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

     Use this to reconcile Trello state. If GitHub shows a PR was merged but the Trello card is not in Deploying/Smoke Test/Done:
     - Move the card to Deploying
     - The routing in step 5 will then invoke the Engineer to watch the deploy

  4. Check for e2e test coverage of cards in Review:
       ls {WORKSPACE}/tests/e2e/*.spec.js 2>/dev/null || echo "none"

  5. Route to next agent:
       CLARIFICATION.md exists                              → STOP (exit without requeue): send questions to user, wait for answers
       Cards in "Smoke Test"  + SMOKE_TEST_RESULT.md = PASS → move card to Done, then REQUEUE
       Cards in "Smoke Test"  + SMOKE_TEST_RESULT.md = FAIL → STOP (exit without requeue): move card to In Progress, report failure to user
       Cards in "Smoke Test"  + no SMOKE_TEST_RESULT.md    → invoke Engineer (step 16: run browser smoke test on live URL)
       Cards in "Deploying"                                 → invoke Engineer (step 16: watch deploy in progress)
       Cards in "Review"      + no e2e spec for this card  → invoke QA (Phase B, write e2e tests)
       Cards in "Review"      + e2e spec exists            → invoke Senior Reviewer
       Cards in "Ready"       + QA_PLAN.md exists          → invoke Engineer
       Cards in "Ready"       + no QA_PLAN.md              → invoke QA (Phase A, advisory plan)
       PR_STATE.md STEP=waiting-ci                         → invoke Engineer (step 10: resume CI watch for PR in PR_STATE.md)
       Cards in "In Progress" + REVIEW_FEEDBACK.md         → invoke Engineer (rework)
       Cards in "In Progress" + no feedback + WIP commits on branch → invoke Engineer (resume interrupted work — pass PR_STATE.md contents if it exists)
       Cards in "In Progress" + no feedback + no branch    → STOP (exit without requeue): report status, something is stuck
       Cards in "Backlog"                                   → invoke Tech Lead
       No cards yet                                         → invoke PM (first time, or user added new requirements)
       No active cards + all cards in Done                  → STOP (exit without requeue): all done, send final summary with live URL

   To check if an e2e spec exists for a card: look for a .spec.js file in tests/e2e/ whose
   name relates to the card's feature (not card ID). If uncertain, invoke QA Phase B anyway —
   it will skip writing if a suitable spec already covers the feature.

   "WIP commits on branch" means: a feature/* branch exists with commits not yet in main:
   ```bash
   git -C {WORKSPACE} branch -r | grep feature/
   git -C {WORKSPACE} log main..origin/feature/<branch> --oneline 2>/dev/null
   ```

  6. Invoke the agent, wait for it to complete
  7. Write the requeue IPC to trigger the next step in a fresh container:
       echo '{"type":"requeue"}' > /workspace/ipc/messages/requeue-$(date +%s%N).json
     Then exit. nanoclaw will start a new container for the next step automatically.
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
- All cards are in Done → pipeline complete, send final summary with live URL
- A card has been stuck In Progress with no WIP branch for 5+ loop iterations → something is fundamentally stuck, report and wait
- An agent returns an error → retry once with a fresh invocation before escalating; only stop if it fails twice in a row
- Senior Reviewer rejects more than 3 times for the same card → escalate to user
- Engineer deploy watch fails more than 3 times for the same card → escalate to user
```

---

## Step 2b — Create ARCHITECTURE_DECISIONS.md

Create `groups/{folder}/{PROJECT}/ARCHITECTURE_DECISIONS.md` using the template for the chosen project type. Substitute `{PROJECT}` throughout.

> **Note:** The bottom section (PR Track decisions) always starts empty — agents append to it as they implement features.

---

### Template: web or saas

```markdown
# Architecture Decisions

This file is the source of truth for all technical constraints. All agents must read it before making architectural choices.

## Environments & URLs

- **Production URL:** (set after first deploy)
- **Staging URL:** (set after first deploy)

## Cloud & Infrastructure

- **Cloud provider:** AWS only. No GCP, Azure, or multi-cloud.
- **IaC:** AWS CDK (TypeScript). No CloudFormation YAML, Terraform, or SAM.
- **Primary region:** `ap-southeast-2` (Sydney) for all application resources (Lambda, DynamoDB, S3, API Gateway, ECS, etc.).
- **Global/US-East-1 exceptions — these must always use `us-east-1`:**
  - **ACM certificates** used by CloudFront (CloudFront requires certs in us-east-1, no exceptions)
  - **Cognito User Pool** (us-east-1 has the broadest feature support and is the standard default)
  - **SES** (us-east-1 has the highest sending limits and best deliverability)
  - **Route 53** is global — no region applies
- **CI/CD:** GitHub Actions only.

## Runtime & Language

- **Language:** TypeScript (Node.js 22). No Python, Go, or other runtimes unless explicitly approved.
- **Runtime target:** AWS Lambda (preferred) or ECS Fargate for long-running processes.
- **Package manager:** npm. No yarn or pnpm.

## Frontend

- **Hosting:** S3 + CloudFront. No Vercel, Netlify, or other third-party hosting.
- **Framework:** Vanilla HTML/JS/CSS unless a framework is explicitly justified. No React/Vue/Angular unless approved.

## Auth

- **Provider:** AWS Cognito (User Pool). No Firebase Auth, Auth0, or custom auth.
- **JWT:** Validated at API Gateway level (JWT authorizer). Lambda reads pre-validated claims — never validates JWT itself.

## Google Services

- **One dedicated GCP project per app** — credentials and quotas are isolated per project.
- **Two credential types from GCP:**
  - **Service account JSON** — used by the agent and backend Lambda for server-side Google API calls (reCAPTCHA, Firebase Admin, Play API). Stored in AWS Secrets Manager. Never committed.
  - **OAuth 2.0 client** — used for "Sign in with Google". Client ID is public (injected at deploy time). Client Secret is stored in AWS Secrets Manager. Never committed.
- **reCAPTCHA Enterprise** (score-based, equivalent to v3) for bot protection on login/signup. Score threshold: 0.5. Free tier: 1M assessments/month. Server-side verification uses the service account via `@google-cloud/recaptcha-enterprise` SDK.
- **Google Sign-In**: OAuth 2.0 authorization code flow. Backend exchanges the auth code for tokens using the OAuth client secret. Cognito can be configured as the identity broker (federation) or the backend can handle token exchange directly.
- Additional Google APIs (Maps, etc.) use the same GCP project — enable per-API and grant the required role to the `agent` service account.

## API Design

- **Style:** REST over HTTPS. GraphQL only if explicitly requested.
- **API Gateway:** AWS API Gateway v2 (HTTP API). Not REST API (v1) unless required.

## Data

- **Primary database:** DynamoDB (single-table design preferred).
- **File storage:** S3.
- **Caching:** ElastiCache (Redis) only if latency requirements demand it.
- **No relational databases** unless explicitly approved.

## Security

- **Secrets:** AWS Secrets Manager only. No hardcoded credentials, no SSM Parameter Store for secrets.
- **IAM:** Least-privilege. No `*` actions in production policies.
- **Encryption:** All S3 buckets encrypted at rest. All data in transit via HTTPS.

## Code Quality

- **Tests:** All code must have unit tests. Minimum 80% coverage.
- **Linting:** ESLint with TypeScript rules.
- **No `any` types** in TypeScript without an explicit comment explaining why.

## Cost Guardrails

- **Prefer serverless** (Lambda, DynamoDB on-demand) over provisioned resources.
- **No NAT Gateways** without approval — use VPC endpoints instead.
- **Lambda:** max 512MB memory, max 30s timeout unless explicitly justified in `DESIGN.md`.
- **DynamoDB:** on-demand billing only. No provisioned capacity.
- **No multi-AZ RDS.** Use DynamoDB.
- **S3:** no Glacier or intelligent tiering unless storing >1GB of infrequently accessed data.
- **All CDK resources must include a cost allocation tag:**
  ```typescript
  Tags.of(app).add('Project', '{PROJECT}');
  Tags.of(app).add('Environment', 'production'); // or 'staging'
  ```
- **CDK diff runs on every PR** and posts a comment showing all resource changes. The Senior Reviewer must review it before merging — reject if new resources are created without justification in `DESIGN.md`.
```

---

### Template: ios

```markdown
# Architecture Decisions

This file is the source of truth for all technical constraints. All agents must read it before making architectural choices.

## Environments & URLs

- **App Store:** (set after first submission)
- **TestFlight:** (set after first build)
- **API base URL:** (set after backend deploy)

## Platform & Language

- **Language:** Swift (latest stable). No Objective-C unless integrating a legacy SDK.
- **Minimum iOS version:** iOS 16.
- **Package manager:** Swift Package Manager. No CocoaPods or Carthage unless a dependency requires it.
- **Xcode version:** latest stable.

## Architecture

- **Pattern:** MVVM. No MVC or VIPER unless explicitly approved.
- **Async:** Swift Concurrency (async/await). No Combine or callbacks unless integrating a third-party SDK.

## Auth

- **Provider:** AWS Cognito via Amplify iOS SDK or direct HTTPS calls to Cognito endpoints.
- **Token storage:** Keychain only. Never UserDefaults.

## Backend

- **Cloud provider:** AWS only.
- **IaC:** AWS CDK (TypeScript). CI/CD via GitHub Actions.
- **Primary region:** `ap-southeast-2` for all application resources. Cognito, ACM (CloudFront certs), and SES must use `us-east-1`.

## Distribution

- **App Store distribution:** via App Store Connect API (fastlane or direct API calls).
- **Signing:** Xcode automatic signing for development. Manual signing for release using `.p8` key from App Store Connect.
- **CI builds:** GitHub Actions with Xcode Cloud or self-hosted macOS runner.

## Code Quality

- **Tests:** XCTest for unit tests. XCUITest for UI tests.
- **Linting:** SwiftLint.
- **No force unwrap** (`!`) without an explicit comment explaining why it is safe.

## Security

- **No hardcoded secrets** in source. Use environment variables injected at build time or fetched from backend.
- **Certificate pinning** for all API calls in production.
```

---

### Template: android

```markdown
# Architecture Decisions

This file is the source of truth for all technical constraints. All agents must read it before making architectural choices.

## Environments & URLs

- **Play Store:** (set after first submission)
- **Internal testing track:** (set after first build)
- **API base URL:** (set after backend deploy)

## Platform & Language

- **Language:** Kotlin. No Java unless integrating a legacy SDK.
- **Minimum SDK:** API 26 (Android 8.0).
- **Build system:** Gradle (Kotlin DSL). No Maven.
- **Package manager:** Gradle dependencies only. No manual JAR imports.

## Architecture

- **Pattern:** MVVM with ViewModel + LiveData/StateFlow. No MVC.
- **Async:** Kotlin Coroutines. No RxJava unless integrating a third-party SDK.
- **DI:** Hilt. No Dagger directly or Koin unless approved.

## Auth

- **Provider:** AWS Cognito via Amplify Android SDK or direct HTTPS calls.
- **Token storage:** EncryptedSharedPreferences. Never plain SharedPreferences for tokens.

## Backend

- **Cloud provider:** AWS only.
- **IaC:** AWS CDK (TypeScript). CI/CD via GitHub Actions.
- **Primary region:** `ap-southeast-2` for all application resources. Cognito, ACM (CloudFront certs), and SES must use `us-east-1`.

## Distribution

- **Play Store distribution:** via Google Play Developer API (service account JSON key).
- **Signing:** debug keystore for development. Release keystore stored securely — never committed to source.
- **CI builds:** GitHub Actions.

## Code Quality

- **Tests:** JUnit 4/5 for unit tests. Espresso for UI tests.
- **Linting:** ktlint + Android Lint.
- **No `!!` (non-null assertion)** without an explicit comment explaining why it is safe.

## Security

- **No hardcoded secrets.** Use BuildConfig fields injected from CI environment variables.
- **Certificate pinning** for all API calls in production.
- **ProGuard/R8** enabled for release builds.
```

---

### Template: library

```markdown
# Architecture Decisions

This file is the source of truth for all technical constraints. All agents must read it before making architectural choices.

## Package

- **Registry:** npm (public or scoped private).
- **Package manager:** npm. No yarn or pnpm.
- **Language:** TypeScript. Compiled to both ESM and CJS. Type declarations included.
- **Node.js:** support LTS versions (current and previous LTS).

## Versioning

- **Scheme:** Semantic Versioning (semver). Breaking changes require a major bump.
- **Changelog:** `CHANGELOG.md` updated on every release following Keep a Changelog format.
- **Release:** via GitHub Actions on tag push (`v*`). No manual npm publish.

## API Design

- **Surface area:** keep public API minimal. Mark internal helpers with `@internal` JSDoc tag.
- **No side effects** at import time.
- **Tree-shakeable:** named exports preferred over default exports.

## Dependencies

- **Zero runtime dependencies** unless absolutely necessary — justify each one in `DESIGN.md`.
- **Peer dependencies:** declare framework dependencies (React, etc.) as `peerDependencies`, not `dependencies`.
- **Dev dependencies only** for testing, building, and linting.

## Code Quality

- **Tests:** Vitest or Jest. Minimum 90% coverage for public API surface.
- **Linting:** ESLint with TypeScript rules.
- **No `any` types** without an explicit comment explaining why.
- **Formatting:** Prettier.

## Security

- **No hardcoded secrets** or environment-specific config.
- **Dependency audit** runs on every PR (`npm audit`).
```

---

## Step 2c — Bootstrap Google services (web/saas only)

Skip this step for iOS, Android, and library projects.

Using the GCP service account JSON from `infra.env`, bootstrap reCAPTCHA Enterprise and store the credentials automatically. The service account JSON path is in `$GOOGLE_SERVICE_ACCOUNT_JSON_{FOLDER_UPPER}`.

```bash
SA_JSON="$GOOGLE_SERVICE_ACCOUNT_JSON_{FOLDER_UPPER}"
PROJECT_ID="$GOOGLE_CLOUD_PROJECT_ID_{FOLDER_UPPER}"
DOMAIN="{production-domain}"  # e.g. www.myapp.com

# Authenticate with the service account
gcloud auth activate-service-account --key-file="$SA_JSON"
gcloud config set project "$PROJECT_ID"

# Create reCAPTCHA Enterprise key (web, score-based / v3-equivalent)
RECAPTCHA_RESPONSE=$(curl -s -X POST \
  "https://recaptchaenterprise.googleapis.com/v1/projects/${PROJECT_ID}/keys" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"displayName\": \"{PROJECT}\",
    \"webSettings\": {
      \"allowedDomains\": [\"$DOMAIN\", \"localhost\"],
      \"integrationType\": \"SCORE\"
    }
  }")

SITE_KEY=$(echo "$RECAPTCHA_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['name'].split('/')[-1])")
echo "reCAPTCHA site key: $SITE_KEY"

# Store the service account JSON itself in AWS Secrets Manager as the reCAPTCHA "secret"
# (For reCAPTCHA Enterprise, server-side verification uses the service account, not a secret key)
SECRET_ARN=$(AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_{FOLDER_UPPER} \
  AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_{FOLDER_UPPER} \
  AWS_DEFAULT_REGION=us-east-1 \
  aws secretsmanager create-secret \
    --name "{PROJECT}/recaptcha-service-account" \
    --description "GCP service account for reCAPTCHA Enterprise verification" \
    --secret-string "$(cat $SA_JSON)" \
    --query ARN --output text)
echo "Secret ARN: $SECRET_ARN"

# Push to GitHub secrets
GH_TOKEN=<github-pat> gh secret set RECAPTCHA_SITE_KEY   --repo {REPO} --body "$SITE_KEY"
GH_TOKEN=<github-pat> gh secret set RECAPTCHA_SECRET_ARN --repo {REPO} --body "$SECRET_ARN"
```

Confirm to the user:
- reCAPTCHA Enterprise key created in project `{PROJECT}`
- Secret stored in AWS Secrets Manager (`us-east-1`)
- `RECAPTCHA_SITE_KEY` and `RECAPTCHA_SECRET_ARN` set as GitHub secrets on `{REPO}`

> **Note:** reCAPTCHA Enterprise server-side verification works differently from v3 — the Lambda verifies tokens using the GCP service account (via the secret ARN above) instead of a plain secret key. The engineer must use the `@google-cloud/recaptcha-enterprise` SDK, not the simple REST endpoint used for v3.

---

## Step 3 — Create Trello board and update credential files

### 3a — Create Trello board

Use the shared `TRELLO_API_KEY` and `TRELLO_TOKEN` from `agents.env` to create a new board and the standard lists:

```bash
# Create board (returns JSON with .id)
BOARD_ID=$(curl -s -X POST "https://api.trello.com/1/boards/" \
  -d "name={PROJECT}&defaultLists=false&key=$TRELLO_API_KEY&token=$TRELLO_TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# Create lists in order (Trello adds bottom-up, so create in reverse)
for LIST in Done "Smoke Test" Deploying Review "In Progress" Ready Backlog; do
  curl -s -X POST "https://api.trello.com/1/lists" \
    -d "name=$LIST&idBoard=$BOARD_ID&key=$TRELLO_API_KEY&token=$TRELLO_TOKEN" > /dev/null
done

echo "Board created: $BOARD_ID"
```

Do NOT print or log the API key or token values.

### 3b — Write credential files

Credentials are split into two files in `/home/ben/Projects/nanoclaw/groups/`. Both are gitignored — never committed, even to the private groups repo.

| File | Who uses it | Access level |
|------|------------|-------------|
| `infra.env` | Orchestrator (Pangge) | Admin — create/manage cloud resources |
| `agents.env` | Sub-agents (Engineer, QA, etc.) | Project-scoped — repo push, Trello, read-only cloud |

**Append to `infra.env`** (admin credentials for the orchestrator):

```
# {PROJECT} — infra admin
AWS_ACCESS_KEY_ID_{FOLDER_UPPER}=<aws-key-id>
AWS_SECRET_ACCESS_KEY_{FOLDER_UPPER}=<aws-secret>
AWS_DEFAULT_REGION_{FOLDER_UPPER}=<aws-region>
GOOGLE_CLOUD_PROJECT_ID_{FOLDER_UPPER}=<gcp-project-id>
GOOGLE_SERVICE_ACCOUNT_JSON_{FOLDER_UPPER}=<host-path-to-service-account-json>
```

Add infra-level extras for the project type (omit lines that don't apply):

```
# Web / SaaS
CLOUDFLARE_API_TOKEN_{FOLDER_UPPER}=<token>
CLOUDFLARE_ACCOUNT_ID_{FOLDER_UPPER}=<account-id>
CLOUDFLARE_ZONE_ID_{FOLDER_UPPER}=<zone-id>
GOOGLE_OAUTH_CLIENT_ID_{FOLDER_UPPER}=<oauth-client-id>       # if using Google Sign-In
GOOGLE_OAUTH_CLIENT_SECRET_{FOLDER_UPPER}=<oauth-client-secret> # if using Google Sign-In

# iOS
APP_STORE_CONNECT_ISSUER_ID_{FOLDER_UPPER}=<id>
APP_STORE_CONNECT_KEY_ID_{FOLDER_UPPER}=<key-id>
APP_STORE_CONNECT_P8_PATH_{FOLDER_UPPER}=<host-path-to-p8>
FIREBASE_CONFIG_IOS_{FOLDER_UPPER}=<host-path-to-GoogleService-Info.plist>

# Android
ANDROID_KEYSTORE_PATH_{FOLDER_UPPER}=<host-path-to-jks>
ANDROID_KEY_ALIAS_{FOLDER_UPPER}=<alias>
ANDROID_KEY_PASSWORD_{FOLDER_UPPER}=<password>
ANDROID_STORE_PASSWORD_{FOLDER_UPPER}=<password>
FIREBASE_CONFIG_ANDROID_{FOLDER_UPPER}=<host-path-to-google-services.json>

# SaaS
STRIPE_SECRET_KEY_{FOLDER_UPPER}=<key>
STRIPE_WEBHOOK_SECRET_{FOLDER_UPPER}=<secret>
SENTRY_DSN_{FOLDER_UPPER}=<dsn>
SENTRY_AUTH_TOKEN_{FOLDER_UPPER}=<token>
```

**Append to `agents.env`** (project-scoped credentials for sub-agents):

```
# {PROJECT} — sub-agent credentials
TRELLO_BOARD_ID_{FOLDER_UPPER}=<board-id from 3a>
GITHUB_TOKEN_{FOLDER_UPPER}=<github-pat>
AWS_RO_ACCESS_KEY_ID_{FOLDER_UPPER}=test
AWS_RO_SECRET_ACCESS_KEY_{FOLDER_UPPER}=test
AWS_RO_DEFAULT_REGION_{FOLDER_UPPER}=<aws-region>
EMAIL_API_KEY_{FOLDER_UPPER}=<key>
```

Note: Sub-agents get `AWS_RO_*` (read-only / LocalStack) credentials, not the admin `AWS_*` keys. For real AWS access, credentials live only in GitHub Actions secrets.

**Security:** Never print, echo, or log any credential values. When confirming to the user, show only the variable names and mask secret values to `****<last4>`. These credentials are per-project — rotating one does not affect others.

---

## Step 4 — Push credentials to GitHub repo secrets

Use `gh secret set --repo {REPO}` for every credential. The `--repo` flag is required to target the specific repo rather than any default context.

**Universal (all project types):**
```bash
GH_TOKEN=<github-pat> gh secret set AWS_ACCESS_KEY_ID           --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set AWS_SECRET_ACCESS_KEY       --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set AWS_DEFAULT_REGION          --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set GOOGLE_CLOUD_PROJECT_ID     --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set GOOGLE_SERVICE_ACCOUNT_JSON --repo {REPO} --body "$(cat <path-to-service-account-json>)"
# RECAPTCHA_SITE_KEY and RECAPTCHA_SECRET_ARN are set automatically by Step 2c
```

**Web / SaaS adds:**
```bash
GH_TOKEN=<github-pat> gh secret set CLOUDFLARE_API_TOKEN        --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set CLOUDFLARE_ACCOUNT_ID       --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set CLOUDFLARE_ZONE_ID          --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set EMAIL_API_KEY               --repo {REPO} --body "<value>"
# If using Google Sign-In:
GH_TOKEN=<github-pat> gh secret set GOOGLE_OAUTH_CLIENT_ID      --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set GOOGLE_OAUTH_CLIENT_SECRET  --repo {REPO} --body "<value>"
```

**iOS adds:**
```bash
GH_TOKEN=<github-pat> gh secret set APP_STORE_CONNECT_ISSUER_ID  --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set APP_STORE_CONNECT_KEY_ID     --repo {REPO} --body "<value>"
# p8 file — base64-encode it first, decode in the workflow
GH_TOKEN=<github-pat> gh secret set APP_STORE_CONNECT_P8_BASE64  --repo {REPO} --body "$(base64 -w0 <path-to-p8>)"
```

**Android adds:**
```bash
GH_TOKEN=<github-pat> gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON --repo {REPO} --body "$(cat <path-to-json>)"
GH_TOKEN=<github-pat> gh secret set ANDROID_KEYSTORE_BASE64          --repo {REPO} --body "$(base64 -w0 <path-to-jks>)"
GH_TOKEN=<github-pat> gh secret set ANDROID_KEY_ALIAS                --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set ANDROID_KEY_PASSWORD             --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set ANDROID_STORE_PASSWORD           --repo {REPO} --body "<value>"
```

**SaaS adds:**
```bash
GH_TOKEN=<github-pat> gh secret set STRIPE_SECRET_KEY       --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set STRIPE_WEBHOOK_SECRET   --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set SENTRY_AUTH_TOKEN       --repo {REPO} --body "<value>"
GH_TOKEN=<github-pat> gh secret set SENTRY_DSN              --repo {REPO} --body "<value>"
```

**Security:** Never print credential values. Confirm to the user by listing the secret names that were set (not the values), e.g.:
```
✅ GitHub secrets set on {REPO}:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION,
  CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, EMAIL_API_KEY
```

Note: The GitHub PAT itself is not pushed as a secret — it's already in `agents.env` for agent use and the workflow can use the built-in `GITHUB_TOKEN` for same-repo operations.

---

## Step 5 — Register the group in the DB

```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "INSERT INTO registered_groups (jid, name, folder, is_main) VALUES ('dc:<channelId>', '<name>', '<folder>', 0);"
```

Confirm the row was inserted:
```bash
sqlite3 /home/ben/Projects/nanoclaw/store/messages.db \
  "SELECT * FROM registered_groups WHERE folder='<folder>';"
```

---

## Step 6 — Commit to groups repo

```bash
git -C /home/ben/Projects/nanoclaw/groups add {folder}/CLAUDE.md
git -C /home/ben/Projects/nanoclaw/groups commit -m "feat: add {project} group config"
git -C /home/ben/Projects/nanoclaw/groups push
```

---

## Step 7 — Restart nanoclaw

```bash
systemctl --user restart nanoclaw
```

Wait 3 seconds, then confirm it came back up:
```bash
systemctl --user status nanoclaw --no-pager | head -5
```

---

## Step 8 — Summary

Tell the user:
- Trello board created: Backlog → Ready → In Progress → Review → Deploying → Smoke Test → Done
- Group folder created: `groups/{folder}/CLAUDE.md`
- Credentials written to `infra.env` and `agents.env` (values never shown)
- GitHub repo secrets set on `{REPO}` (names listed, values never shown)
- DB row inserted for channel `dc:<channelId>`
- nanoclaw restarted and running
- Next step: send a message in the Discord channel to verify the bot responds
