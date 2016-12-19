#!/usr/bin/perl

use CGI qw /:standard/; 
use LWP::UserAgent; 
use strict; 
use Data::Dumper;
use URI::Escape;
use HTML::Entities;

my $q = CGI->new();

my $output = "text";
my $endpoint = "http://localhost:8080/sparql/";
my $limit = 1000;


# filter (regex(str(?label), '__REGEX__', 'i') || regex(str(?altLabel), '__REGEX__', 'i')) .
# limit 20

my $regex = $q->param('term') || 0;
my $exact = $q->param('exact') || 0;
my $list_limit = $q->param('limit') || 20;
my $all = $q->param('all') || 0;
my $thes = $q->param('thes') || 0;
my $source = $q->param('source') || 0;

my $all_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?label ?altLabel WHERE {
 ?term skos:prefLabel ?label .
 optional { ?term skos:altLabel ?altLabel . }
}
order by strlen(?label) ?label

EOQ

my $thes_query = <<EOTQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?label ?altLabel ?term WHERE { graph <http://data.iop.org/thesaurus/$thes> {
 ?term skos:prefLabel ?label .
 optional { ?term skos:altLabel ?altLabel . }
}
}
order by strlen(?label) ?label

EOTQ

#$regex =~ s|(['"\/])|\\$1|g;
$regex =~ s|\\\\|\\|g;
# print STDERR "$regex\n"; # if $regex =~ m/['"\/]/;
my $query = $thes ? $thes_query : $all_query;
if ($regex) {
	$query =~ s/__REGEX__/$regex/g;
	my $rdf_out = &sparqlQuery($query, $endpoint, $output);
	my @terms = split("[\n\r]",$rdf_out);
	$rdf_out = "[";
	my $c;
	foreach (@terms) {
		next if m/\?label/;
		next if m/^\s*$/;
		next unless m/\Q$regex/i;
		if ($exact) {
			# print STDERR "exact: $_\n";
			next unless m/^"\Q$regex"/i;
		}
		my ($term, $synonym, $s) = split ("\t", $_);
		# s/([^\t]+).+/$1/;
		unless ($rdf_out =~ m/$term/) {
			$rdf_out .= "$term,";
			$rdf_out .= "$s," if $source; 
		}
		$c++;
		last if $c >= $list_limit;
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
		next if m/\?label/;
		next if m/^\s*$/;
		my ($term, $synonym, $s) = split ("\t", $_);
		# s/([^\t]+).+/$1/;
		unless ($rdf_out =~ m/$term/) {
			$rdf_out .= "$term,";
			$rdf_out .= "$s," if $source; 
		}
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
