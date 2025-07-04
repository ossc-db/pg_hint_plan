SET search_path TO public;
SET client_min_messages TO log;
\set SHOW_CONTEXT always

EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.val = t2.val;


LOAD 'pg_hint_plan';
SET pg_hint_plan.debug_print TO on;
SELECT setting <> 'off' FROM pg_settings WHERE name = 'compute_query_id';
SHOW pg_hint_plan.enable_hint_table;

/* query-id related test */
SET compute_query_id to off;
SET pg_hint_plan.enable_hint_table to on;	-- error
SET compute_query_id to on;
SET pg_hint_plan.enable_hint_table to on;
SET compute_query_id to off;
SELECT 1;									-- gets warning
SELECT 1;									-- not
SET compute_query_id to on;
SELECT 1;									-- reactivated
SET compute_query_id to off;
SELECT 1;									-- gets warning
SET pg_hint_plan.enable_hint_table to off;
SET compute_query_id to on;
SET pg_hint_plan.enable_hint_table to on;
SELECT 1;									-- no warning

RESET compute_query_id;
RESET pg_hint_plan.enable_hint_table;

EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.val = t2.val;

/*+ Test (t1 t2) */
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
SET pg_hint_plan.enable_hint TO off;
/*+ Test (t1 t2) */
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
SET pg_hint_plan.enable_hint TO on;

/*Set(enable_indexscan off)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
--+Set(enable_indexscan off)
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+Set(enable_indexscan off) /* nest comment */ */
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+Set(enable_indexscan off)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
EXPLAIN (COSTS false) /*+Set(enable_indexscan off)*/
 SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+ Set(enable_indexscan off) Set(enable_hashjoin off) */
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;

/*+ 	 Set 	 ( 	 enable_indexscan 	 off 	 ) 	 */
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+ 	 
	 	Set 	 
	 	( 	 
	 	enable_indexscan 	 
	 	off 	 
	 	) 	 
	 	*/	 	
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+ Set(enable_indexscan off)Set(enable_nestloop off)Set(enable_mergejoin off)	 	
	 	Set(enable_seqscan off)
	 	*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+Set(work_mem "1M")*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+Set(work_mem "1MB")*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+Set(work_mem TO "1MB")*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;

/*+SeqScan() */ SELECT 1;
/*+SeqScan(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+SeqScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+SeqScan(t1)IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+BitmapScan(t2)NoSeqScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+NoIndexScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;

/*+NoBitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t4 WHERE t1.val < 10;
/*+TidScan(t4)*/
EXPLAIN (COSTS false) SELECT * FROM t3, t4 WHERE t3.id = t4.id AND t4.ctid = '(1,1)';
/*+NoTidScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)';

/*+ NestLoop() */ SELECT 1;
/*+ NestLoop(x) */ SELECT 1;
/*+HashJoin(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+NestLoop(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;
/*+NoMergeJoin(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;

/*+MergeJoin(t1 t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t3 WHERE t1.val = t3.val;
/*+NestLoop(t1 t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t3 WHERE t1.val = t3.val;
/*+NoHashJoin(t1 t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t3 WHERE t1.val = t3.val;

/*+MergeJoin(t4 t1 t2 t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+HashJoin(t3 t4 t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+NestLoop(t2 t3 t4 t1) IndexScan(t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+NoNestLoop(t4 t1 t3 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;

/*+Leading( */
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading( )*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading( t3 )*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading( t3 t4 )*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading(t3 t4 t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading(t3 t4 t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading(t3 t4 t1 t2 t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;
/*+Leading(t3 t4 t4)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id;

EXPLAIN (COSTS false) SELECT * FROM t1, (VALUES(1,1),(2,2),(3,3)) AS t2(id,val) WHERE t1.id = t2.id;
/*+HashJoin(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, (VALUES(1,1),(2,2),(3,3)) AS t2(id,val) WHERE t1.id = t2.id;
/*+HashJoin(t1 *VALUES*)*/
EXPLAIN (COSTS false) SELECT * FROM t1, (VALUES(1,1),(2,2),(3,3)) AS t2(id,val) WHERE t1.id = t2.id;
/*+HashJoin(t1 *VALUES*) IndexScan(t1) IndexScan(*VALUES*)*/
EXPLAIN (COSTS false) SELECT * FROM t1, (VALUES(1,1),(2,2),(3,3)) AS t2(id,val) WHERE t1.id = t2.id;

-- single table scan hint test
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(v_1)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(v_2)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(v_1)BitmapScan(v_2)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(v_1)BitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(v_2)BitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);
/*+BitmapScan(v_1)BitmapScan(v_2)BitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT (SELECT max(id) FROM t1 v_1 WHERE id < 10), id FROM v1 WHERE v1.id = (SELECT max(id) FROM t1 v_2 WHERE id < 10);

-- full scan hint pattern test
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+SeqScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+IndexScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+BitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+TidScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+NoSeqScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+NoIndexScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+NoBitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';
/*+NoTidScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE id < 10 AND ctid = '(1,1)';

EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+SeqScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+IndexScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+IndexScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+BitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+BitmapScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+TidScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+TidScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+NoSeqScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoSeqScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+NoIndexScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoIndexScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+NoBitmapScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoBitmapScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

/*+NoTidScan(t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) SeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) IndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) TidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) NoSeqScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) NoIndexScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) NoBitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';
/*+NoTidScan(t1) NoTidScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

-- additional test
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)' AND t1.id < 10 AND t2.id < 10;
/*+BitmapScan(t1) BitmapScan(t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)' AND t1.id < 10 AND t2.id < 10;

-- outer join test
EXPLAIN (COSTS false) SELECT * FROM t1 FULL OUTER JOIN  t2 ON (t1.id = t2.id);
/*+MergeJoin(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1 FULL OUTER JOIN  t2 ON (t1.id = t2.id);
-- Cannot work
/*+NestLoop(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1 FULL OUTER JOIN  t2 ON (t1.id = t2.id);

-- inheritance tables test
SET constraint_exclusion TO off;
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
SET constraint_exclusion TO on;
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
SET constraint_exclusion TO off;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
SET constraint_exclusion TO on;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';

SET constraint_exclusion TO off;
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO on;
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO off;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+NestLoop(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+MergeJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+HashJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO on;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+NestLoop(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+MergeJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+HashJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;

SET constraint_exclusion TO off;
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
SET constraint_exclusion TO on;
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
SET constraint_exclusion TO off;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+NestLoop(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+MergeJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+HashJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO on;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1 WHERE id >= 50 AND id <= 51 AND p1.ctid = '(1,1)';
/*+NestLoop(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+MergeJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+HashJoin(p1 t1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;

SET constraint_exclusion TO off;
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO on;
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO off;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
SET constraint_exclusion TO on;
/*+SeqScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+IndexScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+BitmapScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;
/*+TidScan(p1)*/
EXPLAIN (COSTS false) SELECT * FROM ONLY p1, t1 WHERE p1.id >= 50 AND p1.id <= 51 AND p1.ctid = '(1,1)' AND p1.id = t1.id AND t1.id < 10;

-- IndexScan is safe for unordered indexes
CREATE TABLE ischk (a text, b tsvector) PARTITION BY LIST(a);
CREATE TABLE ischk_d1 PARTITION OF ischk FOR VALUES IN (0);
CREATE TABLE ischk_d2 PARTITION OF ischk FOR VALUES IN (1);
CREATE INDEX ischk_idx ON ischk USING gin (b);
/*+ IndexScan(ischk ischk_idx) */
EXPLAIN (COSTS false) SELECT * FROM ischk WHERE b = 'x';
DROP TABLE ischk;

-- quote test
/*+SeqScan("""t1 )	")IndexScan("t	2 """)HashJoin("""t1 )	"T3"t	2 """)Leading("""t1 )	"T3"t	2 """)Set(application_name"a	a	a""	a	A")*/
EXPLAIN (COSTS false) SELECT * FROM t1 """t1 )	", t2 "t	2 """, t3 "T3" WHERE """t1 )	".id = "t	2 """.id AND """t1 )	".id = "T3".id;

-- duplicate hint test
/*+SeqScan(t1)SeqScan(t2)IndexScan(t1)IndexScan(t2)BitmapScan(t1)BitmapScan(t2)TidScan(t1)TidScan(t2)HashJoin(t1 t2)NestLoop(t2 t1)MergeJoin(t1 t2)Leading(t1 t2)Leading(t2 t1)Set(enable_seqscan off)Set(enable_mergejoin on)Set(enable_seqscan on)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.ctid = '(1,1)' AND t2.ctid = '(1,1)';

-- sub query Leading hint test
SET from_collapse_limit TO 100;
SET geqo_threshold TO 100;
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)Leading(a t1_1 t1_2 t1_4 t1_5)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)Leading(a t3_2 t3_5 t2_2 c1_1 t3_4 t3_3 t2_3 t2_4 t1_3 t2_5 t1_2 t3_1 t1_4 t2_1 t1_5 t1_1)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)Leading(t3_5 t2_5 t1_5)Leading(t3_2 t2_2 t1_2)Leading(t3_4 t2_4 t1_4)Leading(c1_1 t3_3 t2_3 t1_3 t3_1 t2_1 t1_1)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);

SET from_collapse_limit TO 1;
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)Leading(a t1_1 t1_2 t1_4 t1_5)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)Leading(a t3_2 t3_5 t2_2 c1_1 t3_4 t3_3 t2_3 t2_4 t1_3 t2_5 t1_2 t3_1 t1_4 t2_1 t1_5 t1_1)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);
/*+HashJoin(t1_1 t3_1)MergeJoin(t1_3 t3_3)NestLoop(t1_2 t2_2)NestLoop(t1_4 t2_4)NestLoop(t1_5 t2_5)Leading(t3_5 t2_5 t1_5)Leading(t3_2 t2_2 t1_2)Leading(t3_4 t2_4 t1_4)Leading(c1_1 t3_3 t2_3 t1_3 t3_1 t2_1 t1_1)*/
EXPLAIN (COSTS false)
WITH c1_1(id) AS (
SELECT max(t1_5.id) FROM t1 t1_5, t2 t2_5, t3 t3_5 WHERE t1_5.id = t2_5.id AND t2_5.id = t3_5.id
)
SELECT t1_1.id, (
SELECT max(t1_2.id) FROM t1 t1_2, t2 t2_2, t3 t3_2 WHERE t1_2.id = t2_2.id AND t2_2.id = t3_2.id
) FROM t1 t1_1, t2 t2_1, t3 t3_1, (
SELECT t1_3.id FROM t1 t1_3, t2 t2_3, t3 t3_3 WHERE t1_3.id = t2_3.id AND t2_3.id = t3_3.id
) v1_1(id), c1_1 WHERE t1_1.id = t2_1.id AND t2_1.id = t3_1.id AND t2_1.id = v1_1.id AND v1_1.id = c1_1.id AND t1_1.id = (
SELECT max(t1_4.id) FROM t1 t1_4, t2 t2_4, t3 t3_4 WHERE t1_4.id = t2_4.id AND t2_4.id = t3_4.id 
);

-- ambiguous error
EXPLAIN (COSTS false) SELECT * FROM t1, s0.t1, t2 WHERE public.t1.id = s0.t1.id AND public.t1.id = t2.id;
/*+MergeJoin(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, s0.t1, t2 WHERE public.t1.id = s0.t1.id AND public.t1.id = t2.id;
/*+Leading(t1 t2 t1)*/
EXPLAIN (COSTS false) SELECT * FROM t1, s0.t1, t2 WHERE public.t1.id = s0.t1.id AND public.t1.id = t2.id;

-- identifier length test
EXPLAIN (COSTS false) SELECT * FROM t1 "123456789012345678901234567890123456789012345678901234567890123" JOIN t2 ON ("123456789012345678901234567890123456789012345678901234567890123".id = t2.id) JOIN t3 ON (t2.id = t3.id);
/*+
Leading(123456789012345678901234567890123456789012345678901234567890123 t2 t3)
SeqScan(123456789012345678901234567890123456789012345678901234567890123)
MergeJoin(123456789012345678901234567890123456789012345678901234567890123 t2)
Set(123456789012345678901234567890123456789012345678901234567890123 1)
*/
EXPLAIN (COSTS false) SELECT * FROM t1 "123456789012345678901234567890123456789012345678901234567890123" JOIN t2 ON ("123456789012345678901234567890123456789012345678901234567890123".id = t2.id) JOIN t3 ON (t2.id = t3.id);
/*+
Leading(1234567890123456789012345678901234567890123456789012345678901234 t2 t3)
SeqScan(1234567890123456789012345678901234567890123456789012345678901234)
MergeJoin(1234567890123456789012345678901234567890123456789012345678901234 t2)
Set(1234567890123456789012345678901234567890123456789012345678901234 1)
Set(cursor_tuple_fraction 0.1234567890123456789012345678901234567890123456789012345678901234)
*/
EXPLAIN (COSTS false) SELECT * FROM t1 "1234567890123456789012345678901234567890123456789012345678901234" JOIN t2 ON ("1234567890123456789012345678901234567890123456789012345678901234".id = t2.id) JOIN t3 ON (t2.id = t3.id);
SET "123456789012345678901234567890123456789012345678901234567890123" TO 1;
SET "1234567890123456789012345678901234567890123456789012345678901234" TO 1;
SET cursor_tuple_fraction TO 1234567890123456789012345678901234567890123456789012345678901234;

-- multi error
/*+ Set(enable_seqscan 100)Set(seq_page_cost on)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id;

-- debug log of candidate index to use IndexScan
EXPLAIN (COSTS false) SELECT * FROM t5 WHERE t5.id = 1;
/*+IndexScan(t5 t5_id2)*/
EXPLAIN (COSTS false) SELECT * FROM t5 WHERE t5.id = 1;
/*+IndexScan(t5 no_exist)*/
EXPLAIN (COSTS false) SELECT * FROM t5 WHERE t5.id = 1;
/*+IndexScan(t5 t5_id1 t5_id2)*/
EXPLAIN (COSTS false) SELECT * FROM t5 WHERE t5.id = 1;
/*+IndexScan(t5 no_exist t5_id2)*/
EXPLAIN (COSTS false) SELECT * FROM t5 WHERE t5.id = 1;
/*+IndexScan(t5 no_exist5 no_exist2)*/
EXPLAIN (COSTS false) SELECT * FROM t5 WHERE t5.id = 1;

-- outer inner
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;

/*+Leading((t1))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading((t1 t2))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading((t1 t2 t3))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.id < 10;
/*+Leading((t1 t2))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2 WHERE t1.id = t2.id AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;
/*+Leading((((t1 t2) t3) t4))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading((t1 (t2 t3)))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) (t3 t4)))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < ( SELECT t1_2.id FROM t1 t1_2, t2 t2_2 WHERE t1_2.id = t2_2.id AND t2_2.val > 100 ORDER BY t1_2.id LIMIT 1);
/*+Leading(((t1 t2) t3)) Leading(((t3 t1) t2))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t1.val = t3.val AND t1.id < ( SELECT t1_2.id FROM t1 t1_2, t2 t2_2 WHERE t1_2.id = t2_2.id AND t2_2.val > 100 ORDER BY t1_2.id LIMIT 1);
/*+Leading(((t1 t2) t3)) Leading((t1_2 t2_2))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < ( SELECT t1_2.id FROM t1 t1_2, t2 t2_2 WHERE t1_2.id = t2_2.id AND t2_2.val > 100 ORDER BY t1_2.id LIMIT 1);
/*+Leading(((((t1 t2) t3) t1_2) t2_2))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < ( SELECT t1_2.id FROM t1 t1_2, t2 t2_2 WHERE t1_2.id = t2_2.id AND t2_2.val > 100 ORDER BY t1_2.id LIMIT 1);

-- Specified outer/inner leading hint and join method hint at the same time
/*+Leading(((t1 t2) t3))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3)) MergeJoin(t1 t2)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3)) MergeJoin(t1 t2 t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3)) MergeJoin(t1 t3)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;

EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3)) MergeJoin(t3 t4)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2) t3)) MergeJoin(t1 t2 t3 t4)*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4 WHERE t1.id = t2.id AND t3.id = t4.id AND t1.val = t3.val AND t1.id < 10;

/*+ Leading ( ( t1 ( t2 t3 ) ) ) */
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading((t1(t2 t3)))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(("t1(t2" "t3)"))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+ Leading ( ( ( t1 t2 ) t3 ) ) */
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(((t1 t2)t3))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;
/*+Leading(("(t1" "t2)t3"))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3 WHERE t1.id = t2.id AND t2.val = t3.val AND t1.id < 10;

/*+Leading((t1(t2(t3(t4 t5)))))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading((t5(t4(t3(t2 t1)))))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading(((((t1 t2)t3)t4)t5))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading(((((t5 t4)t3)t2)t1))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading(((t1 t2)(t3(t4 t5))))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading(((t5 t4)(t3(t2 t1))))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading((((t1 t2)t3)(t4 t5)))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;
/*+Leading((((t5 t4)t3)(t2 t1)))*/
EXPLAIN (COSTS false) SELECT * FROM t1, t2, t3, t4, t5 WHERE t1.id = t2.id AND t1.id = t3.id AND t1.id = t4.id AND t1.id = t5.id;

-- inherite table test to specify the index's name
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_pkey)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_id_val_idx)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_val_id_idx)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';

EXPLAIN (COSTS false) SELECT val FROM p2 WHERE val >= '50' AND val <= '51' AND p2.ctid = '(1,1)';

-- Inhibit parallel exection to avoid interfaring the hint
set max_parallel_workers_per_gather to 0;
/*+ IndexScan(p2 p2_val)*/
EXPLAIN (COSTS false) SELECT val FROM p2 WHERE val >= '50' AND val <= '51' AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_pkey)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_id2_val)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_val2_id)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';

/*+IndexScan(p2 p2_pkey)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_c1_id_val_idx)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 no_exist)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_pkey p2_c1_id_val_idx)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_pkey no_exist)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_c1_id_val_idx no_exist)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_pkey p2_c1_id_val_idx no_exist)*/
EXPLAIN (COSTS false) SELECT * FROM p2 WHERE id >= 50 AND id <= 51 AND p2.ctid = '(1,1)';

/*+IndexScan(p2 p2_val_idx)*/
EXPLAIN (COSTS false) SELECT val FROM p2 WHERE val >= '50' AND val <= '51' AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_expr)*/
EXPLAIN (COSTS false) SELECT val FROM p2 WHERE val >= '50' AND val <= '51' AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_val_idx6)*/
EXPLAIN (COSTS false) SELECT val FROM p2 WHERE val >= '50' AND val <= '51' AND p2.ctid = '(1,1)';
/*+IndexScan(p2 p2_val_idx p2_val_idx6)*/
EXPLAIN (COSTS false) SELECT val FROM p2 WHERE val >= '50' AND val <= '51' AND p2.ctid = '(1,1)';

-- regular expression
-- ordinary table
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexScanRegexp(t5 t5_[^i].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexScanRegexp(t5 t5_id[0-9].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexScanRegexp(t5 t5[^_].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexScanRegexp(t5 ^.*t5_idaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexScan(t5 t5_id[0-9].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexOnlyScanRegexp(t5 t5_[^i].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexOnlyScanRegexp(t5 t5_id[0-9].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexOnlyScanRegexp(t5 t5[^_].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexOnlyScanRegexp(t5 ^.*t5_idaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ IndexOnlyScan(t5 t5_id[0-9].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ BitmapScanRegexp(t5 t5_[^i].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ BitmapScanRegexp(t5 t5_id[0-9].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ BitmapScanRegexp(t5 t5[^_].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ BitmapScanRegexp(t5 ^.*t5_idaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;
/*+ BitmapScan(t5 t5_id[0-9].*)*/
EXPLAIN (COSTS false) SELECT id FROM t5 WHERE id = 1;

-- Inheritance
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexScanRegexp(p1 p1_.*[^0-9]$)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexScanRegexp(p1 p1_.*val2.*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexScanRegexp(p1 p1[^_].*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexScan(p1 p1_.*val2.*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexOnlyScanRegexp(p1 p1_.*[^0-9]$)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexOnlyScanRegexp(p1 p1_.*val2.*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexOnlyScanRegexp(p1 p1[^_].*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ IndexOnlyScan(p1 p1_.*val2.*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ BitmapScanRegexp(p1 p1_.*[^0-9]$)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ BitmapScanRegexp(p1 p1_.*val2.*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ BitmapScanRegexp(p1 p1[^_].*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;
/*+ BitmapScan(p1 p1_.*val2.*)*/
EXPLAIN (COSTS false) SELECT val FROM p1 WHERE val = 1;

-- Search from hint table
SELECT get_query_id('SELECT * FROM t1 WHERE t1.id = 1') AS query_id \gset
INSERT INTO hint_plan.hints (query_id, application_name, hints)
  VALUES (:'query_id', '', 'SeqScan(t1)');
SELECT get_query_id('SELECT id FROM t1 WHERE t1.id = 1') AS query_id \gset
INSERT INTO hint_plan.hints (query_id, application_name, hints)
  VALUES (:'query_id', '', 'IndexScan(t1)');
SET pg_hint_plan.enable_hint_table = on;
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE t1.id = 1;
SET pg_hint_plan.enable_hint_table = off;
EXPLAIN (COSTS false) SELECT * FROM t1 WHERE t1.id = 1;
TRUNCATE hint_plan.hints;
VACUUM ANALYZE hint_plan.hints;

-- plpgsql test
EXPLAIN (COSTS false) SELECT id FROM t1 WHERE t1.id = 1;

-- static function
CREATE FUNCTION testfunc() RETURNS RECORD AS $$
DECLARE
  ret record;
BEGIN
  SELECT /*+ SeqScan(t1) */ * INTO ret FROM t1 LIMIT 1;
  RETURN ret;
END;
$$ LANGUAGE plpgsql;
SELECT testfunc();

-- dynamic function
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS void AS $$
BEGIN
  EXECUTE format('/*+ SeqScan(t1) */ SELECT * FROM t1');
END;
$$ LANGUAGE plpgsql;
SELECT testfunc();

-- This should not use SeqScan(t1)
/*+ IndexScan(t1) */ SELECT * from t1 LIMIT 1;

-- Perform
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS void AS $$
BEGIN
  PERFORM  1, /*+ SeqScan(t1) */ * from t1;
END;
$$ LANGUAGE plpgsql;
SELECT testfunc();

-- FOR loop
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS int AS $$
DECLARE
  sum int;
  v int;
BEGIN
  sum := 0;
  FOR v IN SELECT /*+ SeqScan(t1) */ v FROM t1 ORDER BY id LOOP
    sum := sum + v;
  END LOOP;
  RETURN v;
END;
$$ LANGUAGE plpgsql;
SELECT testfunc();

-- Dynamic FOR loop
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS int AS $$
DECLARE
  sum int;
  v int;
  i   int;
BEGIN
  sum := 0;
  FOR v IN EXECUTE 'SELECT /*+ SeqScan(t1) */ val FROM t1 ORDER BY id' LOOP
    sum := sum + v;
  END LOOP;
  RETURN v;
END;
$$ LANGUAGE plpgsql;
SELECT testfunc();

-- Cursor FOR loop
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS int AS $$
DECLARE
  ref CURSOR FOR SELECT /*+ SeqScan(t1) */ * FROM t1 ORDER BY id;
  rec record;
  sum int := 0;
BEGIN
  FOR rec IN ref LOOP
    sum := sum + rec.val;
  END LOOP;
  RETURN sum;
END;
$$ LANGUAGE plpgsql;
SELECT testfunc();

-- RETURN QUERY
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS SETOF t1 AS $$
BEGIN
  RETURN QUERY SELECT /*+ SeqScan(t1) */ * FROM t1 ORDER BY id;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM testfunc() LIMIT 1;

-- Test for error exit from inner SQL statement.
DROP FUNCTION testfunc();
CREATE FUNCTION testfunc() RETURNS SETOF t1 AS $$
BEGIN
  RETURN QUERY SELECT /*+ SeqScan(t1) */ * FROM ttx ORDER BY id;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM testfunc() LIMIT 1;

-- this should not use SeqScan(t1) hint.
/*+ IndexScan(t1) */ SELECT * from t1 LIMIT 1;

DROP FUNCTION testfunc();
DROP EXTENSION pg_hint_plan;

-- Dynamic query in pl/pgsql
CREATE OR REPLACE FUNCTION dynsql1(x int) RETURNS int AS $$
DECLARE c int;
BEGIN
  EXECUTE '/*+ IndexScan(t1) */ SELECT count(*) FROM t1 WHERE id < $1'
  	INTO c USING x;
  RETURN c;
END;
$$ VOLATILE LANGUAGE plpgsql;
VACUUM ANALYZE t1;
-- Check generated statistics in function *without* the hint.
-- Only a sequential scan should be counted.
-- Save counters before running the function.
SET pg_hint_plan.enable_hint = false;
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 't1' \gset t1_before_
SELECT dynsql1(9000);
-- Save counters after running the function.
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 't1' \gset t1_after_
-- seqscan should increment, not idxscan.
SELECT :t1_before_seq_scan < :t1_after_seq_scan AS t1_seq_compare,
       :t1_before_idx_scan < :t1_after_idx_scan AS t1_idx_compare;
-- Check generated statistics in function *with* the hint.
-- Only an index scan should be counted.
-- Save counters before running the function.
SET pg_hint_plan.enable_hint = true;
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 't1' \gset t1_before_
SELECT dynsql1(9000);
-- Save counters after running the function.
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 't1' \gset t1_after_
-- idxscan should increment, not seqscan.
SELECT :t1_before_seq_scan < :t1_after_seq_scan AS t1_seq_compare,
       :t1_before_idx_scan < :t1_after_idx_scan AS t1_idx_compare;

-- Looped dynamic query in pl/pgsql
CREATE OR REPLACE FUNCTION dynsql2(x int, OUT r int) AS $$
DECLARE
  c text;
  s int;
BEGIN
  r := 0;
  FOR c IN SELECT f.f FROM (VALUES ('p1_c1'), ('p1_c2')) f(f) LOOP
    FOR s IN EXECUTE '/*+ IndexScan(' || c || ' ' || c || '_pkey) */ SELECT sum(val) FROM ' || c || ' WHERE id < ' || x LOOP
      r := r + s;
    END LOOP;
  END LOOP;
END;
$$ VOLATILE LANGUAGE plpgsql;
-- Check generated statistics in function *without* the hint.
SET pg_hint_plan.enable_hint = false;
-- Save counters before running the function.
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c1' \gset c1_before_
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c2' \gset c2_before_
SELECT dynsql2(9000);
-- Save counters after running the function.
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c1' \gset c1_after_
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c2' \gset c2_after_
SELECT :c1_after_seq_scan - :c1_before_seq_scan AS c1_seq_compare,
       :c1_after_idx_scan - :c1_before_idx_scan AS c1_idx_compare,
       :c2_after_seq_scan - :c2_before_seq_scan AS c2_seq_compare,
       :c2_after_idx_scan - :c2_before_idx_scan AS c2_idx_compare;
-- Check generated statistics in function *with* the hint.
SET pg_hint_plan.enable_hint = true;
-- Save counters before running the function.
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c1' \gset c1_before_
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c2' \gset c2_before_
SELECT dynsql2(9000);
-- Save counters after running the function.
SELECT pg_stat_force_next_flush();
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c1' \gset c1_after_
SELECT seq_scan, idx_scan FROM pg_stat_user_tables
  WHERE schemaname = 'public' AND relname = 'p1_c2' \gset c2_after_
SELECT :c1_after_seq_scan - :c1_before_seq_scan AS c1_seq_compare,
       :c1_after_idx_scan - :c1_before_idx_scan AS c1_idx_compare,
       :c2_after_seq_scan - :c2_before_seq_scan AS c2_seq_compare,
       :c2_after_idx_scan - :c2_before_idx_scan AS c2_idx_compare;

-- Subqueries on inheritance tables under UNION
EXPLAIN (COSTS off) SELECT val FROM p1 WHERE val < 1000
UNION ALL
SELECT val::int FROM p2 WHERE id < 1000;

/*+ IndexScan(p1 p1_val2) */
EXPLAIN (COSTS off) SELECT val FROM p1 WHERE val < 1000
UNION ALL
SELECT val::int FROM p2 WHERE id < 1000;

/*+ IndexScan(p1 p1_val2) IndexScan(p2 p2_id_val_idx) */
EXPLAIN (COSTS off) SELECT val FROM p1 WHERE val < 1000
UNION ALL
SELECT val::int FROM p2 WHERE id < 1000;

-- union all case
EXPLAIN (COSTS off) SELECT val FROM p1 WHERE val < 1000
UNION
SELECT val::int FROM p2 WHERE id < 1000;

/*+ IndexScan(p2 p2_id_val_idx) */
EXPLAIN (COSTS off) SELECT val FROM p1 WHERE val < 1000
UNION
SELECT val::int FROM p2 WHERE id < 1000;

/*+ IndexScan(p1 p1_val2) IndexScan(p2 p2_id_val_idx) */
EXPLAIN (COSTS off) SELECT val FROM p1 WHERE val < 1000
UNION
SELECT val::int FROM p2 WHERE id < 1000;

--
-- Rows hint tests
--
-- Explain result includes "Planning time" if COSTS is enabled, but
-- this test needs it enabled for get rows count. So do tests via psql
-- and grep -v the mutable line.

-- Parse error check
/*+ Rows() */ SELECT 1;
/*+ Rows(x) */ SELECT 1;

-- value types
SELECT explain_filter('
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 #99) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 +99) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 -99) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 *99) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 *0.01) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 #aa) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id); -- ERROR
');

SELECT explain_filter('
/*+ Rows(t1 t2 /99) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id); -- ERROR
');

-- round up to 1
SELECT explain_filter('
/*+ Rows(t1 t2 -99999) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id);
');

-- complex join tree
SELECT explain_filter('
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id) JOIN t3 ON (t3.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t2 #22) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id) JOIN t3 ON (t3.id = t2.id);
');

SELECT explain_filter('
/*+ Rows(t1 t3 *10) */
EXPLAIN SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id) JOIN t3 ON (t3.id = t2.id);
');

-- Query with join RTE and outer-join relids
/*+Leading(ft_1 ft_2 t1)*/
SELECT relname, seq_scan >= 0 AS seq_scan, idx_scan >= 0 AS idx_scan
  FROM pg_stat_user_tables WHERE schemaname = 'public' AND relname = 't1';

-- hint error level
set client_min_messages to 'DEBUG1';
/*+ SeqScan( */ SELECT 1;
/*+ SeqScan(t1) */ SELECT * FROM t1 LIMIT 0;
set pg_hint_plan.parse_messages to 'ERROR';
-- Force an error before running the planner hook, when forcing the Set hints.
/*+ Set(work_mem "foo") */ SELECT 1;
/*+ SeqScan(t1) */ SELECT * FROM t1 LIMIT 0;
set pg_hint_plan.message_level to 'DEBUG1';
set pg_hint_plan.parse_messages to 'NOTICE';
/*+ SeqScan( */ SELECT 1;
/*+ SeqScan(t1) */ SELECT * FROM t1 LIMIT 0;

-- all hint types together
/*+ SeqScan(t1) MergeJoin(t1 t2) Leading(t1 t2) Rows(t1 t2 +10) Parallel(t1 8 hard) Set(random_page_cost 2.0)*/
EXPLAIN (costs off) SELECT * FROM t1 JOIN t2 ON (t1.id = t2.id) JOIN t3 ON (t3.id = t2.id);
