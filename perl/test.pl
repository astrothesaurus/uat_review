#! /usr/bin/perl

use strict;

print <<END_OF_HTML;
Status: 200 Bad Request
Content-type: text/html

<HTML>
<HEAD><TITLE>400 Bad Request</TITLE></HEAD>
<BODY>
  <H1>Error</H1>
  <P>Perl works</P>
</BODY>
</HTML>
END_OF_HTML