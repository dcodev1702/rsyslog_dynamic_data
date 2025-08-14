#!/bin/bash

# Universal AMA Cache Check Script for Ubuntu and RHEL
# This script checks both log files and XML configuration files

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Path to AMA log file
LOG_FILE="/var/opt/microsoft/azuremonitoragent/log/mdsd.info"

# Path to XML configuration files (RHEL)
XML_CONFIG_PATH="/etc/opt/microsoft/azuremonitoragent/config-cache"
XML_FILES=(
    "$XML_CONFIG_PATH/mcsconfig.lkg.xml"
    "$XML_CONFIG_PATH/mcsconfig.latest.xml"
)

# Function to log output with color
log_message() {
    local COLOR="$1"
    local MESSAGE="$2"
    echo -e "${COLOR}${MESSAGE}${NC}"
}

# Function to print a separator line
print_separator() {
    echo "════════════════════════════════════════════════════════════════════"
}

# Function to check disk quota in log file (Ubuntu method)
check_log_file() {
    log_message "$BLUE" "\n📋 Checking AMA Log File (Ubuntu method)..."
    
    if [[ ! -f "$LOG_FILE" ]]; then
        log_message "$YELLOW" "   ⚠ AMA log file not found: $LOG_FILE"
        return 1
    fi
    
    # Find the most recent disk quota line
    CACHE_LINE=$(grep -m 1 "disk quota" "$LOG_FILE" 2>/dev/null)
    if [[ -z "$CACHE_LINE" ]]; then
        log_message "$YELLOW" "   ⚠ No disk quota configuration found in logs"
        return 1
    fi
    
    # Extract numeric cache size (MB)
    CACHE_MB=$(echo "$CACHE_LINE" | grep -oE '[0-9]+[ ]*MB' | grep -oE '[0-9]+')
    if [[ -z "$CACHE_MB" ]]; then
        log_message "$YELLOW" "   ⚠ Could not extract cache size from log line"
        return 1
    fi
    
    log_message "$GREEN" "   ✓ Found in logs: ${CACHE_MB} MB"
    log_message "$NC" "   Log entry: ${CACHE_LINE}"
    return 0
}

# Function to check disk quota in XML config files (RHEL method)
check_xml_config() {
    log_message "$BLUE" "\n📋 Checking XML Configuration Files (RHEL method)..."
    
    local found=0
    
    for xml_file in "${XML_FILES[@]}"; do
        if [[ -f "$xml_file" ]]; then
            log_message "$NC" "   Checking: $(basename $xml_file)"
            
            # Extract diskQuotaInMB from AgentResourceUsage
            DISK_QUOTA=$(grep -oP 'AgentResourceUsage.*diskQuotaInMB\s*=\s*"\K[0-9]+' "$xml_file" 2>/dev/null)
            
            if [[ -n "$DISK_QUOTA" ]]; then
                log_message "$GREEN" "   ✓ Found AgentResourceUsage diskQuotaInMB: ${DISK_QUOTA} MB"
                
                # Convert to GB for display if >= 1000 MB
                if [[ $DISK_QUOTA -ge 1000 ]]; then
                    DISK_QUOTA_GB=$(echo "scale=1; $DISK_QUOTA/1000" | bc 2>/dev/null || echo "$((DISK_QUOTA/1000))")
                    log_message "$GREEN" "   ✓ Cache Size: ${DISK_QUOTA_GB} GB (${DISK_QUOTA} MB)"
                else
                    log_message "$GREEN" "   ✓ Cache Size: ${DISK_QUOTA} MB"
                fi
                
                # Also check for HeartBeat diskQuotaInMB (usually much smaller)
                HB_QUOTA=$(grep -oP 'HeartBeat.*diskQuotaInMB\s*=\s*"\K[0-9]+' "$xml_file" 2>/dev/null)
                if [[ -n "$HB_QUOTA" ]]; then
                    log_message "$NC" "   ℹ HeartBeat diskQuotaInMB: ${HB_QUOTA} MB (separate allocation)"
                fi
                
                found=1
            else
                log_message "$YELLOW" "   ⚠ No diskQuotaInMB found in $(basename $xml_file)"
            fi
        fi
    done
    
    return $((1-found))
}

# Function to get actual cache usage
get_cache_usage() {
    log_message "$BLUE" "\n💾 Cache Usage Analysis:"
    
    local total_cache_mb=0
    local found_cache=0
    
    # Common AMA cache/data directories
    CACHE_DIRS=(
        "/var/opt/microsoft/azuremonitoragent/state"
        "/var/opt/microsoft/azuremonitoragent/events"
        "/var/opt/microsoft/azuremonitoragent/log"
        "/var/cache/azuremonitoragent"
        "/var/lib/azuremonitoragent"
        "/run/mdsd"
        "/var/run/mdsd"
    )
    
    # Check each potential cache directory
    for dir in "${CACHE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            # Get size in KB, then convert to MB
            size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
            if [[ -n "$size_kb" ]] && [[ "$size_kb" -gt 0 ]]; then
                size_mb=$((size_kb / 1024))
                total_cache_mb=$((total_cache_mb + size_mb))
                
                # Only show directories with significant size (>1MB)
                if [[ $size_mb -gt 1 ]]; then
                    if [[ $size_mb -gt 1024 ]]; then
                        size_gb=$(echo "scale=2; $size_mb/1024" | bc 2>/dev/null || echo "$((size_mb/1024))")
                        log_message "$NC" "   📁 $dir: ${size_gb} GB"
                    else
                        log_message "$NC" "   📁 $dir: ${size_mb} MB"
                    fi
                    found_cache=1
                fi
            fi
        fi
    done
    
    # Check for mdsd-specific cache files
    MDSD_CACHE=$(find /var/opt/microsoft/azuremonitoragent -name "*.db" -o -name "*.sqlite" -o -name "*.cache" 2>/dev/null)
    if [[ -n "$MDSD_CACHE" ]]; then
        for cache_file in $MDSD_CACHE; do
            if [[ -f "$cache_file" ]]; then
                size_kb=$(du -sk "$cache_file" 2>/dev/null | cut -f1)
                if [[ -n "$size_kb" ]] && [[ "$size_kb" -gt 1024 ]]; then  # Only show files > 1MB
                    size_mb=$((size_kb / 1024))
                    log_message "$NC" "   📄 $(basename $cache_file): ${size_mb} MB"
                    found_cache=1
                fi
            fi
        done
    fi
    
    if [[ $found_cache -eq 0 ]]; then
        log_message "$YELLOW" "   ⚠ No significant cache data found (cache may be empty or in non-standard location)"
    fi
    
    # Store the total in a global variable instead of echoing it
    TOTAL_CACHE_MB=$total_cache_mb
}

# Function to display system information
show_system_info() {
    log_message "$BLUE" "\n🖥️  System Information:"
    
    # OS Information
    if [[ -f /etc/os-release ]]; then
        OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
        OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2)
        log_message "$NC" "   OS: $OS_NAME $OS_VERSION"
    fi
    
    # AMA Service Status
    if command -v systemctl &> /dev/null; then
        if systemctl is-active azuremonitoragent &> /dev/null; then
            log_message "$GREEN" "   AMA Service: Active ✓"
        else
            log_message "$RED" "   AMA Service: Not Active ✗"
        fi
    fi
    
    # Check mdsd process
    if pgrep mdsd > /dev/null; then
        log_message "$GREEN" "   mdsd Process: Running (PID: $(pgrep mdsd)) ✓"
    else
        log_message "$YELLOW" "   mdsd Process: Not Running ⚠"
    fi
}

# Main execution
clear
print_separator
log_message "$GREEN" "        🔍 Azure Monitor Agent (AMA) Cache Configuration Check"
print_separator

# Show system information
show_system_info

# Initialize results
LOG_RESULT=1
XML_RESULT=1

# Check both methods
check_log_file
LOG_RESULT=$?

check_xml_config
XML_RESULT=$?

# Get actual cache usage (now sets global variable TOTAL_CACHE_MB)
get_cache_usage

# Summary
print_separator
log_message "$BLUE" "\n📊 SUMMARY:"

if [[ $LOG_RESULT -eq 0 ]] || [[ $XML_RESULT -eq 0 ]]; then
    if [[ $XML_RESULT -eq 0 ]]; then
        log_message "$GREEN" "   ✅ AMA Disk Cache Configuration: ${DISK_QUOTA} MB"
        if [[ $DISK_QUOTA -ge 1000 ]]; then
            DISK_QUOTA_GB=$(echo "scale=1; $DISK_QUOTA/1000" | bc 2>/dev/null || echo "$((DISK_QUOTA/1000))")
            log_message "$GREEN" "   ✅ Configured Limit: ${DISK_QUOTA_GB} GB (${DISK_QUOTA} MB)"
        fi
    elif [[ $LOG_RESULT -eq 0 ]]; then
        log_message "$GREEN" "   ✅ AMA Disk Cache Configuration: ${CACHE_MB} MB"
        DISK_QUOTA=$CACHE_MB
    fi
    
    # Display cache usage statistics
    if [[ -n "$DISK_QUOTA" ]] && [[ "$DISK_QUOTA" -gt 0 ]] && [[ "$TOTAL_CACHE_MB" -gt 0 ]]; then
        TOTAL_CACHE_GB=$(echo "scale=2; $TOTAL_CACHE_MB/1024" | bc 2>/dev/null || echo "0")
        USAGE_PERCENT=$(echo "scale=1; ($TOTAL_CACHE_MB * 100) / $DISK_QUOTA" | bc 2>/dev/null || echo "0")
        
        log_message "$BLUE" "\n   📈 Cache Utilization:"
        log_message "$NC" "   • Current Usage: ${TOTAL_CACHE_GB} GB (${TOTAL_CACHE_MB} MB)"
        log_message "$NC" "   • Configured Limit: $(echo "scale=1; $DISK_QUOTA/1024" | bc 2>/dev/null || echo "$((DISK_QUOTA/1024))") GB"
        
        # Color-code the usage percentage
        if (( $(echo "$USAGE_PERCENT > 80" | bc -l 2>/dev/null || echo "0") )); then
            log_message "$RED" "   • Usage: ${USAGE_PERCENT}% ⚠️ HIGH"
        elif (( $(echo "$USAGE_PERCENT > 60" | bc -l 2>/dev/null || echo "0") )); then
            log_message "$YELLOW" "   • Usage: ${USAGE_PERCENT}% ⚡"
        else
            log_message "$GREEN" "   • Usage: ${USAGE_PERCENT}% ✓"
        fi
        
        # Visual progress bar
        FILLED=$(printf "%.0f" $(echo "$USAGE_PERCENT/5" | bc -l 2>/dev/null || echo "0"))
        EMPTY=$((20 - FILLED))
        BAR="["
        for ((i=0; i<$FILLED; i++)); do BAR="${BAR}█"; done
        for ((i=0; i<$EMPTY; i++)); do BAR="${BAR}░"; done
        BAR="${BAR}]"
        log_message "$NC" "   • Progress: $BAR"
        
        # Available space
        AVAILABLE_MB=$((DISK_QUOTA - TOTAL_CACHE_MB))
        if [[ $AVAILABLE_MB -gt 0 ]]; then
            AVAILABLE_GB=$(echo "scale=2; $AVAILABLE_MB/1024" | bc 2>/dev/null || echo "0")
            log_message "$GREEN" "   • Available: ${AVAILABLE_GB} GB (${AVAILABLE_MB} MB)"
        else
            log_message "$RED" "   • Available: 0 MB ⚠️ CACHE FULL"
        fi
    elif [[ "$TOTAL_CACHE_MB" -eq 0 ]] || [[ -z "$TOTAL_CACHE_MB" ]]; then
        log_message "$YELLOW" "\n   📈 Cache Utilization: No significant data cached yet"
    fi
    
    log_message "$NC" "\n   Detection Method:"
    [[ $LOG_RESULT -eq 0 ]] && log_message "$GREEN" "   • Log file (Ubuntu-style) ✓"
    [[ $XML_RESULT -eq 0 ]] && log_message "$GREEN" "   • XML configuration (RHEL-style) ✓"
else
    log_message "$YELLOW" "   ⚠ Could not determine cache configuration"
    log_message "$NC" "   The agent may be using the default value of 10GB (10,000 MB)"
    
    # Still show actual usage if found
    if [[ "$TOTAL_CACHE_MB" -gt 0 ]]; then
        TOTAL_CACHE_GB=$(echo "scale=2; $TOTAL_CACHE_MB/1024" | bc 2>/dev/null || echo "0")
        log_message "$BLUE" "\n   📈 Current Cache Usage: ${TOTAL_CACHE_GB} GB (${TOTAL_CACHE_MB} MB)"
    fi
    
    log_message "$NC" "\n   Troubleshooting tips:"
    log_message "$NC" "   • Ensure AMA service is running: systemctl status azuremonitoragent"
    log_message "$NC" "   • Check for config files: ls -la $XML_CONFIG_PATH/"
    log_message "$NC" "   • Review logs: tail -f $LOG_FILE"
fi

print_separator
log_message "$NC" "Timestamp: $(date)"
print_separator
