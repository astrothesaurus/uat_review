#!/usr/bin/perl

use CGI qw /:standard/; 
use LWP::UserAgent; 
use strict; 
# use Data::Dumper;
use URI::Escape;
# use HTML::Entities;

my $q = CGI->new();
my $base_url = $q->url(-base => 1);

my $output = "text";
my $endpoint = "http://4store:8080/sparql/";
my $limit = 1000;

my $query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?doi ?author ?title WHERE { graph <http://data.iop.org/uat_review> {
 ?doi ioprdf:hasAuthor ?author .
 ?doi ioprdf:hasTitle ?title .
 }
}
order by ?doi

EOQ

# filter (regex(str(?label), '__REGEX__', 'i') || regex(str(?altLabel), '__REGEX__', 'i')) .
# limit 20

my $regex = $q->param('term') || 0;
my $exact = $q->param('exact') || 0;
my $list_limit = $q->param('limit') || 200;
my $all = $q->param('all') || 20;
my $doi = $q->param('doi') || 0;

#$regex =~ s|(['"\/])|\\$1|g;
$regex =~ s|\\\\|\\|g;
# print STDERR "$regex\n"; # if $regex =~ m/['"\/]/;
if ($regex) {
	# $query =~ s/__REGEX__/$regex/g;
	my $rdf_out = &sparqlQuery($query, $endpoint, $output);
	my @terms = split("[\n\r]",$rdf_out);
	# print STDERR "UAT query: " . scalar(@terms) . " term matches found\n";
	$rdf_out = "[";
	my $c;
	foreach my $term (@terms) {
		next if $term =~ m/\?label/;
		next if $term =~ m/^\s*$/;
		next unless $term =~ m/\Q$regex/i;
		if ($exact) {
			# print STDERR "exact: $_\n";
			next unless $term =~ m/"\Q$regex"/i;
		}
		elsif ($doi) {
			$term =~ s/\t.+//gs;
			$term =~s|<http://dx\.doi\.org/([^>]+).+|"$1"|;
			$rdf_out .= "$term," unless $rdf_out =~ m/$term/;
			$c++;
		}
		else{
			my @parts = split("\t", $term);
			foreach my $part (@parts) {
				next unless $part =~ m/\Q$regex/i;
				$part =~ s|[\n\r]| |gs;
				$part =~ s|[<>]||g;
				$part =~ s|http://dx.doi.org/||gs;
				$part = "\"" . $part . "\"" unless $part =~m|^".*"$|;
				print STDERR "\n$part\n$rdf_out\n";
				unless ($rdf_out =~ m/\Q$part/s) {
					$c++;
					$rdf_out .= "$part,";
				}
			}
		}
		# print STDERR "$c matches found\n";
		last if $c > $list_limit;
	}
	$rdf_out =~ s/,$//;
	$rdf_out .= "]\n";
	unless ($rdf_out =~ m/\[\]/) {
		print $q->header(-type => 'application/json', -charset => 'utf-8');
		print $rdf_out;
		# print STDERR $rdf_out;
	}
	else {
		print "Status: 404 Not Found\n";
		print "\n";
		exit;
	}
}
elsif ($all) {
	$query =~ s/__REGEX__/$regex/g;
	my $rdf_out = &sparqlQuery($query, $endpoint, $output);
	my @terms = split("[\n\r]",$rdf_out);
	$rdf_out = "[";
	foreach (@terms) {
		next if m/\?/;
		next if m/^\s*$/;
		s/([^\t]+).+/$1/;
		$_ = "\"" . $_ . "\"" unless $_ =~m|^".*"$|;
		$rdf_out .= "$_," unless $rdf_out =~ m/$_/;
	}
	$rdf_out =~ s/,$//;
	$rdf_out .= "]\n";
	unless ($rdf_out =~ m/\[\]/) {
		print $q->header(-type => 'application/json', -charset => 'utf-8');
		print $rdf_out;
		# print STDERR $rdf_out;
	}
	else {
		print "Status: 404 Not Found\n";
		print "\n";
		exit;
	}
}
else {
	print <<END_OF_HTML;
Status: 400 Bad Request
Content-type: text/html

<HTML>
<HEAD><TITLE>400 Bad Request</TITLE></HEAD>
<BODY>
  <H1>Error</H1>
  <P>No term given for search</P>
</BODY>
</HTML>
END_OF_HTML
	exit;
}

sub sparqlQuery() {
	my $query=shift;
	my $baseURL=shift;
	my $format=shift;
        my %params=(
                "default-graph" => "", "query" => $query,
                "debug" => "on", "timeout" => "30000", "output" => $format,
				"soft-limit" => $limit
        );
        my @fragments=();
        foreach my $k (keys %params) {
                my $fragment="$k=".CGI::escape($params{$k});
                push(@fragments,$fragment);
        }
        $query=join("&", @fragments);
        my $sparqlURL="${baseURL}?$query";
        my $ua = LWP::UserAgent->new;
        $ua->agent("MyApp/0.1 ");
        my $req = HTTP::Request->new(GET => $sparqlURL);
        my $res = $ua->request($req);
        my $str=$res->content;
        return $str;
}
