#!/usr/bin/env bash
# -----------------------------------------------------------------
# @title Task1_file_handling.sh
# @author Eugene Antwi Boasiako
# @index 7352623
# @school Kwame Nkrumah University of Science and Technology (KNUST)
# @description Creates a directory and a file inside it, writes and
#              appends content, reads it back, backs it up, and then
#              removes the original only after confirming it exists.
# @date September 14, 2026
# -----------------------------------------------------------------

set -u  # treat unset variables as an error, catches typos early

usage() {
    echo "Usage: $0 <target-directory>"
    echo "  <target-directory>  path to the directory to create and work in"
    exit 1
}

# ---- input validation ----
if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

TARGET_DIR="$1"
FILE_NAME="notes.txt"
FILE_PATH="${TARGET_DIR}/${FILE_NAME}"
BACKUP_PATH="${FILE_PATH}.bak"

# ---- step 1: create the directory if it doesn't exist ----
# We check for existence first (rather than just calling mkdir -p and
# moving on) because the task wants us to explicitly report whether the
# directory was newly created or already there.
if [[ -d "$TARGET_DIR" ]]; then
    echo "Info: directory '$TARGET_DIR' already existed."
else
    mkdir -p "$TARGET_DIR"
    if [[ $? -eq 0 ]]; then
        echo "Success: created directory '$TARGET_DIR'."
    else
        echo "Error: failed to create directory '$TARGET_DIR' (check permissions)." >&2
        exit 1
    fi
fi

# ---- step 2: create a new file and write content ----
echo "This file was created by Task1_file_handling.sh on $(date)." > "$FILE_PATH"
if [[ $? -eq 0 ]]; then
    echo "Success: wrote initial content to '$FILE_PATH'."
else
    echo "Error: could not write to '$FILE_PATH'." >&2
    exit 1
fi

# ---- step 3: append additional content ----
echo "This line was appended afterward to demonstrate append mode." >> "$FILE_PATH"
if [[ $? -eq 0 ]]; then
    echo "Success: appended additional content to '$FILE_PATH'."
else
    echo "Error: could not append to '$FILE_PATH'." >&2
    exit 1
fi

# ---- step 4: read and display the file's contents ----
if [[ -r "$FILE_PATH" ]]; then
    echo "--- Contents of $FILE_PATH ---"
    cat "$FILE_PATH"
    echo "--- End of file ---"
else
    echo "Error: '$FILE_PATH' is not readable." >&2
    exit 1
fi

# ---- step 5: copy the file to a .bak version ----
cp "$FILE_PATH" "$BACKUP_PATH"
if [[ $? -eq 0 ]]; then
    echo "Success: backed up '$FILE_PATH' to '$BACKUP_PATH'."
else
    echo "Error: backup of '$FILE_PATH' failed." >&2
    exit 1
fi

# ---- step 6: delete the original, but only after checking it exists ----
# Checking existence right before deleting (rather than trusting earlier
# steps) protects against something else removing the file mid-script.
if [[ -f "$FILE_PATH" ]]; then
    echo "Confirmation: '$FILE_PATH' exists and is about to be deleted."
    rm "$FILE_PATH"
    if [[ $? -eq 0 ]]; then
        echo "Success: deleted '$FILE_PATH'. A backup remains at '$BACKUP_PATH'."
    else
        echo "Error: failed to delete '$FILE_PATH'." >&2
        exit 1
    fi
else
    echo "Error: '$FILE_PATH' does not exist, nothing to delete." >&2
    exit 1
fi

exit 0
