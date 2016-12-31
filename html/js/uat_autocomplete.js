
$(function() {

	$( "#search_term" ).autocomplete(
	{
		 source:"http://localhost/cgi-bin/uat_query.pl",
		 minLength:2
	});
});	