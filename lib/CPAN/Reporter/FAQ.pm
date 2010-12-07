#
# This file is part of CPAN-Reporter
#
# This software is Copyright (c) 2006 by David Golden.
#
# This is free software, licensed under:
#
#   The Apache License, Version 2.0, January 2004
#
use strict; # make CPANTS happy
package CPAN::Reporter::FAQ;
BEGIN {
  $CPAN::Reporter::FAQ::VERSION = '1.18_06';
}
# ABSTRACT: Answers and tips for using CPAN::Reporter

# Not really a .pm file, but holds wikidoc which will be
# turned into .pod by the Build.PL
1;


=pod

=head1 NAME

CPAN::Reporter::FAQ - Answers and tips for using CPAN::Reporter

=head1 VERSION

version 1.18_06

=head1 REPORT GRADES

=head2 Why did I receive a report? 

Historically, CPAN Testers was designed to have each tester send a copy of
reports to authors.  This philosophy changed in September 2008 and CPAN Testers
tools were updated to no longer copy authors, but some testers may still be
using an older versions.

=head2 Why was a report sent if a prerequisite is missing?

As of CPAN::Reporter 0.46, FAIL and UNKNOWN reports with unsatisfied 
prerequisites are discarded.  Earlier versions may have sent these reports 
out by mistake as either an NA or UNKNOWN report.

PASS reports are not discarded because it may be useful to know when tests
passed despite a missing prerequisite.  NA reports are sent because information
about the lack of support for a platform is relevant regardless of
prerequisites.

=head1 SENDING REPORTS

=head2 Why did I get an error sending a test report?

Test reports are sent via ordinary email.  The most common reason for errors
sending a report is that many Internet Service Providers (ISP's) will block
outbound SMTP (email) connections as part of their efforts to fight spam.
Instead, email must be routed to the ISP's outbound mail servers, which will
relay the email to the intended destination.

You can configure CPAN::Reporter to use a specific outbound email server 
with the C<<< smtp_server >>> configuration option.

  smtp_server = mail.some-isp.com

In at least one case, an ISP has blocked outbound email unless the 
"from" address was the assigned email address from that ISP.

=head2 Why didn't my test report show up on CPAN Testers?

CPAN Testers uses a mailing list to collect test reports.  If the email
address you set in C<<< email_from >>> is subscribed to the list, your emails
will be automatically processed.  Otherwise, test reports will be held 
until manually reviewed and approved.  

Subscribing an account to the cpan-testers list is as easy as sending a blank
email to cpan-testers-subscribe@perl.org and replying to the confirmation
email.

There is a delay between the time emails appear on the mailing list and the
time they appear on the CPAN Testers website. There is a further delay before
summary statistics appear on search.cpan.org.

If your email address is subscribed to the list but your test reports are still
not showing up, your outbound email may have been silently blocked by your
ISP.  See the question above about errors sending reports.

=head2 Why don't you support sending reports via HTTP or authenticated SMTP?

We do!  See the C<<< transport >>> option in L<CPAN::Reporter::Config>.

=head1 CPAN TESTERS

=head2 Where can I find out more about CPAN Testers?

A good place to start is the CPAN Testers Wiki: 
L<http://wiki.cpantesters.org/>

=head2 Where can I find statistics about reports sent to CPAN Testers?

CPAN Testers statistics are compiled at L<http://stats.cpantesters.org/>

=head2 How do I make sure I get credit for my test reports?

To get credit in the statistics, use the same email address wherever 
you run tests.

For example, if you are a CPAN author, use your PAUSEID email address.

  email_from = pauseid@cpan.org

Otherwise, you should use a consistent "Full Name" as part of your 
email address in the C<<< email_from >>> option.

  email_from = "John Doe" <john.doe@example.com> 

=head1 SEE ALSO

=over

=item *

L<CPAN::Testers>

=item *

L<CPAN::Reporter>

=item *

L<Test::Reporter>

=back

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2006 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut


__END__
