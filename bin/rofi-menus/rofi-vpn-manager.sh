#!/bin/bash

VPN_DIR="$HOME/.cache/rofivpnmenu/vpns"
PID_DIR="$HOME/.cache/rofivpnmenu/pids"
VPN_CONNECTED_ICON=" "
DISABLED_COLOR="#D35F5E"
ENABLED_COLOR="#A3BE8C"
mkdir -p "$VPN_DIR" "$PID_DIR"

# Function to print usage information
print_error() {
    echo "Usage: $0 [--status] [--enabled-color] [--disabled-color]"
    exit 1
}

# Function to upload VPN configuration files
upload_config() {
    CONFIGS=$(zenity --file-selection --multiple --separator="|" \
        --title="Select VPN configurations" \
        --file-filter="OpenVPN configuration files | *.ovpn")
    if [ $? -eq 0 ]; then
        IFS='|' read -ra ADDR <<< "$CONFIGS"
        for i in "${ADDR[@]}"; do
            if [[ $i == *.ovpn ]]; then
                cp "$i" "$VPN_DIR"
                notify-send "OpenVPN" "Configuration files have been successfully added!"
            else
                zenity --error --text="Only files with the extension .ovpn are allowed to upload."
            fi
        done
    fi
}

# Function to delete VPN configuration file
delete_vpn_config() {
    local SELECTED_VPN="$1"
    PID_FILE="$PID_DIR/$SELECTED_VPN.pid"
    
    # If PID file exists, terminate the VPN process
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if [ -n "$PID" ]; then
            kill "$PID"
            sleep 1
            if kill -0 "$PID" 2>/dev/null; then
                kill -9 "$PID"
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # Delete the VPN configuration file
    VPN_CONFIG_FILE="$VPN_DIR/$SELECTED_VPN"
    if [ -f "$VPN_CONFIG_FILE" ]; then
        rm -f "$VPN_CONFIG_FILE"
    fi
    notify-send "OpenVPN" "The $SELECTED_VPN configuration has been successfully deleted!"
}

# Function to disconnect all active VPN connections
disconnect_all_vpns() {
    for PID_PATH in "$PID_DIR"/*.pid; do
        [[ ! -e $PID_PATH ]] && continue
        VPN_PID=$(basename "$PID_PATH" .pid)
        PID=$(cat "$PID_PATH")
        if [ -n "$PID" ]; then
            kill "$PID"
            sleep 1
            if kill -0 "$PID" 2>/dev/null; then
                kill -9 "$PID"
            fi
            notify-send "OpenVPN" "Disconnected from $VPN_PID"
        fi
        rm -f "$PID_PATH"
    done
}

# Function to toggle VPN connection (connect/disconnect)
toggle_vpn() {
    local VPN="$1"
    PID_FILE="$PID_DIR/$VPN.pid"
    if [ -f "$PID_FILE" ]; then
        # If already connected to this VPN, disconnect
        PID=$(cat "$PID_FILE")
        if [ -n "$PID" ]; then
            kill "$PID"
            sleep 1
            if kill -0 "$PID" 2>/dev/null; then
                kill -9 "$PID"
            fi
        fi
        rm -f "$PID_FILE"
        notify-send "OpenVPN" "Disconnected from $VPN"
    else
        PASSWORD=$(rofi -dmenu -password -p "Enter the sudo password:")

        if [ $? -ne 0 ]; then
            notify-send "OpenVPN" "Connection canceled"
            return
        fi
        
        disconnect_all_vpns # Disconnect all active VPNs before connecting to a new one

        echo $PASSWORD | sudo -S nohup openvpn --config "$VPN_DIR/$VPN" >/dev/null 2>&1 &
        PID=$!
        echo $PID > "$PID_FILE"
        notify-send "OpenVPN" "Connecting to $VPN initiated"
    fi
}

# Function to display VPN action menu (connect/disconnect or delete config)
vpn_action_menu() {
    local VPN="$1"
    PID_FILE="$PID_DIR/$VPN.pid"
    ACTIONS="  Connect\n  Delete the config file"
    if [ -f "$PID_FILE" ]; then
        ACTIONS="  Disconnect\n  Delete the config file"
    fi
    ACTION=$(echo -e "$ACTIONS" | rofi -dmenu -p "Action with $VPN:")
    if [ $? -eq 0 ]; then
        case "$ACTION" in
            "  Connect"|"  Disconnect")
                toggle_vpn "$VPN"
                ;;
            "  Delete the config file")
                delete_vpn_config "$VPN"
                ;;
        esac
    fi
}

# Function to show the main rofi menu for selecting VPN configuration
show_rofi_menu() {
    local VPN_LIST=("$VPN_DIR"/*.ovpn) # Read list of .ovpn files into an array
    local MENU_ITEMS=("󰩍  Upload configuration files") # Menu items array

    # Check if .ovpn config files exist
    if compgen -G "$VPN_DIR"/*.ovpn > /dev/null; then
        for VPN_PATH in "${VPN_LIST[@]}"; do
            [[ ! -e $VPN_PATH ]] && continue
            VPN=$(basename "$VPN_PATH")
            VPN_STATUS=""
            PID_FILE="$PID_DIR/$VPN.pid"
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if [ -n "$PID" ] && ps -p $PID > /dev/null; then
                    COMMAND=$(ps -p $PID -o args=)
                    if [[ "$COMMAND" == *"openvpn"* ]]; then
                        VPN_STATUS="$VPN_CONNECTED_ICON "
                    fi
                else
                    rm -f "$PID_FILE"
                fi
            fi
            MENU_ITEMS+=("$VPN_STATUS$VPN")
        done
    fi
    IFS=$'\n' # Set internal field separator to new line
    SELECTED_VPN=$(printf "%s\n" "${MENU_ITEMS[@]}" | rofi -dmenu -p "Select VPN:" -matching fuzzy)
    if [ $? -ne 0 ]; then
        return
    fi
    if [[ "$SELECTED_VPN" == "󰩍  Upload configuration files" ]]; then
        upload_config
        return
    fi

    SELECTED_VPN="${SELECTED_VPN#$VPN_CONNECTED_ICON }"
    vpn_action_menu "$SELECTED_VPN"
}

# Function to print VPN connection status
print_status() {
    local connected=false
    # Check if there are any active VPN connections
    for PID_PATH in "$PID_DIR"/*.pid; do
        [[ ! -e $PID_PATH ]] && continue
        PID=$(cat "$PID_PATH")
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            connected=true
            break
        fi
    done

    if $connected; then
        local icon="󰯄 "
        local color=$ENABLED_COLOR
    else
        local icon="󰯄 "
        local color=$DISABLED_COLOR
    fi

    echo "<span color=\"$color\">$icon</span>"
}

# Command line argument processing
while [[ "$#" -gt 0 ]]; do
    case $1 in
		--enabled-color)
			ENABLED_COLOR="$2"
			shift
			;;
		--disabled-color)
			DISABLED_COLOR="$2"
			shift
			;;
        --status) status=true ;;
        *) print_error ;;
    esac
    shift
done

if [[ "$status" == true ]]; then
    print_status
    exit 0
fi

show_rofi_menu
