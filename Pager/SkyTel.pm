#
# $Id: SkyTel.pm,v 1.8 2001-11-20 16:51:34-05 mprewitt Exp $
# $Source: /usr/local/src/siteperl/SkyTel/0.1/Pager/RCS/SkyTel.pm,v $
# $Locker:  $
#
# (C) 2001 Chelsea Networks/Marc Prewitt <mprewitt@chelsea.net>, under the GNU GPL.
# 
# SkyTel.pm is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# SkyTel.pm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You may have received a copy of the GNU General Public License
# along with this program see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#
package Pager::SkyTel;

use strict;

=head1 NAME

B<Skytel> - SkyTel utilities
    
    CONCRETE CLASS

=head1 SYNOPSIS 

    use SkyTel;

    $skytel = SkyTel->new($username, $password);
    $success = $skytel->forward_text( $pin, $date, $autocopy );
    $success = $skytel->forward_voice( $pin, $date, $autocopy );
    $success = $skytel->forward_all( $pin, $date, $autocopy );
    if ( !$success ) { print STDERR $skytel->getError }

=head1 DESCRIPTION

Provides utilities to control your skytel account like
forwarding text/voice messages.

Requires HTTP::Cookies, LWP::UserAgent, URI and Date::Manip.

=head1 AUTHOR

Marc Prewitt <mprewitt@chelsea.net>

=head1 SEE ALSO

L<HTTP::Cookies>
L<LWP::UserAgent>
L<Date::Manip>
L<URI>

=head1 TODO

Create disable forwarding method.

Create get forwarding info method.

Disable forwarding before trying to forward it? (doesn't seem like it's needed)

x Pin forwarding is not quite working.  Keeps saying it's already forwarded
(try a different pin). Works fine.  Doesn't work if the other pin is already 
forwarded.

x Create forward_voice methods and forward_all

x Need to handle error codes from HTTP::Response better

x Add autocopy option to forward (autocopy = Enable | Disable)

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

use HTTP::Cookies;
use LWP::UserAgent;
use URI;
use Date::Manip;
use Carp;

use vars '$VERSION';

$VERSION = (qw$Revision: 1.8 $)[1];
my $DEBUG = 0;
my $ERROR;

=head1 PUBLIC CONSTANTS

=head2 SkyTel::TEXT

Used to indicate the type of forwarding is text.

=cut
use constant TEXT => 'Text';

=head2 SkyTel::VOICE

Used to indicate the type of forwarding is voice.

=cut
use constant VOICE => 'Voice';

=head2 SkyTel::COPY_ENABLE

Used to enable autocopy

=cut
use constant COPY_ENABLE => 'Enable';

=head2 SkyTel::COPY_DISABLE

Used to disable autocopy

=cut
use constant COPY_DISABLE => 'Disable';

=head1 PUBLIC METHODS

=head2 new

    my $skytel = SkyTel->new( $username, $password );

Creates a new SkyTel object.

B<METHOD TYPE:> Constructor

B<PARAMETERS:> 

$username - The PIN number of your skytel account.
$password - The password for your account

B<RETURN VALUES:> a new SkyTel object or undef if could not
login with username/password.

=cut
sub new {
    my $type = shift;
    my $username = shift;
    my $password = shift;
    my $self = {};

    bless $self, ref $type || $type;
    $self->{username} = $username;
    $self->{password} = $password;
    $self->{cookies} = HTTP::Cookies->new;
    $self->{ua} = LWP::UserAgent->new;

    return $self;
}

=head2 getError

    $errorString = $skytel->getError;

Returns the error message associated with the last error
condition for the object.

=cut
sub getError {
    my $self = shift;
    return $self->{error};
}

=head2 forward_all

    my $success = $skytel->forward_all( $pin );

Forwards this account's text and messages to the specified account.

B<METHOD TYPE:> Instance

B<PARAMETERS:> 

    $pin - Forwarding account pin number
    $date - Date that forwarding expires (max=1 month after today)
    $autocopy - COPY_ENABLE | COPY_DISABLE

B<RETURN VALUES:> 1 if successfully forwarded in, undef if failure.

=cut
sub forward_all {
    my $self = shift;
    my $forward_to = shift;
    my $date_str = shift;
    my $autocopy = shift;
    my $date;

    unless ($date = Date::Manip::ParseDate($date_str)) {
	carp "Unable to parse date: '$date_str'\n";
	return undef;
    }

    return $self->forward_text( $forward_to, $date, $autocopy ) && 
        $self->forward_voice( $forward_to, $date, $autocopy );
}

=head2 forward_text

    my $success = $skytel->forward_text( $pin );

Forwards this account's text messages to the specified account.

B<METHOD TYPE:> Instance

B<PARAMETERS:> 

    $pin - Forwarding account pin number
    $date - Date that forwarding expires (max=1 month after today)
    $autocopy - COPY_ENABLE | COPY_DISABLE

B<RETURN VALUES:> 1 if successfully forwarded in, undef if failure.

=cut
sub forward_text {
    my $self = shift;
    my $forward_to = shift;
    my $date_str = shift;
    my $autocopy = shift;
    my $date;

    print STDERR "Forwarding text messagse\n" if $DEBUG;
    unless ($date = Date::Manip::ParseDate($date_str)) {
	carp "Unable to parse date: '$date_str'\n";
	return undef;
    }

    return $self->_forward( __fwd_text_url($forward_to, $date, $autocopy) );
}

=head2 forward_voice

    my $success = $skytel->forward_voice( $pin );

Forwards this account's voice messages to the specified account.

B<METHOD TYPE:> Instance

B<PARAMETERS:> 

    $pin - Forwarding account pin number
    $date - Date that forwarding expires (max=1 month after today)
    $autocopy - COPY_ENABLE | COPY_DISABLE

B<RETURN VALUES:> 1 if successfully forwarded in, undef if failure.

=cut
sub forward_voice {
    my $self = shift;
    my $forward_to = shift;
    my $date_str = shift;
    my $autocopy = shift;
    my $date;

    print STDERR "Forwarding voice messages\n" if $DEBUG;
    unless ($date = Date::Manip::ParseDate($date_str)) {
	carp "Unable to parse date: '$date_str'\n";
	return undef;
    }

    return $self->_forward( __fwd_voice_url($forward_to, $date, $autocopy) );
}

=head1 setDebug

    SkyTel::setDebug(1)  #on

    SkyTel::setDebug(0)  #off

Turn on of off debugging.

=cut
sub setDebug {
    my $val = shift;

    if ($val) {
        $DEBUG = 1;
    } else {
        $DEBUG = undef;
    }
}

=head1 PROTECTED METHODS

=head2 _forward

    $success = $skytel->_forward( $forward_url )

Submits the $forward_url and returns the result.
Uses the currently set cookies for login state
and updates the cookies with the new server response.

=cut
sub _forward {
    my $self = shift;
    my $forward_url = shift;

    $self->_login || return $self->_setError("Unable to login to SkyTel:\n    $self->{error}\n");

    print STDERR "Sending forward request...\n" if $DEBUG;
    return $self->__send_request( new URI( $forward_url ) );
}

=head2 _setError

    $skytel->_setError( $error_message )

Sets an error for this object.

B<RETURNS>: undef

=cut
sub _setError {
    my $self = shift;
    my $error = shift;

    $self->{error} = $error;
    return undef;
}

=head2 _login

    my $success = $skytel->_login;

Logs into the skytel web server.  If error, sets $self->{error}
with error message.

B<METHOD TYPE:> Instance

B<PARAMETERS:> None

B<RETURN VALUES:> 1 if successfully logged in, undef if failure.

=cut
sub _login {
    my $self = shift;

    if ( $self->{logged_in} ) {
	print STDERR "Login NOP, already logged in\n" if $DEBUG;
	return 1;
    }

    print STDERR "Logging in...\n" if $DEBUG;

    return $self->{login} = $self->__send_request( 
            new URI( __login_url( $self->{username}, $self->{password} )));
}

=begin PRIVATE

PRIVATE METHODS

=begin private __www

    $www = SkyTel->__www();

Returns the base URL of the SkyTel web server.

=cut
sub __www {
    return 'https://www.skytel.com';
}

=begin private __login_url

    $url = SkyTel->__login_url( $pin, $passcode );

B<METHOD TYPE:> Class

B<PARAMETERS:> 

    $pin - account number
    $passcode - password for account

B<RETURN VALUES:> The login URL

=cut
sub __login_url {
    my $pin = shift;
    my $code = shift;

    print "Pin: $pin\nCode: $code\n" if $DEBUG;

    return __www() . '/servlet/CSLogin?Login=LoginForm&RedirectURL=&Submit=Action&' .
	    "Pin=${pin}&Code=${code}";
}


=begin private __fwd_text_url

    $forward_text_url = __fwd_text_url( $forward_to, $date, $autocopy )

Returns the URL to forward the current account to $forward_to until
the date specified by $date.  $forward_to can be a pin, e-mail or phone number.
A pin has the form 8883894020 or 3894020, an e-mail has an @ in it and
a phone number looks likt (212)-417-8276 or 212-417-8276.

=cut
sub __fwd_text_url {
    my $fwd = shift;
    my $date = shift;
    my $autocopy = shift;

    $fwd =~ s/\s+//g;

    if ( $fwd =~ /^\d+$/ ) {
	return __fwd_url($date, TEXT, $autocopy) . __fwd_pager( $fwd, $date );
    } elsif ( $fwd =~ /\@/ ) {
	return __fwd_url($date, TEXT, $autocopy) . __fwd_email( $fwd, $date );
    } else {
	return __fwd_url($date, TEXT, $autocopy) . __fwd_phone( $fwd, $date );
    }
}

=begin private __fwd_voice_url

    $forward_voice_url = __fwd_voice_url( $forward_to, $date, $autocopy )

Returns the URL to forward the current account to $forward_to until
the date specified by $date.  $forward_to can be a pin, e-mail or phone number.
A pin has the form 8883894020 or 3894020, an e-mail has an @ in it and
a phone number looks like (212)-417-8276 or 212-417-8276.

=cut
sub __fwd_voice_url {
    my $fwd = shift;
    my $date = shift;
    my $autocopy = shift;

    $fwd =~ s/\s+//g;

    if ( $fwd =~ /^\d+$/ ) {
	return __fwd_url($date, VOICE, $autocopy) . __fwd_pager( $fwd, $date );
    } elsif ( $fwd =~ /\@/ ) {
	return __fwd_url($date, VOICE, $autocopy) . __fwd_email( $fwd, $date );
    } else {
	return __fwd_url($date, VOICE, $autocopy) . __fwd_phone( $fwd, $date );
    }
}

=begin private __fwd_url

    $forward_page = __fwd_url( $date, $type, $autocopy );

Returns the base of the URL for the page which forwards your text messages.

$date - Date Date::Manip object
$type - TEXT | VOICE
$autocopy - COPY_ENABLE | COPY_DISABLE

=cut
sub __fwd_url {
    my $date = shift;
    my $type = shift;
    my $autocopy = shift || COPY_ENABLE;

    my $hour = Date::Manip::UnixDate($date, "%i");  $hour =~ s/\s+//g;
    my $min  = Date::Manip::UnixDate($date, "%M");  $min =~ s/\s+//g;
    my $ampm = Date::Manip::UnixDate($date, "%p");
    my $month = Date::Manip::UnixDate($date, "%f"); $month =~ s/\s+//g;
    my $year  = Date::Manip::UnixDate($date, "%Y");
    my $day   = Date::Manip::UnixDate($date, "%e"); $day =~ s/\s+//g;

    my $submit;
    if ( $type eq TEXT ) {
	$submit = "B4";
    } else {
	$submit = "B5";
    }

    print STDERR "Fwd Date: $hour:$min$ampm $month/$day/$year\n" if $DEBUG;
    return __www() . "/servlet/CSChange${type}Forward?Submit=${submit}&${type}ForwardAction=Enable&" .
	"exphour=${hour}&expmin=${min}&AMPM=${ampm}&expday=${day}&expmonth=${month}&expyear=${year}&" .
	"autocopy=${autocopy}&" .
	'ForwardAddr=';
}

=begin private __fwd_pager

    $forward_to_pager = __fwd_pager( $forwarding_pin )

Returns the URL paramaters used to forward text messages to the specifed pin.

=cut
sub __fwd_pager {
    my $pin = shift;

    print STDERR "FWD Pager: $pin\n" if $DEBUG;

    return "Pin&pintext=$pin";
}

=begin private __fwd_email

    $forward_to_email = __fwd_email ( $email );

Returns the URL used to forward text messages to the specified email address.

=cut
sub __fwd_email {
    my $email = shift;

    print STDERR "FWD EMail: $email\n" if $DEBUG;

    return "Email&emailtext=$email";
}

=begin private __fwd_phone

    $forward_to_phone = $__fwd_phone( $phone_number );

Returns the URL used to forward text messages to the specified phone number.

=cut
sub __fwd_phone {
    my $phone = shift;

    print STDERR "FWD phone: $phone\n" if $DEBUG;

    my ( $area_code, $prefix, $suffix ) = $phone =~ m/\(?(\d{3})\)?-?(\d{3})-?(\d{4})/;
    
    return "Phone&forwardtext1=${area_code}&forwardtext2=${prefix}&forwardtext3=${suffix}";
}

=begin private __send_request

    $success = $skytel->__send_request($uri)

$uri - URI object

Submits the uri, handles redirects and embedded error messages.

=cut
sub __send_request {
    my $self = shift;
    my $uri = shift;

    my $request = HTTP::Request->new('POST', $uri);

    $self->{cookies}->add_cookie_header($request) if $self->{cookies};

    my $response = $self->{ua}->request($request);
    if ($response->is_error) {
	return $self->_setError( $response->error_as_HTML );
    } elsif ($response->is_redirect) {
	$self->{cookies}->extract_cookies($response);

        my $location = $response->headers->header('location');
        my $new_uri;
        # Add the server/protocol to $location if it isn't there
        if ( $location =~ m|^https?://|i ) {
            $new_uri = new URI( $location );
        } else {
            $new_uri = $uri->clone();
            $new_uri->path_query($location);
        }
        return $self->__send_request( $new_uri );
    } else {
	$self->{cookies}->extract_cookies($response);

	my $content = $response->content;
	
	if ($content =~ m/.*ERROR:\s*([^<]*)<.*/s) {
	    return $self->_setError($1);
	}
	return 1;
    }
    print STDERR $response->content() if $DEBUG;
    return 1;
}

1;
