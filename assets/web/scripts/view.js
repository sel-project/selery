
const UPDATE_TIMEOUT = 3000;
const UNLIMITED = 4294967296;

var showed_player = null;

window.addEventListener("load", function(){
	if(location.hash != "") location.hash = "";
	var max_players = 0;
	function update_data(status) {
		window.lastStatus = status;
		if(status == null || status.length < 6) {
			document.getElementById("players").innerHTML = "0/" + max_players;
			document.getElementById("players_list").style.display = "none";
		} else {
			max_players = status[4] | (status[5] << 8) | (status[6] << 16) | (status[7] << 24);
			document.getElementById("players").innerHTML = (status[0] | (status[1] << 8) | (status[2] << 16) | (status[3] << 24)) + (max_players != UNLIMITED ? "/" + max_players : "");
			document.getElementById("players_list").style.display = status.length > 6 ? "" : "none";
			document.getElementById("players_list").innerHTML = "";
			status = status.slice(8);
			var players = [];
			var skins = 0;
			var decoder = new TextDecoder("utf-8");
			while(status.length) {
				var player = {id:-1, name:""};
				player.id = status[0] | (status[1] << 8) | (status[2] << 16) | (status[3] << 24);
				var length = status[4] | (status[5] << 8);
				var show_skin = length & 0x8000;
				length &= 0x7FFF;
				player.name = decoder.decode(status.slice(6, length + 6));
				status = status.slice(6 + length);
				if(show_skin) {
					skins++;
					player.skin = status.slice(0, 192);
					status = status.slice(192);
				}
				if(player.id >= 0 && player.name.length > 0) players.push(player);
			}
			var players = players.sort(function(a,b){ return unformat(a.name.toLowerCase()).localeCompare(unformat(b.name.toLowerCase())); });
			var list = "";
			for(var i in players) {
				list += "<a href='#" + players[i].id + "'>";
				if(players[i].skin) list += "<div style='display:inline-block;margin-top:-15px;margin-right:8px'>" + generate_image(players[i].skin, 2) + "</div>";
				list += format(players[i].name.replace(/ /g, "&nbsp;")) + "</a>" + (i != players.length - 1 ? ", " : "");
			}
			document.getElementById("players_list").innerHTML = list;
		}
		var online = status != null;
		if(showed_player != null) {
			online = false;
			for(var i in players) {
				if(players[i].id == showed_player) {
					online = true;
					break;
				}
			}
		}
		update_online_status(online);
	}
	function update_online_status(online) {
		if(online) {
			document.getElementById("status").innerHTML = "Online";
			document.getElementById("status").style.color = "#5F5";
		} else {
			document.getElementById("status").innerHTML = "Offline";
			document.getElementById("status").style.color = "#F55";
		}
	}
	function fetch_json() {
		var request = new XMLHttpRequest();
		request.open("GET", "/status", true);
		request.responseType = "arraybuffer";
		request.onload = function(){
			if(request.response) update_data(new Uint8Array(request.response));
		};
		request.onerror = function(){
			update_data(null);
		};
		request.onloadend = function(){
			setTimeout(fetch_json, UPDATE_TIMEOUT);
		};
		request.send();
	}
	document.body.innerHTML = document.body.innerHTML.replace(/{IP}/gm, location.hostname);
	fetch_json();
});

window.addEventListener("hashchange", function(){
	if(location.hash.length >= 1) {
		show_player(location.hash.substr(1));
	} else {
		hide_player();
	}
});

function show_player(player) {
	var request = new XMLHttpRequest();
	request.overrideMimeType("application/json");
	request.open("GET", "/player_" + player + ".json");
	request.onload = function(){
		showed_player = player;
		var json = JSON.parse(request.responseText.replace(/\n/g, ""));
		document.getElementById("server").style.display = "none";
		document.getElementById("player").style.display = "";
		document.getElementById("icon").style.display = "none";
		document.getElementById("player_pic").style.display = "inline-block";
		document.getElementById("player_pic").innerHTML = generate_image(json.skin ? toBinary(atob(json.skin)) : null, 16);
		document.getElementById("version").innerHTML = json.version;
		document.getElementById("player_name").innerHTML = format(json.display) + (json.name != json.display ? "<br><span style='font-size:16px'>" + json.name + "</span>" : "");
	};
	request.send();
}

function toBinary(text) {
	var ret = [];
	for(var i in text) {
		ret.push(text.charCodeAt(i));
	}
	return ret;
}

function generate_image(blob, size) {
	if(blob) {
		var ret = "";
		var pos = 0;
		for(var i=0; i<64; i++) {
			if(i % 8 == 0) ret += "<div style='width:" + size * 8 + "px;height:" + size + "px'>";
			ret += "<div style='display:inline-block;width:" + size + "px;height:" + size + "px;background:rgb(" + blob[pos++] + "," + blob[pos++] + "," + blob[pos++] + ")'></div>";
			if(i % 8 == 7) ret += "</div>";
		}
		return ret;
	} else {
		return "<div style='width:" + size * 8 + "px;height:" + size * 8 + "px;background:url(https://minepic.org/avatar/MHF_Steve) no-repeat center center;background-size:" + size * 8 + "px'></div>";
	}
}

function hide_player() {
	document.getElementById("server").style.display = "";
	document.getElementById("player").style.display = "none";
	document.getElementById("icon").style.display = "";
	document.getElementById("player_pic").style.display = "none";
	document.getElementById("player_name").innerHTML = "";
}
