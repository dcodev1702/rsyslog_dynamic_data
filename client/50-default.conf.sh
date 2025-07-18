#
# Logging for the mail system.  Split it up so that
# it is easy to write scripts to parse these files.
#
#mail.info-/var/log/mail.info
#mail.warn-/var/log/mail.warn
mail.err/var/log/mail.err

#
# Some "catch-all" log files.
#
#*.=debug;\
#auth,authpriv.none;\
#news.none;mail.none-/var/log/debug
#*.=info;*.=notice;*.=warn;\
#auth,authpriv.none;\
#cron,daemon.none;\
#mail,news.none-/var/log/messages

#
# Emergencies are sent to everybody logged in.
#
*.emerg:omusrmsg:*

#
# I like to have messages displayed on the console, but only on a virtual
# console I usually leave idle.
#
#daemon,mail.*;\
#news.=crit;news.=err;news.=notice;\
#*.=debug;*.=info;\
#*.=notice;*.=warn/dev/tty8

##----------- Forward Syslog telemetry to Syslog Collector (Linux) | Date: 18 JUL 2025 -------------------

# "<%PRI%>1 %TIMESTAMP:::date-rfc3339% %HOSTNAME% %FROMHOST-IP% %APP-NAME% %PROCID% %MSGID% %STRUCTURED-DATA% %msg%\n"
#$template AuthLogFormat,"<%pri%> %timestamp% %HOSTNAME% %syslogtag:1:32%%msg:::sp-if-no-1st-sp% %fromhost-ip% %msg%"
#auth,authpriv.* @@10.0.0.8:10514;AuthLogFormat
# Force the client to use its FQDN or IP
$PreserveFQDN on

# Or force a specific hostname/IP
$LocalHostName zolab-sl-client-01

#template(name="add_port_514" type="string" string="[udp:514] %msg%")
$template RSYSLOG_ForwardFormat,"<%pri%> %timestamp% %HOSTNAME% %syslogtag:1:32%%msg:::sp-if-no-1st-sp% %fromhost-ip% %msg%"
# Or use the action template to force the source
auth,authpriv.* action(type="omfwd" 
           target="10.0.0.8" 
           port="10514" 
           protocol="udp"
           template="RSYSLOG_ForwardFormat")

# Set disk queue when rsyslog server will be down
$ActionQueueFileName queue
$ActionQueueMaxDiskSpace 2g
$ActionQueueSaveOnShutdown on
$ActionQueueType LinkedList
$ActionResumeRetryCount -1

##----------- Forward Syslog telemetry to Syslog Collector (Linux) | Date: 18 JUL 2025 -------------------
