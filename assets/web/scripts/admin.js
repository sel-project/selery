
function post(action, data, success) {
	data.action = action;
	var request = new XMLHttpRequest();
	request.overrideMimeType("application/json");
	request.open("POST", "/", true);
	request.onload = function(){
		success(JSON.parse(request.responseText));
	};
	request.send(JSON.stringify(data));
}

window.onload = function(){
	const key = document.cookie.substr(4);
	post("get_info", {}, function(data){ console.log(data); });
}
