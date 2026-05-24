#!/bin/bash
# ----------------------------------------------------------------------
#   DNS Master Switcher
#   Author: Hossein Shourgashti (hosseinit1988)
#   Github: https://github.com/hosseinit1988
#   Description: A professional and beautiful DNS manager for Ubuntu 20+
#   with tons of features, custom DNS addition, and DoT support.
# ----------------------------------------------------------------------

# --- Color Palette ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Configuration & State ---
CONFIG_FILE="$HOME/.dns_switcher_custom.conf"
declare -A DNS_SERVERS

# --- Functions ---

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  Error: Please run this script as root ║${NC}"
        echo -e "${RED}║  Use: sudo $0                        ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        exit 1
    fi
}

# Initialize default DNS providers
init_defaults() {
    DNS_SERVERS=(
        # Iranian & Regional Providers
        ["Shecan"]="178.22.122.100 185.51.200.2"
        ["Radar"]="10.202.10.10 10.202.10.11"
        ["Electro"]="78.157.42.100 78.157.42.101"
        ["Begzar"]="185.55.226.26 185.55.226.25"
        ["DNS Pro"]="87.107.110.109 87.107.110.110"
        ["403"]="10.202.10.202 10.202.10.102"
        ["MCI"]="208.67.220.200 208.67.222.222"
        ["MTN-Irancel"]="74.82.42.42"
        ["Rightel"]="91.239.100.100 89.223.43.71"
        # International Public DNS
        ["Google"]="8.8.8.8 8.8.4.4"
        ["Cloudflare"]="1.1.1.1 1.0.0.1"
        ["Quad9"]="9.9.9.9 149.112.112.112"
        ["OpenDNS"]="208.67.222.222 208.67.220.220"
        ["AdGuard"]="94.140.14.14 94.140.15.15"
        ["Verisign"]="64.6.64.6 64.6.65.6"
        ["NTT"]="129.250.35.250 129.250.35.251"
        ["DNS-XBOX"]="37.220.84.124"
    )
    # Load custom entries if file exists
    load_custom
}

# Load custom DNS entries from config file
load_custom() {
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            # Ignore empty lines and comments
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            DNS_SERVERS["$key"]="$value"
        done < "$CONFIG_FILE"
    fi
}

# Save a new custom DNS permanently
save_custom() {
    local name="$1"
    local ip1="$2"
    local ip2="$3"
    echo "${name}=${ip1} ${ip2}" >> "$CONFIG_FILE"
}

# Draw a beautiful header
draw_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}         DNS Master Switcher ${WHITE}by Hossein Shourgashti${CYAN}      ║${NC}"
    echo -e "${CYAN}║${WHITE}        github.com/hosseinit1988                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

# Show current DNS configuration using resolvectl
show_current_dns() {
    echo -e "\n${BOLD}${WHITE}[*] Current DNS Configuration:${NC}"
    local dns_info
    dns_info=$(resolvectl dns 2>/dev/null | grep -v "Link" | grep -v "^$" || true)
    if [ -z "$dns_info" ]; then
        echo -e "${YELLOW}   ⚠️  Could not retrieve current DNS settings via resolvectl.${NC}"
        echo -e "${WHITE}   Falling back to /etc/resolv.conf:${NC}"
        grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "   •", $2}' || echo "   (none)"
    else
        echo "$dns_info" | while IFS= read -r line; do
            echo -e "${GREEN}   $line${NC}"
        done
    fi

    local dot_status
    dot_status=$(resolvectl status 2>/dev/null | grep "DNS-over-TLS" || echo "unknown")
    echo -e "${BOLD}${WHITE}[*] DNS-over-TLS Status:${NC} ${MAGENTA}${dot_status##*: }${NC}"
    echo
}

# Backup current /etc/resolv.conf (optional, just in case)
backup_resolv() {
    local backup_file="/etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)"
    if cp /etc/resolv.conf "$backup_file" 2>/dev/null; then
        echo -e "${GREEN}   ✓ Backup created: ${WHITE}$backup_file${NC}"
    fi
}

# The core function to change DNS using resolvectl (the Ubuntu way)
set_dns() {
    local provider_name="$1"
    local dns_ips="$2"
    local interface
    
    # Auto-detect primary network interface (usually eth0, ens3, wlan0)
    interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -z "$interface" ]; then
        # Fallback: list interfaces and take the first non-lo one
        interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n1)
        if [ -z "$interface" ]; then
            echo -e "${RED}   ✗ Could not detect network interface! Aborting.${NC}"
            return 1
        fi
    fi

    echo -e "\n${BOLD}${WHITE}[+] Applying '${provider_name}' DNS to interface '$interface'...${NC}"
    backup_resolv

    # Set DNS servers via systemd-resolved
    resolvectl dns "$interface" $dns_ips
    # Optionally set the domain if you want
    # resolvectl domain "$interface" "~."

    # Flush caches and restart to be sure
    systemctl restart systemd-resolved 2>/dev/null
    resolvectl flush-caches 2>/dev/null

    echo -e "${GREEN}   ✓ DNS successfully switched to ${YELLOW}${provider_name}${GREEN}.${NC}"
    echo -e "${GREEN}   ✓ Servers: ${WHITE}${dns_ips// /, }${NC}"
}

# Toggle DNS-over-TLS on/off for all interfaces
toggle_dot() {
    local current_status
    current_status=$(resolvectl status 2>/dev/null | grep "DNS-over-TLS" | head -n1 | awk '{print $NF}')

    if [[ "$current_status" == "yes" || "$current_status" == "opportunistic" ]]; then
        echo -e "${YELLOW}[i] Disabling DNS-over-TLS...${NC}"
        resolvectl dns-over-tls all no
    else
        echo -e "${YELLOW}[i] Enabling DNS-over-TLS (opportunistic mode)...${NC}"
        resolvectl dns-over-tls all opportunistic
    fi
    systemctl restart systemd-resolved 2>/dev/null
    echo -e "${GREEN}   ✓ Done.${NC}"
}

# Reset DNS to default (DHCP-provided)
reset_to_default() {
    local interface
    interface=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')
    if [ -z "$interface" ]; then
        interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n1)
    fi
    if [ -n "$interface" ]; then
        echo -e "${YELLOW}[i] Reverting interface '$interface' to default DNS via DHCP...${NC}"
        resolvectl revert "$interface" 2>/dev/null
        systemctl restart systemd-resolved 2>/dev/null
        resolvectl flush-caches 2>/dev/null
        echo -e "${GREEN}   ✓ Reverted to default settings.${NC}"
    else
        echo -e "${RED}   ✗ Could not detect interface to revert.${NC}"
    fi
}

# Interactive menu to add a new custom DNS
add_custom_dns() {
    echo -e "\n${CYAN}--- Add New Custom DNS Provider ---${NC}"
    read -rp "  Provider Name (e.g., MyPrivateDNS): " c_name
    read -rp "  Primary DNS IP: " c_ip1
    read -rp "  Secondary DNS IP (optional): " c_ip2

    if [ -z "$c_name" ] || [ -z "$c_ip1" ]; then
        echo -e "${RED}   ✗ Name and Primary IP are required.${NC}"
        return
    fi

    if [ -z "$c_ip2" ]; then
        c_ip2="$c_ip1" # If no secondary, use primary twice
    fi

    DNS_SERVERS["$c_name"]="$c_ip1 $c_ip2"
    save_custom "$c_name" "$c_ip1" "$c_ip2"
    echo -e "${GREEN}   ✓ Custom DNS '$c_name' added successfully and saved!${NC}"
    sleep 1.5
}

# Main interactive menu
main_menu() {
    while true; do
        draw_header
        show_current_dns

        echo -e "${BOLD}${WHITE}Available DNS Providers:${NC}"
        echo -e "${CYAN}-----------------------------------------${NC}"
        
        local options=()
        local i=1
        # Sort providers alphabetically for clean look
        for provider in $(printf '%s\n' "${!DNS_SERVERS[@]}" | sort); do
            printf "  ${GREEN}%3d)${NC} ${WHITE}%-18s${NC} : ${YELLOW}%s${NC}\n" "$i" "$provider" "${DNS_SERVERS[$provider]}"
            options+=("$provider")
            ((i++))
        done

        echo -e "${CYAN}-----------------------------------------${NC}"
        echo -e "  ${MAGENTA}A)${NC} Add Custom DNS"
        echo -e "  ${MAGENTA}T)${NC} Toggle DNS-over-TLS (DoT)"
        echo -e "  ${MAGENTA}R)${NC} Reset to Default (DHCP)"
        echo -e "  ${RED}0)${NC} Exit"
        echo

        read -rp "  Your choice: " choice

        # Handle choice
        if [[ "$choice" == "0" ]]; then
            echo -e "\n${GREEN}Goodbye! Stay secure. - Hossein Shourgashti${NC}"
            exit 0
        elif [[ "$choice" =~ ^[0-9]+$ ]]; then
            local idx=$((choice - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#options[@]}" ]; then
                local selected_provider="${options[$idx]}"
                set_dns "$selected_provider" "${DNS_SERVERS[$selected_provider]}"
                read -rp $'\n'"Press Enter to return to menu..."
            else
                echo -e "${RED}   ✗ Invalid number. Press Enter to continue...${NC}"
                read -r
            fi
        else
            case "${choice^^}" in
                A)
                    add_custom_dns
                    ;;
                T)
                    toggle_dot
                    read -rp $'\n'"Press Enter to return to menu..."
                    ;;
                R)
                    reset_to_default
                    read -rp $'\n'"Press Enter to return to menu..."
                    ;;
                *)
                    echo -e "${RED}   ✗ Invalid option. Press Enter to continue...${NC}"
                    read -r
                    ;;
            esac
        fi
    done
}

# --- Main Execution ---
check_root
init_defaults
main_menu
