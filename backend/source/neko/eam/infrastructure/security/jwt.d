/// Minimal JWT (RS256) decoding and verification for XSUAA access tokens.
module neko.eam.infrastructure.security.jwt;

import std.algorithm : splitter, canFind;
import std.array : array;
import std.base64 : Base64URLNoPadding;
import std.datetime : Clock;
import std.string : representation, toStringz;
import vibe.data.json;

class TokenException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow { super(msg, file, line); }
}

struct JwtToken {
	Json header;
	Json payload;
	string signingInput;
	ubyte[] signature;

	string[] scopes() {
		string[] r;
		if (payload["scope"].type == Json.Type.array)
			foreach (s; payload["scope"]) r ~= s.get!string;
		return r;
	}

	/// String claim of the payload ("" if missing).
	string claim(string name) {
		auto v = payload[name];
		return v.type == Json.Type.string ? v.get!string : "";
	}

	string subject() {
		foreach (k; ["user_name", "email", "sub"])
			if (payload[k].type == Json.Type.string) return payload[k].get!string;
		return "anonymous";
	}
}

JwtToken decodeJwt(string token) {
	auto parts = token.splitter('.').array;
	if (parts.length != 3) throw new TokenException("Malformed JWT");
	JwtToken t;
	try {
		t.header = parseJsonString(cast(string) Base64URLNoPadding.decode(stripPadding(parts[0])));
		t.payload = parseJsonString(cast(string) Base64URLNoPadding.decode(stripPadding(parts[1])));
		t.signature = Base64URLNoPadding.decode(stripPadding(parts[2]));
	} catch (Exception e) throw new TokenException("Malformed JWT: " ~ e.msg);
	t.signingInput = parts[0] ~ "." ~ parts[1];
	return t;
}

private string stripPadding(string s) {
	while (s.length && s[$ - 1] == '=') s = s[0 .. $ - 1];
	return s;
}

/// Verifies signature (RS256 with PEM public key), expiry and audience/client.
void verifyJwt(ref JwtToken t, string publicKeyPem, string expectedClientId) {
	if (t.header["alg"].opt!string("") != "RS256")
		throw new TokenException("Unsupported JWT algorithm");
	if (!verifyRs256(t.signingInput, t.signature, publicKeyPem))
		throw new TokenException("Invalid JWT signature");
	auto exp = t.payload["exp"];
	if (exp.type != Json.Type.int_ || exp.get!long < Clock.currTime().toUnixTime())
		throw new TokenException("JWT expired");
	if (expectedClientId.length) {
		bool ok = t.payload["cid"].opt!string("") == expectedClientId
			|| t.payload["azp"].opt!string("") == expectedClientId;
		if (!ok && t.payload["aud"].type == Json.Type.array)
			foreach (a; t.payload["aud"]) ok = ok || a.get!string == expectedClientId;
		if (!ok) throw new TokenException("JWT audience mismatch");
	}
}

/// RSA-SHA256 signature check via OpenSSL EVP.
bool verifyRs256(string signingInput, const(ubyte)[] signature, string publicKeyPem) {
	import deimos.openssl.bio;
	import deimos.openssl.evp;
	import deimos.openssl.pem;
	if (publicKeyPem.length == 0) return false;
	auto pem = normalizePem(publicKeyPem);
	auto bio = BIO_new_mem_buf(cast(void*) pem.ptr, cast(int) pem.length);
	if (bio is null) return false;
	scope (exit) BIO_free(bio);
	auto key = PEM_read_bio_PUBKEY(bio, null, null, null);
	if (key is null) return false;
	scope (exit) EVP_PKEY_free(key);
	auto ctx = EVP_MD_CTX_new();
	if (ctx is null) return false;
	scope (exit) EVP_MD_CTX_free(ctx);
	if (EVP_DigestVerifyInit(ctx, null, EVP_sha256(), null, key) != 1) return false;
	if (EVP_DigestVerifyUpdate(ctx, signingInput.ptr, signingInput.length) != 1) return false;
	return EVP_DigestVerifyFinal(ctx, cast(ubyte*) signature.ptr, signature.length) == 1;
}

/// XSUAA delivers the key on a single line - restore PEM line breaks.
private string normalizePem(string pem) {
	import std.string : replace, strip;
	enum begin = "-----BEGIN PUBLIC KEY-----", end = "-----END PUBLIC KEY-----";
	auto body = pem.replace(begin, "").replace(end, "").replace("\\n", "").replace("\n", "").replace(" ", "").strip;
	string r = begin ~ "\n";
	for (size_t i = 0; i < body.length; i += 64)
		r ~= body[i .. i + 64 > body.length ? body.length : i + 64] ~ "\n";
	return r ~ end ~ "\n";
}

unittest {
	// header {"alg":"RS256"} payload {"scope":["eam.Display"],"user_name":"u"}
	auto t = decodeJwt("eyJhbGciOiJSUzI1NiJ9.eyJzY29wZSI6WyJlYW0uRGlzcGxheSJdLCJ1c2VyX25hbWUiOiJ1In0.AAAA");
	assert(t.scopes == ["eam.Display"] && t.subject == "u");
	bool failed;
	try verifyJwt(t, "", ""); catch (TokenException) failed = true;
	assert(failed, "signature must be rejected without a key");
}
