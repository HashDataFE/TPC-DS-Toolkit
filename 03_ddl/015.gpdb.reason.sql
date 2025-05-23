CREATE TABLE :DB_SCHEMA_NAME.reason (
    r_reason_sk integer NOT NULL,
    r_reason_id character varying(16) NOT NULL,
    r_reason_desc character varying(100)
)
:ACCESS_METHOD
:STORAGE_OPTIONS
:DISTRIBUTED_BY;
