#
# This file is part of CPAN-Reporter
#
# This software is Copyright (c) 2006 by David Golden.
#
# This is free software, licensed under:
#
#   The Apache License, Version 2.0, January 2004
#
package t::Frontend;
use strict;
BEGIN{ if (not $] < 5.006) { require warnings; warnings->import } }

use ExtUtils::MakeMaker ();

BEGIN {
    $INC{"CPAN.pm"} = 1; #fake load
    $CPAN::VERSION = 999;
}

package CPAN::Shell;

sub myprint {
    shift;
    print @_;
}

sub mywarn {
    shift;
    print @_;
}

sub colorable_makemaker_prompt {
    goto \&ExtUtils::MakeMaker::prompt;
}

package CPAN;

$CPAN::Frontend = $CPAN::Frontend = "CPAN::Shell";

1;
