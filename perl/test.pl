#! /usr/bin/perl

use strict;

use POSIX;
use CGI qw /:standard/; 
use Cwd;
# use Data::Dumper;
use Encode qw(decode encode);
# use HTML::Entities;
# use LWP::Simple qw/get/;
use LWP::UserAgent;
use MIME::Lite;
use URI::Escape;

my $ua=LWP::UserAgent->new();

sub get_http {
	my $url = shift;
	my $response = $ua->get($url);
	if ($response->is_success()) {
		return $response->content;
	}
	else {
		return 0;
	}
}

# my $result = get_http("http://4store:8080/status/");
my $result = get_http("http://localhost/cgi-bin/uat_query.pl?term=cho");

if ($result) {
my $timestamp = strftime("%Y%m%d%H%M%S", localtime(time)) . "_" . int(rand(9999));
my $subject = "Feedback for article received ($timestamp)";
my $message = "Test message";

my $from = "uat_feedback\@iop.org";
my $doi = "Null";
	&email_alert($doi, 
		$message,
		$subject,
		"michael.roberts\@iop.org",
		$from
		);


print <<END_OF_HTML;
Status: 200 OK
Content-type: text/html

<HTML>
<HEAD><TITLE>We've got intercommunication</TITLE></HEAD>
<BODY>
  <H1>All is good</H1>
  <P>Perl works</P>
  <p>$result</p>
  <p>$timestamp</p>
</BODY>
</HTML>
END_OF_HTML
}

else {
print <<END_OF_HTML;
Status: 200 OK
Content-type: text/html

<HTML>
<HEAD><TITLE>Everything is going to be OK</TITLE></HEAD>
<BODY>
  <H1>All is good</H1>
  <P>Perl works</P>
  <ul>
  <li>use CGI qw /:standard/; </li>
  <li>use Cwd;</li>
  <li>use Data::Dumper;</li>
  <li>use Encode qw(decode encode);</li>
  <li>use HTML::Entities;</li>
  <li>use LWP::Simple qw/get/;</li>
  <li>use LWP::UserAgent;</li>
  <li>use MIME::Lite;</li>
  <li>use POSIX;</li>
  <li>use URI::Escape;</li>
  </ul>
</BODY>
</HTML>
END_OF_HTML
}


sub email_alert {
	my ($id, $feedback, $subject, $to, $from) = @_;

	my $message = "$feedback";

	my $msg = MIME::Lite->new(
					 From     => $from,
					 To       => $to,
					 Subject  => $subject,
					 Data     => $message
					 );

	$msg->send;
	print "<!-- email sent -->\n";
}