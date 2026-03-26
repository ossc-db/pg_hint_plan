LOAD 'pg_hint_plan';
SET pg_hint_plan.enable_hint TO on;
SET pg_hint_plan.debug_print TO on;
SET client_min_messages TO LOG;
SET jit = off;
SET search_path TO public;

CREATE TABLE as_t (
  id   int,
  tags int[]
);

INSERT INTO as_t
SELECT i, ARRAY[i % 100]::int[]
FROM generate_series(1, 10000) AS g(i);

ANALYZE as_t;

CREATE OR REPLACE FUNCTION as_arr() RETURNS int[]
LANGUAGE plpgsql VOLATILE AS
$$
BEGIN
  RETURN ARRAY[1, 2, 3]::int[];
END;
$$;

--
-- Array operators (&&) with non-Const RHS: planner defaults are crude.
--
SELECT explain_filter('
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr();
');

SELECT explain_filter('
/*+ArrayRows(as_t #2000)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr();
');

SELECT explain_filter('
/*+ArrayRows(as_t #2000) ArrayRows(as_t && #10)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr();
');

SELECT explain_filter('
/*+ArrayRows(as_t && *2)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr();
');

SELECT explain_filter('
/*+ArrayRows(as_t && +100)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr();
');

SELECT explain_filter('
/*+ArrayRows(as_t && -50)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr();
');

--
-- Multiple array predicates on the same relset.
--
SELECT explain_filter('
/*+ArrayRows(as_t #1000)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr() AND tags @> as_arr();
');

SELECT explain_filter('
/*+ArrayRows(as_t && #1000) ArrayRows(as_t = ANY #2000)*/
EXPLAIN SELECT * FROM as_t WHERE tags && as_arr() AND id = ANY(as_arr());
');

--
-- ScalarArrayOpExpr: all comparison operators with ANY/ALL.
--
SELECT explain_filter('
EXPLAIN SELECT * FROM as_t WHERE id = ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t = ANY #1)*/
EXPLAIN SELECT * FROM as_t WHERE id = ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t = ANY *3)*/
EXPLAIN SELECT * FROM as_t WHERE id = ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t = ANY +10)*/
EXPLAIN SELECT * FROM as_t WHERE id = ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t = ANY -5)*/
EXPLAIN SELECT * FROM as_t WHERE id = ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t #2000) ArrayRows(as_t ANY #50) ArrayRows(as_t = ANY #5)*/
EXPLAIN SELECT * FROM as_t WHERE id = ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t < ANY #2000)*/
EXPLAIN SELECT * FROM as_t WHERE id < ANY(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t >= ALL #1000)*/
EXPLAIN SELECT * FROM as_t WHERE id >= ALL(as_arr());
');

SELECT explain_filter('
/*+ArrayRows(as_t != ANY #1)*/
EXPLAIN SELECT * FROM as_t WHERE id != ANY(as_arr());
');

--
-- Partitioned table / inheritance: single-rel hints should apply to each child.
--
CREATE TABLE as_p (
  id   int,
  tags int[]
) PARTITION BY RANGE (id);

CREATE TABLE as_p1 PARTITION OF as_p
  FOR VALUES FROM (1) TO (5001);
CREATE TABLE as_p2 PARTITION OF as_p
  FOR VALUES FROM (5001) TO (10001);

INSERT INTO as_p
SELECT i, ARRAY[i % 100]::int[]
FROM generate_series(1, 10000) AS g(i);

ANALYZE as_p;

SELECT explain_filter('
/*+ArrayRows(as_p && #10)*/
EXPLAIN SELECT * FROM as_p WHERE tags && as_arr();
');

DROP TABLE as_p;

DROP FUNCTION as_arr();
DROP TABLE as_t;
