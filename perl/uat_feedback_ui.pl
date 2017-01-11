#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use POSIX;
# use LWP::Simple qw/get/;
use LWP::UserAgent;
use URI::Escape;
# use Data::Dumper;
use Encode qw(decode encode);
use Cwd;
use MIME::Lite;
use HTTP::Request;

my $ua = LWP::UserAgent->new();
$ua->agent('ThesTermChecker/' . $ua->_agent);
$ua->from('michael.roberts@iop.org');


#
# Github configuration
#
my ($github_username, $github_password, $github_url);
open (my $fh, "<", "github_config") or die "No credential file found.";
while (<$fh>) {
	$github_username = $1 if m|Username: (.+)|i;
	$github_password = $1 if m|Password: (.+)|i;
	$github_url = $1 if m|URL: (.+)|i;
}

my $doi;
my $search;
my $submit;
my ($term1, $term2, $term3, $term4, $term5, $term6, $term7, $term8, $term9, $term10,
	$term11, $term12, $term13, $term14, $term15, $term16, $term17, $term18, $term19, $term20,
	$term21, $term22, $term23, $term24, $term25, $term26, $term27, $term28, $term29, $term30);
my $comments;
my $username;
my $live;
my $validated;
my @entities;
my @wrong_entities;
my @new_terms;
my $list;

my $output = "text";
my $endpoint = "http://4store:8080/sparql/";
my $limit = -1;
	
my $exact_query = <<EOQ;
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?term ?label WHERE 
 {
  graph <http://data.iop.org/thesaurus/2016R3> {
  ?term skos:prefLabel ?label .
  filter(lcase(str(?label)) = lcase("__REGEX__"))
 }
}
EOQ

my $metadata_query = <<EOQ;
PREFIX ioprdf: <http://rdf.iop.org/>
SELECT ?t ?a ?c ?issn
WHERE {
	graph <http://data.iop.org/uat_review> 
	{
	 <http://dx.doi.org/__DOI__> ioprdf:hasTitle ?t .
	 <http://dx.doi.org/__DOI__> ioprdf:hasAbstract ?a .
	 <http://dx.doi.org/__DOI__> ioprdf:hasCitation ?c .
	 <http://dx.doi.org/__DOI__> ioprdf:hasISSN ?issn .
	}
}
EOQ

my $doc_query = <<EOQ;
PREFIX ioprdf: <http://rdf.iop.org/>
SELECT ?p
WHERE {
	graph <http://data.iop.org/uat_review> 
	{
	 <http://dx.doi.org/__DOI__> ?p ?o .
	}
}
limit 1
EOQ

my $annotation_query = <<EOQ;
PREFIX ioprdf: <http://rdf.iop.org/>
SELECT ?annot ?label ?status
WHERE {
	graph <http://data.iop.org/uat_review> 
	{
	 <http://dx.doi.org/__DOI__> ioprdf:hasAnnotation ?annot .
	 ?annot ioprdf:hasTermLabel ?label .
	 ?annot ioprdf:hasStatus ?status .
	}
}
order by ?annot
EOQ

my $annot_rdf_template = <<EOT;
<http://dx.doi.org/__DOI__> <http://rdf.iop.org/hasAnnotation> <__ANNOT_ID__> .
<__ANNOT_ID__> <http://rdf.iop.org/hasTermLabel> "__TERM__" .
<__ANNOT_ID__> <http://rdf.iop.org/hasStatus> "__STATUS__" .
EOT

my $q = CGI->new();

my $self_url = $q->self_url;
my $base_url = $q->url(-base => 1);

my $thes_js = <<JS;

\$(function() {

	\$( "#term1" ).autocomplete(
	{
		 source:"$base_url/cgi-bin/thes_query.pl",
		 minLength:2
	});
});	
JS

my $uat_js = <<JS;

\$(function() {

	\$( "#search_term" ).autocomplete(
	{
		 source:"$base_url/cgi-bin/uat_query.pl",
		 minLength:2
	});
});	
JS

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print $q->start_html(
	-title=>'UAT Annotation feedback UI', 
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
		{-type=>'text/javascript', 'src'=>'/js/css3-mediaqueries.js'},
		# {-type=>'text/javascript', 'src'=>'/js/feedback_autocomplete.js'},
		# {-type=>'text/javascript', 'src'=>'/js/uat_autocomplete.js'},
		{-type=>'text/javascript', 'src'=>'/js/validate_form.js'},
		{-type=>'text/javascript', 'src'=>'/js/toggle.js'},
		$thes_js,
		$uat_js
		],
	# -script=>$js,
	-meta=>{'X-UA-Compatible'=>'IE=edge'}
	
	);

print "<div class=\"container\">\n";
# print $q->p($base_url) . "\n";

if ($q->param) {
	$search = $q->param('search_term') || 0;
	$submit = $q->param('submit') || 0;
	unless ($submit) {
		$submit = $q->param('agree') ? 'Agree' : 0;
		$submit = $q->param('disagree') ? 'Disagree' : 0;
	}
	$doi = $q->param('doi') || 0;
	$term1 = $q->param('term1') || 0;
	$term2 = $q->param('term2') || 0;
	$term3 = $q->param('term3') || 0;
	$term4 = $q->param('term4') || 0;
	$term5 = $q->param('term5') || 0;
	$term6 = $q->param('term6') || 0;
	$term7 = $q->param('term7') || 0;
	$term8 = $q->param('term8') || 0;
	$term9 = $q->param('term9') || 0;
	$term10 = $q->param('term10') || 0;	
	$term11 = $q->param('term11') || 0;
	$term12 = $q->param('term12') || 0;
	$term13 = $q->param('term13') || 0;
	$term14 = $q->param('term14') || 0;
	$term15 = $q->param('term15') || 0;
	$term16 = $q->param('term16') || 0;
	$term17 = $q->param('term17') || 0;
	$term18 = $q->param('term18') || 0;
	$term19 = $q->param('term19') || 0;
	$term20 = $q->param('term20') || 0;
	$term21 = $q->param('term21') || 0;
	$term22 = $q->param('term22') || 0;
	$term23 = $q->param('term23') || 0;
	$term24 = $q->param('term24') || 0;
	$term25 = $q->param('term25') || 0;
	$term26 = $q->param('term26') || 0;
	$term27 = $q->param('term27') || 0;
	$term28 = $q->param('term28') || 0;
	$term29 = $q->param('term29') || 0;
	$term30 = $q->param('term30') || 0;
	$comments = $q->param('comments') || 0;
	$live = $q->param('live') || 0;
	$username = $q->param('username') || 0;
	$validated = $q->param('validated') || 0;
	@entities = $q->param('entities') if $q->param('entities');
}
if ($search) {
	my $result = get_http("http://localhost/cgi-bin/uat_query.pl?doi=1&term=$search"); # server-side
	if ($result) {
		my @results = $result =~ m|"([^"]+?)"[,\]]|gs;
		if (scalar(@results) == 1) {
			if ($search =~ m|^10\.|) {
				$doi = $search;
			}
			else {
				# do we ever get here?
				$doi = get_http("http://localhost/cgi-bin/uat_query.pl?doi=1&term=$search"); # server-side
				chomp $doi;
				$doi =~ s|[\[\]"]||g;
			}
		}
		else {
			$list = 1;
			print $q->h1(scalar(@results) . " results returned from search.") . "\n";
			# iterate through results
			# link to individual articles
			foreach my $d (@results) {
				format_metadata($d);
				print $q->p(b(a({-href=>"uat_feedback_ui.pl?doi=$d"}, "Review this article"))) . "\n";
				print $q->hr();
			}
			print $q->p(a({-href=>"uat_feedback_ui.pl"}, b("Search for another article"))) . "\n";
		}
	}
	else {
		$doi = 0;
		$search = 0;
		print $q->h1("No results returned from search.") . "\n";
	}
}

if (scalar(@entities)>0) {
	@wrong_entities = @entities;
	undef @entities;
}

my $ref = $ENV{'HTTP_REFERER'};
my $rem_host = $q->remote_host();
print "<!-- rem_host: $rem_host -->\n";
print "<!-- " . Dump . " -->\n";
my (%terms, @terms, @status, %source);
{
	# invert selection
	# 'wrong' entities picked in feedback, 
	# we want to store the right ones in the XCAS
		
	my ($terms, $status) = get_annotations($doi);
	if ($terms) {
		my $lookup = get_http("http://localhost/cgi-bin/thes_query.pl?source=1&thes=2016R3&all=1"); #  server-side
		if ($lookup) {
			$lookup =~ s|[\[\]]||gs;
			my @thes_terms = $lookup =~ m|"(.*?)"[,\]]|gs;
			my @sources = $lookup =~ m|<([^>]+)>|gs;
			for my $i (0..$#thes_terms) {
				my ($t, $s) = ($thes_terms[$i], $sources[$i]);
				$source{$t} = $s =~ m|astro| ? "UAT" : "IOP";
			}
		}
		else {
			print $q->h1("Thesaurus lookup failed") . "\n";
		}

		@terms = @$terms;
		@status = @$status;
		foreach ($term1, $term2, $term3, $term4, $term5, $term6, $term7, $term8, $term9, $term10,
				$term11, $term12, $term13, $term14, $term15, $term16, $term17, $term18, $term19, $term20,
				$term21, $term22, $term23, $term24, $term25, $term26, $term27, $term28, $term29, $term30) {
			if ($_) {
				push @terms, $_;
				push @status, "Missed";
				$terms{$_} = "Missed";
				unless ($source{$_}) {
					$source{$_} = "New";
					push @new_terms, $_;
				}
			}
		}
		for my $i (0..$#terms) {
			my $t = $terms[$i];
			next if $t =~ m/^\s*$/;
			my $incorrect;
			if ($validated) {
				foreach my $w (@wrong_entities) {
					 if ($t eq $w) {
						$incorrect = 1;
						$status[$i] = "Incorrect";
						last;
					}
				}
				unless ($incorrect) {
					$status[$i] = "Correct" unless $status[$i] =~ m"Missed";
				}
			}
			$terms{$t} = $status[$i];
		}
		
		pop @entities if $entities[0] =~ m/^\s*$/;
		print "<!-- Stored Terms: " . join("\n", @terms) . "-->\n";
		print "<!-- Confirmed correct entities: " . join("\n", @entities) . "-->\n";
		print "<!-- Wrong entities: " . join("\n", @wrong_entities) . "-->\n";
	}
}

if ($doi && $doi !~ m/\d{2}\.\d{4}\//) {
	print $q->h1("DOI not valid: $doi") . "\n";
	$doi = 0;
}
if (@entities || $validated || 
		$term1 || $term2 || $term3 || $term4 || $term5 || $term6 || $term7 || $term8 || $term9 || $term10 ||
		$term11 || $term12 || $term13 || $term14 || $term15 || $term16 || $term17 || $term18 || $term19 || $term20 ||
		$term21 || $term22 || $term23 || $term24 || $term25 || $term26 || $term27 || $term28 || $term29 || $term30) {
	unless ($validated) {
		# validate data
		# set validated to 1 if it's OK
		$validated = 1 if ((scalar(@entities) >= 1) && $username);
	}
	if ($validated) {
		print $q->h1(span({-class=>'label label-success'}, "Feedback received")) . "\n";
		my $timestamp = strftime("%Y%m%d%H%M%S", localtime(time)) . "_" . int(rand(9999));
		my (@correct_terms, @incorrect_terms, @missed_terms);
		foreach my $t (@terms) {
			push @correct_terms, $t if $terms{$t} eq "Correct";
			push @incorrect_terms, $t if $terms{$t} eq "Incorrect";
			push @missed_terms, $t if $terms{$t} eq "Missed";
			print $q->h1("Term not validated: $t") . "\n" if $terms{$t} eq "Pending";
		}
		
		my $subject = "Feedback for article $doi received ($timestamp)";
		my $message;
		
		$message = join("\n", "Username:", "  $username", "");
		unless ($submit =~ m|agree|i) {
			$message .= join("\n", "Correct terms:", "  " . join("\n  ", @correct_terms), "");
			$message .= join("\n", "Missed terms:", "  " . join("\n  ", @missed_terms), "");
			$message .= join("\n  ", "Incorrect terms:", @incorrect_terms) . "\n" if scalar(@wrong_entities) > 0;
		}
		else {
			$message .= "Feedback review: $submit\n";
		}
		$message .= join("\n", "", "Comments:\n  $comments") if $comments;
		my $from = "uat_feedback\@iop.org";
		unless (($live) && ($username eq "domex")) {
			&email_alert($doi, 
				$message,
				$subject,
				"michael.roberts\@iop.org",
				$from
				);
		}
		
		my $docid = format_metadata($doi);
		
		unless ($submit =~ m|agree|i) {
			print $q->p("Thank you for confirming the following entities are correct:", ul(li(\@correct_terms))) . "\n" if scalar(@correct_terms) > 0;
			print $q->p("Thank you for confirming the following entities were missed:", ul(li(\@missed_terms))) . "\n" if scalar(@missed_terms) > 0;
			print $q->p("Thank you for confirming the following entities are inappropriate:", ul(li(\@incorrect_terms))) . "\n" if scalar(@incorrect_terms) > 0;
		}
		else {
			print $q->p("Thank you for providing review of the feedback received.") . "\n";
		}
		if ($comments) {
			print $q->p("Comment received:") . "\n";
			print $q->p($comments) . "\n";
		}
		if ($username) {
			print $q->p("User ID received:") . "\n";
			print $q->p($username) . "\n";
		}
		my $s_q = $annotation_query;
		$s_q =~ s|__DOI__|$doi|gs;
		my $data = &sparqlQuery($s_q, $endpoint, $output, $limit);
			$s_q =~ s/</&lt;/g;
			$s_q =~ s/>/&gt;/g;
		my @data = split("[\n\r]", $data);
		unless ($submit =~ m|agree|i) {
			for my $i (1..$#data) {
				$data[$i] =~ s/"//g;
				$data[$i] =~ s/[<>]//g;
				my ($annot_id, $term, $status) = split("\t", $data[$i]);
				my $t = $annot_rdf_template;
				$t =~ s/__DOI__/$doi/gs;
				$t =~ s/__ANNOT_ID__/$annot_id/gs;
				$t =~ s/__TERM__/$term/gs;
				$t =~ s/__STATUS__/$status/gs;
				delete_4store_data($t, "http://data.iop.org/uat_review");
			}
		}
		# make annotation review event
		my $datetime = strftime("%Y-%m-%dT%H:%M:%S", localtime(time));
		$username =~ s/\@/_at_/;
		my $rdf = "<http://rdf.iop.org/email/$username> <http://rdf.iop.org/hasDoneReview> <http://rdf.iop.org/AnnotationReview/$timestamp> .\n";
		$rdf .= "<http://rdf.iop.org/AnnotationReview/$timestamp> <http://rdf.iop.org/hasDOI> <http://dx.doi.org/$doi> . \n";
		$rdf .= "<http://rdf.iop.org/AnnotationReview/$timestamp> <http://rdf.iop.org/hasDateTime> \"$datetime\"^^<http://www.w3.org/2001/XMLSchema#dateTime> . \n";
		unless ($submit =~ m|agree|i) {
			# replace terms with validated term list
			my $annot_count;
			print $q->p(scalar(@terms) . " validated terms found.") . "\n";
			foreach my $term (@terms) {
				unless ($rdf =~ m|"$term"|) {
					$annot_count++;
					my $status = $terms{$term};
					my $t = $annot_rdf_template;
					my $annot_id = "http://dx.doi.org/$doi/term/" . sprintf("%04d", $annot_count);
					$t =~ s/__DOI__/$doi/gs;
					$t =~ s/__ANNOT_ID__/$annot_id/gs;
					$t =~ s/__TERM__/$term/gs;
					$t =~ s/__STATUS__/$status/gs;
					$rdf .= $t;
				}
			}
		}
		$rdf .= "<http://rdf.iop.org/AnnotationReview/$timestamp> <http://rdf.iop.org/hasComment> \"".uri_escape_utf8($comments) . "\"";
		my $data_ep = "http://4store:8080/data/";
		my $content = "graph=http://data.iop.org/uat_review&mime-type=application/x-turtle&data=" . uri_escape_utf8($rdf);
		
		my $response = $ua->post(
			$data_ep,
			Content => $content
			);
		unless ($response->is_success()) {
			print $q->h1("Data upload failed.") . "\n";
			print $q->p(($response)) . "\n"; #Dumper
		}
		else {
			print $q->comment("Data uploaded.") . "\n";
		}

		if (scalar(@new_terms) > 0) {
			die "No github config found." unless ($github_username && $github_password && $github_url);
			print $q->p("Submitting suggestion for " . join(", ", @new_terms)) . "\n";
			# integrate with Github here
			my $ua = LWP::UserAgent->new;
			my $title = "New thesaurus term suggestion: ";
			my $body = "Review ID: " . $timestamp;
			$body .= " Comments: $comments" if $comments;
			foreach my $t (@new_terms) {
				my $deposit = join("\n", '{', '"title":"' . $title . ' ' . $t . '",',  '"body":"' . $body . '"'. '}');
				my $req = HTTP::Request->new('POST', $github_url, [], $deposit);
				$req->authorization_basic($github_username, $github_password);
				my $response = $ua->request($req);
				unless ($response->is_success()) {
					print $q->p("Github issue upload failed.") . "\n";
					print $q->p($deposit) . "\n";
					print $q->p($response->as_string) . "\n";
				}
				else {
					print $q->p("Thesaurus suggestion submitted successfully.") . "\n";
				}
			}
		}
	}
	else {
		# Need to prompt for missing data.
		print $q->h1(span({-class=>"label label-warning"}, "Please check your input")) . "\n";
		print $q->h3(span({-class=>"label label-info"}, "No extractions were set as valid.")) . "\n" unless scalar(@entities) >= 1;
		print $q->h3(span({-class=>"label label-info"}, "No contact details provided.")) . "\n" unless $username;
		print_validation_form($doi, 1);
		
	}
	# print_form();
}
elsif ($doi) {
	print "<!-- got DOI $doi -->\n";
	print_validation_form($doi, 0);
}
else {
	print_form() unless $list;
	print "<!-- " . Dump . " -->\n";
}

print "</div> <!-- end container -->\n";
print $q->end_html;

sub print_validation_form {
	my ($doi, $checked) = @_;
	$doc_query =~ s|__DOI__|$doi|;
	my $art_check = &sparqlQuery($doc_query, $endpoint, $output, $limit);
	if ($art_check =~ m|rdf\.iop\.org|) {
		print "<!-- got metadata -->\n";
		my $x;
		my $xcas;
		my ($last_annotated);
		my $docid = format_metadata($doi);
		my $a = $annotation_query;
		$a =~ s/__DOI__/$doi/;
		my $annots = &sparqlQuery($a, $endpoint, $output, $limit);
		if ($annots) {
			format_annots($checked);
		}
	}
	else {
		print $q->p("Unable to retrieve metadata for $doi") . "\n";
		print $q->p($art_check) . "\n";
	}
}

sub format_metadata {
	my $doi = shift;
	my $m = $metadata_query;
	$m =~ s|__DOI__|$doi|gs;
	my $metadata = &sparqlQuery($m, $endpoint, $output, $limit);
	my @meta = split ("[\n\r]", $metadata);
	my ($title, $abstract, $citation, $issn) = split ("\t", $meta[1]);
	$title =~ s|"||gs;
	$abstract =~ s|"||gs;
	$citation =~ s|"||gs;
	print $q->h2($title) . "\n";
	print $q->p($citation) . "\n";
	print $q->p($abstract) . "\n";
	my $iops_url = "http://dx.doi.org/$doi";
	print $q->p("Link to article:", a({-href=>"$iops_url", -target=>'_blank'}, "http://dx.doi.org/$doi")) . "\n";
	print $q->p(a({-href=>"uat_feedback_ui.pl"}, b("Search for another article"))) . "\n" unless $list;
	return join("/", $issn);
}

sub format_annots {
	my ($v) = @_;
	print "<!-- Validated? $v -->\n";

	my %validated_terms;
	my $fb = $terms{$terms[0]} =~ m/Pending/ ? 0 : 1;
	
	foreach my $term (@terms) {
		my $status = $terms{$term};
		$validated_terms{$term} = 1 unless $terms{$term} =~ m|Pending|;
	}
	print $q->start_form({-class=>'form-inline', -role=>'form', -onsubmit=>'return validateForm(this)'});
	print "<div class=\"row\">\n"; # 1
	if (scalar(@terms) > 0) { 
		if ($v && scalar(@entities) == 0) {
			print "<div class=\"col-md-6\" style=\"background: orange\">\n";
		}
		else {
			print "<div class=\"col-md-6\" >\n";
		}

		unless ($fb) { 
			print $q->h3(span({-class=>'label label-info'}, "Step 1: Please tick all the terms that are", u("inappropriate"))) . "\n";
		}
		else {
			print $q->h3(span({-class=>'label label-info'}, "Feedback received (checked terms are inappropriate)")) . "\n";
		}
		
	}
	print "<div class=\"form-group\">\n"; # 3
	if (scalar(@terms) > 0) {
		{
			print "<div class=\"checkbox\" >\n"; # 4
			foreach (@terms) {
				my $s = $source{$_};
				unless ($s) {
					my $source = get_http("http://localhost/cgi-bin/thes_query.pl?source=1&thes=2016R3&term=$_");
					$s = $source =~ m|astro| ? "UAT" : "IOP";
				}
				if ($fb) {
					if ($terms{$_} eq "Incorrect") {
						$validated_terms{$_} = 2;
						print $q->label(input({-type=>'checkbox', -name=>'entities', -value=>"$_", -checked=>'checked', -disabled=>'disabled'}), a({-href=>"/cgi-bin/browse_thes.pl?term=$_", -target=>'_thes'}, "$_"), "($s)") . "<br />\n"; # , -checked=>'checked'
					}
					else {
						unless ($terms{$_} eq "Missed") {
							$validated_terms{$_} = 2;
							print $q->label(input({-type=>'checkbox', -name=>'entities', -value=>"$_", -disabled=>'disabled'}), a({-href=>"/cgi-bin/browse_thes.pl?term=$_", -target=>'_thes'}, "$_"), "($s)") . "<br />\n"; # , -checked=>'checked'
						}
					}
				}
				else {
					print $q->label(input({-type=>'checkbox', -name=>'entities', -value=>"$_"}), a({-href=>"/cgi-bin/browse_thes.pl?term=$_", -target=>'_thes'}, "$_"), "($s)") . "<br />\n"; # , -checked=>'checked'
				}
			}
			print $q->br() . "\n";
			print $q->label(input({-type=>'checkbox', -onclick=>'toggle(this)'}), b("Select all")) . "\n" unless $fb;
			if ($fb) {
				my @missing_terms;
				foreach (@terms) {
					push @missing_terms, $_ if ($terms{$_} eq "Missed");
				}
				if (scalar(@missing_terms) > 0) {
					print $q->br();
					print $q->h4(span({-class=>'label label-warning'}, "Missed terms")) . "\n";
					foreach (@missing_terms) {
						print $q->label(input({-type=>'checkbox', -name=>'entities', -value=>"$_", -disabled=>'disabled'}), a({-href=>"/cgi-bin/browse_thes.pl?term=$_", -target=>'_thes'}, "$_")) . "<br />\n";
					}
				}
			}
			print "</div>\n"; # checkbox
		}
	}
	print "</div>\n"; # form-group
	print "</div>\n"; # col-md-6
	unless ($fb) {
		print "<div class=\"col-md-6, input-group\">\n";
			print $q->h3(span({-class=>'label label-info'}, "Step 2: Please add any other terms relevant to the document.")) . "\n";
			print $q->div({-class=>'btn btn-default mt-1'}, a({-href=>"/cgi-bin/browse_thes.pl", -target=>'_thes'}, "Browse the latest version of the thesaurus.")) . "\n";
			foreach ("term1", "term2", "term3", "term4", "term5") {
				print "<div class=\"row mt-1\">\n";
				print $q->div({-class=>'col-md-3'},"Missing term:");
				print $q->div({-class=>'col-md-3'},textfield(-name=>$_,-size=>50,-id=>$_));
				print "</div>\n";  # row mt-1
			}
			print "<div class=\"row mt-1\">\n";
				print $q->div({-class=>'col-md-3'},"Comments:");
				print $q->div({-class=>'col-md-3'},textarea(-name=>'comments', -rows=>'5', -columns=>'48'));
			print "</div>\n"; # row mt-1
			print "<div class=\"row mt-1\">\n";
				print "<div class=\"col-md-3\">\n";
					print $q->h3(span({-class=>'label label-info'}, "Step 3: Please provide contact information.")) . "\n";
					# print "<div class=\"row mt-1\">\n";
					print $q->div({-class=>'col-md-3'},div({-class=>'col-md-3'},"Please provide an email address if you are happy for representatives of the UAT Steering Committee to contact you with any questions or updates on your feedback. This information will only be used to contact you to discuss your feedback. It will not be used for marketing purposes or disclosed to third parties. Your details will be deleted at the conclusion of the UAT review project.")) . "\n";
					# print "</div>\n"; #row mt-1
				print "</div>\n"; #col md 6
			print "</div>\n"; #row mt-1
			
			if ($v) {
				print "<div class=\"row mt-1\" style=\"background: orange\">" unless $username;
			}
			else {
				print "<div class=\"row mt-1\">\n";
			}
				print $q->div({-class=>'col-md-3'},"Username/email:");
				print $q->div({-class=>'col-md-3'},textfield(-name=>'username',-size=>50,-id=>'username'));
			print "</div>"; # row
			
			print $q->hidden(-name=>'doi', -value=>$doi);
			print $q->hidden(-name=>'validated', -id=>'validated', -value=>$v, -override => 1 );
			print $q->div({-style=>'text-align: right', -class=>'mt-1'},submit(-class=>'btn btn-success btn-lg mt-1', -name=>'submit', -value=>'Submit annotation feedback')) unless $fb;
			print $q->div({-style=>'clear: both;'})."\n";
		print "</div>\n"; # col
	}
	else {
		print "<div class=\"col-md-6, input-group\">\n";
		print $q->h3(span({-class=>'label label-info'}, "Do you agree with the feedback already given?")) . "\n";

		print "<div class=\"row mt-1\">\n";
		print $q->div({-class=>'col-md-3'},"Comments:");
		print $q->div({-class=>'col-md-3'},textarea(-name=>'comments', -rows=>'5', -columns=>'48'));
		print "</div>\n"; # row mt-1
		print "<div class=\"row mt-1\">\n";
		print "<div class=\"col-md-6\">\n";
		print $q->h3(span({-class=>'label label-info'}, "Please provide contact information.")) . "\n";
		print $q->span("Please provide an email address if you are happy for representatives of the UAT Steering Committee to contact you with any questions or updates on your feedback. This information will only be used to contact you to discuss your feedback. It will not be used for marketing purposes or disclosed to third parties. Your details will be deleted at the conclusion of the UAT review project.") . "\n";
		print "</div>\n"; #col md 6
		print "</div>\n"; #row mt-1
		
		if ($v) {
			print "<div class=\"row mt-1\" style=\"background: orange\">" unless $username;
		}
		else {
			print "<div class=\"row mt-1\">\n";
		}
			print $q->div({-class=>'col-md-3'},"Username/email:");
			print $q->div({-class=>'col-md-3'},textfield(-name=>'username',-size=>50,-id=>'username'));
		print "</div>"; # row
		
		print $q->hidden(-name=>'doi', -value=>$doi);
		print $q->hidden(-name=>'validated', -id=>'validated', -value=>$v, -override => 1 );
		
		print $q->div({-style=>'text-align: right', -class=>'mt-1'},submit(-class=>'btn btn-danger btn-lg mt-1', -name=>'submit', -value=>'Disagree'),submit(-class=>'btn btn-success btn-lg mt-1', -name=>'submit', -value=>'Agree'));
		print $q->div({-style=>'clear: both;'})."\n";
		print "</div>\n"; # col
	}
	print "</div>\n"; # row
	print $q->end_form();
}

sub print_form {
	print $q->h2("Please input search term")."\n";
	print $q->p("You can search for title, author or DOI")."\n";
	print $q->start_form(-method=>'POST',-enctype=>'multipart/form-data', -action=>"uat_feedback_ui.pl");
	print $q->p("Search term: ", textfield(-name=>'search_term', -id=>'search_term', -type=>'text', -rows=>1, -columns=>40, -override=>1)) . "\n"; 
	print $q->submit(-name=>'submit', -value=>'Submit') . "\n";
	print $q->end_form;
}

sub email_alert {
	my ($id, $feedback, $subject, $to, $from) = @_;

	my $message = "$feedback";
	#
	my ($api_url, $api_key, $topic_arn) = get_sns_credentials();
	my $req_url = $api_url . "Message=" . uri_escape($message) . "&Subject=" . uri_escape($subject) . "&TopicArn=" . $topic_arn;
	my $req = HTTP::Request->new('POST', $req_url, 'x-api-key'=>$api_key);
	#	my $msg = MIME::Lite->new(
	#					 From     => $from,
	#					 To       => $to,
	#					 Subject  => $subject,
	#					 Data     => $message
	#					 );
	#	$msg->send;
	my $response = $ua->request($req);
	if ($response->is_success) {
		print "<!-- email sent -->\n";
	}
	else {
		warn "Failed to send via SNS: " . $response->as_string();
	}
}

sub get_sns_credentials {
	open (my $fh, "<", "sns_credentials") or die "No SNS credentials\n";
	my ($api_url, $api_key, $topic_arn);
	while (<$fh>) {
		$api_url = $1 if m|api_url: (.+)|i;
		$api_key = $1 if m|api_key: (.+)|i;
		$topic_arn = $1 if m|topic_arn: (.+)|i;
	}
	die "No SNS credentials found in file." unless ($api_url && $api_key && $topic_arn);
	return ($api_url, $api_key, $topic_arn);
}

sub search_thes {
	my $term = shift;
	my $e = $exact_query;
	$e =~ s/__REGEX__/$term/g;
	my $rdf_out = &sparqlQuery($e, $endpoint, $output, $limit);
	my @terms = split("[\n\r]", $rdf_out);
	print $q->comment("$term\n". join("\n", @terms) ). "\n";
	return 1 if scalar(@terms) == 2;
	return 0;
}

sub sparqlQuery() {
	my $query=shift;
	my $baseURL=shift;
	my $format=shift;
	# my $limit=shift;
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

sub get_data {
    my $name   = shift;
    my @values = $q->param( $name );
    return @values > 1
        ? \@values
        : $values[0];
}

sub get_terms {
	my $term = shift;
	my $str;
	foreach my $type ("synonym", "broader", "narrower", "related") {
		foreach my $num (1, 2, 3) {
			$str .= "\t$type: " . $q->param("$term $type $num") . "\n" if $q->param("$term $type $num");
			print $q->p("$type: " . $q->param("$term $type $num")) . "\n" if $q->param("$term $type $num");
		}
	}
	return $str;
}

sub delete_4store_data {
	my ($content, $graph) = @_;
	my $ua = LWP::UserAgent->new();
	my $update_ep = "http://4store:8080/update/";
	$content =~ s/\%/%25/g;
	my $c = "update=DELETE+DATA+{+GRAPH+<" . $graph . ">+{+" . $content . "}+}";
	# print $q->comment("Deleting $content") . "\n";
	my $response = $ua->post(
		$update_ep,
		Content => $c
		);
	$content =~ s/[<>]/|/g;
	$c =~ s/[<>]/|/g;
	unless ($response->is_success()) {
		print $q->h1("Delete upload failed.") . "\n";
		print $q->p(($response)) . "\n"; # Dumper
	}
}

sub convert_numerical_entities {

	my $stringToParse = shift @_;

	if ($stringToParse) {

		#	$stringToParse =~ s/\n//g;
	
		##	Convert hex entity values to decimal first
	
		while ($stringToParse =~ /\&\#x([0-9A-Fa-f]+)\;/) {
			my $hexVal = $1;
			my $decVal = hex($hexVal);
			$stringToParse =~ s/x$hexVal/$decVal/;
		}
	
		my @splitString = split "", $stringToParse;
		for my $i (0..$#splitString) {
			if (ord($splitString[$i]) > 160) {
				$splitString[$i] = "&#".ord($splitString[$i]).";";
			}	
			elsif  (ord($splitString[$i]) > 126) {
				#	Windows ANSI character, probably
				$splitString[$i] = "&#".ord($splitString[$i]).";";
			}
		}
		$stringToParse = join "", @splitString;
	
		$stringToParse =~ s/\&\#34\;/\&quot\;/gs;
		$stringToParse =~ s/\&\#38\;/\&amp\;/gs;
		$stringToParse =~ s/\&\#60\;/\&lt\;/gs;
		$stringToParse =~ s/\&\#62\;/\&gt\;/gs;

		##	Windows ANSI characters...
		##	Got from http://www.alanwood.net/demos/ansi.html
		$stringToParse =~ s/\&\#128\;/\&euro\;/gs;
		$stringToParse =~ s/\&\#129\;//gs;	#	Not used
		$stringToParse =~ s/\&\#130\;/\&sbquo\;/gs;
		$stringToParse =~ s/\&\#131\;/\&fnof\;/gs;
		$stringToParse =~ s/\&\#132\;/\&bdquo\;/gs;
		$stringToParse =~ s/\&\#133\;/\&hellip\;/gs;
		$stringToParse =~ s/\&\#134\;/\&dagger\;/gs;
		$stringToParse =~ s/\&\#135\;/\&Dagger\;/gs;
		$stringToParse =~ s/\&\#136\;/\&circ\;/gs;
		$stringToParse =~ s/\&\#137\;/\&permil\;/gs;
		$stringToParse =~ s/\&\#138\;/\&Scaron\;/gs;
		$stringToParse =~ s/\&\#139\;/\&lsaquo\;/gs;
		$stringToParse =~ s/\&\#140\;/\&OElig\;/gs;
		$stringToParse =~ s/\&\#141\;//gs;	#	Not used
		$stringToParse =~ s/\&\#142\;/\&Zcaron\;/gs;
		$stringToParse =~ s/\&\#143\;//gs;	#	Not used
		$stringToParse =~ s/\&\#144\;//gs;	#	Not used
		$stringToParse =~ s/\&\#145\;/\&lsquo\;/gs;
		$stringToParse =~ s/\&\#146\;/\&rsquo\;/gs;
		$stringToParse =~ s/\&\#147\;/\&ldquo\;/gs;
		$stringToParse =~ s/\&\#148\;/\&rdquo\;/gs;
		$stringToParse =~ s/\&\#149\;/\&bull\;/gs;
		$stringToParse =~ s/\&\#150\;/\&ndash\;/gs;
		$stringToParse =~ s/\&\#151\;/\&mdash\;/gs;
		$stringToParse =~ s/\&\#152\;/\&tilde\;/gs;
		$stringToParse =~ s/\&\#153\;/\&trade\;/gs;
		$stringToParse =~ s/\&\#154\;/\&scaron\;/gs;
		$stringToParse =~ s/\&\#155\;/\&rsaquo\;/gs;
		$stringToParse =~ s/\&\#156\;/\&oelig\;/gs;
		$stringToParse =~ s/\&\#157\;//gs;	#	Not used
		$stringToParse =~ s/\&\#158\;/\&zcaron\;/gs;
		$stringToParse =~ s/\&\#159\;/\&Yuml\;/gs;

		##	'Proper' entities now...
	
		$stringToParse =~ s/\&\#160\;/\&nbsp\;/gs;
		$stringToParse =~ s/\&\#161\;/\&iexcl\;/gs;
		$stringToParse =~ s/\&\#162\;/\&cent\;/gs;
		$stringToParse =~ s/\&\#163\;/\&pound\;/gs;
		$stringToParse =~ s/\&\#164\;/\&curren\;/gs;
		$stringToParse =~ s/\&\#165\;/\&yen\;/gs;
		$stringToParse =~ s/\&\#166\;/\&brvbar\;/gs;
		$stringToParse =~ s/\&\#167\;/\&sect\;/gs;
		$stringToParse =~ s/\&\#168\;/\&uml\;/gs;
		$stringToParse =~ s/\&\#169\;/\&copy\;/gs;
		$stringToParse =~ s/\&\#170\;/\&ordf\;/gs;
		$stringToParse =~ s/\&\#171\;/\&laquo\;/gs;
		$stringToParse =~ s/\&\#172\;/\&not\;/gs;
		$stringToParse =~ s/\&\#173\;/\&shy\;/gs;
		$stringToParse =~ s/\&\#174\;/\&reg\;/gs;
		$stringToParse =~ s/\&\#175\;/\&macr\;/gs;
		$stringToParse =~ s/\&\#176\;/\&deg\;/gs;
		$stringToParse =~ s/\&\#177\;/\&plusmn\;/gs;
		$stringToParse =~ s/\&\#178\;/\&sup2\;/gs;
		$stringToParse =~ s/\&\#179\;/\&sup3\;/gs;
		$stringToParse =~ s/\&\#180\;/\&acute\;/gs;
		$stringToParse =~ s/\&\#181\;/\&micro\;/gs;
		$stringToParse =~ s/\&\#182\;/\&para\;/gs;
		$stringToParse =~ s/\&\#183\;/\&middot\;/gs;
		$stringToParse =~ s/\&\#184\;/\&cedil\;/gs;
		$stringToParse =~ s/\&\#185\;/\&sup1\;/gs;
		$stringToParse =~ s/\&\#186\;/\&ordm\;/gs;
		$stringToParse =~ s/\&\#187\;/\&raquo\;/gs;
		$stringToParse =~ s/\&\#188\;/\&frac14\;/gs;
		$stringToParse =~ s/\&\#189\;/\&frac12\;/gs;
		$stringToParse =~ s/\&\#190\;/\&frac34\;/gs;
		$stringToParse =~ s/\&\#191\;/\&iquest\;/gs;
		$stringToParse =~ s/\&\#192\;/\&Agrave\;/g;
		$stringToParse =~ s/\&\#193\;/\&Aacute\;/g;
		$stringToParse =~ s/\&\#194\;/\&Acirc\;/g;
		$stringToParse =~ s/\&\#195\;/\&Atilde\;/g;
		$stringToParse =~ s/\&\#196\;/\&Auml\;/g;
		$stringToParse =~ s/\&\#197\;/\&Aring\;/g;
		$stringToParse =~ s/\&\#198\;/\&AElig\;/g;
		$stringToParse =~ s/\&\#199\;/\&Ccedil\;/g;
		$stringToParse =~ s/\&\#200\;/\&Egrave\;/g;
		$stringToParse =~ s/\&\#201\;/\&Eacute\;/g;
		$stringToParse =~ s/\&\#202\;/\&Ecirc\;/g;
		$stringToParse =~ s/\&\#203\;/\&Euml\;/g;
		$stringToParse =~ s/\&\#204\;/\&Igrave\;/g;
		$stringToParse =~ s/\&\#205\;/\&Iacute\;/g;
		$stringToParse =~ s/\&\#206\;/\&Icirc\;/g;
		$stringToParse =~ s/\&\#207\;/\&Iuml\;/g;
		$stringToParse =~ s/\&\#208\;/\&ETH\;/g;
		$stringToParse =~ s/\&\#209\;/\&Ntilde\;/g;
		$stringToParse =~ s/\&\#210\;/\&Ograve\;/g;
		$stringToParse =~ s/\&\#211\;/\&Oacute\;/g;
		$stringToParse =~ s/\&\#212\;/\&Ocirc\;/g;
		$stringToParse =~ s/\&\#213\;/\&Otilde\;/g;
		$stringToParse =~ s/\&\#214\;/\&Ouml\;/g;
		$stringToParse =~ s/\&\#215\;/\&times\;/g;
		$stringToParse =~ s/\&\#216\;/\&Oslash\;/g;
		$stringToParse =~ s/\&\#217\;/\&Ugrave\;/g;
		$stringToParse =~ s/\&\#218\;/\&Uacute\;/g;
		$stringToParse =~ s/\&\#219\;/\&Ucirc\;/g;
		$stringToParse =~ s/\&\#220\;/\&Uuml\;/g;
		$stringToParse =~ s/\&\#221\;/\&Yacute\;/g;
		$stringToParse =~ s/\&\#222\;/\&THORN\;/g;
		$stringToParse =~ s/\&\#223\;/\&szlig\;/g;
		$stringToParse =~ s/\&\#224\;/\&agrave\;/g;
		$stringToParse =~ s/\&\#225\;/\&aacute\;/g;
		$stringToParse =~ s/\&\#226\;/\&acirc\;/g;
		$stringToParse =~ s/\&\#227\;/\&atilde\;/g;
		$stringToParse =~ s/\&\#228\;/\&auml\;/g;
		$stringToParse =~ s/\&\#229\;/\&aring\;/g;
		$stringToParse =~ s/\&\#230\;/\&aelig\;/g;
		$stringToParse =~ s/\&\#231\;/\&ccedil\;/g;
		$stringToParse =~ s/\&\#232\;/\&egrave\;/g;
		$stringToParse =~ s/\&\#233\;/\&eacute\;/g;
		$stringToParse =~ s/\&\#234\;/\&ecirc\;/g;
		$stringToParse =~ s/\&\#235\;/\&euml\;/g;
		$stringToParse =~ s/\&\#236\;/\&igrave\;/g;
		$stringToParse =~ s/\&\#237\;/\&iacute\;/g;
		$stringToParse =~ s/\&\#238\;/\&icirc\;/g;
		$stringToParse =~ s/\&\#239\;/\&iuml\;/g;
		$stringToParse =~ s/\&\#240\;/\&eth\;/g;
		$stringToParse =~ s/\&\#241\;/\&ntilde\;/g;
		$stringToParse =~ s/\&\#242\;/\&ograve\;/g;
		$stringToParse =~ s/\&\#243\;/\&oacute\;/g;
		$stringToParse =~ s/\&\#244\;/\&ocirc\;/g;
		$stringToParse =~ s/\&\#245\;/\&otilde\;/g;
		$stringToParse =~ s/\&\#246\;/\&ouml\;/g;
		$stringToParse =~ s/\&\#247\;/\&divide\;/g;
		$stringToParse =~ s/\&\#248\;/\&oslash\;/g;
		$stringToParse =~ s/\&\#249\;/\&ugrave\;/g;
		$stringToParse =~ s/\&\#250\;/\&uacute\;/g;
		$stringToParse =~ s/\&\#251\;/\&ucirc\;/g;
		$stringToParse =~ s/\&\#252\;/\&uuml\;/g;
		$stringToParse =~ s/\&\#253\;/\&yacute\;/g;
		$stringToParse =~ s/\&\#254\;/\&thorn\;/g;
		$stringToParse =~ s/\&\#255\;/\&yuml\;/g;
	
	  $stringToParse =~ s/\&\#256\;/\&Amacr\;/gs;
	  $stringToParse =~ s/\&\#257\;/\&amacr\;/gs;
	  $stringToParse =~ s/\&\#258\;/\&Abreve\;/gs;
	  $stringToParse =~ s/\&\#259\;/\&abreve\;/gs;
	  $stringToParse =~ s/\&\#261\;/\&aogon\;/gs;
	  $stringToParse =~ s/\&\#262\;/\&Cacute\;/gs;
	  $stringToParse =~ s/\&\#263\;/\&cacute\;/gs;
	  $stringToParse =~ s/\&\#268\;/\&Ccaron\;/gs;
	  $stringToParse =~ s/\&\#269\;/\&ccaron\;/gs;
	  $stringToParse =~ s/\&\#270\;/\&Dcaron\;/gs;
	  $stringToParse =~ s/\&\#271\;/\&dcaron\;/gs;
	  $stringToParse =~ s/\&\#279\;/\&edot\;/gs;
	  $stringToParse =~ s/\&\#281\;/\&eogon\;/gs;
	  $stringToParse =~ s/\&\#282\;/\&Ecaron\;/gs;
	  $stringToParse =~ s/\&\#283\;/\&ecaron\;/gs;
	  $stringToParse =~ s/\&\#286\;/\&Gbreve\;/gs;
	  $stringToParse =~ s/\&\#287\;/\&gbreve\;/gs;
	  $stringToParse =~ s/\&\#296\;/\&Itilde\;/gs;
	  $stringToParse =~ s/\&\#297\;/\&itilde\;/gs;
		$stringToParse =~ s/\&\#299\;/i/gs;	#	Should be imacron but entity not on EJs
		$stringToParse =~ s/\&\#305\;/\&inodot\;/gs;
	  $stringToParse =~ s/\&\#317\;/\&Lcaron\;/gs;
	  $stringToParse =~ s/\&\#318\;/\&lcaron\;/gs;
	  $stringToParse =~ s/\&\#321\;/\&Lstrok\;/gs;
	  $stringToParse =~ s/\&\#322\;/\&lstrok\;/gs;
	  $stringToParse =~ s/\&\#323\;/\&Nacute\;/gs;
	  $stringToParse =~ s/\&\#324\;/\&nacute\;/gs;
	  $stringToParse =~ s/\&\#328\;/\&ncaron\;/gs;
	  $stringToParse =~ s/\&\#332\;/\&Omacr\;/gs;
	  $stringToParse =~ s/\&\#338\;/\&OElig\;/gs;
	  $stringToParse =~ s/\&\#339\;/\&oelig\;/gs;
	  $stringToParse =~ s/\&\#344\;/\&Rcaron\;/gs;
	  $stringToParse =~ s/\&\#345\;/\&rcaron\;/gs;
	  $stringToParse =~ s/\&\#346\;/\&Sacute\;/gs;
	  $stringToParse =~ s/\&\#347\;/\&sacute\;/gs;
	  $stringToParse =~ s/\&\#348\;/\&Scirc\;/gs;
	  $stringToParse =~ s/\&\#349\;/\&scirc\;/gs;
		$stringToParse =~ s/\&\#351\;/\&scedil\;/gs;
	  $stringToParse =~ s/\&\#352\;/\&Scaron\;/gs;
	  $stringToParse =~ s/\&\#353\;/\&scaron\;/gs;
	  $stringToParse =~ s/\&\#356\;/\&Tcaron\;/gs;
	  $stringToParse =~ s/\&\#357\;/\&tcaron\;/gs;
	  $stringToParse =~ s/\&\#364\;/\&Ubreve\;/gs;
	  $stringToParse =~ s/\&\#365\;/\&ubreve\;/gs;
	  $stringToParse =~ s/\&\#366\;/\&Uring\;/gs;
	  $stringToParse =~ s/\&\#367\;/\&uring\;/gs;
	  $stringToParse =~ s/\&\#369\;/\&udblac\;/gs;
	  $stringToParse =~ s/\&\#379\;/\&Zdot\;/gs;
	  $stringToParse =~ s/\&\#380\;/\&zdot\;/gs;
	  $stringToParse =~ s/\&\#381\;/\&Zcaron\;/gs;
	  $stringToParse =~ s/\&\#382\;/\&zcaron\;/gs;

		$stringToParse =~ s/\&\#768\;/\&grave\;/g;
		$stringToParse =~ s/\&\#769\;/\&acute\;/g;
		$stringToParse =~ s/\&\#770\;/\&circ\;/g;
		$stringToParse =~ s/\&\#771\;/\&tilde\;/g;
		$stringToParse =~ s/\&\#772\;/\&macr\;/g;
		$stringToParse =~ s/\&\#774\;/\&breve\;/g;
		$stringToParse =~ s/\&\#775\;/\&dot\;/g;
		$stringToParse =~ s/\&\#776\;/\&uml\;/g;
		$stringToParse =~ s/\&\#778\;/\&ring\;/g;
		$stringToParse =~ s/\&\#779\;/\&dblac\;/g;
		$stringToParse =~ s/\&\#780\;/\&caron\;/g;
		$stringToParse =~ s/\&\#783\;/\&dblgr\;/g;
		$stringToParse =~ s/\&\#808\;/\&ogon\;/g;
	
		$stringToParse =~ s/\&\#913\;/\&Alpha\;/gs;
		$stringToParse =~ s/\&\#914\;/\&Beta\;/gs;
		$stringToParse =~ s/\&\#915\;/\&Gamma\;/gs;
		$stringToParse =~ s/\&\#916\;/\&Delta\;/gs;
		$stringToParse =~ s/\&\#917\;/\&Epsilon\;/gs;
		$stringToParse =~ s/\&\#918\;/\&Zeta\;/gs;
		$stringToParse =~ s/\&\#919\;/\&Eta\;/gs;
		$stringToParse =~ s/\&\#920\;/\&Theta\;/gs;
		$stringToParse =~ s/\&\#921\;/\&Iota\;/gs;
		$stringToParse =~ s/\&\#922\;/\&Kappa\;/gs;
		$stringToParse =~ s/\&\#923\;/\&Lambda\;/gs;
		$stringToParse =~ s/\&\#924\;/\&Mu\;/gs;
		$stringToParse =~ s/\&\#925\;/\&Nu\;/gs;
		$stringToParse =~ s/\&\#926\;/\&Xi\;/gs;
		$stringToParse =~ s/\&\#927\;/\&Omicron\;/gs;
		$stringToParse =~ s/\&\#928\;/\&Pi\;/gs;
		$stringToParse =~ s/\&\#929\;/\&Rho\;/gs;
		$stringToParse =~ s/\&\#931\;/\&Sigma\;/gs;
		$stringToParse =~ s/\&\#932\;/\&Tau\;/gs;
		$stringToParse =~ s/\&\#933\;/\&Upsilon\;/gs;
		$stringToParse =~ s/\&\#934\;/\&Phi\;/gs;
		$stringToParse =~ s/\&\#935\;/\&Chi\;/gs;
		$stringToParse =~ s/\&\#936\;/\&Psi\;/gs;
		$stringToParse =~ s/\&\#937\;/\&Omega\;/gs;
		$stringToParse =~ s/\&\#945\;/\&alpha\;/gs;
		$stringToParse =~ s/\&\#946\;/\&beta\;/gs;
		$stringToParse =~ s/\&\#947\;/\&gamma\;/gs;
		$stringToParse =~ s/\&\#948\;/\&delta\;/gs;
		$stringToParse =~ s/\&\#949\;/\&epsilon\;/gs;
		$stringToParse =~ s/\&\#950\;/\&zeta\;/gs;
		$stringToParse =~ s/\&\#951\;/\&eta\;/gs;
		$stringToParse =~ s/\&\#952\;/\&theta\;/gs;
		$stringToParse =~ s/\&\#953\;/\&iota\;/gs;
		$stringToParse =~ s/\&\#954\;/\&kappa\;/gs;
		$stringToParse =~ s/\&\#955\;/\&lambda\;/gs;
		$stringToParse =~ s/\&\#956\;/\&mu\;/gs;
		$stringToParse =~ s/\&\#957\;/\&nu\;/gs;
		$stringToParse =~ s/\&\#958\;/\&xi\;/gs;
		$stringToParse =~ s/\&\#959\;/\&omicron\;/gs;
		$stringToParse =~ s/\&\#960\;/\&pi\;/gs;
		$stringToParse =~ s/\&\#961\;/\&rho\;/gs;
		$stringToParse =~ s/\&\#962\;/\&sigmaf\;/gs;
		$stringToParse =~ s/\&\#963\;/\&sigma\;/gs;
		$stringToParse =~ s/\&\#964\;/\&tau\;/gs;
		$stringToParse =~ s/\&\#965\;/\&upsilon\;/gs;
		$stringToParse =~ s/\&\#966\;/\&phi\;/gs;
		$stringToParse =~ s/\&\#967\;/\&chi\;/gs;
		$stringToParse =~ s/\&\#968\;/\&psi\;/gs;
		$stringToParse =~ s/\&\#969\;/\&omega\;/gs;
		$stringToParse =~ s/\&\#981\;/\&phiv\;/gs;
	
		$stringToParse =~ s/\&\#1013\;/\&epsiv\;/gs;
	
		$stringToParse =~ s/\&\#8194\;/\&ensp\;/gs;
		$stringToParse =~ s/\&\#8195\;/\&emsp\;/gs;
		$stringToParse =~ s/\&\#8200\;/ /gs;
		$stringToParse =~ s/\&\#8201\;/\&thinsp\;/gs;
		$stringToParse =~ s/\&\#8204\;/\&zwnj\;/gs;
		$stringToParse =~ s/\&\#8205\;/\&zwj\;/gs;
		$stringToParse =~ s/\&\#8206\;/\&lrm\;/gs;
		$stringToParse =~ s/\&\#8207\;/\&rlm\;/gs;
		$stringToParse =~ s/\&\#8208\;/-/gs;
		$stringToParse =~ s/\&\#8209\;/-/gs;
		$stringToParse =~ s/\&\#8211\;/\&ndash\;/gs;
		$stringToParse =~ s/\&\#8212\;/\&mdash\;/gs;
		$stringToParse =~ s/\&\#8216\;/\&lsquo\;/gs;
		$stringToParse =~ s/\&\#8217\;/\&rsquo\;/gs;
		$stringToParse =~ s/\&\#8218\;/\&sbquo\;/gs;
		$stringToParse =~ s/\&\#8220\;/\&ldquo\;/gs;
		$stringToParse =~ s/\&\#8221\;/\&rdquo\;/gs;
		$stringToParse =~ s/\&\#8222\;/\&bdquo\;/gs;
		$stringToParse =~ s/\&\#8224\;/\&dagger\;/gs;
		$stringToParse =~ s/\&\#8225\;/\&Dagger\;/gs;
		$stringToParse =~ s/\&\#8226\;/\&bull\;/gs;
		$stringToParse =~ s/\&\#8230\;/\&hellip\;/gs;
		$stringToParse =~ s/\&\#8240\;/\&permil\;/gs;
		$stringToParse =~ s/\&\#8242\;/\&prime\;/gs;
		$stringToParse =~ s/\&\#8243\;/\&Prime\;/gs;
		$stringToParse =~ s/\&\#8249\;/\&lsaquo\;/gs;
		$stringToParse =~ s/\&\#8250\;/\&rsaquo\;/gs;
		$stringToParse =~ s/\&\#8254\;/\&oline\;/gs;
		$stringToParse =~ s/\&\#8260\;/\&frasl\;/gs;
		$stringToParse =~ s/\&\#8270\;/*/gs;
		$stringToParse =~ s/\&\#8364\;/\&euro\;/gs;
		$stringToParse =~ s/\&\#8450\;/\&BbbC\;/gs;
		$stringToParse =~ s/\&\#8465\;/\&image\;/gs;
		$stringToParse =~ s/\&\#8472\;/\&weierp\;/gs;
		$stringToParse =~ s/\&\#8476\;/\&real\;/gs;
		$stringToParse =~ s/\&\#8482\;/\&trade\;/gs;
		$stringToParse =~ s/\&\#8491\;/\&Aring\;/gs;
		$stringToParse =~ s/\&\#8501\;/\&alefsym\;/gs;
		$stringToParse =~ s/\&\#8592\;/\&larr\;/gs;
		$stringToParse =~ s/\&\#8593\;/\&uarr\;/gs;
		$stringToParse =~ s/\&\#8594\;/\&rarr\;/gs;
		$stringToParse =~ s/\&\#8595\;/\&darr\;/gs;
		$stringToParse =~ s/\&\#8596\;/\&harr\;/gs;
		$stringToParse =~ s/\&\#8629\;/\&crarr\;/gs;
		$stringToParse =~ s/\&\#8656\;/\&lArr\;/gs;
		$stringToParse =~ s/\&\#8657\;/\&uArr\;/gs;
		$stringToParse =~ s/\&\#8658\;/\&rArr\;/gs;
		$stringToParse =~ s/\&\#8659\;/\&dArr\;/gs;
		$stringToParse =~ s/\&\#8660\;/\&hArr\;/gs;
	
		$stringToParse =~ s/\&\#8704\;/\&forall\;/gs;
		$stringToParse =~ s/\&\#8706\;/\&part\;/gs;
		$stringToParse =~ s/\&\#8707\;/\&exist\;/gs;
		$stringToParse =~ s/\&\#8709\;/\&empty\;/gs;
		$stringToParse =~ s/\&\#8711\;/\&nabla\;/gs;
		$stringToParse =~ s/\&\#8712\;/\&isin\;/gs;
		$stringToParse =~ s/\&\#8713\;/\&notin\;/gs;
		$stringToParse =~ s/\&\#8715\;/\&ni\;/gs;
		$stringToParse =~ s/\&\#8719\;/\&prod\;/gs;
		$stringToParse =~ s/\&\#8721\;/\&sum\;/gs;
		$stringToParse =~ s/\&\#8722\;/\&minus\;/gs;
		$stringToParse =~ s/\&\#8723\;/\&plusmn\;/gs;
		$stringToParse =~ s/\&\#8727\;/\&lowast\;/gs;
		$stringToParse =~ s/\&\#8730\;/\&radic\;/gs;
		$stringToParse =~ s/\&\#8733\;/\&prop\;/gs;
		$stringToParse =~ s/\&\#8734\;/\&infin\;/gs;
		$stringToParse =~ s/\&\#8736\;/\&ang\;/gs;
		$stringToParse =~ s/\&\#8741\;/\&par\;/gs;
		$stringToParse =~ s/\&\#8743\;/\&and\;/gs;
		$stringToParse =~ s/\&\#8744\;/\&or\;/gs;
		$stringToParse =~ s/\&\#8745\;/\&cap\;/gs;
		$stringToParse =~ s/\&\#8746\;/\&cup\;/gs;
		$stringToParse =~ s/\&\#8747\;/\&int\;/gs;
		$stringToParse =~ s/\&\#8756\;/\&there4\;/gs;
		$stringToParse =~ s/\&\#8764\;/\&sim\;/gs;
		$stringToParse =~ s/\&\#8771\;/\&simeq\;/gs;
		$stringToParse =~ s/\&\#8773\;/\&cong\;/gs;		

		##	Incorrect definition in XML spec? asymp should be approx
		##	$stringToParse =~ s/\&\#8776\;/\&asymp\;/gs;
		$stringToParse =~ s/\&\#8776\;/\&approx\;/gs;

		$stringToParse =~ s/\&\#8800\;/\&ne\;/gs;
		$stringToParse =~ s/\&\#8801\;/\&equiv\;/gs;
		$stringToParse =~ s/\&\#8804\;/\&le\;/gs;
		$stringToParse =~ s/\&\#8805\;/\&ge\;/gs;
		$stringToParse =~ s/\&\#8806\;/\&leqq\;/gs;
		$stringToParse =~ s/\&\#8834\;/\&sub\;/gs;
		$stringToParse =~ s/\&\#8835\;/\&sup\;/gs;
		$stringToParse =~ s/\&\#8836\;/\&nsub\;/gs;
		$stringToParse =~ s/\&\#8838\;/\&sube\;/gs;
		$stringToParse =~ s/\&\#8839\;/\&supe\;/gs;
		$stringToParse =~ s/\&\#8853\;/\&oplus\;/gs;
		$stringToParse =~ s/\&\#8855\;/\&otimes\;/gs;
		$stringToParse =~ s/\&\#8869\;/\&perp\;/gs;
		$stringToParse =~ s/\&\#8900\;/\&diamond\;/gs;
		$stringToParse =~ s/\&\#8901\;/\&sdot\;/gs;
		$stringToParse =~ s/\&\#8902\;/\&star\;/gs;
		$stringToParse =~ s/\&\#8968\;/\&lceil\;/gs;
		$stringToParse =~ s/\&\#8969\;/\&rceil\;/gs;
		$stringToParse =~ s/\&\#8970\;/\&lfloor\;/gs;
		$stringToParse =~ s/\&\#8971\;/\&rfloor\;/gs;
		$stringToParse =~ s/\&\#9001\;/\&lang\;/gs;
		$stringToParse =~ s/\&\#9002\;/\&rang\;/gs;
		$stringToParse =~ s/\&\#9633\;/\&square\;/gs;
		$stringToParse =~ s/\&\#9674\;/\&loz\;/gs;
		$stringToParse =~ s/\&\#9824\;/\&spades\;/gs;
		$stringToParse =~ s/\&\#9827\;/\&clubs\;/gs;
		$stringToParse =~ s/\&\#9829\;/\&hearts\;/gs;
		$stringToParse =~ s/\&\#9830\;/\&diams\;/gs;
	
		$stringToParse =~ s/\&\#10216\;/\&lang\;/gs;
		$stringToParse =~ s/\&\#10217\;/\&rang\;/gs;
		$stringToParse =~ s/\&\#10877\;/\&les\;/gs;
		$stringToParse =~ s/\&\#10878\;/\&ges\;/gs;
		$stringToParse =~ s/\&\#10885\;/\&lesssim\;/gs;
		$stringToParse =~ s/\&\#10886\;/\&gtrsim\;/gs;
		
		#	f-ligatures
		$stringToParse =~ s/\&\#64256\;/ff/gs;
		$stringToParse =~ s/\&\#64257\;/fi/gs;
		$stringToParse =~ s/\&\#64258\;/fl/gs;
		$stringToParse =~ s/\&\#64259\;/ffi/gs;
		$stringToParse =~ s/\&\#64260\;/ffl/gs;
	
	
		##	See G:/prod/XML/DTD/ent/mmlalias.ent and mmlextra.ent for meaning 
		##	of entity numbers in the higher ranges
	
		$stringToParse =~ s/\&\#58103\;/\&Gt\;/gs;

		##	Combining accents
		$stringToParse =~ s/([A-Za-z])(\&)((?:grave|acute|circ|tilde|macr|breve|dot|ring|dblac|caron|dblgr|ogon|uml)\;)/$2$1$3/g;
		$stringToParse =~ s/\&inodot\;\&((?:grave|acute|circ|tilde|macr|breve|dot|ring|dblac|caron|dblgr|ogon|uml)\;)/\&i$1/g;

	}	

	return $stringToParse;

}

sub get_annotations {
	my $doi = shift;
	$annotation_query =~ s|__DOI__|$doi|;
	my $terms = &sparqlQuery($annotation_query, $endpoint, $output, $limit);
	my @terms = split("[\n\r]", $terms);
	shift @terms;
	my @status;
	return 0 unless scalar(@terms >= 1);
	for my $i (0..$#terms) {
		my ($a, $t, $s) = split ("\t", $terms[$i]);
		$t =~ s/"//g;
		$s =~ s/"//g;
		$terms[$i] = $t;
		$status[$i] = $s;
	}
	return (\@terms, \@status);
}

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