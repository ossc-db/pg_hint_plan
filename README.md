# pg\_hint\_plan 1.6

1. [Synopsis](#synopsis)
1. [Description](#description)
1. [The hint table](#the-hint-table)
1. [Installation](#installation)
1. [Unistallation](#unistallation)
1. [Details in hinting](#details-in-hinting)
1. [Errors](#errors)
1. [Functional limitations](#functional-limitations)
1. [Requirements](#requirements)
1. [Hints list](#hints-list)


## Synopsis

`pg_hint_plan` makes it possible to influence PostgreSQL execution plans using so-called "hints" in SQL comments, like `/*+ SeqScan(a) */`.

The PostgreSQL optimizer uses a cost-based approach to determine the most efficient execution plan for a SQL statement. It employs data statistics, rather than static rules, to estimate the costs of each potential plan, then chooses the plan with the lowest cost and executes it. Though the optimizer strives to select the optimal plan, it may not always succeed due to the lack of consideration for certain properties, such as column correlation.

## Description

### Basic Usage

`pg_hint_plan` reads hinting phrases in specially formulated comments given within the target SQL statement. The special form begins with the character sequence `"/\*+"` and ends with `"\*/"`. Hint phrases consist of a hint name followed by parameters enclosed by parentheses and delimited by spaces. Hinting phrases may be delimited by new lines for readability.

In the example below, hash join is selected as the joining method and scanning `pgbench_accounts` by sequential scan method.

<pre>
postgres=# /*+
postgres*#    <b>HashJoin(a b)</b>
postgres*#    <b>SeqScan(a)</b>
postgres*#  */
postgres-# EXPLAIN SELECT *
postgres-#    FROM pgbench_branches b
postgres-#    JOIN pgbench_accounts a ON b.bid = a.bid
postgres-#   ORDER BY a.aid;
                                        QUERY PLAN
---------------------------------------------------------------------------------------
    Sort  (cost=31465.84..31715.84 rows=100000 width=197)
    Sort Key: a.aid
    ->  <b>Hash Join</b>  (cost=1.02..4016.02 rows=100000 width=197)
            Hash Cond: (a.bid = b.bid)
            ->  <b>Seq Scan on pgbench_accounts a</b>  (cost=0.00..2640.00 rows=100000 width=97)
            ->  Hash  (cost=1.01..1.01 rows=1 width=100)
                ->  Seq Scan on pgbench_branches b  (cost=0.00..1.01 rows=1 width=100)
(7 rows)

postgres=#
</pre>

## The hint table

While hints are typically described in specialy formed comments as described in the above section, this may be inconvenient in cases where queries cannot be edited. In these cases, hints can be placed in a special table named `"hint_plan.hints"`. The table consists of the following columns.

|       column        |                                                                                         description                                                                                         |
|:--------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`                | Unique number to identify a row for a hint. This column is filled automatically by sequence.                                                                                                |
| `norm_query_string` | A pattern matches to the query to be hinted. Constants in the query have to be replace with '?' as in the following example. White space is significant in the pattern.                     |
| `application_name`  | The value of `application_name` of sessions to apply the hint. An empty string means sessions of any `application_name`. |
| `hints`             | Hint phrase. This must be a series of hints excluding surrounding comment marks.                                                                                                            |

The following example shows how to operate with the hint table.

    postgres=# INSERT INTO hint_plan.hints(norm_query_string, application_name, hints)
    postgres-#     VALUES (
    postgres(#         'EXPLAIN (COSTS false) SELECT * FROM t1 WHERE t1.id = ?;',
    postgres(#         '',
    postgres(#         'SeqScan(t1)'
    postgres(#     );
    INSERT 0 1
    postgres=# UPDATE hint_plan.hints
    postgres-#    SET hints = 'IndexScan(t1)'
    postgres-#  WHERE id = 1;
    UPDATE 1
    postgres=# DELETE FROM hint_plan.hints
    postgres-#  WHERE id = 1;
    DELETE 1
    postgres=#

The hint table is owned by and has the default privileges of the creating user at the time of creation during the `CREATE EXTENSION` command. Table hints are prioritized over comment hits.

### The types of hints

Hinting phrases are classified into six types based on what kind of object and how they can affect planning. Scanning methods, join methods, joining order, row number correction, parallel query, and GUC setting. You will see the lists of hint phrases of each type in [Hint list](#hints-list).

#### Hints for scan methods

Scan method hints enforce a specific scanning method on the target table. `pg_hint_plan` recognizes the target table by alias names if any. They are `SeqScan`, `IndexScan`, and so on in this kind of hint.

Scan hints are effective on ordinary tables, inheritance tables, UNLOGGED tables, temporary tables, and system catalogs. External (foreign) tables, table functions, VALUES clause, CTEs, views, and subqueries are not affected.

    postgres=# /*+
    postgres*#     SeqScan(t1)
    postgres*#     IndexScan(t2 t2_pkey)
    postgres*#  */
    postgres-# SELECT * FROM table1 t1 JOIN table2 t2 ON (t1.key = t2.key);

#### Hints for join methods

Join method hints enforce the join methods of the joins involving specified tables.

Join method hints are only effective on ordinary tables, inheritance tables, UNLOGGED tables, temporary tables, external (foreign) tables, system catalogs, table functions, VALUES command results, and CTEs. Joins on views and subqueries are not affected.

#### Hint for joining order

This hint "Leading" enforces the order of joining on two or more tables. There are two ways of enforcing join order. One is enforcing the specific order of joining, but not restricting the direction at each join level. The other enforces both join order and join direction. Additional details are available in the [hint list](#hints-list) table.

    postgres=# /*+
    postgres*#     NestLoop(t1 t2)
    postgres*#     MergeJoin(t1 t2 t3)
    postgres*#     Leading(t1 t2 t3)
    postgres*#  */
    postgres-# SELECT * FROM table1 t1
    postgres-#     JOIN table2 t2 ON (t1.key = t2.key)
    postgres-#     JOIN table3 t3 ON (t2.key = t3.key);

#### Hint for row number correction

This hint "Rows" modifies row number estimates for joins that come from the planner.

    postgres=# /*+ Rows(a b #10) */ SELECT... ; Sets rows of join result to 10
    postgres=# /*+ Rows(a b +10) */ SELECT... ; Increments row number by 10
    postgres=# /*+ Rows(a b -10) */ SELECT... ; Subtracts 10 from the row number.
    postgres=# /*+ Rows(a b *10) */ SELECT... ; Makes the number 10 times larger.

#### Hint for parallel plan

This hint `Parallel` enforces parallel execution configuration on scans. The first and second parameter specifiy the table and number of workers to be used for the parallel scan. The third parameter specifies the strength of enfocement. `soft` means that `pg_hint_plan` only changes `max_parallel_worker_per_gather`, leaving all other parameters to the planner. `hard` changes other planner parameters so as to forcibly apply the number.

Parallel plan hints can affect scans on ordinary tables, inheritence parents, unlogged tables, and system catalogs. External tables, table functions, values clause, CTEs, views, and subqueries are not affected. Note that the internal tables of a view can be specified by its real name/alias as the target object. The following example shows that the query is enforced differently on each table.

    postgres=# explain /*+ Parallel(c1 3 hard) Parallel(c2 5 hard) */
           SELECT c2.a FROM c1 JOIN c2 ON (c1.a = c2.a);
                                      QUERY PLAN
    -------------------------------------------------------------------------------
     Hash Join  (cost=2.86..11406.38 rows=101 width=4)
       Hash Cond: (c1.a = c2.a)
       ->  Gather  (cost=0.00..7652.13 rows=1000101 width=4)
             Workers Planned: 3
             ->  Parallel Seq Scan on c1  (cost=0.00..7652.13 rows=322613 width=4)
       ->  Hash  (cost=1.59..1.59 rows=101 width=4)
             ->  Gather  (cost=0.00..1.59 rows=101 width=4)
                   Workers Planned: 5
                   ->  Parallel Seq Scan on c2  (cost=0.00..1.59 rows=59 width=4)

    postgres=# EXPLAIN /*+ Parallel(tl 5 hard) */ SELECT sum(a) FROM tl;
                                        QUERY PLAN
    -----------------------------------------------------------------------------------
     Finalize Aggregate  (cost=693.02..693.03 rows=1 width=8)
       ->  Gather  (cost=693.00..693.01 rows=5 width=8)
             Workers Planned: 5
             ->  Partial Aggregate  (cost=693.00..693.01 rows=1 width=8)
                   ->  Parallel Seq Scan on tl  (cost=0.00..643.00 rows=20000 width=4)

#### GUC parameters temporarily setting

`Set` hints change GUC parameters for a query only at plan time rather than both planning and execution like a typical SET command. GUC parameter shown in [Query Planning](http://www.postgresql.org/docs/current/static/runtime-config-query.html) can have the expected effects on planning unless any other hint conflicts with the planner method configuration parameters. In the case of multiple hints on the same GUC parameter, the last one will take effect. [GUC parameters for `pg_hint_plan`](#guc-parameters-for-pg_hint_plan) are also settable by this hint but will not work as expected. See [Restrictions](#restrictions) for details.

    postgres=# /*+ Set(random_page_cost 2.0) */
    postgres-# SELECT * FROM table1 t1 WHERE key = 'value';
    ...

### GUC parameters for `pg_hint_plan`

GUC parameters below affect the behavior of `pg_hint_plan`.

|         Parameter name         |                                               Description                                                             | Default   |
|:-------------------------------|:----------------------------------------------------------------------------------------------------------------------|:----------|
| `pg_hint_plan.enable_hint`       | True enables `pg_hint_plan`.                                                                                        | `on`      |
| `pg_hint_plan.enable_hint_table` | True enbles hinting by table. `true` or `false`.                                                                    | `off`     |
| `pg_hint_plan.parse_messages`    | Specifies the log level of hint parse error. Valid values are `error`, `warning`, `notice`, `info`, `log`, `debug`. | `INFO`    |
| `pg_hint_plan.debug_print`       | Controls debug print and verbosity. Valid vaiues are `off`, `on`, `detailed`, and `verbose`.                        | `off`     |
| `pg_hint_plan.message_level`     | Specifies message level of debug print. Valid values are `error`, `warning`, `notice`, `info`, `log`, `debug`.      | `INFO`    |

## Installation

This section describes the installation steps.

### Building Binary Module

Simply run `make` at the top of the source tree, then `make install` as an appropriate user. The `PATH` environment variable should be set properly for the target PostgreSQL for this process.

    $ tar xzvf pg_hint_plan-1.x.x.tar.gz
    $ cd pg_hint_plan-1.x.x
    $ make
    $ su
    # make install

### Loading `pg_hint_plan`

`pg_hint_plan` does not require `CREATE EXTENSION`. Simply loading it by `LOAD` command will activate it and of course you can load it globally by setting `shared_preload_libraries` in `postgresql.conf`. Or you might be interested in `ALTER USER SET`/`ALTER DATABASE SET` for automatic loading for specific sessions.

    postgres=# LOAD 'pg_hint_plan';
    LOAD
    postgres=#

Use `CREATE EXTENSION` and `SET pg_hint_plan.enable_hint_tables TO on` if you want to make use of hint tables.

## Unistallation

`make uninstall` in the top directory of source tree will uninstall the installed files if you installed from the source tree and it is left available.

    $ cd pg_hint_plan-1.x.x
    $ su
    # make uninstall

## Details in hinting

#### Syntax and placement

`pg_hint_plan` reads hints from only the first comment block and any character other than alphabets, digits, spaces, underscores, commas, or parentheses, stops parsing immediately. In the following example `HashJoin(a b)` and `SeqScan(a)` are parsed as hints, but `IndexScan(a)` and `MergeJoin(a b)` are not.

    postgres=# /*+
    postgres*#    HashJoin(a b)
    postgres*#    SeqScan(a)
    postgres*#  */
    postgres-# /*+ IndexScan(a) */
    postgres-# EXPLAIN SELECT /*+ MergeJoin(a b) */ *
    postgres-#    FROM pgbench_branches b
    postgres-#    JOIN pgbench_accounts a ON b.bid = a.bid
    postgres-#   ORDER BY a.aid;
                                          QUERY PLAN
    ---------------------------------------------------------------------------------------
     Sort  (cost=31465.84..31715.84 rows=100000 width=197)
       Sort Key: a.aid
       ->  Hash Join  (cost=1.02..4016.02 rows=100000 width=197)
             Hash Cond: (a.bid = b.bid)
             ->  Seq Scan on pgbench_accounts a  (cost=0.00..2640.00 rows=100000 width=97)
             ->  Hash  (cost=1.01..1.01 rows=1 width=100)
                   ->  Seq Scan on pgbench_branches b  (cost=0.00..1.01 rows=1 width=100)
    (7 rows)

    postgres=#

#### Using with PL/pgSQL

`pg_hint_plan` works for queries in PL/pgSQL scripts with some restrictions.

-   Hints affect only on the following kind of queries.
    -   Queries that return one row. (`SELECT`, `INSERT`, `UPDATE` and `DELETE`)
    -   Queries that return multiple rows. (`RETURN QUERY`)
    -   Dynamic SQL statements. (`EXECUTE`)
    -   Cursor open. (`OPEN`)
    -   Loop over result of a query (`FOR`)
-   A hint comment must be placed after the first word in a query, per the following example, as preceding comments are not sent as a part of the query.

        postgres=# CREATE FUNCTION hints_func(integer) RETURNS integer AS $$
        postgres$# DECLARE
        postgres$#     id  integer;
        postgres$#     cnt integer;
        postgres$# BEGIN
        postgres$#     SELECT /*+ NoIndexScan(a) */ aid
        postgres$#         INTO id FROM pgbench_accounts a WHERE aid = $1;
        postgres$#     SELECT /*+ SeqScan(a) */ count(*)
        postgres$#         INTO cnt FROM pgbench_accounts a;
        postgres$#     RETURN id + cnt;
        postgres$# END;
        postgres$# $$ LANGUAGE plpgsql;

#### Letter case in the object names

Unlike the way PostgreSQL handles object names, `pg_hint_plan` compares bare object names in hints against the database internal object names and are case sensitive. Therefore an object name TBL in a hint matches only "TBL" in the database and does not match any unquoted names in a query like TBL, tbl or Tbl.

#### Escaping special chacaters in object names

The objects in a hint parameter should be enclosed by double quotes if they includes parentheses, double quotes, or white spaces. The escaping rule is the same as PostgreSQL.

### Distinction between multiple occurances of a table

`pg_hint_plan` uses aliases to identify the target objects, if present. This allows you to target a specific occurance of a table among multiple occurances.

    postgres=# /*+ HashJoin(t1 t1) */
    postgres-# EXPLAIN SELECT * FROM s1.t1
    postgres-# JOIN public.t1 ON (s1.t1.id=public.t1.id);
    INFO:  hint syntax error at or near "HashJoin(t1 t1)"
    DETAIL:  Relation name "t1" is ambiguous.
    ...
    postgres=# /*+ HashJoin(pt st) */
    postgres-# EXPLAIN SELECT * FROM s1.t1 st
    postgres-# JOIN public.t1 pt ON (st.id=pt.id);
                                 QUERY PLAN
    ---------------------------------------------------------------------
     Hash Join  (cost=64.00..1112.00 rows=28800 width=8)
       Hash Cond: (st.id = pt.id)
       ->  Seq Scan on t1 st  (cost=0.00..34.00 rows=2400 width=4)
       ->  Hash  (cost=34.00..34.00 rows=2400 width=4)
             ->  Seq Scan on t1 pt  (cost=0.00..34.00 rows=2400 width=4)

#### Underlying tables of views or rules

Hints are not applicable on views themselves, but they can affect the queries within a view if a hinted object name matches the object name in the expanded query on the view. Assigning aliases to the tables in a view enables them to be manipulated from outside the view.

    postgres=# CREATE VIEW v1 AS SELECT * FROM t2;
    postgres=# EXPLAIN /*+ HashJoin(t1 v1) */
              SELECT * FROM t1 JOIN v1 ON (c1.a = v1.a);
                                QUERY PLAN
    ------------------------------------------------------------------
     Hash Join  (cost=3.27..18181.67 rows=101 width=8)
       Hash Cond: (t1.a = t2.a)
       ->  Seq Scan on t1  (cost=0.00..14427.01 rows=1000101 width=4)
       ->  Hash  (cost=2.01..2.01 rows=101 width=4)
             ->  Seq Scan on t2  (cost=0.00..2.01 rows=101 width=4)

#### Inheritance tables

Hints can only target the parent of an inheritance table. The hint affects all children of the inheritance table. Direct hints to children are not effective.

#### Hinting on multistatements

One multistatement can have only one hint block, however the included hints will affect all of the individual statements in the multistatement. Note that within the interactive interface of psql, what may seem as a multistatement is internally a sequence of single statements, so hints affect only the initial following statement.

#### VALUES expressions

`VALUES` expressions in `FROM` clause are named as `*VALUES*` internally so it is hintable if it is the only `VALUES` in a query. Two or more `VALUES` expressions in a query seem distinguishable looking at its explain result, but in reality it is merely cosmetic and they are not distinguishable.

    postgres=# /*+ MergeJoin(*VALUES*_1 *VALUES*) */
          EXPLAIN SELECT * FROM (VALUES (1, 1), (2, 2)) v (a, b)
          JOIN (VALUES (1, 5), (2, 8), (3, 4)) w (a, c) ON v.a = w.a;
    INFO:  pg_hint_plan: hint syntax error at or near "MergeJoin(*VALUES*_1 *VALUES*) "
    DETAIL:  Relation name "*VALUES*" is ambiguous.
                                   QUERY PLAN
    -------------------------------------------------------------------------
     Hash Join  (cost=0.05..0.12 rows=2 width=16)
       Hash Cond: ("*VALUES*_1".column1 = "*VALUES*".column1)
       ->  Values Scan on "*VALUES*_1"  (cost=0.00..0.04 rows=3 width=8)
       ->  Hash  (cost=0.03..0.03 rows=2 width=8)
             ->  Values Scan on "*VALUES*"  (cost=0.00..0.03 rows=2 width=8)

### Subqueries

Subqueries in the following context occasionally can be hinted using the name `ANY_subquery`.

    IN (SELECT ... {LIMIT | OFFSET ...} ...)
    = ANY (SELECT ... {LIMIT | OFFSET ...} ...)
    = SOME (SELECT ... {LIMIT | OFFSET ...} ...)

For these syntaxes, the planner internally assigns a name to the subquery when planning joins on tables including it, so join hints are applicable on such joins using the implicit name, per the following example.

    postgres=# /*+HashJoin(a1 ANY_subquery)*/
    postgres=# EXPLAIN SELECT *
    postgres=#    FROM pgbench_accounts a1
    postgres=#   WHERE aid IN (SELECT bid FROM pgbench_accounts a2 LIMIT 10);
                                             QUERY PLAN

    ---------------------------------------------------------------------------------------------
     Hash Semi Join  (cost=0.49..2903.00 rows=1 width=97)
       Hash Cond: (a1.aid = a2.bid)
       ->  Seq Scan on pgbench_accounts a1  (cost=0.00..2640.00 rows=100000 width=97)
       ->  Hash  (cost=0.36..0.36 rows=10 width=4)
             ->  Limit  (cost=0.00..0.26 rows=10 width=4)
                   ->  Seq Scan on pgbench_accounts a2  (cost=0.00..2640.00 rows=100000 width=4)

#### Using `IndexOnlyScan` hint

An unexpected index scan on a different index may be performed when the IndexOnlyScan hint specifies an index that cannot perform an index-only scan.

#### Behavior of `NoIndexScan`

The `NoIndexScan` hint will also prevent index-only scans, similar to `NoIndexOnlyScan`.

#### Parallel hint and `UNION`

A `UNION` can run in parallel only when all underlying subqueries are parallel-safe. Conversely, enforcing parallel on any of the subqueries lets a parallel-executable `UNION` run in parallel. Note a parallel hint with zero workers prevents a scan from being executed in parallel.

#### Setting `pg_hint_plan` parameters by Set hints

`pg_hint_plan` parameters can change the behavior of `pg_hint_plan` itself, which may cause some parameters to not work as expected.

-   Hints to change `enable_hint`, `enable_hint_tables` are ignored even though they are reported as "used hints" in debug logs.
-   Setting `debug_print` and `message_level` works from midst of the processing of the target query.

## Errors

`pg_hint_plan` stops parsing on any error but continues using already parsed hints in the most cases. The following are typical errors.

#### Syntax errors

Any syntactical errors or wrong hint names are reported as a syntax error. These errors are reported in the server log with the message level specified by `pg_hint_plan.message_level` if `pg_hint_plan.debug_print` is on and has already been parsed.

#### Object misspecifications

Object misspecifications will result in hints being silently ignored. This kind of error is reported as "not used hints" in the server log under the same conditions as syntax errors.

#### Redundant or conflicting hints

In cases of redundent hints or multiple hints conflicting with each other, the last hint parsed will be active. This kind of error is reported as "duplication hints" in the server log under the same conditions as syntax errors.

#### Nested comments

Hint comments cannot contain nested comment blocks. If `pg_hint_plan` encounters one, it will stop parsing and, unlike other errors, abandon all previously parsed hint. This kind of error is reported in the same way as other errors.

## Functional limitations

#### Influences of some of planner GUC parameters

The planner does not try to consider joining order for FROM clause entries more than `from_collapse_limit`. Therefore, `pg_hint_plan` cannot affect join order as expected for those cases.

#### Hints trying to enforce unexecutable plans

In the case where hinting results in a plan that connect be executed, the planner may choose any executable plan. Examples of unexecutable plans include:

-   `FULL OUTER JOIN` to use nested loop
-   To use indexes that does not have columns used in quals
-   To do TID scans for queries without ctid conditions

#### Queries in ECPG

ECPG removes comments in queries written as embedded SQLs, so hints cannot be passed in those queries. The only exception is the `EXECUTE` command which passes a given string unmodifed. It is recommended to consider using hint tables in this scenario.

#### Work with `pg_stat_statements`

`pg_stat_statements` generates a query id ignoring comments. As a result, identical queries with different hints are summarized as the same query.

## Requirements

pg_hint_plan 1.6 requires PostgreSQL 16.


PostgreSQL versions tested

- Version 16

OS versions tested

- CentOS 8.5

See also
--------

### PostgreSQL documents

- [EXPLAIN](http://www.postgresql.org/docs/current/static/sql-explain.html)
- [SET](http://www.postgresql.org/docs/current/static/sql-set.html)
- [Server Config](http://www.postgresql.org/docs/current/static/runtime-config.html)
- [Parallel Plans](http://www.postgresql.org/docs/current/static/parallel-plans.html)


## Hints list

The available hints are listed below.

|             Group            |                                                              Format                                                             |                                                                                                                                                                        Description                                                                                                                                                                       |
|:-----------------------------|:--------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Scan method                  | `SeqScan(table)`                                                                                                                  | Forces sequential scan on the table                                                                                                                                                                                                                                                                                                                      |
|                              | `TidScan(table)`                                                                                                                  | Forces TID scan on the table.                                                                                                                                                                                                                                                                                                                            |
|                              | `IndexScan(table[ index...])`                                                                                                     | Forces index scan on the table. Restricted to specified indexes if any.                                                                                                                                                                                                                                                                                   |
|                              | `IndexOnlyScan(table[ index...])`                                                                                                 | Forces index-only scan on the table. Restricted to specfied indexes if any. Index scan may be used if index-only scan is not available.                                                            |
|                              | `BitmapScan(table[ index...])`                                                                                                    | Forces bitmap scan on the table. Restricted to specfied indexes if any.                                                                                                                                                                                                                                                                                  |
|                              | `IndexScanRegexp(table[ POSIX Regexp...])` `IndexOnlyScanRegexp(table[ POSIX Regexp...])` `BitmapScanRegexp(table[ POSIX Regexp...])` | Forces index scan or index-only scan or bitmap scan on the table. Restricted to indexes that match the specified POSIX regular expression pattern.                                                                                                                                                                        |
|                              | `NoSeqScan(table)`                                                                                                                | Forces not to do sequential scan on the table.                                                                                                                                                                                                                                                                                                           |
|                              | `NoTidScan(table)`                                                                                                                | Forces not to do TID scan on the table.                                                                                                                                                                                                                                                                                                                  |
|                              | `NoIndexScan(table)`                                                                                                              | Forces not to do index scan (or index-only scan) on the table.                                                                                                                                                                                                                                                             |
|                              | `NoIndexOnlyScan(table)`                                                                                                          | Forces not to do index-only scan on the table.                                                                                                                                                                                                                                                                   |
|                              | `NoBitmapScan(table)`                                                                                                             | Forces not to do bitmap scan on the table.                                                                                                                                                                                                                                                                                                               |
| Join method                  | `NestLoop(table table[ table...])`                                                                                                | Forces nested loop for the joins between the specifiled tables.                                                                                                                                                                                                                                                                                       |
|                              | `HashJoin(table table[ table...])`                                                                                                | Forces hash join for the joins between the specifiled tables.                                                                                                                                                                                                                                                                                         |
|                              | `MergeJoin(table table[ table...])`                                                                                               | Forces merge join for the joins between the specifiled tables.                                                                                                                                                                                                                                                                                        |
|                              | `NoNestLoop(table table[ table...])`                                                                                              | Forces not to do nested loop for the joins between the specifiled tables.                                                                                                                                                                                                                                                                             |
|                              | `NoHashJoin(table table[ table...])`                                                                                              | Forces not to do hash join for the joins between the specifiled tables.                                                                                                                                                                                                                                                                               |
|                              | `NoMergeJoin(table table[ table...])`                                                                                             | Forces not to do merge join for the joins between the specifiled tables.                                                                                                                                                                                                                                                                              |
| Join order                   | `Leading(table table[ table...])`                                                                                                 | Forces join order as specified.                                                                                                                                                                                                                                                                                                                          |
|                              | `Leading(<join pair>)`                                                                                                            | Forces join order and directions as specified. A join pair is a pair of tables and/or other join pairs enclosed by parentheses, which can make a nested structure.                                                                                                                                                                                       |
| Behavior control on Join     | `Memoize(table table[ table...])`                                                                                                 | Allow the topmost join of a join among the specified tables to memoize the inner result. (Note this doesn't force, but only allows.)                                                                                                                                                                                                                                                                                                              |
|                              | `NoMemoize(table table[ table...])`                                                                                               | Inhibit the topmost join of a join among the specified tables from memoizing the inner result.                                                                                                                                                                                                                                                                                                        |
| Row number correction        | `Rows(table table[ table...] correction)`                                                                                         | Modify row number estimate of the result of joins between the specfied tables. The available methods are absolute (#<n>), addition (+<n>), subtraction (-<n>), or multiplication (*<n>). <n> should be a string that strtod() can read.                                                                                                            |
| Parallel query configuration | `Parallel(table <# of workers> [soft\|hard])`                                                                                     | Enforce or inhibit parallel execution of specfied table. <# of workers> is the desired number of parallel workers, where zero means inhibiting parallel execution. If the third parameter is soft (default), it just changes max_parallel_workers_per_gather and leaves everything else to the planner. Hard means enforcing the specified number of workers. |
| GUC                          | `Set(GUC-param value)`                                                                                                            | Set the GUC parameter to the value during plan time.                                                                                                                                                                                                                                                                                             |

* * * * *

Copyright (c) 2012-2023, NIPPON TELEGRAPH AND TELEPHONE CORPORATION
