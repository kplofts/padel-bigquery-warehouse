-- Datasets (BigQuery "schemas"). Layered: raw -> staging -> core (dims/facts) -> mart.
-- Run once. Location is set by the bq CLI (see load/00_setup.sh).
CREATE SCHEMA IF NOT EXISTS padel_raw   OPTIONS (description = 'Landing zone: 1:1 copy of source OLTP tables');
CREATE SCHEMA IF NOT EXISTS padel_stg   OPTIONS (description = 'Staging: typed, cleaned, deduplicated');
CREATE SCHEMA IF NOT EXISTS padel_core  OPTIONS (description = 'Core warehouse: conformed dimensions + facts (star schema)');
CREATE SCHEMA IF NOT EXISTS padel_mart  OPTIONS (description = 'Business-facing marts / analytics views');
