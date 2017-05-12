module sel.network.http;

import std.concurrency : Tid, send;
import std.conv : to;
import std.socket;
import std.string : indexOf, startsWith;
import std.random : uniform;

void serveResourcePacks(Tid server, string pack2, string pack3) {

	auto port = uniform(ushort(999), ushort.max);

	auto socket = new TcpSocket();
	socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
	socket.bind(new InternetAddress("0.0.0.0", port));
	socket.listen(16);
	socket.blocking = true;

	send(server, port);

	char[] buffer = new char[6];

	const(void)[] response2 = "HTTP/1.1 200 OK\r\nServer: SEL\r\nContent-Type: application/zip\r\nContent-Length: " ~ to!string(pack2.length) ~ "\r\n\r\n" ~ pack2;
	const(void)[] response3 = "HTTP/1.1 200 OK\r\nServer: SEL\r\nContent-Type: application/zip\r\nContent-Length: " ~ to!string(pack3.length) ~ "\r\n\r\n" ~ pack3;

	while(true) {

		//TODO create a non-blocking handler

		auto client = socket.accept();

		auto r = client.receive(buffer);
		if(r > 0) {
			if(buffer[0..5] == "GET /") {
				if(buffer[5] == '2') client.send(response2);
				else if(buffer[5] == '3') client.send(response3);
				else client.close();
			}
		}

	}

}
