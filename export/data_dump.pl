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

my $all_query = <<EOQ;
Select distinct ?s ?p ?o where {
	graph <http://data.iop.org/uat_review> {
		?s ?p ?o .
	}
}
order by ?s ?p ?o
EOQ

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

my $comments_query = <<EOQ;
	PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	PREFIX ioprdf: <http://rdf.iop.org/>
	PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
	PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

	SELECT DISTINCT ?doi ?email ?comment ?dateTime WHERE 
	 {
	  graph <http://data.iop.org/uat_review> {
	  ?review ioprdf:hasDOI ?doi .
	  ?email ioprdf:hasDoneReview ?review .
	  ?review ioprdf:hasComment ?comment .
	  ?review ioprdf:hasDateTime ?dateTime .
	 }
	}
	order by ?dateTime ?doi
EOQ

my $year_month_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

SELECT ?year ?month (count(distinct ?d) as ?c) WHERE {
 graph <http://data.iop.org/uat_review> {
 ?p ioprdf:hasDoneReview ?r .
 ?r ioprdf:hasDOI ?d .
 ?r ioprdf:hasDateTime ?date .
 bind (year(?date) as ?year)
 bind (month(?date) as ?month)
}
}
group by ?year ?month
order by ?year ?month
EOQ
my $q = CGI->new();
my $self_url = $q->self_url;

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
	print "<div class=\"container\">\n";
	print $q->p({-class=>'btn btn-success btn-lg mt-1'}, a({-href=>"$self_url?csv=1"}, "Get term stats CSV file")) . "\n";
	print $q->p({-class=>'btn btn-success btn-lg mt-1'}, a({-href=>"$self_url?comments=1"}, "Get comments CSV file")) . "\n";
	print $q->p({-class=>'btn btn-success btn-lg mt-1'}, a({-href=>"$self_url?nt=1"}, "Get SPARQL dump of entire graph")) . "\n";
	my $data = sparqlQuery($year_month_query, $endpoint, $output, $limit);
	
	my @data = split ("[\n\r]", $data);
	shift @data;
	if (scalar(@data) >= 1) {
		print "<div class=\"row\">\n";
		print $q->span({-class=>'col-sm-2'}, "Year") . "\n";		
		print $q->span({-class=>'col-sm-2'}, "Month") . "\n";		
		print $q->span({-class=>'col-sm-2'}, "Count") . "\n";			
		print "</div>\n";
		foreach (@data) {
			my ($year, $month, $count) = split("\t", $_);
			print "<div class=\"row\">\n";
			
			print $q->span({-class=>'col-sm-2'}, $year) . "\n";		
			print $q->span({-class=>'col-sm-2'}, $month) . "\n";		
			print $q->span({-class=>'col-sm-2'}, $count) . "\n";		
			
			print "</div>\n";
		}
	}
	else {
		print $q->p("No reviews received yet.") . "\n";
	}
	print "</div>\n";
	print $q->end_html;
}
elsif ($q->param('csv')) {
	# get term stats data to CSV
	
	my $data = &sparqlQuery($stats_query, $endpoint, $output, $limit);
	my @data = split("[\n\r]", $data);
	shift @data;
	my $content = join("\t", "Term", "Status", "Count") . "\n";
	$content .= "$_\n" foreach (@data);
	print "Content-type: text/plain\n" .
			  "Content-Disposition: attachment; filename=\"uat_feedback.txt\"\n\n";
	print STDOUT $content;
}
elsif ($q->param('nt')) {
	# get a data dump of the whole database to NT
	my $data = &sparqlQuery($all_query, $endpoint, "sparql", $limit);
	my $content;
	my @results = $data =~ m|(<result>.*?</result>)|gs;
	my ($s, $p, $o);
	foreach my $result (@results) {
		#	<binding name="s"><uri>http://dx.doi.org/10.3847/0004-637X/816/1/9/term/0007</uri></binding>
		#	<binding name="p"><uri>http://rdf.iop.org/hasStatus</uri></binding>
		#	<binding name="o"><literal>Pending</literal></binding>
		$result =~ s|<uri>|<|gs;
		$result =~ s|</uri>|>|gs;
		$result =~ s|<literal datatype="http://www.w3.org/2001/XMLSchema#dateTime">(.*?)</literal>|"$1"^^<http://www.w3.org/2001/XMLSchema#dateTime>|gs;
		$result =~ s|</?literal>|"|gs;
		($s) = $result =~ m|<binding name="s">(.*)</binding>|;
		($p) = $result =~ m|<binding name="p">(.*)</binding>|;
		($o) = $result =~ m|<binding name="o">(.*)</binding>|;
		$content .= join (" ", $s, $p, $o, ".") . "\n";
	}
	
	# my @data = split("[\n\r]", $data);
	# shift @data;
	# my $content = $data; # join("\n", @data);
	print "Content-type: application/rdf+xml\n" .
			  "Content-Disposition: attachment; filename=\"uat_feedback.nt\"\n\n";
	print STDOUT $content;
}
elsif ($q->param('comments')) {
	# get a data dump of feedback comments to CSV
	
	my $data = &sparqlQuery($comments_query, $endpoint, $output, $limit);
	my @data = split("[\n\r]", $data);
	shift @data;
	my $content = join("\t", "Article", "Reviewer", "Comment", "Date") . "\n";
	foreach my $line (@data) {
		my ($doi, $reviewer, $comment, $date) = split ("\t", $line);
		$reviewer =~ s|http://rdf.iop.org/email/||;
		$reviewer =~ s|_at_|@|;
		$comment =~ s|"||gs;
		$comment = uri_unescape($comment);
		$date =~ s|"||gs;
		$date =~ s|\^\^<http://www.w3.org/2001/XMLSchema#dateTime>||g;
		
		if ($comment) {
			$content .= join("\t", $doi, $reviewer, $comment, $date) . "\n";
		}
	}
	print "Content-type: text/plain\n" .
			  "Content-Disposition: attachment; filename=\"uat_comments.txt\"\n\n";
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