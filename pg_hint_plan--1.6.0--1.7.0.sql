/* pg_hint_plan/pg_hint_plan--1.6.0--1.7.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION pg_hint_plan UPDATE TO '1.7.0'" to load this file. \quit

SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints','');
SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints_id_seq','');

-- Hint table uses query IDs since 1.7.0, so drop the past one.
DROP TABLE hint_plan.hints;
CREATE TABLE hint_plan.hints (
    id serial NOT NULL,
    query_id bigint NOT NULL,
    application_name text NOT NULL,
    hints text NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX hints_norm_and_app
  ON hint_plan.hints (query_id, application_name);

GRANT SELECT ON hint_plan.hints TO PUBLIC;
GRANT USAGE ON SCHEMA hint_plan TO PUBLIC;
