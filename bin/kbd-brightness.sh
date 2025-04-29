#!/bin/bash

LEVEL_FILE="/sys/class/leds/asus::kbd_backlight/brightness"
MAX=3

case "$1" in
    up)
        CUR=$(cat "$LEVEL_FILE")
        [[ $CUR -lt $MAX ]] && CUR=$((CUR + 1))
        ;;
    down)
        CUR=$(cat "$LEVEL_FILE")
        [[ $CUR -gt 0 ]] && CUR=$((CUR - 1))
        ;;
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
esac

echo "$CUR" | sudo tee "$LEVEL_FILE" > /dev/null
