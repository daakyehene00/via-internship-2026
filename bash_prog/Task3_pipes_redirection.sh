#!/usr/bin/env bash
# -----------------------------------------------------------------
# @title Task3_pipes_redirection.sh
# @author Eugene Antwi Boasiako
# @index 7352623
# @school Kwame Nkrumah University of Science and Technology (KNUST)
# @description Generates a sample log file, then uses pipes and text
#              tools to summarize it (line count, level breakdown,
#              top IPs, and all ERROR lines). Writes the summary to
#              results.txt and any pipeline errors to errors.log.
# @date September 14, 2026
# -----------------------------------------------------------------

set -u

usage() {
    echo "Usage: $0"
    echo "  Takes no arguments. Generates sample_log.txt in the current"
    echo "  directory, analyzes it, and writes results.txt / errors.log."
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

LOG_FILE="sample_log.txt"
RESULTS_FILE="results.txt"
ERROR_FILE="errors.log"

# ---- generate the sample log data via a heredoc ----
# Self-contained on purpose: grading shouldn't depend on a separate
# data file being present, so the script builds its own fixture.
cat > "$LOG_FILE" << 'LOG_DATA'
2026-09-11 10:02:09 INFO 192.168.1.23 User login successful
2026-09-11 10:03:01 WARN 192.168.1.10 Slow query detected
2026-09-11 10:03:59 WARN 192.168.1.23 Disk usage above 80%
2026-09-11 10:04:26 INFO 192.168.1.10 User logout
2026-09-11 10:05:01 INFO 192.168.1.10 Config reloaded
2026-09-11 10:05:15 WARN 192.168.1.23 Disk usage above 80%
2026-09-11 10:08:18 INFO 192.168.1.10 Config reloaded
2026-09-11 10:09:36 INFO 192.168.1.23 Config reloaded
2026-09-11 10:10:12 INFO 192.168.1.10 Backup completed
2026-09-11 10:11:18 WARN 192.168.1.10 High memory usage detected
2026-09-11 10:13:24 WARN 192.168.1.23 Disk usage above 80%
2026-09-11 10:14:03 INFO 192.168.1.45 Backup completed
2026-09-11 10:17:52 INFO 192.168.1.45 Config reloaded
2026-09-11 10:21:15 INFO 192.168.1.23 User logout
2026-09-11 10:22:20 WARN 192.168.1.10 Retrying connection
2026-09-11 10:25:06 INFO 192.168.1.10 Config reloaded
2026-09-11 10:25:13 WARN 192.168.1.45 High memory usage detected
2026-09-11 10:27:22 WARN 192.168.1.45 Disk usage above 80%
2026-09-11 10:28:10 WARN 192.168.1.10 Slow query detected
2026-09-11 10:30:54 INFO 192.168.1.10 Health check passed
2026-09-11 10:33:58 ERROR 192.168.1.10 Disk write failed
2026-09-11 10:37:42 WARN 192.168.1.10 Disk usage above 80%
2026-09-11 10:40:23 WARN 192.168.1.23 Retrying connection
2026-09-11 10:43:08 INFO 192.168.1.23 Service started
2026-09-11 10:43:37 INFO 192.168.1.23 Config reloaded
2026-09-11 10:44:08 INFO 192.168.1.23 Service started
2026-09-11 10:45:55 INFO 192.168.1.45 Health check passed
2026-09-11 10:49:00 INFO 192.168.1.45 Health check passed
2026-09-11 10:51:56 INFO 192.168.1.99 Health check passed
2026-09-11 10:54:41 INFO 192.168.1.10 Backup completed
2026-09-11 10:57:55 INFO 192.168.1.10 User logout
2026-09-11 10:59:09 WARN 192.168.1.23 Disk usage above 80%
2026-09-11 11:03:02 WARN 192.168.1.23 Slow query detected
2026-09-11 11:05:02 INFO 192.168.1.45 Config reloaded
2026-09-11 11:07:41 WARN 192.168.1.10 High memory usage detected
2026-09-11 11:08:10 ERROR 192.168.1.99 Null pointer exception
2026-09-11 11:11:35 INFO 192.168.1.45 User login successful
2026-09-11 11:15:15 INFO 192.168.1.10 User logout
2026-09-11 11:15:28 INFO 192.168.1.23 User login successful
2026-09-11 11:18:06 INFO 192.168.1.10 User login successful
2026-09-11 11:19:40 INFO 192.168.1.10 Config reloaded
2026-09-11 11:19:44 INFO 192.168.1.10 Health check passed
2026-09-11 11:21:24 INFO 192.168.1.10 Config reloaded
2026-09-11 11:23:54 INFO 192.168.1.10 Health check passed
2026-09-11 11:27:24 WARN 192.168.1.10 Disk usage above 80%
2026-09-11 11:28:30 ERROR 192.168.1.10 Disk write failed
2026-09-11 11:32:23 WARN 192.168.1.23 Disk usage above 80%
2026-09-11 11:33:56 INFO 192.168.1.23 Backup completed
2026-09-11 11:34:44 WARN 192.168.1.10 Disk usage above 80%
2026-09-11 11:37:17 INFO 192.168.1.23 Service started
2026-09-11 11:38:51 WARN 192.168.1.99 Slow query detected
2026-09-11 11:40:30 ERROR 192.168.1.99 Authentication failed
2026-09-11 11:42:22 INFO 192.168.1.23 User logout
2026-09-11 11:43:55 WARN 192.168.1.10 Disk usage above 80%
2026-09-11 11:44:45 INFO 192.168.1.45 Service started
LOG_DATA

if [[ ! -s "$LOG_FILE" ]]; then
    echo "Error: failed to generate '$LOG_FILE'." >&2
    exit 1
fi

# Truncate results.txt / errors.log at the start of each run so old
# output from a previous run doesn't get mixed in with the new one.
: > "$RESULTS_FILE"
: > "$ERROR_FILE"

{
    echo "=== Log Analysis Report ==="
    echo "Generated: $(date)"
    echo

    echo "--- Total log lines ---"
    wc -l < "$LOG_FILE"
    echo

    echo "--- Lines per log level ---"
    # awk picks out column 3 (the level) and counts occurrences directly,
    # which is a single pass rather than three separate grep -c calls.
    awk '{count[$3]++} END {for (lvl in count) print lvl": "count[lvl]}' "$LOG_FILE" | sort
    echo

    echo "--- Top 3 most frequent IP addresses ---"
    # cut pulls column 4 (the IP), sort groups identical values together
    # so uniq -c can count them, then sort -rn ranks by count descending.
    cut -d' ' -f4 "$LOG_FILE" | sort | uniq -c | sort -rn | head -3
    echo

    echo "--- All ERROR lines ---"
    grep "ERROR" "$LOG_FILE"
} > "$RESULTS_FILE" 2> "$ERROR_FILE"

if [[ $? -eq 0 ]]; then
    echo "Success: analysis complete. See '$RESULTS_FILE' for the report."
else
    echo "Error: something in the analysis pipeline failed. See '$ERROR_FILE'." >&2
    exit 1
fi

if [[ -s "$ERROR_FILE" ]]; then
    echo "Notice: '$ERROR_FILE' is non-empty, check it for pipeline warnings."
fi

exit 0
