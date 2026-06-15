#!/usr/bin/env bash
# =================================================================
# Progressive Hint Engine for Bash Dungeon
# =================================================================
# Source this file in any puzzle script to enable tiered hints.
#
# How it works:
#   - Each puzzle defines a unique puzzle_id and 4 hint levels
#     (from vague atmospheric hints to near-answer hints).
#   - State is tracked via hidden files (.hint_state_<puzzle_id>)
#     in the player's current working directory.
#   - Each wrong answer increments the counter and reveals the
#     next hint level. Correct answers reset the counter.
#
# Usage in a puzzle script:
#
#   source "<relative_path>/hint_engine.sh"
#
#   HINT_L0="Vague atmospheric hint..."
#   HINT_L1="Directional hint about the concept..."
#   HINT_L2="Command template hint..."
#   HINT_L3="Near-answer hint..."
#
#   init_hint "my_puzzle"
#
#   echo "Enter Key value: "
#   read -r val
#
#   if [[ $val != "$expected" ]]; then
#       increment_hint "my_puzzle"
#       show_hint "my_puzzle" "$HINT_L0" "$HINT_L1" "$HINT_L2" "$HINT_L3"
#       exit 0
#   else
#       echo "Correct!"
#       reset_hint "my_puzzle"
#   fi
#
# Reuse: Any room can adopt this pattern by sourcing hint_engine.sh
# and defining its own hint strings. The engine is stateless itself;
# all state lives in .hint_state_* files in the room directory.
# =================================================================

# Initialize hint counter for a puzzle.
# Reads existing failure count from the state file if present.
# Args: $1 = puzzle_id
init_hint() {
    local puzzle_id="$1"
    local state_file=".hint_state_${puzzle_id}"
    if [[ -f "$state_file" ]]; then
        _HINT_COUNT=$(cat "$state_file")
    else
        _HINT_COUNT=0
    fi
}

# Increment the hint counter after a wrong answer.
# Persists the count to a hidden state file so it survives
# across separate script invocations.
# Args: $1 = puzzle_id
increment_hint() {
    local puzzle_id="$1"
    local state_file=".hint_state_${puzzle_id}"
    (( _HINT_COUNT++ ))
    echo "$_HINT_COUNT" > "$state_file"
}

# Display the appropriate hint based on the current failure count.
# Levels:
#   0 (1st failure)  - Atmospheric whisper, no commands mentioned
#   1 (2nd failure)  - Directional nudge toward the right concept
#   2 (3rd failure)  - Command template with placeholders
#   3 (4th+ failure) - Near-answer, specific but not a direct giveaway
#
# Args: $1 = puzzle_id, $2 = level0, $3 = level1, $4 = level2, $5 = level3
show_hint() {
    local puzzle_id="$1"
    local hint0="$2"
    local hint1="$3"
    local hint2="$4"
    local hint3="$5"

    echo ""
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    if (( _HINT_COUNT <= 1 )); then
        echo "  A whisper echoes through the chamber..."
        echo "  $hint0"
    elif (( _HINT_COUNT == 2 )); then
        echo "  The dungeon reveals a faint clue..."
        echo "  $hint1"
    elif (( _HINT_COUNT == 3 )); then
        echo "  An ancient glyph glows on the wall..."
        echo "  $hint2"
    else
        echo "  The spirits speak clearly now..."
        echo "  $hint3"
    fi
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo ""
}

# Reset hint counter and remove state file.
# Call this when the puzzle is solved successfully.
# Args: $1 = puzzle_id
reset_hint() {
    local puzzle_id="$1"
    local state_file=".hint_state_${puzzle_id}"
    rm -f "$state_file" 2>/dev/null
    _HINT_COUNT=0
}
