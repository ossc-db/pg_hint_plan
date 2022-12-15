/* pg_hint_plan/pg_hint_plan--1.4--1.5.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION pg_dbms_stats UPDATE TO '1.5'" to load this file. \quit

CREATE TABLE IF NOT EXISTS hint_plan.hints (
	id					serial	NOT NULL,
	norm_query_string	text	NOT NULL,
	application_name	text	NOT NULL,
	hints				text	NOT NULL,
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS hints_norm_and_app ON hint_plan.hints (
	norm_query_string,
	application_name
);

SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints','');
SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints_id_seq','');

GRANT SELECT ON hint_plan.hints TO PUBLIC;
GRANT USAGE ON SCHEMA hint_plan TO PUBLIC;
