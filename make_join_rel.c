/*-------------------------------------------------------------------------
 *
 * make_join_rel.c
 *	  Routines copied from PostgreSQL core distribution with some
 *	  modifications.
 *
 * src/backend/optimizer/path/joinrels.c
 *
 * This file contains the following functions from corresponding files.
 *
 *	static functions:
 *     make_join_rel()
 *     populate_joinrel_with_paths()
 *
 * Portions Copyright (c) 2013-2025, NIPPON TELEGRAPH AND TELEPHONE CORPORATION
 * Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 *-------------------------------------------------------------------------
 */

/*
 * adjust_rows: tweak estimated row numbers according to the hint.
 */
static double
adjust_rows(double rows, RowsHint *hint)
{
	double		result = 0.0;	/* keep compiler quiet */

	if (hint->value_type == RVT_ABSOLUTE)
		result = hint->rows;
	else if (hint->value_type == RVT_ADD)
		result = rows + hint->rows;
	else if (hint->value_type == RVT_SUB)
		result = rows - hint->rows;
	else if (hint->value_type == RVT_MULTI)
		result = rows * hint->rows;
	else
		Assert(false);			/* unrecognized rows value type */

	hint->base.state = HINT_STATE_USED;
	if (result < 1.0)
		ereport(WARNING,
				(errmsg("Force estimate to be at least one row, to avoid possible divide-by-zero when interpolating costs : %s",
						hint->base.hint_str)));
	result = clamp_row_est(result);
	elog(DEBUG1, "adjusted rows %d to %d", (int) rows, (int) result);

	return result;
}


/*
 * make_join_rel
 *	   Find or create a join RelOptInfo that represents the join of
 *	   the two given rels, and add to it path information for paths
 *	   created with the two rels as outer and inner rel.
 *	   (The join rel may already contain paths generated from other
 *	   pairs of rels that add up to the same set of base rels.)
 *
 * NB: will return NULL if attempted join is not valid.  This can happen
 * when working with outer joins, or with IN or EXISTS clauses that have been
 * turned into joins.
 */
RelOptInfo *
make_join_rel(PlannerInfo *root, RelOptInfo *rel1, RelOptInfo *rel2)
{
	Relids		joinrelids;
	SpecialJoinInfo *sjinfo;
	bool		reversed;
	List	   *pushed_down_joins = NIL;
	SpecialJoinInfo sjinfo_data;
	RelOptInfo *joinrel;
	List	   *restrictlist;

	/* We should never try to join two overlapping sets of rels. */
	Assert(!bms_overlap(rel1->relids, rel2->relids));

	/* Construct Relids set that identifies the joinrel (without OJ as yet). */
	joinrelids = bms_union(rel1->relids, rel2->relids);

	/* Check validity and determine join type. */
	if (!join_is_legal(root, rel1, rel2, joinrelids,
					   &sjinfo, &reversed))
	{
		/* invalid join path */
		bms_free(joinrelids);
		return NULL;
	}

	/*
	 * Add outer join relid(s) to form the canonical relids.  Any added outer
	 * joins besides sjinfo itself are appended to pushed_down_joins.
	 */
	joinrelids = add_outer_joins_to_relids(root, joinrelids, sjinfo,
										   &pushed_down_joins);

	/* Swap rels if needed to match the join info. */
	if (reversed)
	{
		RelOptInfo *trel = rel1;

		rel1 = rel2;
		rel2 = trel;
	}

	/*
	 * If it's a plain inner join, then we won't have found anything in
	 * join_info_list.  Make up a SpecialJoinInfo so that selectivity
	 * estimation functions will know what's being joined.
	 */
	if (sjinfo == NULL)
	{
		sjinfo = &sjinfo_data;
		init_dummy_sjinfo(sjinfo, rel1->relids, rel2->relids);
	}

	/*
	 * Find or build the join RelOptInfo, and compute the restrictlist that
	 * goes with this particular joining.
	 */
	joinrel = build_join_rel(root, joinrelids, rel1, rel2,
							 sjinfo, pushed_down_joins,
							 &restrictlist);

	/* !!! START: HERE IS THE PART WHICH IS ADDED FOR PG_HINT_PLAN !!! */
	{
		RowsHint   *rows_hint = NULL;
		int			i;
		RowsHint   *justforme = NULL;
		RowsHint   *domultiply = NULL;
		RowsHint  **rows_hints = (RowsHint **) get_current_hints(HINT_TYPE_ROWS);

		/* Search for applicable rows hint for this join node */
		for (i = 0; i < current_hint_state->num_hints[HINT_TYPE_ROWS]; i++)
		{
			rows_hint = rows_hints[i];

			/*
			 * Skip this rows_hint if it is invalid from the first or it
			 * doesn't target any join rels.
			 */
			if (!rows_hint->joinrelids ||
				rows_hint->base.state == HINT_STATE_ERROR)
				continue;

			if (bms_equal(joinrelids, rows_hint->joinrelids))
			{
				/*
				 * This joinrel is just the target of this rows_hint, so tweak
				 * rows estimation according to the hint.
				 */
				justforme = rows_hint;
			}
			else if (!(bms_is_subset(rows_hint->joinrelids, rel1->relids) ||
					   bms_is_subset(rows_hint->joinrelids, rel2->relids)) &&
					 bms_is_subset(rows_hint->joinrelids, joinrelids) &&
					 rows_hint->value_type == RVT_MULTI)
			{
				/*
				 * If the rows_hint's target relids is not a subset of both of
				 * component rels and is a subset of this joinrel, ths hint's
				 * targets spread over both component rels. This menas that
				 * this hint has been never applied so far and this joinrel is
				 * the first (and only) chance to fire in current join tree.
				 * Only the multiplication hint has the cumulative nature so
				 * we apply only RVT_MULTI in this way.
				 */
				domultiply = rows_hint;
			}
		}

		if (justforme)
		{
			/*
			 * If a hint just for me is found, no other adjust method is
			 * useles, but this cannot be more than twice becuase this joinrel
			 * is already adjusted by this hint.
			 */
			if (justforme->base.state == HINT_STATE_NOTUSED)
				joinrel->rows = adjust_rows(joinrel->rows, justforme);
		}
		else
		{
			if (domultiply)
			{
				/*
				 * If we have multiple routes up to this joinrel which are not
				 * applicable this hint, this multiply hint will applied more
				 * than twice. But there's no means to know of that,
				 * re-estimate the row number of this joinrel always just
				 * before applying the hint. This is a bit different from
				 * normal planner behavior but it doesn't harm so much.
				 */
				set_joinrel_size_estimates(root, joinrel, rel1, rel2, sjinfo,
										   restrictlist);

				joinrel->rows = adjust_rows(joinrel->rows, domultiply);
			}

		}
	}
	/* !!! END: HERE IS THE PART WHICH IS ADDED FOR PG_HINT_PLAN !!! */

	/*
	 * If we've already proven this join is empty, we needn't consider any
	 * more paths for it.
	 */
	if (is_dummy_rel(joinrel))
	{
		bms_free(joinrelids);
		return joinrel;
	}

	/* Build a grouped join relation for 'joinrel' if possible. */
	make_grouped_join_rel(root, rel1, rel2, joinrel, sjinfo,
						  restrictlist);

	/* Add paths to the join relation. */
	populate_joinrel_with_paths(root, rel1, rel2, joinrel, sjinfo,
								restrictlist);

	bms_free(joinrelids);

	return joinrel;
}


/*
 * make_grouped_join_rel
 *	  Build a grouped join relation for the given "joinrel" if eager
 *	  aggregation is applicable and the resulting grouped paths are considered
 *	  useful.
 *
 * There are two strategies for generating grouped paths for a join relation:
 *
 * 1. Join a grouped (partially aggregated) input relation with a non-grouped
 * input (e.g., AGG(B) JOIN A).
 *
 * 2. Apply partial aggregation (sorted or hashed) on top of existing
 * non-grouped join paths (e.g., AGG(A JOIN B)).
 *
 * To limit planning effort and avoid an explosion of alternatives, we adopt a
 * strategy where partial aggregation is only pushed to the lowest possible
 * level in the join tree that is deemed useful.  That is, if grouped paths can
 * be built using the first strategy, we skip consideration of the second
 * strategy for the same join level.
 *
 * Additionally, if there are multiple lowest useful levels where partial
 * aggregation could be applied, such as in a join tree with relations A, B,
 * and C where both "AGG(A JOIN B) JOIN C" and "A JOIN AGG(B JOIN C)" are valid
 * placements, we choose only the first one encountered during join search.
 * This avoids generating multiple versions of the same grouped relation based
 * on different aggregation placements.
 *
 * These heuristics also ensure that all grouped paths for the same grouped
 * relation produce the same set of rows, which is a basic assumption in the
 * planner.
 */
static void
make_grouped_join_rel(PlannerInfo *root, RelOptInfo *rel1,
					  RelOptInfo *rel2, RelOptInfo *joinrel,
					  SpecialJoinInfo *sjinfo, List *restrictlist)
{
	RelOptInfo *grouped_rel;
	RelOptInfo *grouped_rel1;
	RelOptInfo *grouped_rel2;
	bool		rel1_empty;
	bool		rel2_empty;
	Relids		apply_agg_at;

	/*
	 * If there are no aggregate expressions or grouping expressions, eager
	 * aggregation is not possible.
	 */
	if (root->agg_clause_list == NIL ||
		root->group_expr_list == NIL)
		return;

	/* Retrieve the grouped relations for the two input rels */
	grouped_rel1 = rel1->grouped_rel;
	grouped_rel2 = rel2->grouped_rel;

	rel1_empty = (grouped_rel1 == NULL || IS_DUMMY_REL(grouped_rel1));
	rel2_empty = (grouped_rel2 == NULL || IS_DUMMY_REL(grouped_rel2));

	/* Find or construct a grouped joinrel for this joinrel */
	grouped_rel = joinrel->grouped_rel;
	if (grouped_rel == NULL)
	{
		RelAggInfo *agg_info = NULL;

		/*
		 * Prepare the information needed to create grouped paths for this
		 * join relation.
		 */
		agg_info = create_rel_agg_info(root, joinrel, rel1_empty == rel2_empty);
		if (agg_info == NULL)
			return;

		/*
		 * If grouped paths for the given join relation are not considered
		 * useful, and no grouped paths can be built by joining grouped input
		 * relations, skip building the grouped join relation.
		 */
		if (!agg_info->agg_useful &&
			(rel1_empty == rel2_empty))
			return;

		/* build the grouped relation */
		grouped_rel = build_grouped_rel(root, joinrel);
		grouped_rel->reltarget = agg_info->target;

		if (rel1_empty != rel2_empty)
		{
			/*
			 * If there is exactly one grouped input relation, then we can
			 * build grouped paths by joining the input relations.  Set size
			 * estimates for the grouped join relation based on the input
			 * relations, and update the set of relids where partial
			 * aggregation is applied to that of the grouped input relation.
			 */
			set_joinrel_size_estimates(root, grouped_rel,
									   rel1_empty ? rel1 : grouped_rel1,
									   rel2_empty ? rel2 : grouped_rel2,
									   sjinfo, restrictlist);
			agg_info->apply_agg_at = rel1_empty ?
				grouped_rel2->agg_info->apply_agg_at :
				grouped_rel1->agg_info->apply_agg_at;
		}
		else
		{
			/*
			 * Otherwise, grouped paths can be built by applying partial
			 * aggregation on top of existing non-grouped join paths.  Set
			 * size estimates for the grouped join relation based on the
			 * estimated number of groups, and track the set of relids where
			 * partial aggregation is applied.  Note that these values may be
			 * updated later if it is determined that grouped paths can be
			 * constructed by joining other input relations.
			 */
			grouped_rel->rows = agg_info->grouped_rows;
			agg_info->apply_agg_at = bms_copy(joinrel->relids);
		}

		grouped_rel->agg_info = agg_info;
		joinrel->grouped_rel = grouped_rel;
	}

	Assert(IS_GROUPED_REL(grouped_rel));

	/* We may have already proven this grouped join relation to be dummy. */
	if (IS_DUMMY_REL(grouped_rel))
		return;

	/*
	 * Nothing to do if there's no grouped input relation.  Also, joining two
	 * grouped relations is not currently supported.
	 */
	if (rel1_empty == rel2_empty)
		return;

	/*
	 * Get the set of relids where partial aggregation is applied among the
	 * given input relations.
	 */
	apply_agg_at = rel1_empty ?
		grouped_rel2->agg_info->apply_agg_at :
		grouped_rel1->agg_info->apply_agg_at;

	/*
	 * If it's not the designated level, skip building grouped paths.
	 *
	 * One exception is when it is a subset of the previously recorded level.
	 * In that case, we need to update the designated level to this one, and
	 * adjust the size estimates for the grouped join relation accordingly.
	 * For example, suppose partial aggregation can be applied on top of (B
	 * JOIN C).  If we first construct the join as ((A JOIN B) JOIN C), we'd
	 * record the designated level as including all three relations (A B C).
	 * Later, when we consider (A JOIN (B JOIN C)), we encounter the smaller
	 * (B C) join level directly.  Since this is a subset of the previous
	 * level and still valid for partial aggregation, we update the designated
	 * level to (B C), and adjust the size estimates accordingly.
	 */
	if (!bms_equal(apply_agg_at, grouped_rel->agg_info->apply_agg_at))
	{
		if (bms_is_subset(apply_agg_at, grouped_rel->agg_info->apply_agg_at))
		{
			/* Adjust the size estimates for the grouped join relation. */
			set_joinrel_size_estimates(root, grouped_rel,
									   rel1_empty ? rel1 : grouped_rel1,
									   rel2_empty ? rel2 : grouped_rel2,
									   sjinfo, restrictlist);
			grouped_rel->agg_info->apply_agg_at = apply_agg_at;
		}
		else
			return;
	}

	/* Make paths for the grouped join relation. */
	populate_joinrel_with_paths(root,
								rel1_empty ? rel1 : grouped_rel1,
								rel2_empty ? rel2 : grouped_rel2,
								grouped_rel,
								sjinfo,
								restrictlist);
}


/*
 * populate_joinrel_with_paths
 *	  Add paths to the given joinrel for given pair of joining relations. The
 *	  SpecialJoinInfo provides details about the join and the restrictlist
 *	  contains the join clauses and the other clauses applicable for given pair
 *	  of the joining relations.
 */
static void
populate_joinrel_with_paths(PlannerInfo *root, RelOptInfo *rel1,
							RelOptInfo *rel2, RelOptInfo *joinrel,
							SpecialJoinInfo *sjinfo, List *restrictlist)
{
	RelOptInfo *unique_rel2;

	/*
	 * Consider paths using each rel as both outer and inner.  Depending on
	 * the join type, a provably empty outer or inner rel might mean the join
	 * is provably empty too; in which case throw away any previously computed
	 * paths and mark the join as dummy.  (We do it this way since it's
	 * conceivable that dummy-ness of a multi-element join might only be
	 * noticeable for certain construction paths.)
	 *
	 * Also, a provably constant-false join restriction typically means that
	 * we can skip evaluating one or both sides of the join.  We do this by
	 * marking the appropriate rel as dummy.  For outer joins, a
	 * constant-false restriction that is pushed down still means the whole
	 * join is dummy, while a non-pushed-down one means that no inner rows
	 * will join so we can treat the inner rel as dummy.
	 *
	 * We need only consider the jointypes that appear in join_info_list, plus
	 * JOIN_INNER.
	 */
	switch (sjinfo->jointype)
	{
		case JOIN_INNER:
			if (is_dummy_rel(rel1) || is_dummy_rel(rel2) ||
				restriction_is_constant_false(restrictlist, joinrel, false))
			{
				mark_dummy_rel(joinrel);
				break;
			}
			add_paths_to_joinrel(root, joinrel, rel1, rel2,
								 JOIN_INNER, sjinfo,
								 restrictlist);
			add_paths_to_joinrel(root, joinrel, rel2, rel1,
								 JOIN_INNER, sjinfo,
								 restrictlist);
			break;
		case JOIN_LEFT:
			if (is_dummy_rel(rel1) ||
				restriction_is_constant_false(restrictlist, joinrel, true))
			{
				mark_dummy_rel(joinrel);
				break;
			}
			if (restriction_is_constant_false(restrictlist, joinrel, false) &&
				bms_is_subset(rel2->relids, sjinfo->syn_righthand))
				mark_dummy_rel(rel2);
			add_paths_to_joinrel(root, joinrel, rel1, rel2,
								 JOIN_LEFT, sjinfo,
								 restrictlist);
			add_paths_to_joinrel(root, joinrel, rel2, rel1,
								 JOIN_RIGHT, sjinfo,
								 restrictlist);
			break;
		case JOIN_FULL:
			if ((is_dummy_rel(rel1) && is_dummy_rel(rel2)) ||
				restriction_is_constant_false(restrictlist, joinrel, true))
			{
				mark_dummy_rel(joinrel);
				break;
			}
			add_paths_to_joinrel(root, joinrel, rel1, rel2,
								 JOIN_FULL, sjinfo,
								 restrictlist);
			add_paths_to_joinrel(root, joinrel, rel2, rel1,
								 JOIN_FULL, sjinfo,
								 restrictlist);

			/*
			 * If there are join quals that aren't mergeable or hashable, we
			 * may not be able to build any valid plan.  Complain here so that
			 * we can give a somewhat-useful error message.  (Since we have no
			 * flexibility of planning for a full join, there's no chance of
			 * succeeding later with another pair of input rels.)
			 */
			if (joinrel->pathlist == NIL)
				ereport(ERROR,
						(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
						 errmsg("FULL JOIN is only supported with merge-joinable or hash-joinable join conditions")));
			break;
		case JOIN_SEMI:

			/*
			 * We might have a normal semijoin, or a case where we don't have
			 * enough rels to do the semijoin but can unique-ify the RHS and
			 * then do an innerjoin (see comments in join_is_legal).  In the
			 * latter case we can't apply JOIN_SEMI joining.
			 */
			if (bms_is_subset(sjinfo->min_lefthand, rel1->relids) &&
				bms_is_subset(sjinfo->min_righthand, rel2->relids))
			{
				if (is_dummy_rel(rel1) || is_dummy_rel(rel2) ||
					restriction_is_constant_false(restrictlist, joinrel, false))
				{
					mark_dummy_rel(joinrel);
					break;
				}
				add_paths_to_joinrel(root, joinrel, rel1, rel2,
									 JOIN_SEMI, sjinfo,
									 restrictlist);
				add_paths_to_joinrel(root, joinrel, rel2, rel1,
									 JOIN_RIGHT_SEMI, sjinfo,
									 restrictlist);
			}

			/*
			 * If we know how to unique-ify the RHS and one input rel is
			 * exactly the RHS (not a superset) we can consider unique-ifying
			 * it and then doing a regular join.  (The create_unique_paths
			 * check here is probably redundant with what join_is_legal did,
			 * but if so the check is cheap because it's cached.  So test
			 * anyway to be sure.)
			 */
			if (bms_equal(sjinfo->syn_righthand, rel2->relids) &&
				(unique_rel2 = create_unique_paths(root, rel2, sjinfo)) != NULL)
			{
				if (is_dummy_rel(rel1) || is_dummy_rel(rel2) ||
					restriction_is_constant_false(restrictlist, joinrel, false))
				{
					mark_dummy_rel(joinrel);
					break;
				}
				add_paths_to_joinrel(root, joinrel, rel1, unique_rel2,
									 JOIN_UNIQUE_INNER, sjinfo,
									 restrictlist);
				add_paths_to_joinrel(root, joinrel, unique_rel2, rel1,
									 JOIN_UNIQUE_OUTER, sjinfo,
									 restrictlist);
			}
			break;
		case JOIN_ANTI:
			if (is_dummy_rel(rel1) ||
				restriction_is_constant_false(restrictlist, joinrel, true))
			{
				mark_dummy_rel(joinrel);
				break;
			}
			if (restriction_is_constant_false(restrictlist, joinrel, false) &&
				bms_is_subset(rel2->relids, sjinfo->syn_righthand))
				mark_dummy_rel(rel2);
			add_paths_to_joinrel(root, joinrel, rel1, rel2,
								 JOIN_ANTI, sjinfo,
								 restrictlist);
			add_paths_to_joinrel(root, joinrel, rel2, rel1,
								 JOIN_RIGHT_ANTI, sjinfo,
								 restrictlist);
			break;
		default:
			/* other values not expected here */
			elog(ERROR, "unrecognized join type: %d", (int) sjinfo->jointype);
			break;
	}

	/* Apply partitionwise join technique, if possible. */
	try_partitionwise_join(root, rel1, rel2, joinrel, sjinfo, restrictlist);
}
