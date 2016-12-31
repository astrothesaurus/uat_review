
$(function() {

	$( "#search_term" ).autocomplete(
	{
		 source:"http://localhost:8888/cgi-bin/uat_query.pl",
		 minLength:2
	});
});	