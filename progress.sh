#!/usr/bin/env bash
#
# progress.sh - Bash Dungeon progress checker
#
# Shows which areas you have cleared, which key items/rewards you have
# earned, and what to do next. It works entirely from the state of the
# game directory: as you solve a room, the game reveals the next room by
# renaming a hidden ".room" into a visible "room", and some puzzles drop
# reward files (rat_remains, gold, potion_of_health, functions). This
# script reads only that on-disk state. It never modifies the game.
#
# Usage:
#   ./progress.sh                 # run from the repo root (scans ./Enter)
#   ./progress.sh /path/to/root   # point at a game root that contains Enter/
#
# Note: your live inventory lives in the $I shell variable, which the game
# never writes to disk, so it cannot be read here. Instead we report the
# puzzle rewards you have earned and the items currently within reach.

set -u

# --- Locate the game (the Enter/ directory) --------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

GAME_ROOT="${1:-}"
if [ -z "$GAME_ROOT" ]; then
    if [ -d "$SCRIPT_DIR/Enter" ]; then
        GAME_ROOT="$SCRIPT_DIR"
    elif [ -d "$PWD/Enter" ]; then
        GAME_ROOT="$PWD"
    else
        GAME_ROOT="$SCRIPT_DIR"
    fi
fi

ENTER="$GAME_ROOT/Enter"
# Allow the argument to point straight at an Enter/ directory.
if [ ! -d "$ENTER" ] && [ -d "$GAME_ROOT" ] && [ "$(basename "$GAME_ROOT")" = "Enter" ]; then
    ENTER="$GAME_ROOT"
fi

if [ ! -d "$ENTER" ]; then
    echo "progress.sh: could not find the 'Enter' dungeon directory." >&2
    echo "Run this from the repository root, or pass the game root:" >&2
    echo "    ./progress.sh /path/to/bash-dungeon" >&2
    exit 1
fi

# --- Detection helpers -----------------------------------------------------
# A room/item counts as reachable only when its path has NO hidden (dot)
# ancestor. That is exactly the signal the game uses to reveal content:
# a room stays ".hidden" until you solve the puzzle that un-hides it.

_find_first() {
    # $1 = name, $2 = type (f|d). Search relative to ENTER so the
    # "-not -path '*/.*'" filter only inspects components below Enter/.
    ( cd "$ENTER" 2>/dev/null && \
      find . -name "$1" -type "$2" -not -path '*/.*' -print 2>/dev/null | head -n1 )
}

dir_reached()  { [ -n "$(_find_first "$1" d)" ]; }
file_present() { [ -n "$(_find_first "$1" f)" ]; }

# --- Progression model -----------------------------------------------------
# The dungeon is a linear chain. Each entry is the *visible* directory name
# that appears once the previous puzzle is solved. The corridor is the
# always-present starting area.

ROOMS=(first_chamber 2nd_chamber garden_of_mitra room1 shop room2 chamber_of_loss)
ROOM_LABELS=("First Chamber" "Second Chamber" "Garden of Mitra" "Room 1" "Shop" "Room 2" "Chamber of Loss")

CLEARED="[x]"
CURRENT="[>]"
LOCKED="[ ]"

# Frontier = index of the first room not yet reached (count = how many of
# ROOMS are reached). If all are reached the dungeon is complete.
frontier=0
while [ "$frontier" -lt "${#ROOMS[@]}" ] && dir_reached "${ROOMS[$frontier]}"; do
    frontier=$((frontier + 1))
done

# --- Output: header --------------------------------------------------------

echo "======================================================================"
echo "                     BASH DUNGEON - Progress Report"
echo "======================================================================"
echo "Game directory: $ENTER"
echo

# --- Output: areas ---------------------------------------------------------

echo "AREAS"
echo "-----"

# Corridor (depth 0). Cleared once the First Chamber is revealed.
if dir_reached "${ROOMS[0]}"; then
    printf '%s Corridor\n' "$CLEARED"
else
    printf '%s Corridor  (you are here)\n' "$CURRENT"
fi

indent="  "
i=0
while [ "$i" -lt "${#ROOMS[@]}" ]; do
    room="${ROOMS[$i]}"
    label="${ROOM_LABELS[$i]}"
    next=$((i + 1))

    if ! dir_reached "$room"; then
        marker="$LOCKED"
        note="(locked)"
    elif [ "$next" -lt "${#ROOMS[@]}" ] && dir_reached "${ROOMS[$next]}"; then
        marker="$CLEARED"
        note=""
    else
        marker="$CURRENT"
        note="(you are here)"
    fi

    if [ -n "$note" ]; then
        printf '%s%s %s  %s\n' "$indent" "$marker" "$label" "$note"
    else
        printf '%s%s %s\n' "$indent" "$marker" "$label"
    fi

    indent="$indent  "
    i=$((next))
done

deepest="Corridor"
if [ "$frontier" -gt 0 ]; then
    deepest="${ROOM_LABELS[$((frontier - 1))]}"
fi
echo
echo "Areas cleared: $frontier / ${#ROOMS[@]}   (deepest reached: $deepest)"
echo

# --- Output: key items / rewards ------------------------------------------
# These reward files only exist after you complete the matching puzzle.

echo "KEY ITEMS & MILESTONES EARNED"
echo "-----------------------------"
earned=0
check_reward() {
    # $1 = filename, $2 = human description
    if file_present "$1"; then
        printf '  %s %s\n' "$CLEARED" "$2"
        earned=$((earned + 1))
    fi
}
check_reward rat_remains       "Rat slain          (rat_remains, First Chamber)"
check_reward gold              "10 Gold Coins      (gold, Second Chamber chest)"
check_reward potion_of_health  "Potion of Health   (potion_of_health, Garden potioneer)"
check_reward functions         "Functions Tome     (functions, Room 2 vault)"
if [ "$earned" -eq 0 ]; then
    echo "  (none yet)"
fi
echo

# --- Output: reachable items ----------------------------------------------
# Item files you can currently walk up to and add to your inventory ($I).

echo "ITEMS WITHIN REACH (add to inventory with: export I=name)"
echo "--------------------------------------------------------"
reachable=0
check_item() {
    if file_present "$1"; then
        printf '  - %-16s %s\n' "$1" "$2"
        reachable=$((reachable + 1))
    fi
}
check_item short_sword      "(weapon)"
check_item long_sword       "(weapon)"
check_item potion_of_health "(consumable)"
if [ "$reachable" -eq 0 ]; then
    echo "  (nothing reachable yet)"
fi
echo

# --- Output: next step -----------------------------------------------------

echo "NEXT STEP"
echo "---------"
if [ "$frontier" -ge "${#ROOMS[@]}" ]; then
    echo "  You have reached the Chamber of Loss - the final lesson on 'rm'."
    echo "  Tread carefully in there. Congratulations, you've cleared the dungeon!"
else
    case "${ROOMS[$frontier]}" in
        first_chamber)
            echo "  In Enter/corridor: identify the 'chest' (try: head -n 1 chest),"
            echo "  then run it (./chest) to reveal the First Chamber."
            ;;
        2nd_chamber)
            echo "  In the First Chamber: pick up the short_sword (export I=short_sword),"
            echo "  then fight the rat (./rat) to reveal the Second Chamber."
            ;;
        garden_of_mitra)
            echo "  In the Second Chamber: the chest is locked. Its key is the poem's"
            echo "  line count - find the right counting spell, then open the chest"
            echo "  to reveal the Garden of Mitra."
            ;;
        room1)
            echo "  In the Garden of Mitra: set your HP (export HP=100), cross the"
            echo "  thorns (./thorns), then bring the poem to the potioneer"
            echo "  (./potioneer poem) to reveal room1."
            ;;
        shop)
            echo "  In room1: open the chest to reveal the shop."
            ;;
        room2)
            echo "  In the shop: deal with the shopkeeper (./shopkeeper) to reveal room2."
            ;;
        chamber_of_loss)
            echo "  In room2: solve the vault (./vault) to reveal the Chamber of Loss."
            ;;
        *)
            echo "  Explore the deepest unlocked room and read its parchment."
            ;;
    esac
fi
echo "======================================================================"
