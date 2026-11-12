/// Server-side sessions of the local sign-in and the brute-force throttle of the sign-in form.
///
/// Sessions live in memory: a restart signs everybody out (like the single-process JSON storage, run one
/// instance). Each session expires after an idle time and after an absolute lifetime; expired sessions are
/// swept whenever a new one is created, so the store cannot grow without bound.
module neko.eam.infrastructure.security.sessions;

import core.time : Duration, minutes, hours, seconds;
import std.algorithm : min;
import std.datetime : Clock, SysTime;
import std.string : toLower;
import neko.eam.infrastructure.security.password : randomToken;

/// A signed-in browser session.
struct LoginSession {
	string id;
	string tenant;          /// tenant the user signed in to (users and passwords are per tenant)
	string userName;
	string email;
	string displayName;
	bool administrator;       /// built-in local administrator
	bool systemAdministrator; /// built-in local administrator
	bool mustChangePassword;  /// password was set by an administrator - the profile asks for a new one
	string csrfToken;
	SysTime createdAt;
	SysTime lastSeen;
}

class LoginSessionStore {
	private {
		LoginSession[string] _sessions;
		Duration _idle, _lifetime;
	}

	this(Duration idleTimeout = 60.minutes, Duration lifetime = 12.hours) {
		_idle = idleTimeout;
		_lifetime = lifetime;
	}

	Duration idleTimeout() const { return _idle; }

	/// Starts a new session (new id and CSRF token - never reuses an id offered by the client).
	LoginSession create(LoginSession data, SysTime now = Clock.currTime) {
		sweep(now);
		data.id = randomToken(32);
		data.csrfToken = randomToken(24);
		data.createdAt = data.lastSeen = now;
		_sessions[data.id] = data;
		return data;
	}

	/// The live session with `id` (its idle timer restarts); null if unknown or expired.
	LoginSession* touch(string id, SysTime now = Clock.currTime) {
		if (!id.length) return null;
		auto s = id in _sessions;
		if (s is null) return null;
		if (expired(*s, now)) {
			_sessions.remove(id);
			return null;
		}
		s.lastSeen = now;
		return s;
	}

	void destroy(string id) { _sessions.remove(id); }

	/// Signs a user out everywhere (e.g. after an administrator reset the password), except `keepId`.
	size_t destroyForUser(string tenant, string userName, string keepId = null) {
		string[] ids;
		foreach (id, s; _sessions)
			if (id != keepId && s.tenant == tenant && s.userName.toLower == userName.toLower) ids ~= id;
		foreach (id; ids) _sessions.remove(id);
		return ids.length;
	}

	/// Removes expired sessions; returns the number removed.
	size_t sweep(SysTime now = Clock.currTime) {
		string[] ids;
		foreach (id, s; _sessions) if (expired(s, now)) ids ~= id;
		foreach (id; ids) _sessions.remove(id);
		return ids.length;
	}

	size_t length() const { return _sessions.length; }

	private bool expired(const ref LoginSession s, SysTime now) const {
		return now - s.lastSeen > _idle || now - s.createdAt > _lifetime;
	}
}

/// Slows down password guessing: after `freeAttempts` failures of a key (user name, client address) further
/// attempts are refused for a lock time that doubles with every failure (capped). A success clears the key.
class LoginThrottle {
	private {
		struct Entry { uint failures; SysTime lockedUntil; SysTime lastFailure; }
		Entry[string] _entries;
		uint _free;
		Duration _base, _max, _forget;
	}

	this(uint freeAttempts = 5, Duration baseLock = 30.seconds, Duration maxLock = 15.minutes, Duration forgetAfter = 1.hours) {
		_free = freeAttempts; _base = baseLock; _max = maxLock; _forget = forgetAfter;
	}

	/// Remaining lock time of `key` (zero if attempts are allowed).
	Duration lockedFor(string key, SysTime now = Clock.currTime) {
		auto e = key in _entries;
		if (e is null || e.lockedUntil <= now) return Duration.zero;
		return e.lockedUntil - now;
	}

	void failure(string key, SysTime now = Clock.currTime) {
		if (_entries.length > 10_000) forgetOld(now);
		auto e = &_entries.require(key, Entry.init);
		if (e.failures && now - e.lastFailure > _forget) e.failures = 0;
		e.failures++;
		e.lastFailure = now;
		if (e.failures >= _free) {
			auto exponent = min(e.failures - _free, 16u);
			auto lock = _base * (1L << exponent);
			e.lockedUntil = now + (lock > _max ? _max : lock);
		}
	}

	void success(string key) { _entries.remove(key); }

	private void forgetOld(SysTime now) {
		string[] keys;
		foreach (k, e; _entries) if (now - e.lastFailure > _forget && e.lockedUntil <= now) keys ~= k;
		foreach (k; keys) _entries.remove(k);
	}
}

unittest {
	auto store = new LoginSessionStore(10.minutes, 1.hours);
	auto t0 = Clock.currTime;
	LoginSession data;
	data.tenant = "default";
	data.userName = "Anna";
	auto s = store.create(data, t0);
	assert(s.id.length && s.csrfToken.length && s.id != s.csrfToken);
	assert(store.touch(s.id, t0 + 9.minutes) !is null);
	assert(store.touch(s.id, t0 + 18.minutes) !is null, "touch restarts the idle timer");
	assert(store.touch(s.id, t0 + 29.minutes) is null, "idle timeout");
	assert(store.length == 0);
	s = store.create(data, t0);
	foreach (i; 1 .. 7) assert(store.touch(s.id, t0 + (i * 9).minutes) !is null);
	assert(store.touch(s.id, t0 + 63.minutes) is null, "absolute lifetime");
	auto a = store.create(data, t0), b = store.create(data, t0);
	assert(store.destroyForUser("default", "anna", a.id) == 1 && store.touch(a.id, t0) !is null);
	assert(store.touch("", t0) is null && store.touch("unknown", t0) is null);

	auto throttle = new LoginThrottle(3, 10.seconds, 60.seconds);
	foreach (_; 0 .. 2) throttle.failure("u", t0);
	assert(throttle.lockedFor("u", t0) == Duration.zero);
	throttle.failure("u", t0);
	assert(throttle.lockedFor("u", t0) == 10.seconds);
	throttle.failure("u", t0);
	assert(throttle.lockedFor("u", t0) == 20.seconds);
	foreach (_; 0 .. 5) throttle.failure("u", t0);
	assert(throttle.lockedFor("u", t0) == 60.seconds, "capped");
	assert(throttle.lockedFor("u", t0 + 61.seconds) == Duration.zero);
	throttle.success("u");
	throttle.failure("u", t0);
	assert(throttle.lockedFor("u", t0) == Duration.zero);
}
