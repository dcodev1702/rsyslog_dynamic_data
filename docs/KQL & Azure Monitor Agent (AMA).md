# KQL & Azure Monitor Agent (AMA) Guide

## Kusto Query Language (KQL) Getting Started

KQL (Kusto Query Language) is essential for analyzing syslog data in Azure Log Analytics. Here are key resources to get started:

### Official Microsoft Documentation
- **[KQL Overview](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)** - Official Microsoft KQL documentation
- **[KQL Quick Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kql-quick-reference)** - Essential operators and functions
- **[Log Analytics Tutorial](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-tutorial)** - Hands-on KQL in Azure Monitor

### Learning Resources
- **[Rod Trent's KQL Resources](https://github.com/rod-trent/KustoCourse)** - Comprehensive KQL learning materials by Rod Trent
- **[KQL Detective](https://detective.kusto.io/)** - Interactive KQL challenges and training scenarios
- **[LA-Demo Environment](https://aka.ms/LADemo)** - Microsoft's demo environment for practicing KQL queries

### Essential KQL Operators for Syslog Analysis
```kql
// Basic filtering and selection
Syslog
| where TimeGenerated > ago(1h)
| where Computer == "ServerName"
| project TimeGenerated, Computer, SyslogMessage

// Parse protocol and port (using our solution)
Syslog
| parse SyslogMessage with Protocol " " Port " " CleanMessage
| where Protocol in ("udp", "tcp")
| extend Port = toint(Port)

// Aggregation and counting
Syslog
| summarize Count = count() by Computer, Protocol, Port
| order by Count desc

// Time-based analysis
Syslog
| where TimeGenerated > ago(24h)
| summarize Count = count() by bin(TimeGenerated, 1h), Protocol
| render timechart
```

### KQL Best Practices
- **Filter early** - Use `where` clauses at the beginning of queries
- **Limit results** - Use `take` or `limit` for large datasets
- **Use specific time ranges** - Always specify time windows for better performance
- **Project only needed columns** - Use `project` to reduce data transfer

## Azure Monitor Agent and Data Collection Rules

### Azure Monitor Agent (AMA)

Azure Monitor Agent is the next-generation data collection agent that replaces the legacy Log Analytics Agent (MMA). AMA provides enhanced security, performance, and manageability for collecting monitoring data.

#### Key Features of AMA
- **Enhanced Security** - Managed identity and Azure AD authentication
- **Better Performance** - Optimized data collection and reduced resource usage
- **Centralized Configuration** - Uses Data Collection Rules (DCRs) for flexible configuration
- **Multi-homing Support** - Can send data to multiple Log Analytics workspaces
- **Cost Optimization** - Granular control over data collection to manage costs

#### AMA Architecture Benefits
- **Simplified Management** - Centralized configuration through DCRs
- **Improved Reliability** - Better handling of network interruptions and buffering
- **Enhanced Filtering** - Client-side filtering reduces bandwidth and costs
- **Future-Proof** - Microsoft's strategic direction for Azure monitoring

#### Official AMA Documentation
- **[Azure Monitor Agent Overview](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview)**
- **[AMA Migration Guide](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration)**
- **[AMA Installation](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-install)**

### Data Collection Rules (DCRs)

Data Collection Rules define what data to collect, how to transform it, and where to send it. DCRs provide a centralized and flexible way to configure data collection across your environment.

#### DCR Key Concepts
- **Data Sources** - Define what data to collect (e.g., Syslog, Windows Events, Performance Counters)
- **Transformations** - KQL-based data filtering and modification before ingestion
- **Destinations** - Where to send the collected data (Log Analytics workspaces)
- **Associations** - Link DCRs to specific machines or resource groups

#### Syslog DCR Example Configuration

The following DCR configuration demonstrates how to collect syslog data and transform it to extract protocol and port information.

**Important Note on Custom Fields:**

Custom fields (columns ending with `_CF`) **cannot be created directly from a Data Collection Rule**. Custom fields must be created through the Azure portal or API before they can be referenced in DCR transformations. 

For detailed instructions on creating custom fields, refer to the official Microsoft documentation: **[Create Custom Fields in Azure Monitor Logs](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/custom-fields)**

**DCR Transform Approach:**

Instead of relying on custom fields, the DCR transformation below uses standard columns and KQL parsing to extract protocol and port information during data ingestion:

```json
{
    "properties": {
        "dataSources": {
            "syslog": [
                {
                    "name": "syslogDataSource",
                    "streams": ["Microsoft-Syslog"],
                    "facilityNames": [
                        "auth",
                        "authpriv", 
                        "cron",
                        "daemon",
                        "kern",
                        "local0",
                        "local1",
                        "local2",
                        "local3",
                        "local4",
                        "local5",
                        "local6",
                        "local7",
                        "mail",
                        "news",
                        "syslog",
                        "user",
                        "uucp"
                    ],
                    "logLevels": [
                        "Debug",
                        "Info", 
                        "Notice",
                        "Warning",
                        "Error",
                        "Critical",
                        "Alert",
                        "Emergency"
                    ]
                }
            ]
        },
        "destinations": {
            "logAnalytics": [
                {
                    "workspaceResourceId": "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}",
                    "name": "centralWorkspace"
                }
            ]
        },
        "dataFlows": [
            {
                "streams": ["Microsoft-Syslog"],
                "destinations": ["centralWorkspace"],
                "transformKql": "source | extend TimeGenerated = now() | parse SyslogMessage with Protocol_CF \" \" Port_CF \" \" CleanSyslogMessage | project TimeGenerated, Computer, Facility, SeverityLevel, Protocol = Protocol_CF, Port = toint(Port_CF), SyslogMessage = CleanSyslogMessage",
                "outputStream": "Microsoft-Syslog"
            }
        ]
    }
}
```

**Transform KQL Explanation:**
- `source` - References the incoming syslog data stream
- `extend TimeGenerated = now()` - Sets current timestamp for ingestion time
- `parse SyslogMessage with Protocol_CF " " Port_CF " " CleanSyslogMessage` - Extracts protocol and port from message
- `Protocol_CF` and `Port_CF` - Temporary variables for parsing (not actual custom fields)
- `project` - Selects and renames columns for final output
- `toint(Port_CF)` - Converts port string to integer for proper data typing
- `SyslogMessage = CleanSyslogMessage` - Replaces original message with clean version (protocol/port removed)
- `outputStream` - Specifies the destination table for transformed data

For detailed information about KQL transformations in Data Collection Rules, refer to: **[Data Collection Transformations in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-transformations-kql)**

**Resulting Table Schema:**
After applying this DCR, the Microsoft-Syslog table will include:
- `TimeGenerated` - Ingestion timestamp
- `Computer` - Source computer name (preserved from original client)
- `Facility` - Syslog facility
- `SeverityLevel` - Log severity level
- `Protocol` - Extracted protocol (udp/tcp)
- `Port` - Extracted port number (514/10514/20514) as integer
- `SyslogMessage` - Clean message content without protocol/port prefix

#### DCR Benefits for Syslog Collection
- **Centralized Configuration** - Manage syslog collection settings from Azure portal
- **Granular Filtering** - Filter facilities and log levels to reduce noise
- **Data Transformation** - Use KQL to transform data before ingestion (perfect for our protocol/port extraction)
- **Cost Control** - Filter out unnecessary data to optimize ingestion costs
- **Scalability** - Apply same configuration across multiple syslog collectors

#### Official DCR Documentation
- **[Data Collection Rules Overview](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-overview)**
- **[Create DCR for Syslog](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-syslog)**
- **[DCR Transformations](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-transformations)**
- **[DCR Structure and Syntax](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-structure)**
