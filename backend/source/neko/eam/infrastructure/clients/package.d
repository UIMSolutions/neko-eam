/// Technical HTTP / API clients for external services.
module neko.eam.infrastructure.clients;

import std.conv : to;
import vibe.data.json;
import vibe.http.client : requestHTTP;
import vibe.http.common : HTTPMethod;
import vibe.stream.operations : readAllUTF8;

/// Small OData v4 client, used by the CLI `--remote` option to talk to a running EAM server.
class ODataClient {
	private string _serviceRoot, _authorization;

	this(string serviceRoot, string authorization = null) {
		_serviceRoot = serviceRoot.length && serviceRoot[$ - 1] == '/' ? serviceRoot : serviceRoot ~ "/";
		_authorization = authorization;
	}

	Json get(string path) { return call(HTTPMethod.GET, path, Json.undefined); }
	Json post(string path, Json body) { return call(HTTPMethod.POST, path, body); }
	Json patch(string path, Json body) { return call(HTTPMethod.PATCH, path, body); }
	void remove(string path) { call(HTTPMethod.DELETE, path, Json.undefined); }

	private Json call(HTTPMethod method, string path, Json body) {
		Json result;
		requestHTTP(_serviceRoot ~ path, (scope req) {
			req.method = method;
			req.headers["Accept"] = "application/json";
			if (_authorization.length) req.headers["Authorization"] = _authorization;
			if (body.type != Json.Type.undefined) req.writeJsonBody(body);
		}, (scope res) {
			auto text = res.bodyReader.readAllUTF8();
			if (res.statusCode >= 400) {
				string msg = text;
				try msg = parseJsonString(text)["error"]["message"].get!string; catch (Exception) {}
				throw new Exception("HTTP " ~ res.statusCode.to!string ~ ": " ~ msg);
			}
			result = text.length ? parseJsonString(text) : Json.undefined;
		});
		return result;
	}
}
