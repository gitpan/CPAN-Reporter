package CPAN::Reporter;

$VERSION     = "0.10";

use strict;
# use warnings; # only for Perl >= 5.6
use Config::Tiny;
use ExtUtils::MakeMaker qw/prompt/;
use File::Basename qw/basename/;
use File::HomeDir;
use File::Path qw/mkpath/;
use File::Temp;
use IO::File;
use Tee;
use Test::Reporter;

#--------------------------------------------------------------------------#
# public API
#--------------------------------------------------------------------------#

sub test {
    my ($dist, $system_command) = @_;
    my $temp_out = File::Temp->new;
    tee($system_command, { stderr => 1 }, $temp_out);
    my $temp_in = IO::File->new( $temp_out );
    if ( not defined $temp_in ) {
        warn "CPAN::Reporter couldn't read test results\n";
        return;
    }
    my $result = {
        dist => $dist,
        command => $system_command,
        output => do { local $/; <$temp_in> }
    };
    $result->{tests_ok} = $result->{output} =~ m{^All tests successful}ms;
    _process_report( $result );
    return $result->{tests_ok};    
}

#--------------------------------------------------------------------------#
# defaults and prompts
#--------------------------------------------------------------------------#

my %defaults = (
    email_from => {
        default => '',
    },
    cc_author => {
        default => 'ask/no',
        prompt => "Do you want to CC the the module author?",
    },
    edit_report => {
        default => 'ask/no',
        prompt => "Do you want to edit the test report?",
    },
    send_report => {
        default => 'ask/yes',
        prompt => "Do you want to send the test report?",
    },
    email_to => {
        default => undef, # not written to starter config
    },
    smtp_server => {
        default => undef, # not written to starter config
    },
);

#--------------------------------------------------------------------------#
# private functions
#--------------------------------------------------------------------------#

sub _get_config_options {
    # setup paths
    my $config_dir = File::Spec->catdir( 
        File::HomeDir->my_documents, ".cpanreporter"
    );
    my $config_file = File::Spec->catfile( $config_dir, "config.ini" );

    # make directory and if it doesn't exist
    mkpath $config_dir if ! -d $config_dir;
    
    # read or create config file
    my $config;
    if ( -e $config_file ) {
        $config = Config::Tiny->read( $config_file )
            or warn "Couldn't read CPAN::Reporter configuration file\n";
    }
    else {
        $config = Config::Tiny->new();
        # initialize with any defined default
        for ( keys %defaults ) {
            $config->{_}{$_} = $defaults{$_}{default} 
                if defined $defaults{$_}{default};
        }
        $config->write( $config_file );
    }
       
    # extract and return valid options
    my %active;
    for my $option ( keys %defaults ) {
        if ( exists $config->{_}{$option} ) {
            $active{$option} = $config->{_}{$option};
        }
        else {
            $active{$option} = $defaults{$option}{default}
                if defined $defaults{$option}{default};
        }
    }
    
    return \%active;
}

#--------------------------------------------------------------------------#

sub _prereq_report {
    my $data = shift;
    my $prereq = $data->{dist}->prereq_pm;
    my $report;
    for my $module ( keys %$prereq ) {
        my $version = eval "require $module; return $module->VERSION";
        $version = defined $version ? $version : "Not found";
        $report .= "    $module\: $version (Need $prereq->{$module})\n";
    }
    return $report || "    No requirements found\n";
}

#--------------------------------------------------------------------------#

sub _process_report {
    my ( $result ) = @_;

    # Get configuration options
    my $config = _get_config_options;
    
    if ( ! $config->{email_from} ) {
        warn << "EMAIL_REQUIRED";
        
CPAN::Reporter requires an email-address.  Test report will not be sent.
See documentation for configuration details.

EMAIL_REQUIRED
        return;
    }
        
    # Setup variables for use in report
    $result->{dist_name} = basename($result->{dist}->pretty_id);
    $result->{dist_name} =~ s/(\.tar\.gz|\.tgz|\.zip)$//i;
    $result->{author} = $result->{dist}->author->fullname;
    $result->{author_id} = $result->{dist}->author->id;
    $result->{prereq_pm} = _prereq_report( $result );
    
    # Setup the test report
    print "Preparing to send a test report\n";
    my $tr = Test::Reporter->new;
    $tr->from( $config->{email_from} );
    $tr->address( $config->{email_to} ) if $config->{email_to};
    if ( $config->{smtp_server} ) {
        my @mx = split " ", $config->{smtp_server};
        $tr->mx( \@mx );
    }
    
    # Populate the test report
    
    # CPAN.pm won't normally test a failed 'make', so that should
    # catch prereq failures that would normally be N/A.
    if ( $result->{tests_ok} ) {
        $tr->grade( 'pass' );
    }
    elsif ( $result->{output} =~ m{^FAILED--no tests were run}ms ) {
        $tr->grade( 'unknown' );
    }
    else {
        $tr->grade( 'fail' );
    }
    $tr->distribution( $result->{dist_name}  );
    $tr->comments( _report_text( $result ) );
    $tr->via( 'CPAN::Reporter ' . CPAN::Reporter->VERSION );
    my @cc;

    # User prompts for action
    if ( _prompt( $config, "cc_author") =~ 'y' ) {
        push @cc, "$result->{author_id}\@cpan.org";
    }
    
    if ( _prompt( $config, "edit_report" ) =~ 'y' ) {
        $ENV{VISUAL} ||= $ENV{EDITOR};
        $tr->edit_comments;
    }
    
    if ( _prompt( $config, "send_report" ) =~ 'y' ) {
        print "Sending test report with '" . $tr->grade . 
              "' to " . $tr->address . "\n";
        $tr->send( @cc ) or warn $tr->errstr. "\n";
    }

    return;
}

#--------------------------------------------------------------------------#

sub _prompt {
    my ($config, $option) = @_;
    my $prompt;
    if     ( lc $config->{$option} eq 'ask/yes' ) { 
        $prompt = prompt( $defaults{$option}{prompt} . " (yes/no)", "yes" );
    }
    elsif  ( lc $config->{$option} =~ m{ask(/no)?} ) {
        $prompt = prompt( $defaults{$option}{prompt} . " (yes/no)", "no" );
    }
    else { 
        $prompt = $config->{$option};
    }
    return lc $prompt;
}

#--------------------------------------------------------------------------#

sub _report_text {
    my $data = shift;
    
    # generate report
    my $output = << "ENDREPORT";

Dear $data->{author},
    
This is a computer-generated test report for $data->{dist_name}.

ENDREPORT
    
    if ( $data->{tests_ok} ) { $output .= << "ENDREPORT"; 
Thank you for uploading your work to CPAN.  Congratulations!
All tests were successfully.

ENDREPORT
    }
    else { $output .=  <<"ENDREPORT";
Thank you for uploading your work to CPAN.  However, it appears that
there were some problems testing your distribution.

ENDREPORT
    }
    $output .= << "ENDREPORT";
Additional comments from tester: 
[none provided]

--

Prerequisite modules loaded:

$data->{prereq_pm}
--

Output from '$data->{command}':

$data->{output}
ENDREPORT

    return $output;
}

1; #this line is important and will help the module return a true value

__END__

#--------------------------------------------------------------------------#
# pod documentation 
#--------------------------------------------------------------------------#

=begin wikidoc

= NAME

CPAN::Reporter - Provides Test::Reporter support for CPAN.pm

= VERSION

This documentation describes version %%VERSION%%.

= SYNOPSIS

0 Install a version of CPAN.pm that supports CPAN::Reporter
0 Install CPAN::Reporter
0 Edit .cpanreporter/config.ini
0 Test/install modules as normal with {cpan} or {CPAN::Shell}

= DESCRIPTION

~Note: {CPAN::Reporter} is not yet supported by the current development release
of {CPAN.pm}.  Advanced users who wish to experiment with {CPAN::Reporter} may
see [/"GETTING STARTED"] for instructions on installing a development branch
that supports it.~

{CPAN::Reporter} is an add-on for the {CPAN.pm} module that uses
[Test::Reporter] to send the results of module tests to the CPAN
Testers project.  

The goal of the CPAN Testers project ( [http://testers.cpan.org/] ) is to
test as many CPAN packages as possible on as many platforms as
possible.  This provides valuable feedback to module authors and
potential users to identify bugs or platform compatibility issues and
improves the overall quality and value of CPAN.

One way individuals can contribute is to send test results for each module that
they test or install.  Installing {CPAN::Reporter} gives the option
of automatically generating and emailing test reports whenever tests are run
via {CPAN.pm}.

= GETTING STARTED

{CPAN::Reporter} requires a version of {CPAN.pm} that knows to look for it.
The current development release of {CPAN.pm} does not yet support
{CPAN::Reporter}.  However, a development branch with patches for
{CPAN::Reporter} is available from a subversion repository:

 https://pause.perl.org:5460/svn/cpanpm/branches/dagolden-cpan-reporter
 
This branch roughly corresponds to CPAN 1.87_55 plus a few additional
patches, including {CPAN::Reporter} support.

Advanced users may wish to install this branch and experiment with 
{CPAN::Reporter}.  Note -- there is no guarantee that this branch is
stable.  Proceed with caution.

To install the {CPAN.pm} branch:

* export the source code from the repository

 $ svn export (repository url above)

* inside the checkout directory, run "perl Makefile.PL".  Ignore errors
* run "make"
* run "make install"

Depending on the version of {CPAN.pm} already installed, users may be prompted
to renew their configuration settings when they next run {cpan}.  This will
include an option to enable {CPAN::Reporter}.  To manually enable
{CPAN::Reporter}, type the following commands from the {CPAN.pm} shell prompt:

 cpan> o conf test_report 1
 cpan> o conf commit

After installation, users will need to edit their {CPAN::Reporter}
configuration file per the instructions below.

= CONFIG FILE OPTIONS

Default options for {CPAN::Reporter} are read from a configuration file 
{.cpanreporter/config.ini} in the user's home directory (Unix) or "My 
Documents" directory (Windows).  If CPAN::Reporter does not find a
configuration file, it will attempt to create one with default values.

The configuration file is in "ini" format, with the option name and value
separated by an "=" sign

  email_from = "John Doe" <johndoe@nowhere.org>
  cc_author = no

Options shown below as taking "yes/no/ask" should be set to one of
four values; the result of each is as follows:

* {yes} -- automatic yes
* {no} -- automatic no
* {ask/no} or just {ask} -- prompt each time, but default to no
* {ask/yes} -- prompt each time, but default to yes

For prompts, the default will be used if return is pressed immediately at
the prompt or if the {PERL_MM_USE_DEFAULTS} environment variable is set to
a true value.

Descriptions for each option follow.

== Email Address (required)

{CPAN::Reporter} requires users to provide an email address that will be used
in the "From" header of the email to cpan-testers@perl.org.

* {email_from = <email address>} -- email address of the user sending the
test report; it should be a valid address format, e.g.:

 user@domain
 John Doe <user@domain>
 "John Q. Public" <user@domain>

Because {cpan-testers} uses a mailing list to collect test reports, it is
helpful if the email address provided is subscribed to the list.  Otherwise,
test reports will be held until manually reviewed and approved.  

To keep cpan-testers email separate from everyday email, it may be worthwhile
to use email program filters or to set up a free email account somewhere to use
as the cpan-testers address.

Subscribing an account to the cpan-testers list is as easy as sending a blank
email to cpan-testers-subscribe@perl.org and replying to the confirmation
email.

== Standard Options

These options are included in the standard config file template that is
automatically created.

* {cc_author = yes/no/ask} -- should module authors should be sent a copy of 
the test report at their {author@cpan.org} address (default: ask/no)
* {edit_report = yes/no/ask} -- edit the test report before sending 
(default: ask/no)
* {send_report = yes/no/ask} -- should test reports be sent at all 
(default: ask/yes)

== Additional Options

These additional options are only necessary in special cases, such as for
testing or for configuring {CPAN::Reporter} to work from behind a firewall
that restricts outbound email.

* {smtp_server = <server list>} -- one or more alternate outbound mail servers if the 
default perl.org mail servers cannot be reached (e.g. users behind a firewall);
multiple servers may be given, separated with a space (default: none)
* {email_to = <email address>} -- alternate destination for reports instead of
{cpan-testers@perl.org}; used for testing (default: none)

= FUNCTIONS

{CPAN::Reporter} provides one public function for use within CPAN.pm.
It is not imported during {use}.  Ordinary users will never need it.  

== {test()}

 CPAN::Reporter::test( $cpan_dist, $system_command );

Given a {CPAN::Distribution} object and a system command to run distribution
tests (e.g. "{make test}"), {test()} executes the command via {system()} while
teeing the output to a file.  Based on the output captured in the file,
{test()} generates and sends a [Test::Reporter] report.  It returns true if the
captured output indicates that all tests passed and false, otherwise.

= BUGS

Please report any bugs or feature using the CPAN Request Tracker.  
Bugs can be submitted by email to bug-CPAN-Reporter@rt.cpan.org or 
through the web interface at 
[http://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Reporter]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= AUTHOR

David A. Golden (DAGOLDEN)

dagolden@cpan.org

http://www.dagolden.org/

= COPYRIGHT AND LICENSE

Copyright (c) 2006 by David A. Golden

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

= DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=end wikidoc

=cut
