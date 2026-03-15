---
name: commit-all
description: Add, commit, and push all changes across the three project repos (nanoclaw, nanoclaw-groups, EverRecord). Triggers on "commit all", "push all", "commit and push", "save everything".
---

# Commit All Repos

Checks all three repos for changes, commits, and pushes in one go.

## Repos

| Repo | Path | Remote |
|------|------|--------|
| nanoclaw | `/home/ben/Projects/nanoclaw` | `git push origin main` (B-Kuai/nanoclaw fork — never push to `upstream`) |
| nanoclaw-groups | `/home/ben/Projects/nanoclaw/groups` | `git push origin main` (B-Kuai/nanoclaw-groups) |
| EverRecord | `/home/ben/Projects/nanoclaw/groups/discord_main/EverRecord` | `git push origin main` (B-Kuai/EverRecord) |

## Process

Work **innermost-out** to avoid dirty-subdir noise: EverRecord → groups → nanoclaw.

For each repo:

1. Run `git -C <path> status --short` to check for changes
2. If no changes, skip with a note
3. If changes exist:
   a. Run `git -C <path> diff` and `git -C <path> diff --cached` to review what changed
   b. Stage all changes: `git -C <path> add -A`
   c. Write a concise commit message summarizing the changes (not just "update files")
   d. Commit:
      ```bash
      git -C <path> commit -m "$(cat <<'EOF'
      <commit message>

      Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
      EOF
      )"
      ```
   e. Push: `git -C <path> push origin main`

## Rules

- Never commit files containing secrets (`.env` files are gitignored — verify before staging)
- Never push nanoclaw to `upstream` — always `origin`
- If a push fails, report the error — do not force push
- If the user provided a message via args (e.g. `/commit-all fix typos`), use it as the commit message for all repos that have changes (still append Co-Authored-By)

## Output

After all repos are processed, show a summary:

```
nanoclaw:       ✅ pushed (or ⏭️ no changes)
nanoclaw-groups: ✅ pushed (or ⏭️ no changes)
EverRecord:     ✅ pushed (or ⏭️ no changes)
```
