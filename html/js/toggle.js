function toggle(source) {
  checkboxes = document.getElementsByName('entities');
  for(var i=0, n=checkboxes.length;i<n;i++) {
    checkboxes[i].checked = source.checked;
  }
}

$(document).ready(function(){
  $("#sparql_input").hide();
  $("#hide").click(function(){
    $("#sparql_input").hide();
  });
  $("#show").click(function(){
    $("#sparql_input").show();
  });
});
