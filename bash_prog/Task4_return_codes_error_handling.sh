#!/usr/bin/env bash
# -----------------------------------------------------------------
# @title Task4_return_codes_error_handling.sh
# @author Eugene Antwi Boasiako
# @index 7352623
# @school Kwame Nkrumah University of Science and Technology (KNUST)
# @description Runs a sequence of environment checks (host reachable,
#              disk space, file exists, command installed), exiting
#              with a specific code the moment one fails.
# @date September 14, 2026
#
# Exit codes:
#   0 = all checks passed
#   1 = missing required argument
#   2 = host unreachable
#   3 = insufficient disk space
#   4 = required file not found
#   5 = required command not found
# -----------------------------------------------------------------

set -u

usage() {
    echo "Usage: $0 <hostname>"
    echo "  <hostname>  a host to ping-check as part of the run"
    exit 1
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

HOST="$1"
REQUIRED_FILE="/etc/hosts"
REQUIRED_COMMAND="grep"
MIN_FREE_DISK_KB=102400   # ~100MB, arbitrary demo threshold
TMP_FILE=""

# ---- trap: clean up temp files no matter how the script exits ----
# A single trap on EXIT covers success, failure, and Ctrl+C (which bash
# turns into an EXIT after the signal), so we don't need three trap lines.
cleanup() {
    if [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]]; then
        rm -f "$TMP_FILE"
    fi
}
trap cleanup EXIT

TMP_FILE=$(mktemp)

# check_status centralizes the pattern of "look at $?, log it, exit on
# failure" so each check below is a one-line call instead of a repeated
# if/else block.
check_status() {
    local result="$1"
    local message="$2"
    local exit_code_on_fail="$3"

    if [[ "$result" -eq 0 ]]; then
        echo "PASS: $message"
    else
        echo "FAIL: $message" >&2
        exit "$exit_code_on_fail"
    fi
}

# ---- check 1: is the host reachable? ----
ping -c 1 -W 2 "$HOST" > "$TMP_FILE" 2>&1
check_status $? "host '$HOST' is reachable" 2

# ---- check 2: is there enough free disk space? ----
# We read the "Available" column (in KB) from df for the current partition.
AVAILABLE_KB=$(df --output=avail -k . | tail -n 1 | tr -d ' ')
if [[ "$AVAILABLE_KB" -ge "$MIN_FREE_DISK_KB" ]]; then
    DISK_CHECK_RESULT=0
else
    DISK_CHECK_RESULT=1
fi
check_status "$DISK_CHECK_RESULT" "at least ${MIN_FREE_DISK_KB}KB free disk space (found ${AVAILABLE_KB}KB)" 3

# ---- check 3: does the required file exist and is it readable? ----
if [[ -f "$REQUIRED_FILE" && -r "$REQUIRED_FILE" ]]; then
    FILE_CHECK_RESULT=0
else
    FILE_CHECK_RESULT=1
fi
check_status "$FILE_CHECK_RESULT" "required file '$REQUIRED_FILE' exists and is readable" 4

# ---- check 4: is the required command/tool installed? ----
command -v "$REQUIRED_COMMAND" > /dev/null 2>&1
check_status $? "required command '$REQUIRED_COMMAND' is installed" 5

echo "All checks passed."
exit 0
