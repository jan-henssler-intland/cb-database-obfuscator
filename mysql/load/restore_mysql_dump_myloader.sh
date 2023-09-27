#!/bin/bash
#https://lefred.be/content/mysql-cpu-information-from-sql/
echo "ALTER INSTANCE ENABLE|DISABLE INNODB REDO_LOG;"
#3.Check current redo log state [ON|OFF] from performance_schema global status.

echo "SELECT * FROM performance_schema.global_status WHERE variable_name = 'innodb_redo_log_enabled';"
echo "SET GLOBAL innodb_flush_log_at_trx_commit=2;"
echo "SHOW GLOBAL VARIABLES LIKE 'innodb_flush_log%';"
echo "wait 5 sec..."
sleep 5
set -o errexit
set -o pipefail

#RESTORE_DATE is part of the cb deployment
TH4INX=${TH4INX:-14}
TH4TAB=${TH4TAB:-14}
TH4ALL=${TH4ALL:-28}
LOGFILE=${LOGFILE:-/tmp/import.log}

if [ $# -eq 1 ];then
    #we assume that this is the dump folder
    logger -t $0 "import dump from ${1}"
else
    echo "the first argument is the path+filename to the dump folder"
    logger -t $0 "the first argument is the path+filename to the dump folder"
    exit 1
fi
#this will not disable binlogs --enable-binlog=0 \
#not supported on mysql 8 --disable-redo-log \

echo "import dump"
myloader -v 3 \
--overwrite-tables \
--skip-definer \
--compress-protocol=1 \
--innodb-optimize-keys \
--serialized-table-creation \
--max-threads-per-table ${TH4TAB} \
--max-threads-for-index-creation ${TH4INX} \
--threads ${TH4ALL} \
-L ${LOGFILE} \
-h ${MYSQL_HOST} -u ${MYSQL_USER} -p "${MYSQL_PASSWORD}" -P ${MYSQL_PORT} -B ${MYSQL_DATABASE} -d ${1}
