function validateForm(form) {
	var returnValue = true;
	var returnValue2 = true;
	if (document.getElementById( "validated" ).value !== "1") {
		// alert("Not validated");
		var cbResults = 0;
		var cbCount = 0;
		var username = '';
		for (var i = 0; i < form.elements.length; i++ ) {
			if (form.elements[i].type == 'checkbox') {
				cbCount++;
				if (form.elements[i].checked == true) {
					cbResults += 1;
				}
			}
			else if (form.elements[i].name == 'username') {
				username = form.elements[i].value;
			}
		};
		if (cbResults == cbCount) {
			returnValue = confirm("Warning: No extracted terms are marked as correct.\n\nClick OK to continue, or Cancel to return to the form.");
		};
		
		if (username == '' && returnValue == true) { //  && returnValue == true
			returnValue2 = confirm("Warning: No username or email address supplied.\n\nClick OK to submit the form without this information, or Cancel to return to the form.");
		};
		if (returnValue == true && returnValue2 == true) {
			document.getElementById( "validated" ).value = "1";
		};
		if (returnValue2 == false) {
			returnValue = false;
		};
	};
	return returnValue;
}
