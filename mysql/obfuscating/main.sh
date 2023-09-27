#!/bin/bash
set -o pipefail
INSTDIR=`dirname $0`
cd $INSTDIR
#--defaults-file=./.my.cnf
export MYCNF=${MYCNF:-./.my.cnf}

#if the table tmp_users exist the bottom of  prepare_runonce.sql is reached
MYTMP_USERS_COUNT=`echo "SHOW TABLES LIKE 'tmp_users';" |mysql  --defaults-file=${MYCNF} -s|wc -l`
if [ $? -ne 0 ];then
	echo "error in pipe?"
	exit 1
fi

if [ ${MYTMP_USERS_COUNT} -eq 0 ];then
	echo "prepare obfuscating run"
	mysql  --defaults-file=${MYCNF} < prepare_runonce.sql
fi

#prepare procedures START ...

#things that must run in an order...
mysql  --defaults-file=${MYCNF} < seriell.sql

if [ $? -ne 0 ];then
	echo "error occur exit now"
	exit 2
fi

#./run_paralell_connection.sh 
#cleanup
mysql  --defaults-file=${MYCNF} < post_cleanup.sql
#will destroy data mysql  --defaults-file=${MYCNF} < post_cleanup_rerunable_condition.sql

