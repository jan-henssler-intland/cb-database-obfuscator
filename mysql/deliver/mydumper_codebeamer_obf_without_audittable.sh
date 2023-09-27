MYOBF=${MYOBF:-/mnt/ob_codebeamer.sql}
MYLOG=${MYLOG:-/tmp/mylog.log}
MYSQL_HOST=localhost
MYSQL_USER=user
MYSQL_PASSWORD=pwd
MYSQL_DATABASE=db

mydumper \
   --host ${MYSQL_HOST} \
   --user ${MYSQL_USER} \
   --password ${MYSQL_PASSWORD} \
   --database ${MYSQL_DATABASE} \
   --less-locking \
   --checksum-all \
   --compress \
   --order-by-primary \
   --skip-definer \
   --triggers \
   --events \
   --build-empty-files \
   --omit-from-file exclude_tables.txt \
   --logfile ${MYLOG} \
   --threads 16 \
   --outputdir ${MYOBF}
