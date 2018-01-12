
function format(str) {
	var f = str;
	f = f.replace(/\u00A70|{black}/gmi, "<span style='color:#000'>");
	f = f.replace(/\u00A71|{dark_blue}/gmi, "<span style='color:#00A'>");
	f = f.replace(/\u00A72|{dark_green}/gmi, "<span style='color:#0A0'>");
	f = f.replace(/\u00A73|{dark_aqua}/gmi, "<span style='color:#0AA'>");
	f = f.replace(/\u00A74|{dark_red}/gmi, "<span style='color:#A00'>");
	f = f.replace(/\u00A75|{dark_purple}/gmi, "<span style='color:#A0A'>");
	f = f.replace(/\u00A76|{gold}/gmi, "<span style='color:#FA0'>");
	f = f.replace(/\u00A77|{gray}/gmi, "<span style='color:#AAA'>");
	f = f.replace(/\u00A78|{dark_gray}/gmi, "<span style='color:#555'>");
	f = f.replace(/\u00A79|{blue}/gmi, "<span style='color:#55F'>");
	f = f.replace(/\u00A7a|{green}/gmi, "<span style='color:#5F5'>");
	f = f.replace(/\u00A7b|{aqua}/gmi, "<span style='color:#5FF'>");
	f = f.replace(/\u00A7c|{red}/gmi, "<span style='color:#F55'>");
	f = f.replace(/\u00A7d|{light_purple}/gmi, "<span style='color:#F5F'>");
	f = f.replace(/\u00A7e|{yellow}/gmi, "<span style='color:#FF5'>");
	f = f.replace(/\u00A7f|{white}/gmi, "<span style='color:#FFF'>");
	f = f.replace(/\u00A7l|\u00A7m|{bold}/gmi, "<span style='font-weight:bold'>");
	f = f.replace(/\u00A7r|{normal}/gmi, "</span>");
	f = f.replace(/\u00A7k|\u00A7o|\u00A7n/gmi, "");
	var matches = f.match(/<span/g);
	for(var i in matches) {
		f += "</span>";
	}
	return f;
}

function unformat(str) {
	return str.replace(/\u00A7[a-fA-F0-9k-or]/gmi, "");
}
