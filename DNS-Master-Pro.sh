#!/bin/bash

# ======================================================
# DNS Master Pro - Graphical Edition (TUI)
# Author: Based on original by Hossein Shourgashti
# Description: Enhanced graphical DNS manager using dialog
# Dependencies: dialog, resolvectl, systemd-resolved, dig
# ======================================================

# --- Color & Dialog Configuration ---
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
DIALOG_HEIGHT=20
DIALOG_WIDTH=75
declare -A DNS_SERVERS

# --- Check if running as root ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        dialog --title "Permission Error" --msgbox "Please run this script as root:\nsudo $0" 8 50
        exit 1
    fi
}

# --- Check and install dependencies ---
check_dependencies() {
    local deps=("dialog" "resolvectl" "systemctl" "dig")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        dialog --title "Missing Dependencies" \
               --msgbox "The following packages are required:\n\n${missing[*]}\n\nInstall them using:\nsudo apt install dialog dnsutils systemd-resolved" 12 60
        exit 1
    fi
}

# --- Initialize default DNS providers ---
init_defaults() {
    DNS_SERVERS=(
        ["Shecan"]="178.22.122.100 185.51.200.2"
        ["Radar"]="10.202.10.10 10.202.10.11"
        ["Electro"]="78.157.42.100 78.157.42.101"
        ["Begzar"]="185.55.226.26 185.55.226.25"
        ["DNS Pro"]="87.107.110.109 87.107.110.110"
        ["403"]="10.202.10.202 10.202.10.102"
        ["MCI"]="208.67.220.200 208.67.222.222"
        ["MTN-Irancel"]="74.82.42.42"
        ["Rightel"]="91.239.100.100 89.223.43.71"
        ["Google"]="8.8.8.8 8.8.4.4"
        ["Cloudflare"]="1.1.1.1 1.0.0.1"
        ["Quad9"]="9.9.9.9 149.112.112.112"
        ["OpenDNS"]="208.67.222.222 208.67.220.220"
        ["AdGuard"]="94.140.14.14 94.140.15.15"
        ["Verisign"]="64.6.64.6 64.6.65.6"
        ["NTT"]="129.250.35.250 129.250.35.251"
        ["DNS-XBOX"]="37.220.84.124"
    )
    load_custom
}

# --- Load custom DNS entries ---
load_custom() {
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            DNS_SERVERS["$key"]="$value"
        done < "$CONFIG_FILE"
    fi
}

# --- Save custom DNS entry ---
save_custom() {
    local name="$1"
    local ip1="$2"
    local ip2="$3"
    echo "${name}=${ip1} ${ip2}" >> "$CONFIG_FILE"
}

# --- Get current DNS servers ---
get_current_dns() {
    local interface
    interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -z "$interface" ]; then
        interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n1)
    fi
    
    if [ -n "$interface" ]; then
        resolvectl dns "$interface" 2>/dev/null | grep -v "Link" | grep -v "^$" || echo "No DNS set (DHCP)"
    else
        grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' || echo "No DNS found"
    fi
}

# --- Get DNS-over-TLS status ---
get_dot_status() {
    resolvectl status 2>/dev/null | grep "DNS-over-TLS" | head -n1 | awk '{print $NF}'
}

# --- Change DNS using resolvectl ---
set_dns() {
    local provider_name="$1"
    local dns_ips="$2"
    local interface
    
    interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -z "$interface" ]; then
        interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n1)
    fi
    
    if [ -z "$interface" ]; then
        dialog --title "Error" --msgbox "Could not detect network interface!" 6 40
        return 1
    fi
    
    # Backup resolv.conf
    cp /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    
    # Apply DNS
    resolvectl dns "$interface" $dns_ips
    systemctl restart systemd-resolved 2>/dev/null
    resolvectl flush-caches 2>/dev/null
    
    dialog --title "Success" --msgbox "DNS switched to: $provider_name\nServers: ${dns_ips// /, }" 8 50
}

# --- Toggle DNS-over-TLS ---
toggle_dot() {
    local current_status
    current_status=$(get_dot_status)
    
    if [[ "$current_status" == "yes" || "$current_status" == "opportunistic" ]]; then
        resolvectl dns-over-tls all no
        systemctl restart systemd-resolved 2>/dev/null
        dialog --title "DoT Disabled" --msgbox "DNS-over-TLS has been disabled." 6 40
    else
        resolvectl dns-over-tls all opportunistic
        systemctl restart systemd-resolved 2>/dev/null
        dialog --title "DoT Enabled" --msgbox "DNS-over-TLS has been enabled (opportunistic mode)." 6 40
    fi
}

# --- Reset DNS to default (DHCP) ---
reset_to_default() {
    local interface
    interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -z "$interface" ]; then
        interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n1)
    fi
    
    if [ -n "$interface" ]; then
        resolvectl revert "$interface" 2>/dev/null
        systemctl restart systemd-resolved 2>/dev/null
        resolvectl flush-caches 2>/dev/null
        dialog --title "Reset Complete" --msgbox "DNS reverted to default (DHCP) on interface: $interface" 6 50
    else
        dialog --title "Error" --msgbox "Could not detect interface to revert." 6 40
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
    
    if [ -z "$name" ] || [ -z "$ip1" ]; then
        dialog --title "Error" --msgbox "Name and Primary IP are required!" 6 40
        return
    fi
    
    if [ -z "$ip2" ]; then
        ip2="$ip1"
    fi
    
    DNS_SERVERS["$name"]="$ip1 $ip2"
    save_custom "$name" "$ip1" "$ip2"
    dialog --title "Success" --msgbox "Custom DNS '$name' added successfully!" 6 40
}

# --- DNS Benchmark (simple ping test) ---
benchmark_dns() {
    local servers=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222" "94.140.14.14")
    local results=()
    local fastest=""
    local fastest_time=999999
    
    {
        echo "0"
        echo "XXX"
        echo "Starting DNS Benchmark..."
        echo "XXX"
        
        for i in "${!servers[@]}"; do
            local server="${servers[$i]}"
            local avg_ping=$(ping -c 3 -q "$server" 2>/dev/null | awk -F/ '/^rtt/ {print $5}')
            
            if [ -n "$avg_ping" ]; then
                results+=("$server: $avg_ping ms")
                if (( $(echo "$avg_ping < $fastest_time" | bc -l 2>/dev/null || echo "0") )); then
                    fastest_time=$avg_ping
                    fastest=$server
                fi
            else
                results+=("$server: TIMEOUT")
            fi
            
            local percent=$(( (i + 1) * 100 / ${#servers[@]} ))
            echo "$percent"
            echo "XXX"
            echo "Testing $server ... ($((i + 1))/${#servers[@]})"
            echo "XXX"
        done
        
        echo "100"
        echo "XXX"
        echo "Benchmark Complete!"
        echo "Fastest: $fastest ($fastest_time ms)"
        echo "XXX"
    } | dialog --title "DNS Benchmark" --gauge "Initializing..." 10 70 0
    
    if [ -n "$fastest" ]; then
        dialog --title "Benchmark Results" --yesno "Fastest DNS: $fastest ($fastest_time ms)\n\nDo you want to set it as primary DNS?" 10 60
        if [ $? -eq 0 ]; then
            set_dns "Benchmark Winner" "$fastest"
        fi
    else
        dialog --msgbox "No responsive DNS servers found." 6 40
    fi
}

# --- Resolve domain (dig) ---
resolve_domain() {
    local domain=$(dialog --title "Resolve Domain" --inputbox "Enter domain name:" 8 40 "google.com" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return
    
    local result=$(dig +short "$domain" | head -10)
    if [ -z "$result" ]; then
        result="No IP found or domain does not exist."
    fi
    
    dialog --title "Resolve Result for $domain" --msgbox "$result" 20 60
}

# --- Show network information ---
show_network_info() {
    local info=""
    info+="===== System Information =====\n"
    info+="Hostname: $(hostname)\n"
    info+="Kernel: $(uname -r)\n"
    info+="OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')\n\n"
    
    info+="===== Network Interfaces =====\n"
    info+="$(ip -br addr show | grep -v lo)\n\n"
    
    info+="===== Current DNS Servers =====\n"
    info+="$(get_current_dns)\n\n"
    
    info+="===== DNS-over-TLS Status =====\n"
    info+="$(get_dot_status)\n\n"
    
    info+="===== Routing Table =====\n"
    info+="$(ip route | grep default)"
    
    dialog --title "Network Information" --msgbox "$info" 25 70
}

# --- Main Menu ---
main_menu() {
    while true; do
        # Get current info for display
        local current_dns=$(get_current_dns | head -2 | tr '\n' ' ')
        local dot_status=$(get_dot_status)
        
        # Build menu options
        local menu_options=()
        menu_options+=("1" "Change DNS Server")
        menu_options+=("2" "Add Custom DNS")
        menu_options+=("3" "DNS Benchmark")
        menu_options+=("4" "Resolve Domain")
        menu_options+=("5" "Network Information")
        menu_options+=("6" "Toggle DNS-over-TLS")
        menu_options+=("7" "Reset to Default (DHCP)")
        menu_options+=("8" "Exit")
        
        local choice=$(dialog --clear --title "DNS Master Pro - Graphical Edition" \
            --menu "Current DNS: $current_dns\nDoT Status: $dot_status\n\nSelect an option:" \
            $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
            "${menu_options[@]}" \
            3>&1 1>&2 2>&3)
        
        case $choice in
            1)
                # Show list of DNS providers
                local provider_list=()
                local provider_names=()
                local i=1
                for provider in $(printf '%s\n' "${!DNS_SERVERS[@]}" | sort); do
                    provider_list+=("$i" "$provider - ${DNS_SERVERS[$provider]}")
                    provider_names+=("$provider")
                    ((i++))
                done
                
                local selected=$(dialog --clear --title "Select DNS Provider" \
                    --menu "Choose a DNS provider:" 20 70 15 \
                    "${provider_list[@]}" \
                    3>&1 1>&2 2>&3)
                
                if [ -n "$selected" ] && [ "$selected" -ge 1 ] && [ "$selected" -le "${#provider_names[@]}" ]; then
                    local idx=$((selected - 1))
                    local prov="${provider_names[$idx]}"
                    set_dns "$prov" "${DNS_SERVERS[$prov]}"
                fi
                ;;
            2)
                add_custom_dns
                ;;
            3)
                benchmark_dns
                ;;
            4)
                resolve_domain
                ;;
            5)
                show_network_info
                ;;
            6)
                toggle_dot
                ;;
            7)
                reset_to_default
                ;;
            8|"")
                dialog --clear --title "Goodbye" --msgbox "Stay secure!" 6 30
                clear
                exit 0
                ;;
        esac
    done
}

# --- Main Execution ---
clear
check_root
check_dependencies
init_defaults
main_menu
