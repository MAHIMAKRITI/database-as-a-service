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
[mysqld_safe]
syslog

[heartbeat]
host=heartbeat
database=heartbeat
user=heartbeat
password=pulse

[client]
port                            = 3306
socket                          = /var/lib/mysql/mysql.sock

[mysql]
no_auto_rehash
#default_character_set           = latin1

[mysqld]
binlog_format=row
performance_schema=OFF
transaction_isolation = READ-COMMITTED

port                            = 3306
socket                          = /var/lib/mysql/mysql.sock
datadir                         = /data/data
tmpdir                          = /data/tmp/

skip_external_locking
skip_name_resolve

default_storage_engine          = innodb


character_set_server            = utf8

max_connections                 = 1000
max_connect_errors              = 999999

thread_cache_size               = 32
table_open_cache                = 4096

query_cache_type                = 1
query_cache_size                = {{ configuration.query_cache_size.value }}

thread_stack                    = 192K
thread_concurrency              = 16

max_allowed_packet              = {{ configuration.max_allowed_packet.value }}
sort_buffer_size                = {{ configuration.sort_buffer_size.value }}

tmp_table_size                  = {{ configuration.tmp_table_size.value }}
max_heap_table_size             = {{ configuration.max_heap_table_size.value }}

# Dual Master
read_only                       = 1
#skip_slave_start                = 1

# Binary Logging
sync_binlog                     = 1
expire_logs_days                = 3
max_binlog_size                 = {{ configuration.max_binlog_size.value }}
log_bin                         = /data/repl/mysql-bin
relay_log                       = /data/repl/mysql-relay
log_slave_updates


# Slow Query Logging
#log_slow_queries                = 1
long_query_time                 = 1
slow_query_log_file             = /data/logs/mysql-slow.log
slow_query_log


# MyISAM
key_buffer_size                 = {{ configuration.key_buffer_size.value }}
myisam_sort_buffer_size         = {{ configuration.myisam_sort_buffer_size.value }}
read_buffer_size                = {{ configuration.read_buffer_size.value }}
read_rnd_buffer_size            = {{ configuration.read_rnd_buffer_size.value }}
# InnoDB
innodb_data_home_dir            = /data/data
innodb_data_file_path           = ibdata1:10M:autoextend
innodb_autoextend_increment     = 8
innodb_file_per_table

innodb_buffer_pool_size         = {{ configuration.innodb_buffer_pool_size.value }}
#innodb_additional_mem_pool_size = 20M

innodb_log_group_home_dir       = /data/data
innodb_log_files_in_group       = 3
innodb_log_file_size            = {{ configuration.innodb_log_file_size.value }}
innodb_log_buffer_size          = {{ configuration.innodb_log_buffer_size.value }}

innodb_lock_wait_timeout        = 50

innodb_flush_log_at_trx_commit  = 1
innodb_flush_method             = O_DIRECT
innodb_file_io_threads          = 4
innodb_thread_concurrency       = 16
innodb_max_dirty_pages_pct      = 90
innodb_max_purge_lag            = 0

explicit_defaults_for_timestamp = TRUE

# Lastly, include /etc/server_id.cnf which should contain:
#
# [mysqld]
# server_id=XXX
#

!include /etc/server_id.cnf

EOF_DBAAS
) > /etc/my.cnf
    die_if_error "Error setting my.cnf"

}

createserveriddbfile()
{
    echo ""; echo $(date "+%Y-%m-%d %T") "- Creating the server id db file"

(cat <<EOF_DBAAS
[mysqld]
server_id={{SERVERID}}
EOF_DBAAS
) >  /etc/server_id.cnf
    die_if_error "Error setting server_id file"

}

configure_graylog()
{
    echo "\$EscapeControlCharactersOnReceive off" >> /etc/rsyslog.d/dbaaslog.conf
    sed -i "\$a \$template db-log, \"<%PRI%>%TIMESTAMP% %HOSTNAME% %syslogtag%%msg%	tags: INFRA,DBAAS,MYSQL,{{DATABASENAME}}\"" /etc/rsyslog.d/dbaaslog.conf
    sed -i "\$a*.*                    @{{ GRAYLOG_ENDPOINT }}; db-log" /etc/rsyslog.d/dbaaslog.conf
    /etc/init.d/rsyslog restart
}

createconfigdbfile
createserveriddbfile
configure_graylog

exit 0