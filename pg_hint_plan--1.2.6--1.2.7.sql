/* pg_hint_plan/pg_hint_plan--1.2.6--1.2.7.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_hint_plan" to load this file. \quit

SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints','');
SELECT pg_catalog.pg_extension_config_dump('hint_plan.hints_id_seq','');
