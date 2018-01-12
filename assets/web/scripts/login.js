
var logging_in = false;
var animation;

function login() {
	if(logging_in) return;
	logging_in = true;
	document.getElementById("login").style.display = "none";
	document.getElementById("loading").style.display = "block";
	animation = setInterval(function(){
		var lt = document.getElementById("loading_text");
		if(lt.innerHTML.endsWith("...")) lt.innerHTML = lt.innerHTML.substring(0,  lt.innerHTML.length - 3);
		else lt.innerHTML += ".";
	}, 250);
	var request = new XMLHttpRequest();
	request.overrideMimeType("application/json");
	request.open("POST", "/login", true);
	request.onload = function(){ handleResponse(JSON.parse(request.responseText)); };
	request.onerror = function(){ handleResponse({error: "network"}); };
	request.send(JSON.stringify({password: document.getElementById("password").value}));
}

function handleResponse(response) {
	if(response.success) {
		document.cookie = "key=" + response.key;
		location.reload();
	} else {
		logging_in = false;
		clearInterval(animation);
		document.getElementById("loading_text").innerHTML = document.getElementById("loading_text").innerHTML.replace(/\./g, "");
		document.getElementById("loading").style.display = "none";
		document.getElementById("error").style.display = "block";
		document.getElementById("error_text").innerHTML = (function(){
			switch(response.error) {
				case "wrong_password": return WRONG_PASSWORD;
				case "limit": return LIMIT_REACHED;
				case "network": return NETWORK_ERROR;
				default: return UNKNOWN_ERROR;
			}
		})();
	}
}

function retry() {
	document.getElementById("error").style.display = "none";
	document.getElementById("login").style.display = "block";
}

function unlock() {
	document.getElementById("locked").style.display = "none";
	document.getElementById("unlocked").style.display = "";
	document.getElementById("password").type = "text";
}

function lock() {
	document.getElementById("locked").style.display = "";
	document.getElementById("unlocked").style.display = "none";
	document.getElementById("password").type = "password";
}

window.onload = function(){
	document.getElementsByTagName("input")[0].onkeydown = function(event){
		if(event.keyCode == 13) login();
	}
}
