#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})
step="multi_user_reports"

log_time "Step ${step} started"
printf "\n"


init_log ${step}

get_version
filter="gpdb"

for i in ${PWD}/*.${filter}.*.sql; do
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${i}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${i}
  echo ""
done

filename=$(ls ${PWD}/*.copy.*.sql)

for i in ${TPC_DS_DIR}/log/rollout_testing_*; do
  logfile="'${i}'"
  loadsql="\COPY tpcds_testing.sql FROM ${logfile} WITH DELIMITER '|';"
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c \"${loadsql}\""
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c "${loadsql}"
  echo ""
done

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -c "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpcds_testing'" | psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -e

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/detailed_report.sql
echo ""

echo "Finished ${step}"
log_time "Step ${step} finished"
printf "\n"
