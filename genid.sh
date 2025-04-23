#!/bin/bash

genid() {
    # Create counter file if it doesn't exist
    if [ ! -f .counter ]; then
        echo 0 > .counter
    fi

    # Access counter file with exclusive lock
    local status
    {
        flock -x 123

        # Read in last-used id
        prev_id=$(<.counter)

        if ! [[ "$prev_id" =~ ^[0-9]+$ ]]; then
            echo "Error: .counter contains malformed data" >&2
            status=1
        else
            # Increment to create new id
            new_id=$((prev_id + 1))

            # Update counter file with new id
            echo "$new_id" > .counter

            # Output id to stdout
            printf "%05d\n" "$new_id"
            status=0
        fi
    } 123>.counter.lock

    return $status
}