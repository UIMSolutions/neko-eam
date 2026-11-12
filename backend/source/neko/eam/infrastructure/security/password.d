/// Password hashing for the local sign-in: PBKDF2-HMAC-SHA256 (OpenSSL) with a random 16 byte salt.
///
/// Encoded as `pbkdf2-sha256$<iterations>$<salt base64url>$<hash base64url>`, so the work factor can be
/// raised later: hashes with fewer iterations are re-hashed after the next successful sign-in.
module neko.eam.infrastructure.security.password;

import std.algorithm : splitter;
import std.array : array;
import std.base64 : Base64URLNoPadding;
import std.conv : to;
import neko.eam.ports.services : IPasswordHasher;

/// Cryptographically secure random bytes (OpenSSL); throws if the RNG is not available.
ubyte[] secureRandomBytes(size_t n) @trusted {
	import deimos.openssl.rand : RAND_bytes;
	auto buf = new ubyte[n];
	if (RAND_bytes(buf.ptr, cast(int) n) != 1) throw new Exception("No secure random numbers available");
	return buf;
}

/// Random token for session ids and CSRF tokens (base64url, `bytes` of entropy).
string randomToken(size_t bytes = 32) @trusted {
	return Base64URLNoPadding.encode(secureRandomBytes(bytes)).idup;
}

/// Constant-time comparison (length is not secret).
bool constantTimeEquals(const(ubyte)[] a, const(ubyte)[] b) @trusted {
	import deimos.openssl.crypto : CRYPTO_memcmp;
	return a.length == b.length && (a.length == 0 || CRYPTO_memcmp(a.ptr, b.ptr, a.length) == 0);
}

class Pbkdf2PasswordHasher : IPasswordHasher {
	enum scheme = "pbkdf2-sha256";
	/// Work factor; a sign-in costs about 50 ms of CPU on current hardware.
	enum uint defaultIterations = 120_000;
	enum size_t saltBytes = 16, hashBytes = 32;

	private uint _iterations;

	this(uint iterations = defaultIterations) { _iterations = iterations; }

	string hash(string password) {
		auto salt = secureRandomBytes(saltBytes);
		return encode(_iterations, salt, derive(password, salt, _iterations));
	}

	bool verify(string password, string encoded) {
		Parsed p;
		if (!parse(encoded, p)) return false;
		return constantTimeEquals(derive(password, p.salt, p.iterations), p.hash);
	}

	bool needsRehash(string encoded) {
		Parsed p;
		return !parse(encoded, p) || p.iterations < _iterations;
	}

	private struct Parsed { uint iterations; ubyte[] salt; ubyte[] hash; }

	private static bool parse(string encoded, out Parsed p) {
		auto parts = encoded.splitter('$').array;
		if (parts.length != 4 || parts[0] != scheme) return false;
		try {
			p.iterations = parts[1].to!uint;
			p.salt = Base64URLNoPadding.decode(parts[2]);
			p.hash = Base64URLNoPadding.decode(parts[3]);
		} catch (Exception) return false;
		return p.iterations >= 1000 && p.iterations <= 10_000_000 && p.salt.length >= 8 && p.hash.length == hashBytes;
	}

	private static string encode(uint iterations, const(ubyte)[] salt, const(ubyte)[] hash) {
		return scheme ~ "$" ~ iterations.to!string ~ "$" ~ Base64URLNoPadding.encode(salt).idup ~ "$"
			~ Base64URLNoPadding.encode(hash).idup;
	}

	private static ubyte[] derive(string password, const(ubyte)[] salt, uint iterations) @trusted {
		import deimos.openssl.evp : EVP_sha256, PKCS5_PBKDF2_HMAC;
		auto key = new ubyte[hashBytes];
		if (PKCS5_PBKDF2_HMAC(password.ptr, cast(int) password.length, salt.ptr, cast(int) salt.length,
				cast(int) iterations, EVP_sha256(), cast(int) key.length, key.ptr) != 1)
			throw new Exception("Password hashing failed");
		return key;
	}
}

unittest {
	auto h = new Pbkdf2PasswordHasher(2000);
	auto encoded = h.hash("correct horse 7");
	assert(h.verify("correct horse 7", encoded));
	assert(!h.verify("correct horse 8", encoded));
	assert(h.hash("correct horse 7") != encoded, "salted");
	assert(!h.needsRehash(encoded) && new Pbkdf2PasswordHasher(4000).needsRehash(encoded));
	foreach (bad; ["", "plain", "pbkdf2-sha256$x$a$b", "md5$1000$AAAAAAAAAAA$AAAA"]) assert(!h.verify("x", bad));
	// RFC 7914 / well-known PBKDF2-HMAC-SHA256 vector: P="password", S="salt", c=1, dkLen=32
	auto v = Pbkdf2PasswordHasher.derive("password", cast(const(ubyte)[]) "salt", 1);
	import std.digest : toHexString, LetterCase;
	assert(toHexString!(LetterCase.lower)(v) == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b");
	assert(constantTimeEquals([1, 2], [1, 2]) && !constantTimeEquals([1, 2], [1, 3]) && !constantTimeEquals([1], [1, 2]));
	assert(randomToken().length == 43 && randomToken() != randomToken());
}
