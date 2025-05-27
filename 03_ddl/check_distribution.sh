#!/bin/bash

# To run this shell, please source tpcds_variables.sh and functions.sh.

VARS_FILE="tpcds_variables.sh"
FUNCTIONS_FILE="functions.sh"

current_dir=$(pwd)
parent_dir="${current_dir%/*}"
echo "Parent Directory: $parent_dir"

# shellcheck source=tpcds_variables.sh
source $parent_dir/${VARS_FILE}
# shellcheck source=functions.sh
source $parent_dir/${FUNCTIONS_FILE}

PWD=$(get_pwd ${BASH_SOURCE[0]})

get_version
log_time "Current database running this test is:\n${VERSION_FULL}"

if [ "${DB_VERSION}" == "gpdb_4_3" ] || [ "${DB_VERSION}" == "gpdb_5" ]; then

  distkeyfile="distribution_original.txt"
else
  distkeyfile="distribution.txt"
fi

for z in $(cat ${PWD}/${distkeyfile}); do
  table_name=$(echo ${z} | awk -F '|' '{print $2}')
  distribution=$(echo ${z} | awk -F '|' '{print $3}')
  if [ "${distribution}" != "REPLICATED" ]; then
    # Check the table distribution situations
    log_time "Distribution for table ${DB_SCHEMA_NAME}.${table_name}"
    sql=$(cat <<EOF
WITH segment_counts AS (
    SELECT 
        gp_segment_id,
        COUNT(*) as row_count
    FROM 
        ${DB_SCHEMA_NAME}.${table_name}
    GROUP BY gp_segment_id
)
SELECT 
    MAX(row_count) FILTER (WHERE gp_segment_id IS NOT NULL) as max_rows,
    MIN(row_count) FILTER (WHERE gp_segment_id IS NOT NULL) as min_rows,
    ROUND(AVG(row_count) FILTER (WHERE gp_segment_id IS NOT NULL), 0) as avg_rows,
    ROUND(
        (MAX(row_count) FILTER (WHERE gp_segment_id IS NOT NULL) - 
         MIN(row_count) FILTER (WHERE gp_segment_id IS NOT NULL)) * 100.0 / 
        NULLIF(AVG(row_count) FILTER (WHERE gp_segment_id IS NOT NULL), 0), 
        2
    ) as skew_percent,
    COUNT(*) as total_segments,
    SUM(row_count) as total_rows
FROM 
    segment_counts;
EOF
    )
    psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "${sql}"
  fi
done

# Check the partitions tables are correctly set, should be none rows retures.

log_time "Check the partitions tables are correctly set, should be none rows retures."

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(cr_returned_date_sk),min(cr_returned_date_sk) from  ${DB_SCHEMA_NAME}.catalog_returns_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(cs_sold_date_sk),min(cs_sold_date_sk) from  ${DB_SCHEMA_NAME}.catalog_sales_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(inv_date_sk),min(inv_date_sk) from  ${DB_SCHEMA_NAME}.inventory_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(sr_returned_date_sk),min(sr_returned_date_sk) from  ${DB_SCHEMA_NAME}.store_returns_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(ss_sold_date_sk),min(ss_sold_date_sk) from  ${DB_SCHEMA_NAME}.store_sales_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(wr_returned_date_sk),min(wr_returned_date_sk)  from  ${DB_SCHEMA_NAME}.web_returns_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select max(ws_sold_date_sk),min(ws_sold_date_sk)  from  ${DB_SCHEMA_NAME}.web_sales_1_prt_others;"

#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select sotdschemaname,pg_size_pretty(sum(sotdsize)+sum(sotdtoastsize)+sum(sotdadditionalsize)) from gp_toolkit.gp_size_of_table_disk group by sotdschemaname;"
#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select sotuschemaname,pg_size_pretty(sum(sotusize)::numeric) from gp_toolkit.gp_size_of_table_uncompressed group by sotuschemaname;"