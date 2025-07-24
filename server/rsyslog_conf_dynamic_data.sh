# /etc/rsyslog.conf configuration file for rsyslog
# BE SURE YOU RENAME THIS FILE FROM: rsyslog_conf_dynamic_data.sh TO rsyslog.conf located in /etc

# For more information install rsyslog-doc and see
# /usr/share/doc/rsyslog-doc/html/configuration/index.html
#
# Default logging rules can be found in /etc/rsyslog.d/50-default.conf

    
#################
#### MODULES ####
#################

module(load="imuxsock") # provides support for local system logging
#module(load="immark")  # provides --MARK-- message capability
    
# provides UDP syslog reception
#module(load="imudp")
#input(type="imudp" port="514")

# provides TCP syslog reception
#module(load="imtcp")
#input(type="imtcp" port="514")


# /etc/rsyslog.d/00-inputs.conf
# Load required modules
    

# -------------------- CUSTOM ENTRY BEGINS :: 18 JUL 2025 --------------------------   
# Port-specific syslog configuration for /etc/rsyslog.conf
# Add this section to your existing /etc/rsyslog.conf file

# Load required modules
module(load="imudp")
module(load="imtcp")

# Allow UDP and TCP messages from localhost and 10.0.0.0/24 to prevent "disallowed sender" errors
$AllowedSender UDP, 127.0.0.1, 10.0.0.0/24
$AllowedSender TCP, 127.0.0.1, 10.0.0.0/24

# Internal (localhost) listener to receive the tagged messages and process them through AMA
input(type="imudp" port="1515" address="127.0.0.1" ruleset="RSYSLOG_DefaultRuleset")

# UDP inputs with specific rulesets for preprocessing
input(type="imudp" port="514" ruleset="preprocess_udp_514")
input(type="imudp" port="10514" ruleset="preprocess_udp_10514")
input(type="imudp" port="20514" ruleset="preprocess_udp_20514")

# TCP inputs with specific rulesets for preprocessing
input(type="imtcp" port="514" ruleset="preprocess_tcp_514")
input(type="imtcp" port="10514" ruleset="preprocess_tcp_10514")
input(type="imtcp" port="20514" ruleset="preprocess_tcp_20514")

# Preprocessing rulesets - set custom properties for protocol, port, and preserve original hostname
ruleset(name="preprocess_udp_514") {
    set $.protocol = "udp";
    set $.port = "514";
    set $.original_hostname = $hostname;
    set $.org = "ORG1-U-514";
    call intermediate_ama_forward
}

ruleset(name="preprocess_tcp_514") {
    set $.protocol = "tcp";
    set $.port = "514";
    set $.original_hostname = $hostname;
    set $.org = "ORG2-T-514"
    call intermediate_ama_forward
}

ruleset(name="preprocess_udp_10514") {
    set $.protocol = "udp";
    set $.port = "10514";
    set $.original_hostname = $hostname;
    set $.org = "ORG3-U-10514"
    call intermediate_ama_forward
}

ruleset(name="preprocess_tcp_10514") {
    set $.protocol = "tcp";
    set $.port = "10514";
    set $.original_hostname = $hostname;
    set $.org = "ORG4-T-10514"
    call intermediate_ama_forward
}

ruleset(name="preprocess_udp_20514") {
    set $.protocol = "udp";
    set $.port = "20514";
    set $.original_hostname = $hostname;
    set $.org = "ORG5-U-20514"
    call intermediate_ama_forward
}

ruleset(name="preprocess_tcp_20514") {
    set $.protocol = "tcp";
    set $.port = "20514";
    set $.original_hostname = $hostname;
    set $.org = "ORG6-T-20514"
    call intermediate_ama_forward
}

# Intermediate template that creates a complete syslog message with protocol/port tags and preserves original hostname
template(name="Intermediate_AMA_Format" type="string" string="<%PRI%>%TIMESTAMP% %$.original_hostname% %fromhost-ip% %$.protocol% %$.port% %$.org% %syslogtag%")

# Intermediate AMA forwarding ruleset - forwards to internal port for AMA processing
ruleset(name="intermediate_ama_forward") {
    action(type="omfwd"
    template="Intermediate_AMA_Format"
    target="127.0.0.1" Port="1515" Protocol="udp"
    queue.type="Direct")
}

# -------------------- CUSTOM ENTRY ENDS :: 18 JUL 2025 --------------------------

# Filter duplicated messages
$RepeatedMsgReduction on

# Set the default permissions for all log files.
$FileOwner syslog


# Rest of config...
###########################
#### GLOBAL DIRECTIVES ####
###########################

# Set the default permissions for all log files.
$FileOwner syslog
$FileGroup adm
$FileCreateMode 0640
$DirCreateMode 0755
$Umask 0022
$PrivDropToUser syslog
$PrivDropToGroup syslog

# Where to place spool and state files
$WorkDirectory /var/spool/rsyslog

# Include all config files in /etc/rsyslog.d/
$IncludeConfig /etc/rsyslog.d/*.conf
