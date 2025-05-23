CREATE TABLE :DB_SCHEMA_NAME.household_demographics (
    hd_demo_sk integer NOT NULL,
    hd_income_band_sk integer,
    hd_buy_potential character varying(15),
    hd_dep_count integer,
    hd_vehicle_count integer
)
:ACCESS_METHOD
:STORAGE_OPTIONS
:DISTRIBUTED_BY;
