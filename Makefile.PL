#  See lib/ExtUtils/MakeMaker.pm for details of how to influence
#  the contents of the Makefile that is written.
#
# $Id: Makefile.PL,v 1.5 2001-11-20 17:04:46-05 mprewitt Exp $
#
use ExtUtils::MakeMaker;
use strict;

my $version = "0.1.2";

WriteMakefile(
    NAME        => 'Pager',
    DISTNAME    => 'Pager-SkyTel',
    VERSION     => $version,
    dist        => { COMPRESS=>'gzip -9f', SUFFIX => 'gz',
                     ZIP=>'/usr/bin/zip',ZIPFLAGS=>'-rl'},
    INST_SCRIPT => './blib/bin',
    PL_FILES    => { 'fwd_skytel.PL'=> 'fwd_skytel' },
    EXE_FILES   => [ 'fwd_skytel' ],
    PREREQ_PM   => { 'HTTP::Cookies' => 0,
                     'LWP::UserAgent' => 0,
                     'URI' => 0,
                     'Date::Manip' => 0,
                     'Term::ReadKey' => 0 }
);

require Date::Manip;
eval {
    Date::Manip::Date_TimeZone()
};

if ($@) {
    print "\n\nWARNING:\n\n";
    print "You must set your timezone variable for this library to work correctly.\n";
    print "If you are using Windows, open the properties of \"My Computer\" and set\n";
    print "a SYSTEM variable TZ to your timezone.  I suggest using the form \"EST5EDT\"\n";
    print "so you don't have to change it every 6 months when going to or from daylight\n";
    print "savings time.\n";
}
