#!/usr/bin/perl

use CGI qw /:standard/; 
use LWP::UserAgent; 
use strict; 
# use Data::Dumper;
use URI::Escape;
# use HTML::Entities;

my $q = CGI->new();

my $self_url = $q->url;

my $output = "text";
my $endpoint = "http://localhost:8080/sparql/";
my $limit = -1;
my $sparql_query;
my $exact;

my $match_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?term ?label WHERE {
 graph <__GRAPH__> {
 ?term skos:prefLabel ?label .
 optional { ?term skos:altLabel ?altLabel . }
 filter (regex(str(?label), '__REGEX__', 'i') || regex(str(?altLabel), '__REGEX__', 'i')) .
}
}
order by ?label
EOQ

my $graph_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT DISTINCT ?g WHERE {
 GRAPH ?g {
  ?s ?p ?o
 }
}
EOQ

my $exact_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?term ?label WHERE {
 graph <__GRAPH__> {
 ?term skos:prefLabel ?label .
 filter(lcase(str(?label)) = lcase("__REGEX__"))
}
}
EOQ

my $excl_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?term ?label WHERE {
 graph <__GRAPH__> {
 ?term skos:prefLabel ?label .
 optional { ?term skos:altLabel ?altLabel . }
 filter ((regex(str(?label), '__REGEX__', 'i') || regex(str(?altLabel), '__REGEX__', 'i')) &&
	(lcase(?label) != lcase('__REGEX__')) ).
}
}
order by ?label

EOQ

my $rel_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?label WHERE {
 graph <__GRAPH__> {
 ?term skos:__TYPE__ ?rel_id .
 ?rel_id skos:prefLabel ?label .
 ?term skos:prefLabel "__LABEL__" .
}
}
order by ?label
EOQ

my $alt_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?label WHERE {
 graph <__GRAPH__> {
 ?term skos:altLabel ?label .
 ?term skos:prefLabel "__LABEL__" .
}
}
order by ?label
EOQ

my $tlt_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?term ?label WHERE {
 graph <__GRAPH__> {
 ?term skos:prefLabel ?label .
 optional { ?term skos:broader ?parent } .
 filter (!bound(?parent))
}
}
order by ?label
EOQ

my $synonyms_template = "<h3>Synonyms</h3>\n<ul>\n__SYNONYM_LIST__</ul>\n";
my $synonym_template = "<li>__SYNONYM__</li>\n";

my $regex = $q->param('term') || 0;

my $title = "Thesaurus browser";
$title .= ": $regex" if $regex;
print $q->header(-type => 'text/html', -charset => 'UTF-8');
print $q->start_html(
	-title=>$title, 
	-style=>[
		{'src'=>'https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css'}, 
		{'src'=>'https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap-theme.min.css'}, 
		{'src'=>'http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css'}
		], 
	-script=>[
		{-type=>'text/javascript', 'src'=>'http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js'},
		{-type=>'text/javascript', 'src'=>'http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js'},
		{-type=>'text/javascript', 'src'=>'https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js'},
		{-type=>'text/javascript', 'src'=>'/js/feedback_autocomplete.js'}
		]
	);

my @graphs = &get_thes_versions;
my %labels;
foreach (@graphs) {
	my $label;
	($label) = m|data.iop.org/thesaurus/(.+)|;
	$labels{$_} = $label;
}
@graphs = sort(keys(%labels));
my $graph = $q->param('graph') || $graphs[-2];

if ($regex) {
	$regex =~ s|(['"\/])|\\$1|g;
	$regex =~ s|\\\\|\\|g;
	$exact_query =~ s/__REGEX__/$regex/g;
	$match_query =~ s/__REGEX__/$regex/g;
	my $rdf_out = sparqlQuery($exact_query, $endpoint, $output);
	print "<!-- $rdf_out -->\n";
	my @terms = split("[\n\r]", $rdf_out);
	
	if (scalar(@terms) == 2) {
		$sparql_query = $exact_query;
		$exact = 1;
		print "<!-- found exact match -->\n";
	}
	else {
		print "<!-- " . (@terms) . " -->\n";
		$sparql_query = $match_query;
	}
}
else {
	$sparql_query = $tlt_query;
}
print "<div class=\"container\">\n";
print "<!-- " . Dump . " -->\n";
print "<!-- " . (%labels) . "\n" . (@graphs) ." -->\n";
print $q->start_form(-method=>'POST',-enctype=>'multipart/form-data', -action=>"browse_thes.pl");
print '
<div class="jumbotron" role="alert"><h3>Search the thesaurus</h3>
	<div class="row">
		<div class="col-lg-8">
			<div class="input-group">
				<input type="text" class="form-control" name="term" id="term1">
				<span class="input-group-btn">
				<button class="btn btn-success" type="submit">Search</button>
				</span>
			</div><!-- /input-group -->
		</div><!-- /.col-xs-10 -->
		<div class="col-lg-4">
				<span>Version:</span>';

print '
				<select name="graph">
';
foreach my $g (sort(keys(%labels))) {
	if ($g eq $graph) {
		print '				<option selected="selected" value="' . $g . '">' . $labels{$g} . '</option>' . "\n";
	}
	else {
		print '				<option value="' . $g . '">' . $labels{$g} . '</option>' . "\n";
	}
}	
print '
				</select>
';

print '
		</div><!-- /.col-xs-10 -->
	</div><!-- /.row -->

</div>
';
print $q->end_form();
my $rdf_out = sparqlQuery($sparql_query, $endpoint, $output);
my @terms = split("[\n\r]", $rdf_out);
shift @terms;
if ($exact) {
	$excl_query =~ s/__REGEX__/$regex/gs;
	my $rdf_out = sparqlQuery($excl_query, $endpoint, $output);
	my @terms2 = split("[\n\r]", $rdf_out);
	shift @terms2;
	# print "<!-- $_ -->\n" foreach @terms2;
	push (@terms, @terms2);
}

# print "<!-- $_ -->\n" foreach @terms;
my $phrase = " terms found";
$phrase =~ s/s// if scalar(@terms) == 1;
print $q->h3(span({-class=>"label label-success"}, (scalar(@terms)). $phrase)) . "\n";
foreach my $row (@terms) {
	my ($url, $term) = split("\t", $row);
	my ($syns, $nars, $broads, $rels);
	$term =~ s/"//g;
	next if $term =~ m/\?label/;
	next if $term =~ m/^\s*$/;
	print $q->h1(a{-href=>"$self_url?term=$term&graph=$graph"}, $term)."\n";
	my ($source) = $url =~ m|http://([^/]+)|;
	print $q->p({-class=>'small'}, "Source: $source") . "\n";
	my $temp_alt_query = $alt_query;
	$temp_alt_query =~ s/__LABEL__/$term/;
	my $list = sparqlQuery($temp_alt_query, $endpoint, $output);
	my @altterms = split("[\n\r]", $list);
	if (scalar(@altterms) > 1) {
		foreach my $relterm (@altterms) {
			my $syn = $synonym_template;
			next if $relterm =~ m/\?label/;
			next if $relterm =~ m/^\s*$/;
			$relterm =~ s/"//g;
			$syn =~ s/__SYNONYM__/$relterm/;
			$syns .= $syn;
		}
		my $temp_synonyms_template = $synonyms_template;
		$temp_synonyms_template =~ s/__SYNONYM_LIST__/$syns/;
		print $temp_synonyms_template;
	}
	if ($regex) {
		print "<div class=\"row\">\n";
		foreach my $type ("broader", "narrower", "related") {
			my $temp_query = $rel_query;
			$temp_query =~ s/__TYPE__/$type/;
			$temp_query =~ s/__LABEL__/$term/;
			my $list = sparqlQuery($temp_query, $endpoint, $output);
			my @relterms = split("[\n\r]", $list);
			print "<div class=\"col-lg-4\">\n";
			print $q->h3("$type terms") ."\n";
			if (scalar(@relterms) > 1) {
				foreach my $relterm (@relterms) {
					next if $relterm =~ m/\?label/;
					next if $relterm =~ m/^\s*$/;
					$relterm =~ s/"//g;
					print $q->p(a{-href=>"$self_url?term=$relterm&graph=$graph"}, $relterm)."\n";
				}
			}
			print "</div><!-- end col -->";
		}
		print "</div><!-- end row -->\n";
	}
	print $q->hr() . "\n";
}

print "</div>\n";
print $q->end_html();

sub get_thes_versions {
	my $list = sparqlQuery($graph_query, $endpoint, $output);
	my @graphs = split("[\n\r]", $list);
	pop @graphs;
	my @return;
	foreach (@graphs) {
		# print "<!-- $_ -->\n";
		s/[<>]//g;
		push @return, $_ if m/thesaurus/;
	}
	return @return;
}

sub sparqlQuery(@args) {
	my $query=shift;
	$query =~ s/__GRAPH__/$graph/g;
	# print "<!-- $query -->\n";
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
		# print "$sparqlURL\n";
        my $ua = LWP::UserAgent->new;
        $ua->agent("MyApp/0.1 ");
        my $req = HTTP::Request->new(GET => $sparqlURL);
        my $res = $ua->request($req);
        my $str=$res->content;
        return $str;
}
