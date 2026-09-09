-- Test hypothetical indexes with hypopg

-- Skip test if hypopg is not installed.
SELECT count(*) = 0 AS hypopg_missing FROM pg_available_extensions
  WHERE name = 'hypopg' \gset
\if :hypopg_missing
\quit
\endif

LOAD 'pg_hint_plan';

CREATE EXTENSION hypopg;

-- Hypothetical index names embed an OID, so filter them out.
CREATE FUNCTION hypopg_explain(text) RETURNS SETOF text
LANGUAGE plpgsql AS
$$
DECLARE
  ln text;
BEGIN
  FOR ln IN EXECUTE $1
  LOOP
    ln := regexp_replace(ln, '<[0-9]+>', '<NNN>', 'g');
    return next ln;
  END LOOP;
END;
$$;

CREATE TABLE hypopg_t1(a int, b int, c int);
CREATE INDEX hypopg_t1_a_idx ON hypopg_t1 (a);
SELECT regexp_replace(indexname, '<[0-9]+>', '<NNN>') AS indexname
  FROM hypopg_create_index('CREATE INDEX hypopg_t1_b_idx ON hypopg_t1 (b)');

-- Hint matching a real index discards the hypothetical index
SELECT hypopg_explain('
EXPLAIN (COSTS OFF) SELECT /*+ IndexScan(hypopg_t1 hypopg_t1_a_idx) */
  FROM hypopg_t1 WHERE a = 3 AND b = 4');

-- scan methods, hypothetical index discarded.
SELECT hypopg_explain('
EXPLAIN (COSTS OFF) SELECT /*+ IndexScan(hypopg_t1 hypopg_t1_b_idx) */
  FROM hypopg_t1 WHERE a = 3 AND b = 4');
SELECT hypopg_explain('
EXPLAIN (COSTS OFF) SELECT /*+ IndexScan(hypopg_t1 btree_hypopg_t1_b) */
  FROM hypopg_t1 WHERE a = 3 AND b = 4');

-- DisableIndex: hypothetical index discard
SELECT hypopg_explain('
EXPLAIN (COSTS OFF) SELECT /*+ DisableIndex(hypopg_t1 hypopg_t1_a_idx) */
  FROM hypopg_t1 WHERE a = 3 AND b = 4');

DROP FUNCTION hypopg_explain;
DROP TABLE hypopg_t1;
DROP EXTENSION hypopg;
