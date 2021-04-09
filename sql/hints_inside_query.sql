LOAD 'pg_hint_plan';

explain (costs false)
select * from t1 join t2 on t1.id = t2.id where '/*+HashJoin(t1 t2)*/' <> '';

set pg_hint_plan.hints_inside_query = on;
explain (costs false)
select * from t1 join t2 on t1.id = t2.id where '/*+HashJoin(t1 t2)*/' <> '';

set pg_hint_plan.hints_inside_query = off;
explain (costs false)
select * from t1 join t2 on t1.id = t2.id where '/*+HashJoin(t1 t2)*/' <> '';

set pg_hint_plan.hints_inside_query = on;
/*+ MergeJoin(t1 t2) */
explain (costs false)
select * from t1 join t2 on t1.val = t2.val where '/*+HashJoin(t1 t2)*/' <> '';

/*+ HashJoin(t1 t2) */
explain (costs false)
select * from t1 join t2 on t1.val = t2.val where '/*+MergeJoin(t1 t2)*/' <> '';
