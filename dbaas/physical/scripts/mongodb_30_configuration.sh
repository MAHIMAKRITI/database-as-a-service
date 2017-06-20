#!/bin/bash

die_if_error()
{
    local err=$?
    if [ "$err" != "0" ]; then
        echo "$*"
        exit $err
    fi
}

createconfigdbfile()
{
    echo ""; echo $(date "+%Y-%m-%d %T") "- Creating the database config file"

(cat <<EOF_DBAAS
# mongodb.conf


########################################
## Basic database configuration
########################################

# Location of the database files
dbpath=/data/data/

# Storage Engine
storageEngine= wiredTiger

# Alternative directory structure, in which files for each database are kept in a unique directory
directoryperdb=true

# Fork the server process and run in background
fork = true

# small files
{% if DISK_SIZE_IN_GB < 5.0 %}
smallfiles = true
{% else %}
smallfiles = false
{% endif %}


########################################
## Log Options
########################################

# Send the log to syslog
syslog = true
quiet = false

########################################
## Administration & Monitoring
########################################

# Allow extended operations at the Http Interface
rest = true
httpinterface = true

{% if IS_HA  %}
########################################
## Replica Sets
########################################

# Use replica sets with the specified logical set name
replSet={{REPLICASETNAME}}

# File used to authenticate in replica set environment
keyFile=/data/mongodb.key

# Custom size for replication operation log in MB.
oplogSize = 512
{% else %}
########################################
## Security
########################################

# Turn on/off security.  Off is currently the default
auth = true
{% endif %}

{% if DATABASERULE == "ARBITER" %}
# disable journal
nojournal=yes
{% endif %}

EOF_DBAAS
) > /data/mongodb.conf
    die_if_error "Error setting mongodb.conf"

    chown mongodb:mongodb /data/mongodb.conf
    die_if_error "Error changing mongodb conf file owner"
}

createmongodbkeyfile()
{
    echo ""; echo $(date "+%Y-%m-%d %T") "- Creating the mongodb key file"

(cat <<EOF_DBAAS
{{MONGODBKEY}}
EOF_DBAAS
) >  /data/mongodb.key
    die_if_error "Error setting mongodb key file"
    
    chown mongodb:mongodb /data/mongodb.key
    die_if_error "Error changing mongodb key file owner"
    chmod 600 /data/mongodb.key
    die_if_error "Error changing mongodb key file permission"

}

configure_graylog()
{
    sed -i "\$a \$EscapeControlCharactersOnReceive off" /etc/rsyslog.conf
    sed -i "\$a \$template db-log, \"<%PRI%>%TIMESTAMP% %HOSTNAME% %syslogtag%%msg%	tags: INFRA,DBAAS,MONGODB,{{DATABASENAME}}\"" /etc/rsyslog.conf
    sed -i "\$a*.*                    @{{ GRAYLOG_ENDPOINT }}; db-log" /etc/rsyslog.conf
    /etc/init.d/rsyslog restart
}

createconfigdbfile
createmongodbkeyfile
configure_graylog

exit 0