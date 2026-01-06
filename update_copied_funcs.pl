#! /usr/bin/perl

use strict;

my $srcpath;
my @sources = (
	'src/backend/optimizer/path/allpaths.c');
my %defs =
  ('core.c'
   => {protos => [],
	   funcs => ['set_plain_rel_pathlist',
				 'create_plain_partial_paths',],
	   head => core_c_head()});

# open (my $in, '-|', "objdump -W `which postgres`") || die "failed to objdump";
# while (<$in>)
# {
# 	if (/DW_AT_comp_dir .*: (.*\/)src\/backend\//)
# 	{
# 		$srcpath = $1;
# 		last;
# 	}
# }
# close($in);
$srcpath='/Users/lukasfittl/Code/postgres/';

die "source path not found" if (! defined $srcpath);
#printf("Source path = %s\n", $srcpath);

my %protos;
my %funcs;
my %func_is_static;
my %func_source;

for my $fname (@sources)
{
	my $f = $srcpath.$fname;
	my $source;

	open (my $in, '<', $f) || die "failed to open $f: $!";
	while (<$in>)
	{
		$source .= $_;
	}

	## Collect static prototypes

	while ($source =~ /\n(static [^\(\)\{\}]*?(\w+)(\([^\{\);]+?\);))/gsm)
	{
		#	print "Prototype found: $2\n";
		$protos{$2} = $1;
	}

	## Collect function bodies

	while ($source =~ /(\n\/\*\n.+?\*\/\n(static )?(.+?)\n(.+?) *\(.*?\)\n\{.+?\n\}\n)/gsm)
	{
		$funcs{$4} = $1;
		$func_is_static{$4} = (defined $2);
		$func_source{$4} = $fname;

		  #	printf("Function found: %s$4\n", $func_is_static{$4} ? "static " : "");
	}

	close($in);
}


# Generate files
for my $fname (keys %defs)
{
	my %d = %{$defs{$fname}};

	my @protonames = @{$d{'protos'}};
	my @funcnames = @{$d{'funcs'}};
	my $head = $d{'head'};

	print "Generate $fname.\n";
	open (my $out, '>', $fname) || die "could not open $fname: $!";

	print $out $head;

	for (@protonames)
	{
		print " Prototype: $_\n";
		print $out "\n";
		die "Prototype for $_ not found" if (! defined $protos{$_});
		print $out $protos{$_};
	}

	for (@funcnames)
	{
		printf(" %s function: $_@%s\n",
			   $func_is_static{$_}?"static":"public", $func_source{$_});
		print $out "\n";
		die "Function body for $_ not found" if (! defined $funcs{$_});
		print $out $funcs{$_};
	}

	close($out);
}

sub core_c_head()
{
	return << "EOS";
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
EOS
}
