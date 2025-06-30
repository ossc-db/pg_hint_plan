/* pg_hint_plan/pg_hint_plan--1.7.1--1.8.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION pg_hint_plan UPDATE TO '1.8.0'" to load this file. \quit

SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints', '');
SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints_id_seq', '');

GRANT SELECT ON hint_plan.hints TO PUBLIC;
GRANT USAGE ON SCHEMA hint_plan TO PUBLIC;
