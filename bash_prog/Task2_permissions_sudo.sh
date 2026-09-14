#!/usr/bin/env bash
# -----------------------------------------------------------------
# @title Task2_permissions_sudo.sh
# @author Eugene Antwi Boasiako
# @index 7352623
# @school Kwame Nkrumah University of Science and Technology (KNUST)
# @description Reports a file's permissions (symbolic and numeric),
#              demonstrates chmod in both numeric and symbolic form,
#              and attempts a chown only when run with root privileges.
# @date September 14, 2026
# -----------------------------------------------------------------

set -u

usage() {
    echo "Usage: $0 <file-path>"
    echo "  <file-path>  path to an existing file to inspect and modify"
    exit 1
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

FILE_PATH="$1"

if [[ ! -e "$FILE_PATH" ]]; then
    echo "Error: '$FILE_PATH' does not exist." >&2
    exit 1
fi

# Small helper so we don't repeat the same stat calls twice (before/after).
# Using stat directly is more reliable than parsing `ls -l` columns, which
# shift depending on locale and flags.
report_permissions() {
    local label="$1"
    local symbolic numeric owner group
    symbolic=$(stat -c '%A' "$FILE_PATH" 2>/dev/null)
    numeric=$(stat -c '%a' "$FILE_PATH" 2>/dev/null)
    owner=$(stat -c '%U' "$FILE_PATH" 2>/dev/null)
    group=$(stat -c '%G' "$FILE_PATH" 2>/dev/null)

    if [[ -z "$symbolic" ]]; then
        echo "Error: could not stat '$FILE_PATH'." >&2
        exit 1
    fi

    echo "--- $label ---"
    echo "Owner: $owner  Group: $group"
    echo "Symbolic: $symbolic"
    echo "Numeric:  $numeric"
}

# ---- step 1: report current permissions ----
report_permissions "Permissions before changes"

# ---- step 2: change permissions, demonstrating both syntaxes ----
# Numeric form first: this is the common way to set an exact mode in one shot.
chmod 644 "$FILE_PATH"
if [[ $? -eq 0 ]]; then
    echo "Success: applied numeric chmod 644."
else
    echo "Error: numeric chmod failed on '$FILE_PATH'." >&2
    exit 1
fi

# Symbolic form second: useful when you want to adjust one bit (like +x)
# without having to know or recompute the full numeric mode.
chmod u+x "$FILE_PATH"
if [[ $? -eq 0 ]]; then
    echo "Success: applied symbolic chmod u+x."
else
    echo "Error: symbolic chmod failed on '$FILE_PATH'." >&2
    exit 1
fi

# ---- step 3: chown, but only if running as root ----
# id -u returns 0 for root. We check this instead of just trying chown
# and catching the failure, because we want a clear, intentional message
# rather than a generic "operation not permitted" error leaking through.
if [[ "$(id -u)" -eq 0 ]]; then
    chown root "$FILE_PATH"
    if [[ $? -eq 0 ]]; then
        echo "Success: changed owner of '$FILE_PATH' to root."
    else
        echo "Error: chown failed on '$FILE_PATH' even though running as root." >&2
    fi
else
    echo "Notice: skipping chown — this script is not running as root/sudo."
    echo "        Re-run with 'sudo $0 $FILE_PATH' to attempt the ownership change."
fi

# ---- step 4: report permissions again so before/after is visible ----
report_permissions "Permissions after changes"

exit 0
