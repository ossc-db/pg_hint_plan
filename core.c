/*-------------------------------------------------------------------------
 *
 * core.c
 *	  Routines copied from PostgreSQL core distribution.
 *
 * The main purpose of this files is having access to static functions in core.
 *
 * This file contains the following functions from corresponding files.
 *
 * src/backend/optimizer/path/allpaths.c
 *
 *	static functions:
 *	   set_plain_rel_pathlist()
 *	   create_plain_partial_paths()
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 *-------------------------------------------------------------------------
 */

#include "access/tsmapi.h"
#include "catalog/pg_operator.h"
#include "foreign/fdwapi.h"


/*
 * set_plain_rel_pathlist
 *	  Build access paths for a plain relation (no subquery, no inheritance)
 */
static void
set_plain_rel_pathlist(PlannerInfo *root, RelOptInfo *rel, RangeTblEntry *rte)
{
	Relids		required_outer;

	/*
	 * We don't support pushing join clauses into the quals of a seqscan, but
	 * it could still have required parameterization due to LATERAL refs in
	 * its tlist.
	 */
	required_outer = rel->lateral_relids;

	/*
	 * Consider TID scans.
	 *
	 * If create_tidscan_paths returns true, then a TID scan path is forced.
	 * This happens when rel->baserestrictinfo contains CurrentOfExpr, because
	 * the executor can't handle any other type of path for such queries.
	 * Hence, we return without adding any other paths.
	 */
	if (create_tidscan_paths(root, rel))
		return;

	/* Consider sequential scan */
	add_path(rel, create_seqscan_path(root, rel, required_outer, 0));

	/* If appropriate, consider parallel sequential scan */
	if (rel->consider_parallel && required_outer == NULL)
		create_plain_partial_paths(root, rel);

	/* Consider index scans */
	create_index_paths(root, rel);
}


/*
 * create_plain_partial_paths
 *	  Build partial access paths for parallel scan of a plain relation
 */
static void
create_plain_partial_paths(PlannerInfo *root, RelOptInfo *rel)
{
	int			parallel_workers;

	parallel_workers = compute_parallel_worker(rel, rel->pages, -1,
											   max_parallel_workers_per_gather);

	/* If any limit was set to zero, the user doesn't want a parallel scan. */
	if (parallel_workers <= 0)
		return;

	/* Add an unordered partial path based on a parallel sequential scan. */
	add_partial_path(rel, create_seqscan_path(root, rel, NULL, parallel_workers));
}
