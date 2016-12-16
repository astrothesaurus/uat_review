
$(function() {

	$( "#term1" ).autocomplete(
	{
		 source:"http://corichi/cgi-bin/sam_query.pl",
		 minLength:2
	});
});	