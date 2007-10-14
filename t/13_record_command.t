#!perl
use strict;
BEGIN{ if (not $] < 5.006) { require warnings; warnings->import } }

select(STDERR); $|=1;
select(STDOUT); $|=1;

use Test::More;
use t::Helper;
use t::Frontend;
use Config;
use File::Temp ();
use IO::CaptureOutput qw/capture/;
use Probe::Perl ();

#--------------------------------------------------------------------------#
# fixtures
#--------------------------------------------------------------------------#

my $perl = Probe::Perl->find_perl_interpreter();

my $quote = $^O eq 'MSWin32' || $^O eq 'MSDOS' ? q{"} : q{'};

#--------------------------------------------------------------------------#
# Test planning
#--------------------------------------------------------------------------#

my @cases = (
    {
        label => "Exit with 0",
        program => 'print qq{foo\n}; exit 0',
        args => '',
        output => [ "foo\n" ],
        exit_code => 0,
    },
    {
        label => "Exit with 1",
        program => 'print qq{foo\n}; exit 1',
        args => '',
        output => [ "foo\n" ],
        exit_code => 1 << 8,
    },
    {
        label => "Exit with 2",
        program => 'print qq{foo\n}; exit 2',
        args => '',
        output => [ "foo\n" ],
        exit_code => 2 << 8,
    },
    {
        label => "Exit with args in shell quotes",
        program => 'print qq{foo $ARGV[0]\n}; exit 0',
        args => "${quote}apples oranges bananas${quote}",
        output => [ "foo apples oranges bananas\n" ],
        exit_code => 0,
    },
    {
        label => "Exit with args and pipe",
        program => 'print qq{foo @ARGV\n}; exit 1',
        args => "bar=1 | $perl -pe 0",
        output => [ "foo bar=1\n" ],
        exit_code => 1 << 8,
    },
    {
        label => "Timeout kills process",
        program => '$now=time(); 1 while( time() - $now < 20); print qq{foo\n}; exit 0',
        args => '',
        output => [],
        delay => 20,
        timeout => 5,
        exit_code => 9,
    },
    {
        label => "Timeout not reached",
        program => '$now=time(); 1 while( time() - $now < 2); print qq{foo\n}; exit 0',
        args => '',
        output => ["foo\n"],
        delay => 2,
        timeout => 10,
        exit_code => 0,
    },
    {
        label => "Timeout not reached (with shell quotes)",
        program => '$now=time(); 1 while( time() - $now < 2); print qq{foo $ARGV[0]\n}; exit 0',
        args => "${quote}apples oranges bananas${quote}",
        output => [ "foo apples oranges bananas\n" ],
        delay => 2,
        timeout => 10,
        exit_code => 0,
    },
    {
        label => "Relative path command",
        relative => 1,
        program => 'print qq{foo\n}; exit 0',
        args => '',
        output => [ "foo\n" ],
        exit_code => 0,
    },
    {
        label => "Relative and timeout",
        relative => 1,
        program => '$now=time(); 1 while( time() - $now < 20); print qq{foo\n}; exit 0',
        args => '',
        output => [],
        delay => 20,
        timeout => 5,
        exit_code => 9,
    },
);

my $tests_per_case = 4;
plan tests => 1 + $tests_per_case * @cases;

#--------------------------------------------------------------------------#
# tests
#--------------------------------------------------------------------------#

require_ok( "CPAN::Reporter" );

for my $c ( @cases ) {
SKIP: {
    skip "Couldn't run perl with relative path", $tests_per_case
        if $c->{relative} && system("perl -e 1") == -1;
    if ( $^O eq 'MSWin32' && $c->{timeout} ) {
        eval "use Win32::Process 0.10 ()";
        skip "Win32::Process 0.10 needed for timeout testing", $tests_per_case
            if $@;
    }

    my $fh = File::Temp->new() 
        or die "Couldn't create a temporary file: $!\nIs your temp drive full?";
    print {$fh} $c->{program}, "\n";
    $fh->flush;
    my ($output, $exit);
    my ($stdout, $stderr);
    my $start_time = time();
    my $cmd = $c->{relative} ? "perl" : $perl; 
    eval {
        capture sub {
            ($output, $exit) = CPAN::Reporter::record_command( 
                "$cmd $fh $c->{args}", $c->{timeout}
            );
        }, \$stdout, \$stderr;
    };
    my $run_time = time() - $start_time;
    diag $@ if $@;
    if ( $c->{timeout} ) {
        my $right_range =  $c->{timeout} < $c->{delay}  
                        ?  (    $run_time >= $c->{timeout} 
                            &&  $run_time <= $c->{delay}    )
                        :  (    $run_time <= $c->{timeout} 
                            &&  $run_time >= $c->{delay}    )
                        ;   
        ok( $right_range, "$c->{label}: runtime in right range");
    }
    else {
        pass "$c->{label}: No timeout requested";
    }
    like( $stdout, "/" . quotemeta(join(q{},@$output)) . "/", 
        "$c->{label}: captured stdout" 
    );
    is_deeply( $output, $c->{output},  "$c->{label}: output as expected" )
        or diag "STDOUT:\n$stdout\n\nSTDERR:\n$stderr\n";
    is( $exit, $c->{exit_code}, "$c->{label}: exit code correct" ); 
} # SKIP
}
