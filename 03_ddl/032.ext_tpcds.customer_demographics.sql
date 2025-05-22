CREATE EXTERNAL TABLE ext_tpcds.customer_demographics (like ${SCHEMA_NAME}.customer_demographics)  
LOCATION (:LOCATION)
FORMAT 'TEXT' (DELIMITER '|' NULL AS '' ESCAPE AS E'\\');
