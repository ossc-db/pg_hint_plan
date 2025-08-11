/*-------------------------------------------------------------------------
 *
 * query_scan_int.h
 *	  lexical scanner internal declarations
 *
 * This file declares the QueryScanStateData structure used by query_scan.l.
 *
 * One difficult aspect of this code is that we need to work in multibyte
 * encodings that are not ASCII-safe.  A "safe" encoding is one in which each
 * byte of a multibyte character has the high bit set (it's >= 0x80).  Since
 * all our lexing rules treat all high-bit-set characters alike, we don't
 * really need to care whether such a byte is part of a sequence or not.
 * In an "unsafe" encoding, we still expect the first byte of a multibyte
 * sequence to be >= 0x80, but later bytes might not be.  If we scan such
 * a sequence as-is, the lexing rules could easily be fooled into matching
 * such bytes to ordinary ASCII characters.  Our solution for this is to
 * substitute 0xFF for each non-first byte within the data presented to flex.
 * The flex rules will then pass the FF's through unmolested.  The
 * query_scan_emit() subroutine is responsible for looking back to the
 * original string and replacing FF's with the corresponding original bytes.
 *
 * Another interesting thing we do here is scan different parts of the same
 * input with physically separate flex lexers (ie, lexers written in separate
 * .l files).  We can get away with this because the only part of the
 * persistent state of a flex lexer that depends on its parsing rule tables
 * is the start state number, which is easy enough to manage --- usually,
 * in fact, we just need to set it to INITIAL when changing lexers.  But to
 * make that work at all, we must use re-entrant lexers, so that all the
 * relevant state is in the yyscan_t attached to the QueryScanState;
 * if we were using lexers with separate static state we would soon end up
 * with dangling buffer pointers in one or the other.  Also note that this
 * is unlikely to work very nicely if the lexers aren't all built with the
 * same flex version, or if they don't use the same flex options.
 *
 *
 * Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * query_scan_int.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef QUERY_SCAN_INT_H
#define QUERY_SCAN_INT_H

#include "query_scan.h"

/*
 * These are just to allow this file to be compilable standalone for header
 * validity checking; in actual use, this file should always be included
 * from the body of a flex file, where these symbols are already defined.
 */
#ifndef YY_TYPEDEF_YY_BUFFER_STATE
#define YY_TYPEDEF_YY_BUFFER_STATE
typedef struct yy_buffer_state *YY_BUFFER_STATE;
#endif
#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void *yyscan_t;
#endif

/*
 * All working state of the lexer must be stored in QueryScanStateData
 * between calls.  This allows us to have multiple open lexer operations,
 * which is needed for nested include files.  The lexer itself is not
 * recursive, but it must be re-entrant.
 */
typedef struct QueryScanStateData
{
	yyscan_t	scanner;		/* Flex's state for this QueryScanState */

	StringInfo	output_buf;		/* current output buffer */

	int			elevel;			/* level of reports generated at parsing */

	/*
	 * These variables always refer to the outer buffer, never to any stacked
	 * variable-expansion buffer.
	 */
	YY_BUFFER_STATE scanbufhandle;
	char	   *scanbuf;		/* start of outer-level input buffer */
	const char *scanline;		/* current input line at outer level */

	/* safe_encoding, curline, refline are used by emit() to replace FFs */
	int			encoding;		/* encoding being used now */
	bool		safe_encoding;	/* is current encoding "safe"? */
	bool		std_strings;	/* are string literals standard? */
	const char *curline;		/* actual flex input string for cur buf */
	const char *refline;		/* original data for cur buffer */

	/*
	 * All this state lives across successive input lines.  start_state is
	 * adopted by yylex() on entry, and updated with its finishing state on
	 * exit.
	 */
	int			start_state;	/* yylex's starting/finishing state */
	int			state_before_str_stop;	/* start cond. before end quote */
	int			paren_depth;	/* depth of nesting in parentheses */
	int			xcdepth;		/* depth of nesting in slash-star comments */
	char	   *dolqstart;		/* current $foo$ quote start string */
	int			xhintnum;		/* number of query hints found */

	/*
	 * State to track boundaries of BEGIN ... END blocks in function
	 * definitions, so that semicolons do not send query too early.
	 */
	int			identifier_count;	/* identifiers since start of statement */
	char		identifiers[4]; /* records the first few identifiers */
	int			begin_depth;	/* depth of begin/end pairs */
} QueryScanStateData;


extern YY_BUFFER_STATE query_scan_prepare_buffer(QueryScanState state,
												 const char *txt, int len,
												 char **txtcopy);
extern void query_yyerror(int elevel, const char *txt, const char *message);

extern void query_scan_emit(QueryScanState state, const char *txt, int len);

#endif							/* QUERY_SCAN_INT_H */
