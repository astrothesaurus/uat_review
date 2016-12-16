
$(function() {

	$( "#search_term" ).autocomplete(
	{
		 source:"http://corichi/cgi-bin/uat_query.pl",
		 minLength:2
	});
});	