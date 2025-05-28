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

  distkeyfile="$parent_dir/03_ddl/distribution_original.txt"
else
  distkeyfile="$parent_dir/03_ddl/distribution.txt"
fi

for z in $(cat ${distkeyfile}); do
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