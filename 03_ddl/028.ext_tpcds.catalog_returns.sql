CREATE EXTERNAL TABLE ext_tpcds.catalog_returns (like ${SCHEMA_NAME}.catalog_returns)
LOCATION (:LOCATION)
FORMAT 'TEXT' (DELIMITER '|' NULL AS '' ESCAPE AS E'\\');
