#!/usr/bin/perl

use strict; 
use CGI qw /:standard/; 
use LWP::UserAgent; 
use Data::Dumper;
use URI::Escape;
use HTML::Entities;
use LWP::Simple qw(get);

my $output = "text";
my $endpoint = "http://localhost:8080/sparql/";
my $limit = -1;

my $live_cs = "http://services.iop.org/content-service";
my $metadata_url = $live_cs . "/article/doi/__DOI__?header_accept=application%2Fvnd.iop.org.header%2Bxml";
# http://dev.services.iop.org/content-service/book/isbn/978-1-6270-5481-2/book-part/CHAPTER/bk978-1-6270-5481-2ch1
# chapter metadata (title, DOI) is in the book-level XML; don't need to go to chapter level
my $book_metadata_url = $live_cs . "/book/isbn/";

my $id_query = <<EOQ;
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?doi WHERE {
 graph <http://data.iop.org/doi2id> {
 <http://iopscience.iop.org/__ID__> ioprdf:hasDOI ?doi .
}
}
EOQ

my $doi_query = <<EOQ;
PREFIX ioprdf: <http://rdf.iop.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT DISTINCT ?id WHERE {
 graph <http://data.iop.org/doi2id> {
 ?id ioprdf:hasDOI <http://dx.doi.org/__DOI__> .
}
}
EOQ

sub sparqlQuery(@) {
	my $query=shift;
	my $baseURL=shift;
	my $format=shift;
	# print STDERR $query;
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

my $q = CGI->new();
my $doi = $q->param('doi') || 0;
my $id = $q->param('id') || 0;

if ($doi) {
	$doi_query =~ s/__DOI__/$doi/;
	my $data = sparqlQuery($doi_query, $endpoint, $output);
	my @data = split("[\n\r]", $data);
	# print STDERR "$data, @data\n";
	if ($#data == 0) {
		# DOI not found
		# query using the old method, then populate the 
		# database and return the found value
		# print STDERR "DOI $doi not recognised\n";
		my $id = get_id($doi);
		$id =~ s/journals://;
		if (add_entry($id, $doi)) {
			print_success_message($id);
		}
		else {
			print_failure_message("ID: $id / DOI: $doi\nUnable to add entry to database");
		}
	}
	elsif ($#data == 1) {
		# found a hit
		# return it
		my $id;
		if ($data[1] =~ m/chapter/) {
			($id) = $data[1] =~ m|http://iopscience.iop.org/(?:chapter/[\dX-]+/)?([^">/]+)|;
		}
		else {
			($id) = $data[1] =~ m|http://iopscience.iop.org/([^">]+)|;
		}
		print_success_message($id);
	}
	else {
		# have more than 1 row returned
		# this should never happen!
		print_failure_message("ID: $id / DOI: $doi\nMultiple entries found for DOI");
		# print STDERR Dumper($data);
	}
}
elsif ($id) {
	$id =~ s/(books|journals)://;
	# print STDERR "doi2id: $id requested\n";
	my $t_id = $id;
	if ($id =~ m/978-[\dX-]+/) {
		my ($isbn) = $id =~ m/(978-[\dX-]+)/;
		$t_id = "chapter/$isbn/$id";
	}
	$id_query =~ s/__ID__/$t_id/;
	my $data = sparqlQuery($id_query, $endpoint, $output);
	my @data = split("[\n\r]", $data);
	if ($#data == 0) {
		print STDERR "doi2id: $t_id not found\n";
		# DOI not found
		# query using the old method, then populate the 
		# database and return the found value
		my $doi = get_doi($id);
		if ($doi) {
			$doi =~ s/doi://;
			if (add_entry($id, $doi)) {
				print_success_message($doi);
				print STDERR "Added $doi | $id to database\n";
			}
			else {
				print_failure_message("ID: $id / DOI: $doi\nUnable to add entry to database");
			}
		}
		else {
				print_failure_message("ID: $id / DOI: $doi\nUnable to find DOI");
		}
	}
	elsif ($#data == 1) {
		print STDERR "doi2id: $id DOI match found\n";
		# print STDERR "doi2id: " . $data[1] . "\n";
		# found a hit
		# return it
		my ($doi) = $data[1] =~ m|http://dx.doi.org/([^">]+)|;
		print_success_message($doi);
	}
	else {
		# have more than 1 row returned
		# this should never happen!
		print_failure_message("ID: $id / DOI: $doi\nMultiple entries found for ID");
		print STDERR Dumper($data);
	}
}
else {
	print_failure_message("ID: $id / DOI: $doi\nNo ID or DOI provided");
}

sub print_failure_message {
	my $doi = shift;
	print <<END_OF_HTML;
Status: 400 Bad Request
Content-type: text/html

<HTML>
<HEAD><TITLE>400 Bad Request</TITLE></HEAD>
<BODY>
  <H1>Error</H1>
  <P>Unable to find ID/DOI for $doi</P>
</BODY>
</HTML>
END_OF_HTML
	exit;
}

sub print_success_message {
	my $data = shift;
	print <<END_OF_HTML;
Status: 200 OK
Content-type: text/html

$data
END_OF_HTML
}

sub add_entry {
	my ($id, $doi) = @_;
	my $rdf;
	if ($id =~ m/\d{4}-\d{3}[0-9X]/) {
		$rdf = "<http://iopscience.iop.org/$id> <http://rdf.iop.org/hasDOI> <http://dx.doi.org/$doi> . ";
	}
	elsif ($id =~ m/978-[\dX-]+/) {
		my ($isbn) = $id =~ m/bk([\dX-]+)(?:ch\d+)?/;
		$rdf = "<http://iopscience.iop.org/chapter/$isbn/$id> <http://rdf.iop.org/hasDOI> <http://dx.doi.org/$doi> . ";
	}
	my $ua = LWP::UserAgent->new();
	my $update_ep = "http://localhost:8080/data/";
	my $content = "graph=http://data.iop.org/doi2id&mime-type=application/x-turtle&data=" . uri_escape_utf8($rdf);
	# print $q->comment($content) . "\n";
	my $response = $ua->post(
		$update_ep,
		Content => $content
		);
	unless ($response->is_success()) {
		print STDERR Dumper($response);
		return 0;
	}
	else {
		print STDERR "$rdf\n$content\n";
		return 1;
	}
}

sub get_id {
	my $doi = shift;
	my $docid;
	if ($doi =~ m|/978-|) {
		my ($isbn) = $doi =~ m|(978[\dX-]+)(?:ch\d+)?|;
		my $metadata = get($book_metadata_url . $isbn);
		if ($metadata) {
			my ($chapter_meta) = $metadata =~ m|(<book:chapter.*?<book:meta[^>]*doi="$doi".*?</book:chapter>)|s;
			($docid) = $chapter_meta =~ m|<book:chapter.*?id="([^"]+)|s;
				print STDERR "doi2id.pl: No ID found in metadata: $isbn\n" . length($metadata) . "\n" . length($chapter_meta) . "\n" unless $docid;
		}
		else {
			print STDERR "doi2id.pl: Failure to get chapter metadata: $doi|$isbn\n";
		}	
	}
	else {
		$metadata_url =~ s/__DOI__/$doi/;
		my $metadata = get($metadata_url);
		$docid = format_metadata($metadata);
	}
	return $docid;
}

sub get_doi {
	my $docid = shift;
	my $doi;
	if ($docid =~ m!(books:|978-)!) {
		$docid =~ s/books://;
		print STDERR "doi2id.pl: checking for DOI: $docid\n";
		my ($isbn) = $docid =~ m|([\dX-]+)(ch\d+)?|;
		my $metadata = get($book_metadata_url . $isbn);
		if ($metadata) {
			if ($metadata =~ m/$docid/) {
				my ($chapter_meta) = $metadata =~ m|(<book:chapter.*?id="$docid".*?</book:chapter>)|s;
				($doi) = $chapter_meta =~ m|<book:meta.*?doi="([^"]+)"|s;
				print STDERR "doi2id.pl: No DOI found in metadata:\n" . length($metadata) . "\n" . length($chapter_meta) . "\n" unless $doi;
			}
			else {
				print STDERR "doi2id.pl: Couldn't find ID in metadata!\n";
			}
		}
		else {
			print STDERR "doi2id.pl: Failure to get chapter metadata: $doi\n";
		}
	}
	else {
		$docid =~ s/journals://gs;
		$docid = "http://iopscience.iop.org/" . $docid;
		# print STDERR "doi2id: requesting $docid\n";
		my $result = get($docid);
		if ($result) {
			if ($result =~ m/<meta\s*name="dc\.identifier"\s*content="([^"]+)"/) {
				# print STDERR "doi2id: regex matched dc.identifier\n";
				($doi) = $result =~ m|<meta\s*name="dc\.identifier"\s*content="([^"]+)"/?>|igs;
				# print STDERR "doi2id: got DOI ($doi)\n";
			# print STDERR "$result\n" unless $doi;
			}
			else {
				# print STDERR "doi2id: Regex didn't match dc.identifier\n";
			}
		}
		else {
			# print STDERR "doi2id: Unable to get $docid\n";
		}
	}
	return $doi;# if $doi;
	# return 0;
}

sub format_metadata {
	my $m = shift;
	my ($issn, $vol, $issue, $art);
	($issn) = $m =~ m|<issn[^>]*>(.*)</issn>|s;
	($vol) = $m =~ m|<volume[^>]*>(.*)</volume>|s;
	($issue) = $m =~ m|<issue[^>]*>(.*)</issue>|s;
	($art) = $m =~ m|<artnum[^>]*>(.*)</artnum>|s;
	return join("/", $issn, $vol, $issue, $art);
}
