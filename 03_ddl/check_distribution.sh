#!/bin/bash

# To run this shell, please source tpcds_variables.sh and functions.sh manually.

# VARS_FILE="tpcds_variables.sh"
# FUNCTIONS_FILE="functions.sh"

# shellcheck source=tpcds_variables.sh
# source ./${VARS_FILE}
# shellcheck source=functions.sh
# source ./${FUNCTIONS_FILE}

PWD=$(get_pwd ${BASH_SOURCE[0]})

get_version
log_time "Current database running this test is:\n${VERSION_FULL}"

if [ "${VERSION}" == "gpdb_4_3" ] || [ "${VERSION}" == "gpdb_5" ]; then

  distkeyfile="distribution_original.txt"
else
  distkeyfile="distribution.txt"
fi


for z in $(cat ${PWD}/${distkeyfile}); do
  table_name=$(echo ${z} | awk -F '|' '{print $2}')
  distribution=$(echo ${z} | awk -F '|' '{print $3}')
  if [ "${distribution}" != "REPLICATED" ]; then
    # Check the table distribution situations
    log_time "Distribution for table ${SCHEMA_NAME}.${table_name}"
    log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c \"SELECT gp_segment_id,COUNT(*) AS row_count FROM ${SCHEMA_NAME}.${table_name} GROUP BY gp_segment_id ORDER BY row_count DESC;\""
    psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "SELECT gp_segment_id,COUNT(*) AS row_count FROM ${SCHEMA_NAME}.${table_name} GROUP BY gp_segment_id ORDER BY row_count DESC;"
  fi
done