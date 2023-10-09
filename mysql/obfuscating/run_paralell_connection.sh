#!/bin/bash
TARGETDB="${MYSQL_DATABASE:-codebeamer}"
OUTFILE="/tmp/${TARGETDB}-paralell-connection.log"
export MYCNF=${MYCNF:-./.my.cnf}
export MAX_CONN_USE=35
export MAX_CONN_INTERVALL_CHECK="0.100"



#connection count select count(*) from INFORMATION_SCHEMA.PROCESSLIST where info like '%';
wait_until_below_sql_statements () {
  #echo "must below $MAX_CONN_USE"
  current_sql_count=100

  while [ ${current_sql_count} -gt ${MAX_CONN_USE} ]; do
  	current_sql_count=$(  echo " select count(*) from INFORMATION_SCHEMA.PROCESSLIST where info like '%';"|mysql --defaults-file=${MYCNF} -s )
  	if [ $? -ne 0 ];then
	  	echo "error....happen db dead? exiting now"
	  	exit 1
  	fi
	if [ ${current_sql_count} -gt ${MAX_CONN_USE} ]; then
		echo -n "."
		sleep ${MAX_CONN_INTERVALL_CHECK}
	fi
  done
}

wait_until_table_is_usable () {
  #echo "must below $MAX_CONN_USE"
  statement_count=10
  while [ ${statement_count} -gt 0 ]; do
  	statement_count=$(  echo "show open tables where \`Database\` like DATABASE() and \`Table\` like '$1' and in_use>0;"|mysql --defaults-file=${MYCNF} -s | wc -l )
	#echo "count $statement_count "
  	if [ $? -ne 0 ];then
	  	echo "error....happen db dead? exiting now"
	  	exit 1
  	fi
	if [  ${statement_count} -gt 0 ]; then
		echo -n "."
		sleep ${MAX_CONN_INTERVALL_CHECK}
	fi
  done
}
###############################################main###################################################
###############################################audit_trail_logs#######################################
#just be sure that none is using my table

wait_until_table_is_usable audit_trail_logs

MAX_ATL_ID=`echo 'SELECT max(id) FROM  audit_trail_logs;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

# multi thread audit trail
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-audit_trail_logs"
while [ ${start} -lt ${MAX_ATL_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end audit_trail_logs"
        echo "CALL replace_obfuscated_user(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-audit_trail_logs"
wait
echo "stop audit_trail_logs" >> ${OUTFILE}
################################################acl_role###################################################
##just be sure that none is using my table
wait_until_table_is_usable acl_role

MAX_ACL_ID=`echo 'SELECT max(id) FROM  acl_role;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

#we rush multiple times over obfuscated_acl_role_batch
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-obfuscated_acl_role_batch"
while [ ${start} -lt ${MAX_ACL_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end acl_role"
        echo "CALL obfuscated_acl_role_batch(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-obfuscated_acl_role_batch"
wait
echo "stop obfuscated_acl_role_batch" >> ${OUTFILE}
################################################object_reference#######################################
##just be sure that none is using my table
wait_until_table_is_usable object_reference

MAX_OBJREF_ID=`echo 'SELECT max(id) FROM  object_reference;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

#we rush multiple times over obfuscate_object_reference_batch
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-obfuscate_object_reference_batch"
while [ ${start} -lt ${MAX_OBJREF_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end object_reference"
        echo "CALL obfuscate_object_reference_batch(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-obfuscate_object_reference_batch"
wait
echo "stop obfuscate_object_reference_batch" >> ${OUTFILE}
################################################object_revision#######################################
##just be sure that none is using my table
wait_until_table_is_usable object_revision

MAX_OBJ_ID=`echo 'SELECT max(id) FROM  object;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

#we rush multiple times over object_revision
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-obfuscate_object_revision"
while [ ${start} -lt ${MAX_OBJ_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end object_revision"
        echo "CALL obfuscate_object_revision_batch(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-obfuscate_object_revision"
echo "------>start-obfuscate_jira_doors"
echo "CALL obfuscate_jira_doors();"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
echo "------>stop-obfuscate_jira_doors"
wait
echo "stop obfuscate_object_revision" >> ${OUTFILE}
###############################################task#######################################
#just be sure that none is using my table
wait_until_table_is_usable task

MAX_TASK_ID=`echo 'SELECT max(id) FROM  task;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

#we rush multiple times over task
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-obfuscated_task_batch"
while [ ${start} -lt ${MAX_TASK_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end task"
        echo "CALL obfuscated_task_batch(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-obfuscated_task_batch"
wait
echo "stop obfuscated_task_batch" >> ${OUTFILE}

###############################################task_type#######################################
#just be sure that none is using my table
wait_until_table_is_usable task_type

MAX_TTYPE_ID=`echo 'SELECT max(id) FROM task_type;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

#we rush multiple times over object_revision
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-obfuscate_task_type"
while [ ${start} -lt ${MAX_TTYPE_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end task_type"
        echo "CALL obfuscate_task_type(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-obfuscate_task_type"
wait
echo "stop obfuscate_task_type" >> ${OUTFILE}

##############################################after call#######################################
MAX_QUEUE_ID=`echo 'SELECT max(id) FROM statement_queue_obfuscate;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=1

echo "start multiconnection" >> ${OUTFILE}
echo "------>start-statement_queue_obfuscate $start AND $MAX_QUEUE_ID"
while [ ${start} -lt ${MAX_QUEUE_ID} ];do
        PREPARED_STATEMENT=`echo "SELECT statement FROM statement_queue_obfuscate WHERE id = ${start};"|mysql --defaults-file=${MYCNF} -s 2>&1 `
        echo "current id $start statement_queue_obfuscate and $PREPARED_STATEMENT"
        echo "$PREPARED_STATEMENT" |mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
  wait_until_below_sql_statements
  let start=${start}+1
done
echo "------>stop-statement_queue_obfuscate"
wait
echo "stop statement_queue_obfuscate" >> ${OUTFILE}


echo "CALL obfuscate_jira_doors();"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &