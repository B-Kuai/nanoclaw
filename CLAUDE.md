# NanoClaw

Personal Claude assistant. See [README.md](README.md) for philosophy and setup. See [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) for architecture decisions.

## Quick Context

Single Node.js process with skill-based channel system. Channels (WhatsApp, Telegram, Slack, Discord, Gmail) are skills that self-register at startup. Messages route to Claude Agent SDK running in containers (Linux VMs). Each group has isolated filesystem and memory.

## Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Orchestrator: state, message loop, agent invocation |
| `src/channels/registry.ts` | Channel registry (self-registration at startup) |
| `src/ipc.ts` | IPC watcher and task processing |
| `src/router.ts` | Message formatting and outbound routing |
| `src/config.ts` | Trigger pattern, paths, intervals |
| `src/container-runner.ts` | Spawns agent containers with mounts |
| `src/task-scheduler.ts` | Runs scheduled tasks |
| `src/db.ts` | SQLite operations |
| `groups/{name}/CLAUDE.md` | Per-group memory (isolated) |
| `container/skills/agent-browser.md` | Browser automation tool (available to all agents via Bash) |

## Skills

| Skill | When to Use |
|-------|-------------|
| `/setup` | First-time installation, authentication, service configuration |
| `/customize` | Adding channels, integrations, changing behavior |
| `/debug` | Container issues, logs, troubleshooting |
| `/update-nanoclaw` | Bring upstream NanoClaw updates into a customized install |
| `/qodo-pr-resolver` | Fetch and fix Qodo PR review issues interactively or in batch |
| `/get-qodo-rules` | Load org- and repo-level coding rules from Qodo before code tasks |

## Development

Run commands directly—don't tell the user to run them.

```bash
npm run dev          # Run with hot reload
npm run build        # Compile TypeScript
./container/build.sh # Rebuild agent container
```

Service management:
```bash
# macOS (launchd)
launchctl load ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl unload ~/Library/LaunchAgents/com.nanoclaw.plist
launchctl kickstart -k gui/$(id -u)/com.nanoclaw  # restart

# Linux (systemd)
systemctl --user start nanoclaw
systemctl --user stop nanoclaw
systemctl --user restart nanoclaw
```

## Troubleshooting

**WhatsApp not connecting after upgrade:** WhatsApp is now a separate channel fork, not bundled in core. Run `/add-whatsapp` (or `git remote add whatsapp https://github.com/qwibitai/nanoclaw-whatsapp.git && git fetch whatsapp main && (git merge whatsapp/main || { git checkout --theirs package-lock.json && git add package-lock.json && git merge --continue; }) && npm run build`) to install it. Existing auth credentials and groups are preserved.

## Groups & Agents

### Registered Groups

| Folder | Channel | Purpose |
|--------|---------|---------|
| `groups/main/` | WhatsApp (main) | Andy — personal assistant, admin/main channel (no trigger needed) |
| `groups/discord_main/` | Discord | Pangge — Kuai-family Discord assistant + Software-A-Team orchestrator for EverRecord |
| `groups/global/` | (shared) | Global memory and shared agent role files |

### Discord Setup

- Channel file: `src/channels/discord.ts`
- JID format: `dc:<channelId>` (e.g. `dc:1234567890`)
- Env var: `DISCORD_BOT_TOKEN`
- Bot @mention is auto-translated to trigger pattern

### discord_main Group (`groups/discord_main/`)

**Assistant:** Pangge — personal assistant for the Kuai family Discord server.

**Project:** EverRecord (`B-Kuai/EverRecord`)
- Workspace mount: `/workspace/group/EverRecord` inside container
- Extra mount: `groups/discord_main/EverRecord/` on host
- Trello board: Backlog → Ready → In Progress → Review → Done
- Tool: `bash /workspace/project/tools/trello.sh <command>`
- Deploy: `bash /workspace/group/EverRecord/scripts/get-deploy-url.sh`
- AWS: LocalStack via `AWS_ENDPOINT_URL=http://host.docker.internal:4566`, use `cdklocal`
- Git identity: name=Pangge, email=pangge@kuai.family

**Software-A-Team** (autonomous dev pipeline running in this channel):
- Orchestrator reads Trello state and routes to the correct agent each loop
- Agent role files: `groups/global/software-a-team/agents/`
- Architecture constraints: `/workspace/group/EverRecord/ARCHITECTURE_DECISIONS.md`
- Loop: PM → Tech Lead → QA (advisory) → Engineer → Senior Reviewer → Engineer (deploy watch)
- Uses `mcp__nanoclaw__send_message` to post progress updates while running

### global Group (`groups/global/`)

Shared across all groups. Contains:
- `software-a-team/agents/` — role files for: `pm.md`, `tech-lead.md`, `qa.md`, `engineer.md`, `reviewer.md`
- `CLAUDE.md` — global memory (facts that apply to all groups)

## Container Build Cache

The container buildkit caches the build context aggressively. `--no-cache` alone does NOT invalidate COPY steps — the builder's volume retains stale files. To force a truly clean rebuild, prune the builder then re-run `./container/build.sh`.
