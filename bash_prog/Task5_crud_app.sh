#!/usr/bin/env bash
# -----------------------------------------------------------------
# @title Task5_crud_app.sh
# @author Eugene Antwi Boasiako
# @index 7352623
# @school Kwame Nkrumah University of Science and Technology (KNUST)
# @description Menu-driven Todo List CRUD app. Data lives in
#              todo_data.csv next to the script (ID,description,status,due_date).
# @date September 14, 2026
#
# Exit codes:
#   0 = normal exit
#   1 = data file could not be created/accessed
# -----------------------------------------------------------------

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="${SCRIPT_DIR}/todo_data.csv"
BACKUP_FILE="${DATA_FILE}.bak"

usage() {
    echo "Usage: $0"
    echo "  Launches an interactive Todo List menu. No arguments needed."
    echo "  Data is stored in: $DATA_FILE"
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

# ---- ensure the data file exists before we do anything else ----
if [[ ! -f "$DATA_FILE" ]]; then
    touch "$DATA_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: could not create data file '$DATA_FILE'." >&2
        exit 1
    fi
fi

# backup_data is called before update/delete specifically — those are the
# two operations that overwrite or remove rows, so they're the ones worth
# protecting against a mistake.
backup_data() {
    cp "$DATA_FILE" "$BACKUP_FILE"
}

next_id() {
    # Highest existing ID + 1, or 1 if the file is empty. Reading the
    # whole file each time is fine at this scale and keeps the logic simple.
    local max_id
    max_id=$(cut -d',' -f1 "$DATA_FILE" | sort -n | tail -1)
    if [[ -z "$max_id" ]]; then
        echo 1
    else
        echo $((max_id + 1))
    fi
}

add_task() {
    local description status due_date id
    read -rp "Task description: " description
    if [[ -z "$description" ]]; then
        echo "Error: description cannot be empty. Task not added." >&2
        return 1
    fi
    read -rp "Due date (optional, press Enter to skip): " due_date

    id=$(next_id)
    status="pending"
    echo "${id},${description},${status},${due_date}" >> "$DATA_FILE"
    echo "Added task #${id}: ${description}"
}

list_tasks() {
    if [[ ! -s "$DATA_FILE" ]]; then
        echo "No tasks yet."
        return 0
    fi
    printf "%-5s %-30s %-10s %-12s\n" "ID" "Description" "Status" "Due Date"
    while IFS=',' read -r id description status due_date; do
        printf "%-5s %-30s %-10s %-12s\n" "$id" "$description" "$status" "$due_date"
    done < "$DATA_FILE"
}

search_tasks() {
    local term matches
    read -rp "Search term: " term
    if [[ -z "$term" ]]; then
        echo "Error: search term cannot be empty." >&2
        return 1
    fi
    matches=$(grep -i "$term" "$DATA_FILE")
    if [[ -z "$matches" ]]; then
        echo "No tasks matched '${term}'."
    else
        echo "$matches" | while IFS=',' read -r id description status due_date; do
            printf "%-5s %-30s %-10s %-12s\n" "$id" "$description" "$status" "$due_date"
        done
    fi
}

find_task_line() {
    # Echoes the matching line number in the CSV for a given ID, or
    # nothing if not found. Centralized here so update/delete share it.
    grep -n "^${1}," "$DATA_FILE" | cut -d':' -f1
}

update_task() {
    local id line_num description status due_date
    read -rp "ID of task to update: " id
    line_num=$(find_task_line "$id")
    if [[ -z "$line_num" ]]; then
        echo "No task found with ID ${id}."
        return 0
    fi

    read -rp "New description (Enter to keep current): " description
    read -rp "New status (pending/done, Enter to keep current): " status
    read -rp "New due date (Enter to keep current): " due_date

    local old_line old_desc old_status old_due
    old_line=$(sed -n "${line_num}p" "$DATA_FILE")
    IFS=',' read -r _ old_desc old_status old_due <<< "$old_line"

    [[ -z "$description" ]] && description="$old_desc"
    [[ -z "$status" ]] && status="$old_status"
    [[ -z "$due_date" ]] && due_date="$old_due"

    backup_data
    sed -i "${line_num}s/.*/${id},${description},${status},${due_date}/" "$DATA_FILE"
    if [[ $? -eq 0 ]]; then
        echo "Updated task #${id}."
    else
        echo "Error: update failed for task #${id}." >&2
        return 1
    fi
}

delete_task() {
    local id line_num confirm
    read -rp "ID of task to delete: " id
    line_num=$(find_task_line "$id")
    if [[ -z "$line_num" ]]; then
        echo "No task found with ID ${id}."
        return 0
    fi

    read -rp "Are you sure you want to delete task #${id}? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Delete cancelled."
        return 0
    fi

    backup_data
    sed -i "${line_num}d" "$DATA_FILE"
    if [[ $? -eq 0 ]]; then
        echo "Deleted task #${id}."
    else
        echo "Error: delete failed for task #${id}." >&2
        return 1
    fi
}

# ---- main menu loop ----
while true; do
    echo
    echo "=== Todo List ==="
    echo "1) Add"
    echo "2) View/List"
    echo "3) Search"
    echo "4) Update"
    echo "5) Delete"
    echo "6) Exit"
    read -rp "Choose an option (1-6): " choice

    case "$choice" in
        1) add_task ;;
        2) list_tasks ;;
        3) search_tasks ;;
        4) update_task ;;
        5) delete_task ;;
        6) echo "Goodbye."; exit 0 ;;
        *) echo "Invalid option, please choose 1-6." ;;
    esac
done
