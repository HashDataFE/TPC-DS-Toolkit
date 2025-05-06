#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

step="single_user_reports"

log_time "Step ${step} started"
printf "\n"

init_log ${step}

SF=${GEN_DATA_SCALE}

filter="gpdb"

for i in ${PWD}/*.${filter}.*.sql; do
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${i}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${i}
  echo ""
done

for i in ${PWD}/*.copy.*.sql; do
  logstep=$(echo ${i} | awk -F 'copy.' '{print $2}' | awk -F '.' '{print $1}')
  logfile="${TPC_DS_DIR}/log/rollout_${logstep}.log"
  logfile="'${logfile}'"
  loadsql="\COPY tpcds_reports.$logstep FROM ${logfile} WITH DELIMITER '|';"
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c \"${loadsql}\""
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c "${loadsql}"
  echo ""
done

report_schema="tpcds_reports"
# psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpcds_reports'" | psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -e
log_time "psql -t -A ${PSQL_OPTIONS} -c \"select 'analyze ' ||schemaname||'.'||tablename||';' from pg_tables WHERE schemaname = '${report_schema}';\" |xargs -I {} -P 5 psql -a -A ${PSQL_OPTIONS} -c \"{}\""
psql -t -A ${PSQL_OPTIONS} -c "select 'analyze ' ||schemaname||'.'||tablename||';' from pg_tables WHERE schemaname = '${report_schema}';" |xargs -I {} -P 5 psql -a -A ${PSQL_OPTIONS} -c "{}"

echo "********************************************************************************"
echo "Generate Data"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/gen_data_report.sql
echo ""
echo "********************************************************************************"
echo "Data Loads"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/loads_report.sql
echo ""
echo "********************************************************************************"
echo "Analyze"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/analyze_report.sql
echo ""
echo ""
echo "********************************************************************************"
echo "Queries"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/queries_report.sql
echo ""

echo "********************************************************************************"
echo "Summary"
echo "********************************************************************************"
echo ""
LOAD_TIME_SERIAL=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from tpcds_reports.load where tuples > 0")
LOAD_TIME_PARALLEL=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "SELECT ROUND(MAX(end_epoch_seconds) - MIN(start_epoch_seconds)) FROM tpcds_reports.load WHERE tuples > 0")
ANALYZE_TIME=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from tpcds_reports.sql where id = 1")
QUERIES_TIME=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from (SELECT split_part(description, '.', 2) AS id, min(duration) AS duration FROM tpcds_reports.sql where tuples >= 0 GROUP BY split_part(description, '.', 2)) as sub")
SUCCESS_QUERY=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select count(*) from tpcds_reports.sql where tuples >= 0")
FAILD_QUERY=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select count(*) from tpcds_reports.sql where tuples < 0 and id > 1")

printf "Scale Factor (SF)\t%d\n" "${SF}"
printf "Load SERIAL (seconds)\t\t\t%d\n" "${LOAD_TIME_SERIAL}"
printf "Load PARALLEL (seconds)\t\t\t%d\n" "${LOAD_TIME_PARALLEL}"
printf "Analyze (seconds)\t\t\t%d\n" "${ANALYZE_TIME}"
printf "1 User Queries (seconds)\t\t%d\tFor %d success queries and %d failed queries\n" "${QUERIES_TIME}" "${SUCCESS_QUERY}" "${FAILD_QUERY}"
echo ""
echo "********************************************************************************"

echo "Finished ${step}"
log_time "Step ${step} finished"
printf "\n"
