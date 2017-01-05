#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use LWP::UserAgent;
use URI::Escape;

my $ua = LWP::UserAgent->new();
$ua->agent('ThesTermChecker/' . $ua->_agent);
$ua->from('michael.roberts@iop.org');


#
# SPARQL config & query definitions
# 

my $output = "text";
my $endpoint = "http://4store:8080/sparql/";
my $limit = -1;
	
my $stats_query = <<EOQ;
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	PREFIX ioprdf: <http://rdf.iop.org/>
	PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
	PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

	SELECT DISTINCT ?label ?status (count(?status) as ?c) WHERE 
	 {
	  graph <http://data.iop.org/uat_review> {
	  ?termID ioprdf:hasStatus ?status .
	  ?termID ioprdf:hasTermLabel ?label .
	  ?doi ioprdf:hasAnnotation ?termID .
	  ?review ioprdf:hasDOI ?doi .
	 }
	}
	group by ?label ?status
	order by ?label ?status
EOQ

my $q = CGI->new();

unless ($q->param) {

	print $q->header(-type => 'text/html', -charset => 'UTF-8');
	print $q->start_html(
		-title=>'UAT Annotation feedback data dump', 
		-style=>[
			{'src'=>'/css/bootstrap.min.css'}, 
			{'src'=>'/css/bootstrap-theme.min.css'}, 
			{'src'=>'http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css'}, 
			{'src'=>'/css/custom.css'}
			], 
		-script=>[
			{-type=>'text/javascript', 'src'=>'http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js'},
			{-type=>'text/javascript', 'src'=>'http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js'},
			{-type=>'text/javascript', 'src'=>'/js/bootstrap.min.js'},
			{-type=>'text/javascript', 'src'=>'/js/css3-mediaqueries.js'}
			],
		-meta=>{'X-UA-Compatible'=>'IE=edge'}
		
		);
}
elsif ($q->param('csv')) {
	# get term stats data to CSV
	# what's a sensible format?
	my $data = &sparqlQuery($stats_query, $endpoint, $output, $limit);
	my @data = split("[\n\r]", $data);
	shift @data;
	my $content = join("\t", "Term", "Status", "Count");
	$content .= "$_\n" foreach (@data);
	print "Content-type: text/plain\n" .
			  "Content-Disposition: attachment; filename=\"uat_feedback.txt\"\n\n";
	print STDOUT $content;
}
elsif ($q->param('nt')) {
	# get a data dump of the whole database to NT
	
	my $content;
	print "Content-type: application/rdf+xml\n" .
			  "Content-Disposition: attachment; filename=\"uat_feedback.nt\"\n\n";
	print STDOUT $content;
}

sub sparqlQuery() {
	my $query=shift;
	my $baseURL=shift;
	my $format=shift;
	my $limit=shift;
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
	my $req = HTTP::Request->new(GET => $sparqlURL);
	my $res = $ua->request($req);
	my $str=$res->content;
	return $str;
}