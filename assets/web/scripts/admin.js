
var current_tab;

var animation;
var animation_dots;

var server = null;
var connected = false;

var worlds = {};
var players = {};

var next_id;
var commands = {};
var logs = {};

window.onload = function(){
	if(location.hash !== "#app") {
		document.getElementById("close").style.display = "none";
		document.getElementById("conn_todo").style.display = "none";
		document.getElementById("retry").style.display = "block";
	}
	function setOnClick(button, tab) {
		button.onclick = function(){ changeView(tab); };
	}
	var tabs = document.getElementsByClassName("tab_button");
	for(var i=0; i<tabs.length; i++) {
		var tab = tabs[i];
		var name = tab.id.substr(0, tab.id.indexOf("_"));
		setOnClick(tab, name);
		if(tab.classList.contains("selected")) {
			current_tab = name;
		}
	}
	next_id = Math.round(Math.random() * 2000000 + 10000);
	document.getElementById("console_input_text").onkeydown = function(event){
		if(event.keyCode == 13) {
			var issued = event.target.value;
			server.send(JSON.stringify({id: "command", command: issued, command_id: next_id}));
			commands[next_id] = issued;
			event.target.value = "";
			next_id++;
		}
	}
	connect();
}

function changeView(tab) {
	if(tab != current_tab) {
		console.log(tab);
		document.getElementById(current_tab).style.display = "none";
		document.getElementById(current_tab + "_button").classList.remove("selected");
		document.getElementById(tab).style.display = "block";
		document.getElementById(tab + "_button").classList.add("selected");
		current_tab = tab;
	}
}

function connect() {
	if(server != null) return;
	document.title = document.getElementById("alert_title").innerHTML = TITLE_CONNECTING;
	document.getElementById("alert").style.display = "none";
	document.getElementById("loading").style.display = "block";
	animation_dots = "";
	animation = setInterval(function(){
		if(animation_dots.length == 3) animation_dots = "";
		else animation_dots += ".";
		document.getElementById("connecting_text").innerHTML = TITLE_CONNECTING + animation_dots;
	}, 200);
	server = new WebSocket("ws://" + location.host);
	server.onerror = error;
	server.onclose = error;
	server.onopen = function(){
		clearInterval(animation);
		connected = true;
		document.getElementById("loading").style.display = "none";
		document.getElementById("main").style.display = "block";
		//TODO reset data
	}
	server.onmessage = handleHub;
}

function error(event) {
	clearInterval(animation);
	document.title = document.getElementById("alert_title").innerHTML = TITLE_ERROR;
	document.getElementById("loading").style.display = "none";
	document.getElementById("main").style.display = "none";
	document.getElementById("alert").style.display = "block";
	if(connected) {
		document.getElementById("conn_closed").style.display = "block";
		document.getElementById("conn_error").style.display = "none";
	} else {
		document.getElementById("conn_error").style.display = "block";
		document.getElementById("conn_closed").style.display = "none";
	}
	server = null;
	connected = false;
}

function handleHub(event) {
	var json = JSON.parse(event.data);
	console.log(json);
	switch(json.packet) {
		case "settings":
			
			break;
		case "add_world":
			worlds[json.id] = {id: json.id, name: json.name, dimension: json.dimension, parent: json.parent || -1};
			//TODO update list
			break;
		case "remove_world":
			delete worlds[json.id];
			//TODO update list
			break;
		case "add_player":
		
			break;
		case "remove_player":
		
			break;
		case "log":
			var cm = document.getElementById("console_messages");
			var scroll = cm.scrollTop + cm.offsetHeight == cm.scrollHeight; // scrolled by user
			var message = document.createElement("p");
			message.classList.add("console_message");
			message.innerText = json.log;
			message.innerHTML = format(message.innerHTML);
			//TODO popup event info
			cm.appendChild(message);
			if(scroll) cm.scrollTop = cm.scrollHeight;
			break;
		default:
			break;
	}
}
