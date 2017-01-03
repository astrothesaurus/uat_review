
$(function() {

	$( "#term1" ).autocomplete(
	{
		 source:"http://localhost:8888/cgi-bin/thes_query.pl",
		 minLength:2
	});
});	