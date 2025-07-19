# RSyslog Protocol::Port ID Solution with Azure Monitor Agent (AMA)

## Overview
This solution enables a centralized syslog collector to identify which organization (client) sent each message by automatically adding protocol and port information to syslog entries. Messages include separate protocol and port fields (e.g., `udp 514`, `tcp 10514`) and are forwarded to Azure Monitor Agent for ingestion into Azure Log Analytics with full client identification.

## Problem Statement
When multiple organizations send syslog data to a central collector on different ports, there was no way to identify which organization sent each message once it reached Azure Log Analytics. The solution needed to work within strict operational constraints while preserving original client metadata.

## Executive Summary
This RSyslog solution addresses enterprise syslog aggregation challenges by implementing protocol and port identification without compromising existing Azure Monitor Agent integrations. The solution operates entirely in memory, preserves client hostnames, and maintains full compatibility with existing AMA configurations through an innovative intermediate templating approach that works around RSyslog v8.23 read-only variable limitations.

**Key Business Value:**
- **Multi-tenant log separation** - Clear identification of message sources in consolidated logs
- **Zero infrastructure changes** - No modifications to existing AMA or client configurations
- **Performance optimized** - Memory-only operations with minimal processing overhead
- **Compliance ready** - Maintains audit trails with complete source attribution

## Constraints & Requirements
- **No disk writes allowed** - Solution must operate entirely in memory
- **Azure Monitor Agent (AMA) template must remain completely untouched** - Cannot modify the existing AMA configuration at `/etc/rsyslog.d/10-azuremonitoragent.conf`
- **Preserve original client hostnames** - Client machine names must be maintained, not replaced with localhost
- **No external programs** - Must use only built-in rsyslog modules (no `omprog`, no temporary files)
- **Support multiple protocols/ports** - Handle both TCP and UDP on ports 514, 10514, and 20514
- **Read-only variables** - RSyslog v8.23 treats `$msg` and `$syslogtag` as read-only
- **Maintain existing functionality** - All existing syslog processing must continue to work

## Solution Architecture

### Flow Diagram
```
External Clients → Port-Specific Inputs → Preprocessing Rulesets → Intermediate Template → Internal Port → AMA Template → Azure Monitor Agent → Log Analytics
```

### Technical Implementation
1. **Port-Specific Inputs**: Each protocol/port combination gets its own input with a dedicated ruleset
2. **Custom Properties**: Use `$.protocol`, `$.port`, and `$.original_hostname` to store connection metadata
3. **Intermediate Template**: Reconstructs syslog format with separate protocol and port fields while preserving hostname
4. **Internal Re-injection**: Forward to internal port 1515 for normal AMA processing
5. **AMA Processing**: Unchanged AMA template processes messages with embedded protocol/port information

## Key Features
- ✅ **Zero disk I/O** - All processing in memory
- ✅ **Hostname preservation** - Original client machine names maintained  
- ✅ **Granular metadata** - Separate protocol and port fields for flexible log analysis
- ✅ **Clean message format** - Protocol and port as separate fields: `hostname syslogtag protocol port message`
- ✅ **AMA compatibility** - Works with existing Azure Monitor Agent configuration
- ✅ **Scalable design** - Easy to add additional ports/protocols
- ✅ **Performance optimized** - Minimal overhead using direct queue operations

## Custom Variables
The solution uses three custom RSyslog properties:
- `$.protocol` - Contains "udp" or "tcp"
- `$.port` - Contains the port number ("514", "10514", "20514")
- `$.original_hostname` - Preserves the original client hostname

These variables are inserted as separate fields in the syslog message format: `hostname syslogtag protocol port message`

## Configuration
The solution adds port-specific inputs and preprocessing logic to `/etc/rsyslog.conf` while keeping the AMA configuration at `/etc/rsyslog.d/10-azuremonitoragent.conf` completely unchanged.

### Supported Ports
- **514** (UDP/TCP) - Organization 1
- **10514** (UDP/TCP) - Organization 2  
- **20514** (UDP/TCP) - Organization 3

## Results
Messages appear in Azure Log Analytics with clear organization identification:
```
[udp:514] Original message from Organization 1
[tcp:10514] Original message from Organization 2
[udp:20514] Original message from Organization 3
```

## Technical Innovation
The solution leverages RSyslog's custom property system (`$.protocol`, `$.port`, `$.original_hostname`) to work around read-only variable limitations in RSyslog v8.23. Through an innovative intermediate templating approach, the solution reconstructs syslog messages with embedded protocol and port information while preserving all original client metadata. This granular field-based approach enables flexible log analysis and easy expansion to additional protocols or ports without requiring any changes to existing Azure Monitor Agent configurations.

**Innovation Highlights:**
- **Memory-only processing** - Eliminates disk I/O bottlenecks and temporary file management
- **Variable workaround** - Bypasses RSyslog read-only limitations using custom properties
- **Non-invasive integration** - Maintains existing AMA template and configuration integrity
- **Scalable architecture** - Modular design supports easy addition of new ports and protocols

This approach successfully overcomes the technical constraints of RSyslog v8.23 while maintaining full compatibility with Azure Monitor Agent's existing configuration requirements, providing a robust enterprise-grade solution for multi-tenant syslog aggregation.

## Additional Documentation

## Additional Documentation

For platform-specific configuration and Azure integration guidance, see the companion guides:

- **[RedHat Enterprise Linux (RHEL) 9.x Configuration.md](docs/RedHat%20Enterprise%20Linux%20(RHEL)%209.x%20Configuration.md)** - SELinux, Firewall, and RSyslog commands for RHEL 9.x
- **[KQL & Azure Monitor Agent (AMA).md](docs/KQL%20&%20Azure%20Monitor%20Agent%20(AMA).md)** - KQL queries, AMA overview, and Data Collection Rules

