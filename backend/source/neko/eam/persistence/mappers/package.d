/// Converters between JSON documents, storage records and domain entities.
module neko.eam.persistence.mappers;

import std.conv : to, ConvException;
import std.traits : FieldNameTuple, isArray, isSomeString;
import vibe.data.json;

/// Field-by-field copy (records <-> entities), converting enums to/from their names.
TDst copyFields(TDst, TSrc)(TSrc src) {
	static if (is(TDst == class)) auto dst = new TDst;
	else TDst dst;
	static foreach (name; FieldNameTuple!TDst) {
		static if (__traits(hasMember, TSrc, name)) {
			{
				alias D = typeof(__traits(getMember, dst, name));
				auto v = __traits(getMember, src, name);
				static if (is(typeof(v) == D)) {
					static if (isArray!D && !isSomeString!D) __traits(getMember, dst, name) = v.dup;
					else __traits(getMember, dst, name) = v;
				} else static if (is(D == enum)) {
					// tolerate unknown / empty values from older documents: keep the default
					if (v.length) try __traits(getMember, dst, name) = v.to!D; catch (ConvException) {}
				} else
					__traits(getMember, dst, name) = v.to!D;
			}
		}
	}
	return dst;
}

/// Record -> JSON document.
Json recordToJson(T)(const T record) {
	auto j = Json.emptyObject;
	static foreach (name; FieldNameTuple!T) {
		{
			auto v = __traits(getMember, record, name);
			static if (is(typeof(v) : const(string[]))) {
				auto arr = Json.emptyArray;
				foreach (s; v) arr ~= Json(s);
				j[name] = arr;
			} else
				j[name] = Json(v);
		}
	}
	return j;
}

/// JSON document -> record; missing fields keep their defaults (schema evolution).
T recordFromJson(T)(Json j) {
	T r;
	static foreach (name; FieldNameTuple!T) {
		{
			auto v = j[name];
			alias F = typeof(__traits(getMember, r, name));
			if (v.type != Json.Type.undefined && v.type != Json.Type.null_) {
				static if (isSomeString!F) __traits(getMember, r, name) = v.to!string;
				else static if (is(F == string[])) {
					F arr;
					foreach (e; v) arr ~= e.to!string;
					__traits(getMember, r, name) = arr;
				} else static if (is(F == double)) __traits(getMember, r, name) = v.to!double;
				else static if (is(F == int)) __traits(getMember, r, name) = cast(int) v.to!long;
				else static if (is(F == bool)) __traits(getMember, r, name) = v.to!bool;
				else static assert(0, "Unsupported record field type " ~ F.stringof);
			}
		}
	}
	return r;
}

unittest {
	import neko.eam.persistence.records;
	import neko.eam.domain;
	ApplicationRecord r;
	r.id = "a"; r.name = "X"; r.status = "Retired"; r.capabilityIds = ["c"]; r.annualCost = 12.5;
	auto j = recordToJson(r);
	auto r2 = recordFromJson!ApplicationRecord(j);
	assert(r2 == r);
	auto e = copyFields!Application(r2);
	assert(e.status == LifecycleStatus.Retired && e.capabilityIds == ["c"]);
	assert(copyFields!ApplicationRecord(e).status == "Retired");
}
