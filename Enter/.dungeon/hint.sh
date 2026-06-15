#!/usr/bin/env bash
# ============================================================================
# Bash Dungeon - progressive hint engine
# ----------------------------------------------------------------------------
# SOURCE this file to enable hints:   source .dungeon/hint.sh
#
# It adds two commands to your shell:
#   hint            reveal the next hint for the room you are standing in
#   hint N          jump to hint tier N
#   hint reset      forget how many hints you've seen in this room
#   hint off        turn off the automatic "stuck?" nudges (same as: unhint)
#
# It also *offers* a hint automatically (it never reveals one for you) after
# you mistype several commands in a room, or linger in a room for a while.
#
# Hints live in a plain '.hints' file inside each room. The mechanism is
# data-driven: drop a '.hints' file into ANY directory and it gains hints,
# no code changes required. See .dungeon/README for the format.
#
# This script is READ-ONLY: it parses '.hints' files and tracks counters.
# It never runs or edits the dungeon's puzzle scripts, and uses no 'eval'.
# ============================================================================

# --- Refuse to run if executed instead of sourced --------------------------
# (functions defined in a child process would vanish immediately)
__dungeon_sourced=0
(return 0 2>/dev/null) && __dungeon_sourced=1
if [ "$__dungeon_sourced" -eq 0 ]; then
	printf 'This is a spell you must SOURCE, not run:\n    source %s\n' "$0" >&2
	exit 1
fi
unset __dungeon_sourced

# --- Configuration (override before sourcing if you like) ------------------
HINT_STATE_DIR="${HINT_STATE_DIR:-${TMPDIR:-/tmp}/bash-dungeon-hints}"
: "${HINT_MISS_THRESHOLD:=3}"     # mistyped commands before we offer a hint
: "${HINT_LINGER_THRESHOLD:=8}"   # prompts spent in one room before we offer
mkdir -p "$HINT_STATE_DIR" 2>/dev/null
__DUNGEON_HINT_DISABLED=          # cleared on (re)source -> re-enables nudges

# --- Per-room state ---------------------------------------------------------
# State is kept in one small file per room so we don't depend on associative
# arrays (macOS ships bash 3.2, which lacks them). Each file holds four ints:
#     tier miss linger offered
# The room key is a checksum of $PWD, which is stable and filename-safe.
__dungeon_hint_key() { printf '%s' "$PWD" | cksum | awk '{print $1}'; }
__dungeon_hint_state_file() { printf '%s/%s' "$HINT_STATE_DIR" "$(__dungeon_hint_key)"; }

__dungeon_hint_read() {  # echoes: tier miss linger offered
	local f tier miss linger offered
	f="$(__dungeon_hint_state_file)"
	if [ -f "$f" ]; then
		read -r tier miss linger offered < "$f"
	fi
	# normalise anything missing or corrupt back to 0
	case "$tier"    in ''|*[!0-9]*) tier=0    ;; esac
	case "$miss"    in ''|*[!0-9]*) miss=0    ;; esac
	case "$linger"  in ''|*[!0-9]*) linger=0  ;; esac
	case "$offered" in ''|*[!0-9]*) offered=0 ;; esac
	printf '%s %s %s %s\n' "$tier" "$miss" "$linger" "$offered"
}

__dungeon_hint_write() {  # args: tier miss linger offered
	printf '%s %s %s %s\n' "$1" "$2" "$3" "$4" > "$(__dungeon_hint_state_file)"
}

# --- Find the nearest .hints (current room, then walk upward) ---------------
__dungeon_find_hints() {
	local d="$PWD"
	while :; do
		if [ -f "$d/.hints" ]; then printf '%s/.hints\n' "$d"; return 0; fi
		[ "$d" = "/" ] && return 1
		d="$(dirname "$d")"
	done
}

# --- Count how many tiers a .hints file defines ----------------------------
__dungeon_hint_max() { awk '/^\[[0-9]+\]/{c++} END{print c+0}' "$1"; }

# --- Print a single tier (label stripped) ----------------------------------
__dungeon_hint_show_tier() {  # args: hints_file tier_number
	awk -v want="$2" '
		/^\[[0-9]+\]/ {
			num = $0; sub(/^\[/, "", num); sub(/\].*$/, "", num)
			if (num + 0 == want + 0) {
				printing = 1
				rest = $0; sub(/^\[[0-9]+\][ \t]*/, "", rest); print rest
			} else printing = 0
			next
		}
		printing { print }
	' "$1"
}

# --- The `hint` command -----------------------------------------------------
hint() {
	local hints maxt tier miss linger offered arg n
	hints="$(__dungeon_find_hints 2>/dev/null)"
	if [ -z "$hints" ]; then
		printf 'There are no hints in this room. Read the parchment with `cat`.\n'
		return 0
	fi
	read -r tier miss linger offered <<< "$(__dungeon_hint_read)"
	maxt="$(__dungeon_hint_max "$hints")"
	arg="${1:-}"

	case "$arg" in
		reset)     __dungeon_hint_write 0 0 0 0; printf 'Hints reset for this room.\n'; return 0 ;;
		off|--off) unhint; return 0 ;;
		''|next)   n=$((tier + 1)); [ "$n" -lt 1 ] && n=1 ;;
		*[!0-9]*)  printf 'Usage: hint [N|reset|off]\n'; return 1 ;;
		*)         n="$arg" ;;
	esac

	if [ "$n" -gt "$maxt" ]; then
		__dungeon_hint_write "$maxt" "$miss" "$linger" "$offered"
		printf 'That was the last clue -- you have everything you need. Try it!\n'
		return 0
	fi
	[ "$n" -lt 1 ] && n=1

	printf 'Hint (%s of %s):\n' "$n" "$maxt"
	__dungeon_hint_show_tier "$hints" "$n"
	__dungeon_hint_write "$n" "$miss" "$linger" "$offered"
}

# --- Turn off automatic nudges ---------------------------------------------
unhint() {
	__DUNGEON_HINT_DISABLED=1
	if [ -n "${__DUNGEON_CNF_INSTALLED:-}" ]; then
		if [ -n "${ZSH_VERSION:-}" ]; then
			unset -f command_not_found_handler 2>/dev/null
		else
			unset -f command_not_found_handle 2>/dev/null
		fi
		__DUNGEON_CNF_INSTALLED=
	fi
	printf 'Automatic hint nudges disabled. Re-run `source .dungeon/hint.sh` to re-enable.\n'
}

# --- Shared: offer (but never reveal) a hint -------------------------------
# kind=$1 ("miss"|"linger"); message printed once per room.
__dungeon_hint_bump() {
	[ -n "${__DUNGEON_HINT_DISABLED:-}" ] && return 0
	local hints tier miss linger offered
	hints="$(__dungeon_find_hints 2>/dev/null)" || return 0
	[ -n "$hints" ] || return 0
	read -r tier miss linger offered <<< "$(__dungeon_hint_read)"

	if [ "$1" = miss ]; then
		miss=$((miss + 1))
		if [ "$offered" -eq 0 ] && [ "$miss" -ge "$HINT_MISS_THRESHOLD" ]; then
			offered=1
			printf '\nStuck? Type `hint` for a clue.\n' >&2
		fi
	else
		linger=$((linger + 1))
		if [ "$offered" -eq 0 ] && [ "$linger" -ge "$HINT_LINGER_THRESHOLD" ]; then
			offered=1
			printf '\nYou have been in this room a while. Type `hint` for a clue.\n' >&2
		fi
	fi
	__dungeon_hint_write "$tier" "$miss" "$linger" "$offered"
}

__dungeon_hint_on_miss() { __dungeon_hint_bump miss; }
__dungeon_hint_precmd()  { __dungeon_hint_bump linger; }

# --- Wire up the shell hooks (idempotent; safe to re-source) ---------------
if [ -n "${ZSH_VERSION:-}" ]; then
	# Only install our command-not-found handler if the shell has none,
	# so we don't clobber a distro/user handler.
	if ! typeset -f command_not_found_handler >/dev/null 2>&1; then
		command_not_found_handler() {
			__dungeon_hint_on_miss
			printf '%s: command not found\n' "$1" >&2
			return 127
		}
		__DUNGEON_CNF_INSTALLED=1
	fi
	typeset -ga precmd_functions
	(( ${precmd_functions[(I)__dungeon_hint_precmd]} )) || precmd_functions+=(__dungeon_hint_precmd)
elif [ -n "${BASH_VERSION:-}" ]; then
	if ! declare -F command_not_found_handle >/dev/null 2>&1; then
		command_not_found_handle() {
			__dungeon_hint_on_miss
			printf '%s: command not found\n' "$1" >&2
			return 127
		}
		__DUNGEON_CNF_INSTALLED=1
	fi
	case ";${PROMPT_COMMAND:-};" in
		*";__dungeon_hint_precmd;"*) : ;;
		*) PROMPT_COMMAND="__dungeon_hint_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
	esac
fi

__DUNGEON_HINT_LOADED=1
printf 'Hints enabled. Type `hint` when you are stuck (run it again to reveal more). `unhint` to silence nudges.\n'
