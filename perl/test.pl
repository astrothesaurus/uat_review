#! /usr/bin/perl

use strict;

# use CGI qw /:standard/; 
# use LWP::UserAgent; 
# use Data::Dumper;
# use URI::Escape;
# use HTML::Entities;

print <<END_OF_HTML;
Status: 200 OK
Content-type: text/html

<HTML>
<HEAD><TITLE>Everything is going to be OK</TITLE></HEAD>
<BODY>
  <H1>Error</H1>
  <P>Perl works</P>
</BODY>
</HTML>
END_OF_HTML
