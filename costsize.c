/*-------------------------------------------------------------------------
 * costsize.c
 *    Routines to compute relation sizes and path costs. 
 * 
 * The main purpose of this files is having access to static functions of 
 * cost model.
 * 
 * This file contains the following functions from corresponding files.
 * 
 * src/backend/optimizer/path/costsize.c
 * 
 *  static functions:
 *     cost_rescan()
 *     relation_byte_size()
 *     cost_memoize_rescan()
 *     get_parallel_divisor()
 *     cached_scansel()
 *     get_expr_width()
 *     page_size()
 *-------------------------------------------------------------------------
 */

#include "utils/selfuncs.h"

static void cost_rescan(PlannerInfo *root, Path *path, Cost *rescan_startup_cost,
                        Cost *rescan_total_cost);
static double relation_byte_size(double tuples, int width);
static void cost_memoize_rescan(PlannerInfo *root, MemoizePath *mpath,
                                Cost *rescan_startup_cost, Cost *rescan_total_cost);
static double get_parallel_divisor(Path *path);
static MergeScanSelCache *cached_scansel(PlannerInfo *root, RestrictInfo *rinfo,
                                         PathKey *pathkey);
static int32 get_expr_width(PlannerInfo *root, const Node *expr);
static double page_size(double tuples, int width);

/*
 * cost_rescan
 *		Given a finished Path, estimate the costs of rescanning it after
 *		having done so the first time.  For some Path types a rescan is
 *		cheaper than an original scan (if no parameters change), and this
 *		function embodies knowledge about that.  The default is to return
 *		the same costs stored in the Path.  (Note that the cost estimates
 *		actually stored in Paths are always for first scans.)
 *
 * This function is not currently intended to model effects such as rescans
 * being cheaper due to disk block caching; what we are concerned with is
 * plan types wherein the executor caches results explicitly, or doesn't
 * redo startup calculations, etc.
 */
static void
cost_rescan(PlannerInfo *root, Path *path,
			Cost *rescan_startup_cost,	/* output parameters */
			Cost *rescan_total_cost)
{
	switch (path->pathtype)
	{
		case T_FunctionScan:

			/*
			 * Currently, nodeFunctionscan.c always executes the function to
			 * completion before returning any rows, and caches the results in
			 * a tuplestore.  So the function eval cost is all startup cost
			 * and isn't paid over again on rescans. However, all run costs
			 * will be paid over again.
			 */
			*rescan_startup_cost = 0;
			*rescan_total_cost = path->total_cost - path->startup_cost;
			break;
		case T_HashJoin:

			/*
			 * If it's a single-batch join, we don't need to rebuild the hash
			 * table during a rescan.
			 */
			if (((HashPath *) path)->num_batches == 1)
			{
				/* Startup cost is exactly the cost of hash table building */
				*rescan_startup_cost = 0;
				*rescan_total_cost = path->total_cost - path->startup_cost;
			}
			else
			{
				/* Otherwise, no special treatment */
				*rescan_startup_cost = path->startup_cost;
				*rescan_total_cost = path->total_cost;
			}
			break;
		case T_CteScan:
		case T_WorkTableScan:
			{
				/*
				 * These plan types materialize their final result in a
				 * tuplestore or tuplesort object.  So the rescan cost is only
				 * cpu_tuple_cost per tuple, unless the result is large enough
				 * to spill to disk.
				 */
				Cost		run_cost = cpu_tuple_cost * path->rows;
				double		nbytes = relation_byte_size(path->rows,
														path->pathtarget->width);
				long		work_mem_bytes = work_mem * 1024L;

				if (nbytes > work_mem_bytes)
				{
					/* It will spill, so account for re-read cost */
					double		npages = ceil(nbytes / BLCKSZ);

					run_cost += seq_page_cost * npages;
				}
				*rescan_startup_cost = 0;
				*rescan_total_cost = run_cost;
			}
			break;
		case T_Material:
		case T_Sort:
			{
				/*
				 * These plan types not only materialize their results, but do
				 * not implement qual filtering or projection.  So they are
				 * even cheaper to rescan than the ones above.  We charge only
				 * cpu_operator_cost per tuple.  (Note: keep that in sync with
				 * the run_cost charge in cost_sort, and also see comments in
				 * cost_material before you change it.)
				 */
				Cost		run_cost = cpu_operator_cost * path->rows;
				double		nbytes = relation_byte_size(path->rows,
														path->pathtarget->width);
				long		work_mem_bytes = work_mem * 1024L;

				if (nbytes > work_mem_bytes)
				{
					/* It will spill, so account for re-read cost */
					double		npages = ceil(nbytes / BLCKSZ);

					run_cost += seq_page_cost * npages;
				}
				*rescan_startup_cost = 0;
				*rescan_total_cost = run_cost;
			}
			break;
		case T_Memoize:
			/* All the hard work is done by cost_memoize_rescan */
			cost_memoize_rescan(root, (MemoizePath *) path,
								rescan_startup_cost, rescan_total_cost);
			break;
		default:
			*rescan_startup_cost = path->startup_cost;
			*rescan_total_cost = path->total_cost;
			break;
	}
}

/*
 * relation_byte_size
 *	  Estimate the storage space in bytes for a given number of tuples
 *	  of a given width (size in bytes).
 */
static double
relation_byte_size(double tuples, int width)
{
	return tuples * (MAXALIGN(width) + MAXALIGN(SizeofHeapTupleHeader));
}

/*
 * cost_memoize_rescan
 *	  Determines the estimated cost of rescanning a Memoize node.
 *
 * In order to estimate this, we must gain knowledge of how often we expect to
 * be called and how many distinct sets of parameters we are likely to be
 * called with. If we expect a good cache hit ratio, then we can set our
 * costs to account for that hit ratio, plus a little bit of cost for the
 * caching itself.  Caching will not work out well if we expect to be called
 * with too many distinct parameter values.  The worst-case here is that we
 * never see any parameter value twice, in which case we'd never get a cache
 * hit and caching would be a complete waste of effort.
 */
static void
cost_memoize_rescan(PlannerInfo *root, MemoizePath *mpath,
					Cost *rescan_startup_cost, Cost *rescan_total_cost)
{
	EstimationInfo estinfo;
	ListCell   *lc;
	Cost		input_startup_cost = mpath->subpath->startup_cost;
	Cost		input_total_cost = mpath->subpath->total_cost;
	double		tuples = mpath->subpath->rows;
	double		calls = mpath->calls;
	int			width = mpath->subpath->pathtarget->width;

	double		hash_mem_bytes;
	double		est_entry_bytes;
	double		est_cache_entries;
	double		ndistinct;
	double		evict_ratio;
	double		hit_ratio;
	Cost		startup_cost;
	Cost		total_cost;

	/* available cache space */
	hash_mem_bytes = get_hash_memory_limit();

	/*
	 * Set the number of bytes each cache entry should consume in the cache.
	 * To provide us with better estimations on how many cache entries we can
	 * store at once, we make a call to the executor here to ask it what
	 * memory overheads there are for a single cache entry.
	 */
	est_entry_bytes = relation_byte_size(tuples, width) +
		ExecEstimateCacheEntryOverheadBytes(tuples);

	/* include the estimated width for the cache keys */
	foreach(lc, mpath->param_exprs)
		est_entry_bytes += get_expr_width(root, (Node *) lfirst(lc));

	/* estimate on the upper limit of cache entries we can hold at once */
	est_cache_entries = floor(hash_mem_bytes / est_entry_bytes);

	/* estimate on the distinct number of parameter values */
	ndistinct = estimate_num_groups(root, mpath->param_exprs, calls, NULL,
									&estinfo);

	/*
	 * When the estimation fell back on using a default value, it's a bit too
	 * risky to assume that it's ok to use a Memoize node.  The use of a
	 * default could cause us to use a Memoize node when it's really
	 * inappropriate to do so.  If we see that this has been done, then we'll
	 * assume that every call will have unique parameters, which will almost
	 * certainly mean a MemoizePath will never survive add_path().
	 */
	if ((estinfo.flags & SELFLAG_USED_DEFAULT) != 0)
		ndistinct = calls;

	/*
	 * Since we've already estimated the maximum number of entries we can
	 * store at once and know the estimated number of distinct values we'll be
	 * called with, we'll take this opportunity to set the path's est_entries.
	 * This will ultimately determine the hash table size that the executor
	 * will use.  If we leave this at zero, the executor will just choose the
	 * size itself.  Really this is not the right place to do this, but it's
	 * convenient since everything is already calculated.
	 */
	mpath->est_entries = Min(Min(ndistinct, est_cache_entries),
							 PG_UINT32_MAX);

	/*
	 * When the number of distinct parameter values is above the amount we can
	 * store in the cache, then we'll have to evict some entries from the
	 * cache.  This is not free. Here we estimate how often we'll incur the
	 * cost of that eviction.
	 */
	evict_ratio = 1.0 - Min(est_cache_entries, ndistinct) / ndistinct;

	/*
	 * In order to estimate how costly a single scan will be, we need to
	 * attempt to estimate what the cache hit ratio will be.  To do that we
	 * must look at how many scans are estimated in total for this node and
	 * how many of those scans we expect to get a cache hit.
	 */
	hit_ratio = ((calls - ndistinct) / calls) *
		(est_cache_entries / Max(ndistinct, est_cache_entries));

	Assert(hit_ratio >= 0 && hit_ratio <= 1.0);

	/*
	 * Set the total_cost accounting for the expected cache hit ratio.  We
	 * also add on a cpu_operator_cost to account for a cache lookup. This
	 * will happen regardless of whether it's a cache hit or not.
	 */
	total_cost = input_total_cost * (1.0 - hit_ratio) + cpu_operator_cost;

	/* Now adjust the total cost to account for cache evictions */

	/* Charge a cpu_tuple_cost for evicting the actual cache entry */
	total_cost += cpu_tuple_cost * evict_ratio;

	/*
	 * Charge a 10th of cpu_operator_cost to evict every tuple in that entry.
	 * The per-tuple eviction is really just a pfree, so charging a whole
	 * cpu_operator_cost seems a little excessive.
	 */
	total_cost += cpu_operator_cost / 10.0 * evict_ratio * tuples;

	/*
	 * Now adjust for storing things in the cache, since that's not free
	 * either.  Everything must go in the cache.  We don't proportion this
	 * over any ratio, just apply it once for the scan.  We charge a
	 * cpu_tuple_cost for the creation of the cache entry and also a
	 * cpu_operator_cost for each tuple we expect to cache.
	 */
	total_cost += cpu_tuple_cost + cpu_operator_cost * tuples;

	/*
	 * Getting the first row must be also be proportioned according to the
	 * expected cache hit ratio.
	 */
	startup_cost = input_startup_cost * (1.0 - hit_ratio);

	/*
	 * Additionally we charge a cpu_tuple_cost to account for cache lookups,
	 * which we'll do regardless of whether it was a cache hit or not.
	 */
	startup_cost += cpu_tuple_cost;

	*rescan_startup_cost = startup_cost;
	*rescan_total_cost = total_cost;
}

/*
 * Estimate the fraction of the work that each worker will do given the
 * number of workers budgeted for the path.
 */
static double
get_parallel_divisor(Path *path)
{
	double		parallel_divisor = path->parallel_workers;

	/*
	 * Early experience with parallel query suggests that when there is only
	 * one worker, the leader often makes a very substantial contribution to
	 * executing the parallel portion of the plan, but as more workers are
	 * added, it does less and less, because it's busy reading tuples from the
	 * workers and doing whatever non-parallel post-processing is needed.  By
	 * the time we reach 4 workers, the leader no longer makes a meaningful
	 * contribution.  Thus, for now, estimate that the leader spends 30% of
	 * its time servicing each worker, and the remainder executing the
	 * parallel plan.
	 */
	if (parallel_leader_participation)
	{
		double		leader_contribution;

		leader_contribution = 1.0 - (0.3 * path->parallel_workers);
		if (leader_contribution > 0)
			parallel_divisor += leader_contribution;
	}

	return parallel_divisor;
}

/*
 * run mergejoinscansel() with caching
 */
static MergeScanSelCache *
cached_scansel(PlannerInfo *root, RestrictInfo *rinfo, PathKey *pathkey)
{
	MergeScanSelCache *cache;
	ListCell   *lc;
	Selectivity leftstartsel,
				leftendsel,
				rightstartsel,
				rightendsel;
	MemoryContext oldcontext;

	/* Do we have this result already? */
	foreach(lc, rinfo->scansel_cache)
	{
		cache = (MergeScanSelCache *) lfirst(lc);
		if (cache->opfamily == pathkey->pk_opfamily &&
			cache->collation == pathkey->pk_eclass->ec_collation &&
			cache->strategy == pathkey->pk_strategy &&
			cache->nulls_first == pathkey->pk_nulls_first)
			return cache;
	}

	/* Nope, do the computation */
	mergejoinscansel(root,
					 (Node *) rinfo->clause,
					 pathkey->pk_opfamily,
					 pathkey->pk_strategy,
					 pathkey->pk_nulls_first,
					 &leftstartsel,
					 &leftendsel,
					 &rightstartsel,
					 &rightendsel);

	/* Cache the result in suitably long-lived workspace */
	oldcontext = MemoryContextSwitchTo(root->planner_cxt);

	cache = (MergeScanSelCache *) palloc(sizeof(MergeScanSelCache));
	cache->opfamily = pathkey->pk_opfamily;
	cache->collation = pathkey->pk_eclass->ec_collation;
	cache->strategy = pathkey->pk_strategy;
	cache->nulls_first = pathkey->pk_nulls_first;
	cache->leftstartsel = leftstartsel;
	cache->leftendsel = leftendsel;
	cache->rightstartsel = rightstartsel;
	cache->rightendsel = rightendsel;

	rinfo->scansel_cache = lappend(rinfo->scansel_cache, cache);

	MemoryContextSwitchTo(oldcontext);

	return cache;
}

/*
 * get_expr_width
 *		Estimate the width of the given expr attempting to use the width
 *		cached in a Var's owning RelOptInfo, else fallback on the type's
 *		average width when unable to or when the given Node is not a Var.
 */
static int32
get_expr_width(PlannerInfo *root, const Node *expr)
{
	int32		width;

	if (IsA(expr, Var))
	{
		const Var  *var = (const Var *) expr;

		/* We should not see any upper-level Vars here */
		Assert(var->varlevelsup == 0);

		/* Try to get data from RelOptInfo cache */
		if (!IS_SPECIAL_VARNO(var->varno) &&
			var->varno < root->simple_rel_array_size)
		{
			RelOptInfo *rel = root->simple_rel_array[var->varno];

			if (rel != NULL &&
				var->varattno >= rel->min_attr &&
				var->varattno <= rel->max_attr)
			{
				int			ndx = var->varattno - rel->min_attr;

				if (rel->attr_widths[ndx] > 0)
					return rel->attr_widths[ndx];
			}
		}

		/*
		 * No cached data available, so estimate using just the type info.
		 */
		width = get_typavgwidth(var->vartype, var->vartypmod);
		Assert(width > 0);

		return width;
	}

	width = get_typavgwidth(exprType(expr), exprTypmod(expr));
	Assert(width > 0);
	return width;
}

/*
 * page_size
 *	  Returns an estimate of the number of pages covered by a given
 *	  number of tuples of a given width (size in bytes).
 */
static double
page_size(double tuples, int width)
{
	return ceil(relation_byte_size(tuples, width) / BLCKSZ);
}