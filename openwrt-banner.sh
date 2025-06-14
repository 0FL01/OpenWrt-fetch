#!/bin/sh

# Color codes
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
NC='\033[0m' # No Color

# Logging function for errors
log_error() {
    printf "[ERROR] %s\n" "$1" >&2
}

print_banner() {
    printf "\033[1;1H\033[2J" # Clear screen
    printf "${RED}"
    cat << 'EOF'
    ██████╗ ██████╗ ███████╗███╗   ██╗██╗    ██╗██████╗ ████████╗
   ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██║    ██║██╔══██╗╚══██╔══╝
   ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║ █╗ ██║██████╔╝   ██║   
   ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║███╗██║██╔══██╗   ██║   
   ╚██████╔╝██║     ███████╗██║ ╚████║╚███╔███╔╝██║  ██║   ██║   
    ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   
EOF
    printf "${NC}\n"
}

get_cpu_temp() {
    local temp_file="/sys/class/thermal/thermal_zone0/temp"
    if [ ! -f "$temp_file" ]; then
        printf "${YELLOW}N/A${NC}"
        return
    fi
    
    local temp=$(cat "$temp_file")
    local temp_c=$((temp/1000))
    
    if [ $temp_c -ge 65 ]; then
       printf "${RED}%d.0°C${NC}" "$temp_c"
    else
       printf "${GREEN}%d.0°C${NC}" "$temp_c"
    fi
}

get_uptime() {
    local uptime_sec=$(cut -d' ' -f1 /proc/uptime | cut -d'.' -f1)
    local days=$((uptime_sec / 86400))
    local hours=$(((uptime_sec % 86400) / 3600))
    local minutes=$(((uptime_sec % 3600) / 60))
    
    if [ $days -gt 0 ]; then
        printf "%d day, %d hours, %d minutes" $days $hours $minutes
    elif [ $hours -gt 0 ]; then
        printf "%d hours, %d minutes" $hours $minutes
    else
        printf "%d minutes" $minutes
    fi
}

get_memory_info() {
    awk '/MemTotal/{total=$2} /MemFree/{free=$2} /Buffers/{buffers=$2} /Cached/{cached=$2} 
         END{
             used_kb = total - free - buffers - cached
             used_mb = int(used_kb/1024)
             total_mb = int(total/1024)
             printf "%dMB/%dMB used", used_mb, total_mb
         }' /proc/meminfo
}

get_swap_info() {
    awk '/SwapTotal/{total=$2} /SwapFree/{free=$2}
         END{
             if(total > 0) {
                 used_kb = total - free
                 used_mb = int(used_kb/1024)
                 total_mb = int(total/1024)
                 printf "%dMB/%dMB used", used_mb, total_mb
             } else {
                 printf "0B/511MB used"
             }
         }' /proc/meminfo
}

get_load_avg() {
    cut -d' ' -f1-3 /proc/loadavg
}

get_disk_usage() {
    df -h / | awk 'NR==2{gsub(/G/, "GB", $3); gsub(/G/, "GB", $2); gsub(/%/, "", $5); print $3"/"$2" used ("$5"%)"}'
}

get_ssh_sessions() {
    local ssh_count=0
    
    if command -v netstat >/dev/null 2>&1; then
        ssh_count=$(netstat -tn 2>/dev/null | grep ':22 ' | grep ESTABLISHED | wc -l 2>/dev/null || echo "0")
    elif command -v ss >/dev/null 2>&1; then
        ssh_count=$(ss -tn 2>/dev/null | grep ':22 ' | grep ESTAB | wc -l 2>/dev/null || echo "0")
    elif [ -f /proc/net/tcp ]; then
        # Port 22 in hex = 0016
        ssh_count=$(awk '$2 ~ /:0016$/ && $4 == "01" {count++} END {print count+0}' /proc/net/tcp 2>/dev/null || echo "0")
    elif command -v who >/dev/null 2>&1; then
        ssh_count=$(who 2>/dev/null | wc -l || echo "0")
    elif command -v w >/dev/null 2>&1; then
        ssh_count=$(w -h 2>/dev/null | wc -l || echo "0")
    else
        ssh_count="N/A"
    fi
    
    printf "%s" "$ssh_count"
}

# A more reliable function to determine the CPU model on ARM systems
get_cpu_model() {
    # Method 1: Try to read the model from the device tree (most reliable for device name)
    if [ -r /proc/device-tree/model ]; then
        local model
        model=$(cat /proc/device-tree/model | tr -d '\0') # tr -d '\0' removes null characters
        if [ -n "$model" ]; then
            printf "%s" "$model"
            return
        fi
    fi

    # Method 2: If that fails, look for "Hardware" or "model name" in /proc/cpuinfo
    # This is less reliable but may work on older systems
    local model
    model=$(awk -F': ' '/^Hardware|^model name/ {print $2; exit}' /proc/cpuinfo)
    if [ -n "$model" ]; then
        printf "%s" "$model"
        return
    fi
    
    # Method 3: Search in kernel logs (dmesg)
    # This can provide technical but useful information
    model=$(dmesg | grep -m 1 "CPU:" | sed 's/.*CPU: //')
    if [ -n "$model" ]; then
        printf "%s" "$model"
        return
    fi

    # If nothing is found, return "Unknown"
    printf "Unknown"
}

print_system_info() {
    local current_date
    current_date=$(date +'%Y-%m-%d %H:%M:%S')
    
    local uptime
    uptime=$(get_uptime)
    
    local ext_ip
    ext_ip=$(wget -qO- --timeout=3 ipinfo.io/ip 2>/dev/null || echo 'N/A')
    
    local cpu_model
    cpu_model=$(get_cpu_model)
    
    local cpu_temp
    cpu_temp=$(get_cpu_temp)

    local cores
    cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")
    
    local architecture
    architecture=$(uname -m)
    
    local kernel
    kernel=$(uname -r)
    
    local processes
    processes=$(ps | wc -l)
    
    local disk_info
    disk_info=$(get_disk_usage)

    local mem_info
    mem_info=$(get_memory_info)

    local swap_info
    swap_info=$(get_swap_info)

    local load_avg
    load_avg=$(get_load_avg)
    
    local board
    board=$(grep OPENWRT_BOARD /etc/os-release | cut -d'"' -f2 2>/dev/null || echo 'Unknown')
    
    local ssh_sessions
    ssh_sessions=$(get_ssh_sessions)
    
    local packages
    packages=$(opkg list-installed 2>/dev/null | wc -l || echo "0")
    
    local upgrades
    upgrades=$(opkg list-upgradable 2>/dev/null | wc -l || echo "0")

    printf "\n"
    printf "Date:         ${YELLOW}📅 %s${NC}\n" "$current_date"
    printf "Uptime:       ${BLUE}🕐 %s${NC}\n" "$uptime"
    printf "Router:       ${RED}%s${NC}\n" "$cpu_model"
    printf "External IP:  ${CYAN}%s${NC}\n" "$ext_ip"
    printf "OS:           ${GREEN}Linux 🐧${NC}\n"
    printf "CPU:          ${GREEN}%s${NC}\n" "$board"
    printf "Kernel:       ${GREEN}%s${NC}\n" "$kernel"
    printf "Architecture: ${GREEN}%s${NC}\n" "$architecture"
    printf "CPU Temp:     🌡 %s\n" "$cpu_temp"
    printf "Cores:        ${RED}%s${NC}\n" "$cores"
    printf "Processes:    ${RED}%s${NC}\n" "$processes"
    printf "Disk Usage:   ${PURPLE}💾 %s${NC}\n" "$disk_info"
    printf "Memory:       ${PURPLE}🧠 %s${NC}\n" "$mem_info"
    printf "Swap:         ${PURPLE}💿 %s${NC}\n" "$swap_info"
    printf "Load Avg:     ${PURPLE}📊 %s${NC}\n" "$load_avg"
    printf "Packages:     ${YELLOW}📦 %s${NC}\n" "$packages"
    printf "Upgrades:     ${YELLOW}⬆️  %s${NC}\n" "$upgrades"
    printf "SSH Sessions: ${RED}🔗 %s${NC}\n" "$ssh_sessions"
    printf "\n${NC}"
}

# Main execution
print_banner
print_system_info