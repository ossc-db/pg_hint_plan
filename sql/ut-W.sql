LOAD 'pg_hint_plan';
ALTER SYSTEM SET session_preload_libraries TO 'pg_hint_plan';
SET pg_hint_plan.enable_hint TO on;
SET pg_hint_plan.debug_print TO on;
SET client_min_messages TO LOG;


CREATE TABLE s1.tl (a int);
INSERT INTO s1.tl (SELECT a FROM generate_series(0, 100000) a);

-- Queries on ordinary tables with default setting
EXPLAIN (COSTS false) SELECT * FROM s1.t1;

SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;
SET max_parallel_workers_per_gather to DEFAULT;

/*+Parallel(t1 8)*/
EXPLAIN (COSTS false) SELECT * FROM s1.t1;

/*+Parallel(t1 8 soft)*/
EXPLAIN (COSTS false) SELECT * FROM s1.t1;

/*+Parallel(t1 8 hard)*/
EXPLAIN (COSTS false) SELECT * FROM s1.t1;

/*+Parallel(t1 4 hard) */ /* to be gather merge*/
EXPLAIN (COSTS false) SELECT * FROM s1.t1 ORDER BY s1.t1.c1 LIMIT 4;

-- Queries on inheritance tables
SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;
/*+Parallel(p1 8)*/
EXPLAIN (COSTS false) SELECT * FROM p1;
SET parallel_setup_cost to DEFAULT;
SET parallel_tuple_cost to DEFAULT;
SET min_parallel_table_scan_size to DEFAULT;
SET min_parallel_index_scan_size to DEFAULT;

/*+Parallel(p1 8 hard)*/
EXPLAIN (COSTS false) SELECT * FROM p1;

-- hinting on children makes the whole inheritance parallel
/*+Parallel(p1_c1 8 hard)*/
EXPLAIN (COSTS false) SELECT * FROM p1;


-- Joins
EXPLAIN (COSTS false) SELECT * FROM p1_c1_c1 join p2_c1_c1 on p1_c1_c1.id = p2_c1_c1.id;

/*+Parallel(p1_c1_c1 8 hard)*/
EXPLAIN (COSTS false) SELECT * FROM p1_c1_c1 join p2_c1_c1 on p1_c1_c1.id = p2_c1_c1.id;

SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;

/*+Parallel(p1_c1_c1 8 soft) Parallel(p2_c1_c1 0)*/
EXPLAIN (COSTS false) SELECT * FROM p1_c1_c1 join p2_c1_c1 on p1_c1_c1.id = p2_c1_c1.id;

/*+Parallel(p1_c1_c1 8 hard) Parallel(p2_c1_c1 0)*/
EXPLAIN (COSTS false) SELECT * FROM p1_c1_c1 join p2_c1_c1 on p1_c1_c1.id = p2_c1_c1.id;

/*+Parallel(p1_c1_c1 8 hard) Parallel(p2_c1_c1 8 hard)*/
EXPLAIN (COSTS false) SELECT * FROM p1_c1_c1 join p2_c1_c1 on p1_c1_c1.id = p2_c1_c1.id;


-- Joins on inheritance tables
SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;
/*+Parallel(p1 8)*/
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

/*+Parallel(p1 8)Parallel(p2 0)*/
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

SET parallel_setup_cost to DEFAULT;
SET parallel_tuple_cost to DEFAULT;
SET min_parallel_table_scan_size to DEFAULT;
SET min_parallel_index_scan_size to DEFAULT;

/*+Parallel(p2 8 soft)*/
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

/*+Parallel(p2 8 hard)*/
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

/*+Parallel(p2 8 hard) Parallel(p1 5 hard) */
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;


-- Mixture with a scan hint
-- p1 can be parallel
/*+Parallel(p1 8 hard) IndexScan(p2) */
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

-- Parallel sequential scan
/*+Parallel(p1 8 hard) SeqScan(p1) */
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

-- Parallel index scan
/*+Parallel(p1 8 hard) IndexScan(p1) */
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;

-- This hint doesn't turn on parallel, so the Parallel hint is ignored
set max_parallel_workers_per_gather TO 0;
/*+Parallel(p1 0 hard) IndexScan(p1) */
EXPLAIN (COSTS false) SELECT * FROM p1 join p2 on p1.id = p2.id;


-- Parallel on UNION
EXPLAIN (COSTS false) SELECT id FROM p1 UNION ALL SELECT id FROM p2;

-- parallel hinting on any relation enables parallel
SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;
SET max_parallel_workers_per_gather to 0;

/*+Parallel(p1 8) */
EXPLAIN (COSTS false) SELECT id FROM p1 UNION ALL SELECT id FROM p2;

-- set hint does the same thing
/*+Set(max_parallel_workers_per_gather 1)*/
EXPLAIN (COSTS false) SELECT id FROM p1 UNION ALL SELECT id FROM p2;

-- applies largest number of workers on merged parallel paths
SET parallel_setup_cost to DEFAULT;
SET parallel_tuple_cost to DEFAULT;
SET min_parallel_table_scan_size to DEFAULT;
SET min_parallel_index_scan_size to DEFAULT;
SET max_parallel_workers_per_gather to 8;
/*+Parallel(p1 5 hard)Parallel(p2 6 hard) */
EXPLAIN (COSTS false) SELECT id FROM p1 UNION ALL SELECT id FROM p2;


-- num of workers of non-hinted relations should be default value
SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;
SET max_parallel_workers_per_gather to 3;
SET enable_indexscan to false;

/*+Parallel(p1 8 hard) */
EXPLAIN (COSTS false) SELECT * FROM p1 join t1 on p1.id = t1.id;

-- Negative hint
SET enable_indexscan to DEFAULT;
SET parallel_setup_cost to 0;
SET parallel_tuple_cost to 0;
SET min_parallel_table_scan_size to 0;
SET min_parallel_index_scan_size to 0;
SET max_parallel_workers_per_gather to 5;
EXPLAIN (COSTS false) SELECT * FROM p1;

/*+Parallel(p1 0 hard)*/
EXPLAIN (COSTS false) SELECT * FROM p1;

-- Errors
/*+Parallel(p1 100x hard)Parallel(p1 -1000 hard)Parallel(p1 1000000 hard)
   Parallel(p1 8 hoge)Parallel(p1)Parallel(p1 100 soft x)*/
EXPLAIN (COSTS false) SELECT id FROM p1 UNION ALL SELECT id FROM p2;

-- Hints on unhintable relations are just ignored
\t
/*+Parallel(p1 5 hard) Parallel(s1 3 hard) IndexScan(ft1) SeqScan(cte1)
  TidScan(fs1) IndexScan(t) IndexScan(*VALUES*) */
EXPLAIN (COSTS false) SELECT id FROM p1_c1_c1 as s1 TABLESAMPLE SYSTEM(10)
 UNION ALL
SELECT id FROM ft1
 UNION ALL
(WITH cte1 AS (SELECT id FROM p1 WHERE id % 2 = 0) SELECT id FROM cte1)
 UNION ALL
SELECT userid FROM pg_stat_statements fs1
 UNION ALL
SELECT x FROM (VALUES (1), (2), (3)) t(x);


\t
ALTER SYSTEM SET session_preload_libraries TO DEFAULT;
SELECT pg_reload_conf();
