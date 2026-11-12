/// ISO date value helpers.
module neko.eam.domain.types.isodate;

import std.datetime : Date, Clock;

/// true if `value` is empty or a valid ISO date (YYYY-MM-DD).
bool isIsoDateOrEmpty(string value) @safe {
	if (value.length == 0)
		return true;
	try {
		Date.fromISOExtString(value);
		return value.length == 10;
	} catch (Exception) {
		return false;
	}
}

/// Today as ISO date string.
string todayIso() @safe {
	return (cast(Date) Clock.currTime()).toISOExtString();
}

/// Compares two ISO date strings (both non-empty, valid). Lexical order equals chronological order.
bool isBefore(string a, string b) @safe pure nothrow {
	return a.length && b.length && a < b;
}

/// `iso` shifted by `days` (negative = earlier). Empty or invalid input yields "".
string addDays(string iso, long days) @safe {
	import core.time : dur;
	if (iso.length == 0) return "";
	try return (Date.fromISOExtString(iso) + dur!"days"(days)).toISOExtString();
	catch (Exception) return "";
}

@safe unittest {
	assert(addDays("2026-03-01", -1) == "2026-02-28");
	assert(addDays("", 3) == "");
	assert(isIsoDateOrEmpty(""));
	assert(isIsoDateOrEmpty("2026-11-12"));
	assert(!isIsoDateOrEmpty("2026-13-01"));
	assert(!isIsoDateOrEmpty("yesterday"));
	assert(isBefore("2025-01-01", "2026-01-01"));
}
