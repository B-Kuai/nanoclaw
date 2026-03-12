#!/usr/bin/env bash
# Trello CLI tool for NanoClaw agents
# Usage: trello.sh <command> [args...]
# Env: TRELLO_API_KEY, TRELLO_TOKEN, TRELLO_BOARD_ID

set -euo pipefail

API="https://api.trello.com/1"
KEY="${TRELLO_API_KEY:?TRELLO_API_KEY not set}"
TOKEN="${TRELLO_TOKEN:?TRELLO_TOKEN not set}"
BOARD="${TRELLO_BOARD_ID:?TRELLO_BOARD_ID not set}"
AUTH="key=${KEY}&token=${TOKEN}"

cmd="${1:-help}"
shift || true

# ── helpers ────────────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

trello_get()  { curl -sf "${API}${1}?${AUTH}${2:+&$2}"; }
trello_post() { curl -sf -X POST  "${API}${1}?${AUTH}" --data-urlencode "${2:-}" ${3:+--data-urlencode "$3"} ${4:+--data-urlencode "$4"} ${5:+--data-urlencode "$5"}; }
trello_put()  { curl -sf -X PUT   "${API}${1}?${AUTH}&${2}"; }

# Get list ID by name (case-insensitive partial match)
get_list_id() {
  local name="$1"
  local result
  result=$(trello_get "/boards/${BOARD}/lists" "fields=id,name" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
name = sys.argv[1].lower()
matches = [l for l in data if name in l['name'].lower()]
if not matches:
    print('', end='')
else:
    print(matches[0]['id'])
" "$name")
  echo "$result"
}

# Pretty-print a card
print_card() {
  echo "$1" | python3 -c "
import sys, json
c = json.load(sys.stdin)
print(f\"ID:   {c['id']}\")
print(f\"Name: {c['name']}\")
print(f\"URL:  {c['url']}\")
if c.get('desc'):
    print(f\"Desc: {c['desc']}\")
"
}

# ── commands ───────────────────────────────────────────────────────────────────

cmd_lists() {
  # List all lists on the board with their IDs
  trello_get "/boards/${BOARD}/lists" "fields=id,name" \
    | python3 -c "
import sys, json
for l in json.load(sys.stdin):
    print(f\"{l['name']:<25} {l['id']}\")
"
}

cmd_cards() {
  # List cards, optionally filtered by list name
  local list_name="${1:-}"
  if [[ -n "$list_name" ]]; then
    local list_id
    list_id=$(get_list_id "$list_name")
    [[ -z "$list_id" ]] && die "List not found: $list_name"
    trello_get "/lists/${list_id}/cards" "fields=id,name,url,desc" \
      | python3 -c "
import sys, json
cards = json.load(sys.stdin)
if not cards:
    print('(no cards)')
for c in cards:
    print(f\"[{c['id'][-6:]}] {c['name']}\")
    print(f\"       {c['url']}\")
"
  else
    trello_get "/boards/${BOARD}/cards" "fields=id,name,url,idList" \
      | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    print(f\"[{c['id'][-6:]}] {c['name']}\")
"
  fi
}

cmd_create() {
  # create <list-name> <card-title> [description]
  local list_name="${1:?Usage: trello.sh create <list-name> <title> [description]}"
  local title="${2:?Card title required}"
  local desc="${3:-}"

  local list_id
  list_id=$(get_list_id "$list_name")
  [[ -z "$list_id" ]] && die "List not found: $list_name"

  local result
  result=$(curl -sf -X POST "${API}/cards?${AUTH}" \
    --data-urlencode "idList=${list_id}" \
    --data-urlencode "name=${title}" \
    --data-urlencode "desc=${desc}")

  echo "Card created:"
  print_card "$result"
}

cmd_move() {
  # move <card-id-or-partial> <target-list-name>
  local card_ref="${1:?Usage: trello.sh move <card-id> <list-name>}"
  local list_name="${2:?Target list name required}"

  # Resolve card ID (support short 6-char suffix)
  local card_id
  if [[ ${#card_ref} -lt 24 ]]; then
    card_id=$(trello_get "/boards/${BOARD}/cards" "fields=id" \
      | python3 -c "
import sys, json
ref = sys.argv[1]
cards = json.load(sys.stdin)
matches = [c['id'] for c in cards if c['id'].endswith(ref)]
print(matches[0] if matches else '')
" "$card_ref")
    [[ -z "$card_id" ]] && die "Card not found: $card_ref"
  else
    card_id="$card_ref"
  fi

  local list_id
  list_id=$(get_list_id "$list_name")
  [[ -z "$list_id" ]] && die "List not found: $list_name"

  trello_put "/cards/${card_id}" "idList=${list_id}" > /dev/null
  echo "Card moved to: $list_name"
}

cmd_comment() {
  # comment <card-id-or-partial> <comment-text>
  local card_ref="${1:?Usage: trello.sh comment <card-id> <text>}"
  local text="${2:?Comment text required}"

  local card_id
  if [[ ${#card_ref} -lt 24 ]]; then
    card_id=$(trello_get "/boards/${BOARD}/cards" "fields=id" \
      | python3 -c "
import sys, json
ref = sys.argv[1]
cards = json.load(sys.stdin)
matches = [c['id'] for c in cards if c['id'].endswith(ref)]
print(matches[0] if matches else '')
" "$card_ref")
    [[ -z "$card_id" ]] && die "Card not found: $card_ref"
  else
    card_id="$card_ref"
  fi

  curl -sf -X POST "${API}/cards/${card_id}/actions/comments?${AUTH}" \
    --data-urlencode "text=${text}" > /dev/null
  echo "Comment added."
}

cmd_show() {
  # show <card-id-or-partial>
  local card_ref="${1:?Usage: trello.sh show <card-id>}"
  local card_id

  if [[ ${#card_ref} -lt 24 ]]; then
    card_id=$(trello_get "/boards/${BOARD}/cards" "fields=id" \
      | python3 -c "
import sys, json
ref = sys.argv[1]
cards = json.load(sys.stdin)
matches = [c['id'] for c in cards if c['id'].endswith(ref)]
print(matches[0] if matches else '')
" "$card_ref")
    [[ -z "$card_id" ]] && die "Card not found: $card_ref"
  else
    card_id="$card_ref"
  fi

  local result
  result=$(trello_get "/cards/${card_id}" "fields=id,name,url,desc,idList")
  print_card "$result"
}

cmd_help() {
  cat <<'EOF'
Trello tool for NanoClaw agents

Commands:
  lists                          List all board lists with IDs
  cards [list-name]              List cards (all or filtered by list)
  create <list> <title> [desc]   Create a card in a list
  move <card-id> <list>          Move a card to a list
  comment <card-id> <text>       Add a comment to a card
  show <card-id>                 Show card details

List names support partial, case-insensitive matching.
Card IDs support the last 6 characters as a short reference.

Examples:
  trello.sh lists
  trello.sh cards "In Progress"
  trello.sh create Backlog "Fix login bug" "Users can't log in on mobile"
  trello.sh move abc123 "In Progress"
  trello.sh comment abc123 "Started working on this"
EOF
}

# ── dispatch ───────────────────────────────────────────────────────────────────

case "$cmd" in
  lists)   cmd_lists "$@" ;;
  cards)   cmd_cards "$@" ;;
  create)  cmd_create "$@" ;;
  move)    cmd_move "$@" ;;
  comment) cmd_comment "$@" ;;
  show)    cmd_show "$@" ;;
  help|--help|-h) cmd_help ;;
  *) die "Unknown command: $cmd. Run trello.sh help." ;;
esac
