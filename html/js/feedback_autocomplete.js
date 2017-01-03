
$(function() {

	$( "#term1" ).autocomplete(
	{
		 source:"http://localhost/cgi-bin/thes_query.pl",
		 minLength:2
	});
});	