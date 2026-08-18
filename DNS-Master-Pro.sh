#!/bin/bash
# ======================================================
# DNS Master Pro - Graphical Edition
# ======================================================

# --- Check and install dialog if missing ---
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing..."
    sudo apt update
    sudo apt install -y dialog
    if [ $? -ne 0 ]; then
        echo "Failed to install dialog. Please install manually:"
        echo "sudo apt install dialog"
        exit 1
    fi
fi

# --- Dialog Configuration ---
export DIALOGRC=/dev/null
export NEWT_COLORS='
root=,black
window=,black
border=black,black
textbox=white,black
button=black,white
title=cyan,black
'

# --- Global Variables ---
CONFIG_FILE="$HOME/.dns_master_pro_custom.conf"
declare -A DNS_SERVERS

# --- Initialize DNS providers ---
init_defaults() {
    DNS_SERVERS=(
        ["Google"]="8.8.8.8 8.8.4.4"
        ["Cloudflare"]="1.1.1.1 1.0.0.1"
        ["Quad9"]="9.9.9.9 149.112.112.112"
        ["OpenDNS"]="208.67.222.222 208.67.220.220"
        ["AdGuard"]="94.140.14.14 94.140.15.15"
        ["Shecan"]="178.22.122.100 185.51.200.2"
        ["Radar"]="10.202.10.10 10.202.10.11"
        ["Electro"]="78.157.42.100 78.157.42.101"
        ["Begzar"]="185.55.226.26 185.55.226.25"
        ["403"]="10.202.10.202 10.202.10.102"
    )
    # Load custom entries
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            DNS_SERVERS["$key"]="$value"
        done < "$CONFIG_FILE"
    fi
}

# --- Check root ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        dialog --title "Error" --msgbox "Please run as root:\nsudo $0" 8 40
        exit 1
    fi
}

# --- Get current DNS ---
get_current_dns() {
    local interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -n "$interface" ]; then
        resolvectl dns "$interface" 2>/dev/null | grep -v "Link" | grep -v "^$" || echo "No DNS set (DHCP)"
    else
        echo "No interface found"
    fi
}

# --- Get DoT status ---
get_dot_status() {
    resolvectl status 2>/dev/null | grep "DNS-over-TLS" | head -n1 | awk '{print $NF}' || echo "unknown"
}

# --- Set DNS ---
set_dns() {
    local name="$1"
    local ips="$2"
    local interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    
    if [ -z "$interface" ]; then
        dialog --msgbox "No network interface found!" 6 40
        return 1
    fi
    
    # Backup resolv.conf
    cp /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    
    # Apply DNS
    resolvectl dns "$interface" $ips
    systemctl restart systemd-resolved 2>/dev/null
    resolvectl flush-caches 2>/dev/null
    
    dialog --title "Success" --msgbox "DNS switched to: $name\n\nServers: ${ips// /, }" 8 50
}

# --- Toggle DNS-over-TLS ---
toggle_dot() {
    local current=$(get_dot_status)
    
    if [[ "$current" == "yes" || "$current" == "opportunistic" ]]; then
        resolvectl dns-over-tls all no
        systemctl restart systemd-resolved
        dialog --title "DoT" --msgbox "DNS-over-TLS has been DISABLED" 6 40
    else
        resolvectl dns-over-tls all opportunistic
        systemctl restart systemd-resolved
        dialog --title "DoT" --msgbox "DNS-over-TLS has been ENABLED (opportunistic)" 6 40
    fi
}

# --- Reset to default ---
reset_to_default() {
    local interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    
    if [ -n "$interface" ]; then
        resolvectl revert "$interface"
        systemctl restart systemd-resolved
        resolvectl flush-caches
        dialog --title "Reset" --msgbox "DNS reverted to default (DHCP) on: $interface" 6 50
    else
        dialog --msgbox "No interface found!" 6 40
    fi
}

# --- Add custom DNS ---
add_custom_dns() {
    local name=$(dialog --title "Add Custom DNS" --inputbox "Provider Name:" 8 40 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return
    
    local ip1=$(dialog --title "Add Custom DNS" --inputbox "Primary DNS IP:" 8 40 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return
    
    local ip2=$(dialog --title "Add Custom DNS" --inputbox "Secondary DNS IP (optional):" 8 40 "$ip1" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return
    
    [ -z "$ip2" ] && ip2="$ip1"
    
    DNS_SERVERS["$name"]="$ip1 $ip2"
    echo "${name}=${ip1} ${ip2}" >> "$CONFIG_FILE"
    dialog --title "Success" --msgbox "Custom DNS '$name' added successfully!" 6 40
}

# --- Main menu ---
main_menu() {
    while true; do
        local current_dns=$(get_current_dns | head -2 | tr '\n' ' ')
        local dot_status=$(get_dot_status)
        
        local choice=$(dialog --clear --title "DNS Master Pro" \
            --menu "Current DNS: $current_dns\nDoT: $dot_status\n\nSelect option:" 20 70 8 \
            1 "Change DNS Server" \
            2 "Add Custom DNS" \
            3 "Toggle DNS-over-TLS" \
            4 "Reset to Default (DHCP)" \
            5 "Exit" \
            3>&1 1>&2 2>&3)
        
        case $choice in
            1)
                # Build provider list
                local list=()
                local names=()
                local i=1
                for provider in $(printf '%s\n' "${!DNS_SERVERS[@]}" | sort); do
                    list+=("$i" "$provider - ${DNS_SERVERS[$provider]}")
                    names+=("$provider")
                    ((i++))
                done
                
                local sel=$(dialog --clear --title "Select DNS Provider" \
                    --menu "Choose a provider:" 20 70 10 \
                    "${list[@]}" \
                    3>&1 1>&2 2>&3)
                
                if [ -n "$sel" ] && [ "$sel" -ge 1 ] 2>/dev/null; then
                    local idx=$((sel - 1))
                    local prov="${names[$idx]}"
                    set_dns "$prov" "${DNS_SERVERS[$prov]}"
                fi
                ;;
            2)
                add_custom_dns
                ;;
            3)
                toggle_dot
                ;;
            4)
                reset_to_default
                ;;
            5|"")
                dialog --clear --title "Goodbye" --msgbox "Stay secure!" 6 30
                clear
                echo "DNS Master Pro exited."
                exit 0
                ;;
        esac
    done
}

# --- Main ---
clear
echo "Starting DNS Master Pro..."
sleep 1
init_defaults
check_root
main_menu
