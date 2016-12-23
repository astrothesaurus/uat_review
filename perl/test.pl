#! /usr/bin/perl

use strict;

use CGI qw /:standard/; 
use Cwd;
use Data::Dumper;
use Encode qw(decode encode);
use HTML::Entities;
use LWP::Simple qw/get/;
use LWP::UserAgent;
use MIME::Lite;
use POSIX;
use URI::Escape;


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
