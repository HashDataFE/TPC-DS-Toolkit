CREATE TABLE :DB_SCHEMA_NAME.ship_mode (
    sm_ship_mode_sk integer NOT NULL,
    sm_ship_mode_id character varying(16) NOT NULL,
    sm_type character varying(30),
    sm_code character varying(10),
    sm_carrier character varying(20),
    sm_contract character varying(20)
)
:ACCESS_METHOD
:STORAGE_OPTIONS
:DISTRIBUTED_BY;
