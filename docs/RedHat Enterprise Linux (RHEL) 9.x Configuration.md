# RedHat Enterprise Linux (RHEL) 9.x Configuration

When implementing the RSyslog Protocol/Port Identification Solution on RHEL 9.x with SELinux and Firewall enabled, additional configuration steps are required to ensure proper operation.

## SELinux Configuration

### Listing Ports with Syslogd Label
```bash
# List all TCP ports with syslogd_port_t label
sudo semanage port -l | grep syslogd_port_t | grep tcp

# List all UDP ports with syslogd_port_t label  
sudo semanage port -l | grep syslogd_port_t | grep udp

# Check specific port labels
sudo semanage port -l | grep "514\|10514\|20514"
```

### Adding Ports with Syslogd Label
```bash
# Add UDP ports for syslog
sudo semanage port -a -t syslogd_port_t -p udp 514
sudo semanage port -a -t syslogd_port_t -p udp 10514
sudo semanage port -a -t syslogd_port_t -p udp 20514
sudo semanage port -a -t syslogd_port_t -p udp 1515  # Internal port

# Add TCP ports for syslog
sudo semanage port -a -t syslogd_port_t -p tcp 514
sudo semanage port -a -t syslogd_port_t -p tcp 10514
sudo semanage port -a -t syslogd_port_t -p tcp 20514
sudo semanage port -a -t syslogd_port_t -p tcp 1515  # Internal port

# CRITICAL: Add AMA Syslog hairpin port (REQUIRED for AMA functionality)
sudo semanage port -a -t syslogd_port_t -p tcp 28330

# If ports already exist, use -m (modify) instead of -a (add)
sudo semanage port -m -t syslogd_port_t -p udp 514
sudo semanage port -m -t syslogd_port_t -p tcp 28330
```

**⚠️ IMPORTANT:** Port TCP 28330 with the `syslogd_port_t` label is **REQUIRED** for Azure Monitor Agent to function properly. Without this SELinux label, AMA will NOT be able to successfully send syslog traffic to the Log Analytics REST API endpoints, causing data ingestion failures.

### Azure Monitor Agent REST API Endpoints

For AMA to successfully send telemetry to a Log Analytics Workspace, the following REST API endpoints must be accessible. Consult the **[official Microsoft documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-network-configuration)** for the most current endpoint requirements:

**Primary Data Ingestion Endpoints:**
```
# Global Azure (Commercial)
*.ods.opinsights.azure.com:443         # Data ingestion endpoint
*.oms.opinsights.azure.com:443         # Agent configuration and management

# Azure Government
*.ods.opinsights.azure.us:443          # Data ingestion endpoint  
*.oms.opinsights.azure.us:443          # Agent configuration and management
```

**Additional Required Endpoints:**
```
# Azure Resource Manager
management.azure.com:443               # ARM endpoint for resource management

# Azure Active Directory  
login.microsoftonline.com:443          # Authentication (Azure Commercial)
login.microsoftonline.us:443           # Authentication (Azure Government)

# Data Collection Endpoint (DCE) - if using custom DCE
<your-dce-name>.<region>.ingest.monitor.azure.com:443

# Workspace-specific endpoints (replace {workspace-id} with your LAW ID)
{workspace-id}.ods.opinsights.azure.com:443
{workspace-id}.oms.opinsights.azure.com:443
```

**Network Configuration Requirements:**
- All endpoints require **HTTPS (port 443)** outbound access
- No inbound ports required for AMA (outbound only)
- Proxy support available if direct internet access is not permitted
- Certificate validation must be enabled (do not disable SSL/TLS verification)

**Verification Commands:**
```bash
# Test connectivity to Log Analytics endpoints
curl -I https://{workspace-id}.ods.opinsights.azure.com
nslookup {workspace-id}.ods.opinsights.azure.com

# Check AMA agent connectivity
sudo /opt/microsoft/azuremonitoragent/bin/mdsd -c /etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/ -l
```

Refer to **[Azure Monitor Agent Network Configuration](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-network-configuration)** for complete network requirements and troubleshooting guidance.

### SELinux Troubleshooting Commands
```bash
# Check SELinux status
sudo getenforce
sudo sestatus

# Monitor SELinux denials in real-time
sudo tail -f /var/log/audit/audit.log | grep denied

# Search for syslog-related denials
sudo ausearch -m avc -ts recent | grep syslog

# Generate SELinux policy from denials (if needed)
sudo grep syslog /var/log/audit/audit.log | audit2allow -M mysyslog
sudo semodule -i mysyslog.pp

# Check SELinux context of rsyslog process
sudo ps -eZ | grep rsyslog

# Verify file contexts for rsyslog
sudo ls -Z /etc/rsyslog.conf
sudo ls -Z /var/log/
```

## Firewall Configuration

### Check Firewall Status
```bash
# Check if firewalld is running
sudo systemctl status firewalld

# Check firewall state
sudo firewall-cmd --state

# List active zones
sudo firewall-cmd --get-active-zones
```

### List Current Firewall Settings
```bash
# List all current firewall rules
sudo firewall-cmd --list-all

# List services allowed through firewall
sudo firewall-cmd --list-services

# List ports allowed through firewall
sudo firewall-cmd --list-ports

# Check specific zone settings
sudo firewall-cmd --zone=public --list-all
```

### Add Ports/Protocols to Firewall
```bash
# Add syslog ports permanently (consolidated command)
sudo firewall-cmd --permanent \
  --add-port=514/udp --add-port=514/tcp \
  --add-port=10514/udp --add-port=10514/tcp \
  --add-port=20514/udp --add-port=20514/tcp

# Add internal port (optional, for troubleshooting)
sudo firewall-cmd --permanent --add-port=1515/udp

# Reload firewall to apply changes
sudo firewall-cmd --reload

# Verify changes
sudo firewall-cmd --list-ports

# Alternative: Add syslog service (includes standard port 514)
sudo firewall-cmd --permanent --add-service=syslog
sudo firewall-cmd --reload
```

## General RSyslog Commands

### Service Management
```bash
# Restart rsyslog service
sudo systemctl restart rsyslog

# Start rsyslog service
sudo systemctl start rsyslog

# Stop rsyslog service
sudo systemctl stop rsyslog

# Enable rsyslog to start at boot
sudo systemctl enable rsyslog
```

### Service Status and Monitoring
```bash
# Check rsyslog service status
sudo systemctl status rsyslog

# View rsyslog logs
sudo journalctl -u rsyslog -f

# View recent rsyslog logs
sudo journalctl -u rsyslog --since "1 hour ago"

# Check for errors in rsyslog
sudo journalctl -u rsyslog -p err
```

### Configuration Validation
```bash
# Test rsyslog configuration syntax
sudo rsyslogd -N1

# Test configuration with verbose output
sudo rsyslogd -N1 -d

# Check which ports rsyslog is listening on
sudo netstat -tulpn | grep rsyslog
sudo ss -tulpn | grep rsyslog

# View rsyslog configuration files
sudo cat /etc/rsyslog.conf
sudo ls -la /etc/rsyslog.d/
```
