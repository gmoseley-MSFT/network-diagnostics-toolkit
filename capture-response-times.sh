#!/bin/bash

capture_duration_seconds=${1:-60} # Default to 60 seconds if not specified
capture_folder="/root/captures"
mkdir -p "$capture_folder"

# Function to delete all but the three most recent capture files
cleanup_old_captures() {
    # List all files that do not contain "failure" in their names, sorted by modification time, and delete them
    # This keeps any file with "failure" in its name untouched
    ls -t "$capture_folder"/cx-tcpdump-*.pcap | grep -v "failure" | xargs -r rm --
}

# Main capture and monitoring loop
while :; do
    # Prepare for the new capture file
    new_capture_file="$capture_folder/cx-tcpdump-$(date +%Y-%m-%d-%H-%M-%S).pcap"

    # Start continuous tcpdump capture in the background
    tcpdump -w "$new_capture_file" > /dev/null 2>&1 &
    tcpdump_pid=$!

    echo "Started tcpdump capture with PID $tcpdump_pid."

    error_occurred=false # Flag to track if an error occurred

    # Sleep for the specified capture duration or until a request takes longer than 3 seconds
    end_time=$((SECONDS + capture_duration_seconds))
    while [ $SECONDS -lt $end_time ]; do
        if ! curl -o /dev/null -s --max-time 3 https://login.microsoft.com; then
            echo "Request took longer than 3 seconds or failed. Preparing to stop the current capture."
            error_occurred=true
            break
        else
            echo "Request completed within 3 seconds. Continuing to monitor..."
        fi
        sleep 1 # Check every second
    done

    # Stop the current capture
    kill $tcpdump_pid
    wait $tcpdump_pid 2>/dev/null
    echo "Stopped tcpdump capture. Capture saved to $new_capture_file"

    # If an error was detected, copy the pcap file and append "failure" to the name
    if [ "$error_occurred" = true ]; then
        failure_capture_file="${new_capture_file%.pcap}-failure.pcap"
        cp "$new_capture_file" "$failure_capture_file"
        echo "Error detected. Copy of capture saved to $failure_capture_file"
    fi

    # Cleanup old captures, keeping only the last three
    cleanup_old_captures
done
