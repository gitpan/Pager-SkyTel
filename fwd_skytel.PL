#!/usr/local/bin/perl

#  (DO NOT EDIT fwd_skytel, instead edit fwd_skytel.PL and run make

use Config;
use File::Basename qw(&basename &dirname);
use strict;

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
my $file;
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
        if ($Config{'osname'} eq 'VMS' or
            $Config{'osname'} eq 'OS2');  # "case-forgiving"

open OUT,">$file" or die "Can't create $file: $!";
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'}

!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';

#  (DO NOT EDIT fwd_skytel, instead edit fwd_skytel.PL and run make

#
# $Id: fwd_skytel.PL,v 1.9 2002-12-16 14:32:55-05 mprewitt Exp $
#
# (C) 2001 Chelsea Networks/Marc Prewitt <mprewitt@chelsea.net>, under the GNU GPL.
# 
# fwd_skytel is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# fwd_skytel is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You may have received a copy of the GNU General Public License
# along with fwd_skytel see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#
=head1 NAME 

B<fwd_skytel> - Forwards a skytel pager to another pin, email or phone number.

=head1 DESCRIPTION

    fwd_skytel --account={pin_number} [--pass={password}] --fwd={forward_to} --date={date} [--[no]copy]

    fwd_skytel --account={pin_number} [--pass={password}] --disable

Forwards the pager specified by B<--account> to the phone, email or pin specifed
by B<--fwd>.  B<--fwd> is interpreted as an e-mail address if it contains an
@ symbol, as a phone number if it contains dashes or parenthesis as in (212) 555-1212,
or a pager pin if it contains only numbers.

Forwarding will be in effect until the date specified by B<--date>.  The
B<--date> paramater accepts any date format allowed by Date::Manip.

If B<--password> is not provided, it will be prompted for.

B<--[no]copy]> turns on or off mailbox copy.  The default is to retail a copy
of the forwarded message in your mailbox.

The second form of the command with the B<--disable> option, turns off existing
fowarding.

Requires HTTP::Cookies, LWP::UserAgent, Date::Manip and Term::ReadKey;

=head1 WHY?

We have a single pager number which is used for after hours emergencies.  In addition,
all the techs who handle these calls have their own pagers.  Instead of carrying
around two pagers when you're on call, we forward the on-call pager to the on-call
tech's pager.  We wrote a cron job which runs fwd_skytel at the beginning
of each week to foward the on-call pager to the on-call tech's pager.

Another manager found a different use for this.  He always wanted to receive a copy
of pages that went to the on-call pager.  He would forward his on-call pager to
his phone.  However, SkyTel only allows you to forward your pager for 30 days at a time.
He used this script to reforward the pager once a month with a cron job so the forwarding
never expired.

=head1 AUTHOR

Marc Prewitt, Chelsea Networks <mprewitt@chelsea.net>

=head1 TODO

Support more skytel options.

=head1 KNOWN BUGS

Windows Users: 

You need to set a TZ variable to your timezone for the date calculations 
to work correctly.  To do this, open the properties of "My Computer" 
and set a SYSTEM variable TZ to your timezone.  I suggest using the
form "EST5EDT" so you don't have to change it every 6 months when going
to or from daylight savings time.

SSL/HTTPS Notes:

If you receive the message: "501 Protocol scheme 'https' is not supported"
you do not have SSL installed and Pager::SkyTel will not be able to communicate
with the SkyTel web server.  Pager::SkyTel uses LWP::UserAgent for it's https 
support which in turn uses either IO::Socket::SSL or Crypt::SSLeay.  Therefore,
if you install one of them, things should work much better.  See the README.SSL
file which comes with LWP::UserAgent (in the libwww-perl package.)

=cut

use strict;
BEGIN { unshift @INC, "." };
use Pager::SkyTel;
use Getopt::Long;
use Term::ReadKey;

use vars '$VERSION';

$VERSION = '0.0.1';

my ($account, $pass, $fwd_pin, $date, $copy, $verbose, $disable );
$copy = 1;

GetOptions(
	"account|pin=i" => \$account,
	"copy!" => \$copy,
	"pass:s" => \$pass,
	"fwd:s" => \$fwd_pin,
	"date:s" => \$date,
        "verbose!" => \$verbose,
        "disable!" => \$disable
	) || exit Usage();

sub Usage {
    print "Usage: fwd_skytel --account={pin_number} [--pass={password}] --fwd={forward_to} --date={date} [--verbose]\n\n";
    print "Usage: fwd_skytel --account={pin_number} [--pass={password}] --disable\n";
    return 2;
}

#
#  Prompt the user for their password if it's not supplied
#  on as a command-line argument.
#
if ( !$pass ) {
    print STDERR "Password: ";
    ReadMode('noecho');
    $pass = ReadLine(0);
    ReadMode('normal');
    chomp($pass);
    print STDERR "\n";
}

Pager::SkyTel::setDebug(1) if $verbose;

my $sky = Pager::SkyTel->new( $account, $pass );

if ($disable) {
    if ( $fwd_pin || $date ) {
        print STDERR "Cannot use --fwd or --date option with --disable option\n";
        exit Usage();
    }
    $sky->disable_forward_all() || die "Unable to disable forwarding.\n    " . $sky->getError;
} else {
    if ( $disable ) {
        print STDERR "Cannot use --disable option with --fwd option\n";
        exit Usage();
    }
    if ( $copy ) {
        $copy = Pager::SkyTel::COPY_ENABLE;
    } else {
        $copy = Pager::SkyTel::COPY_DISABLE;
    }

    $sky->forward_all( $fwd_pin, $date, $copy ) || die "Unable to forward.\n    " . $sky->getError;
}
exit 0;

END {
    #  Reset the terminal if we die in the middle of password entry.
    ReadMode('normal');
}


!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
