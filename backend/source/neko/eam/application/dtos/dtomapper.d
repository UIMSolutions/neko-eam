/// Reflection based mapping between entities and DTOs, and string-map parsing for CLI/GUI input.
module neko.eam.application.dtos.dtomapper;

import std.algorithm : map, filter;
import std.array : array, split;
import std.conv : to, ConvException;
import std.string : strip;
import std.traits : FieldNameTuple, isArray, isSomeString;
import neko.eam.domain.exceptions : ValidationException;

/// Copies all equally named fields of `src` into a new `TDst`, converting enum <-> string.
TDst mapFields(TDst, TSrc)(TSrc src) {
	static if (is(TDst == class)) auto dst = new TDst;
	else TDst dst;
	static if (is(TSrc == class)) if (src is null) throw new Exception("mapFields: null source");
	static foreach (name; FieldNameTuple!TDst) {
		static if (__traits(hasMember, TSrc, name)) {
			{
				alias D = typeof(__traits(getMember, dst, name));
				auto v = __traits(getMember, src, name);
				try {
					static if (is(typeof(v) == D)) {
						static if (isArray!D && !isSomeString!D) __traits(getMember, dst, name) = v.dup;
						else __traits(getMember, dst, name) = v;
					} else
						__traits(getMember, dst, name) = v.to!D;
				} catch (ConvException e) {
					throw new ValidationException(name, "Invalid value '" ~ v.to!string ~ "' for field '" ~ name ~ "'");
				}
			}
		}
	}
	return dst;
}

/// Names of all DTO fields.
string[] fieldNames(T)() {
	string[] names;
	static foreach (n; FieldNameTuple!T) names ~= n;
	return names;
}

/// Applies `key=value` style input to a DTO. Arrays are comma separated.
void applyStringValues(T)(ref T dto, string[string] values) {
	foreach (key, raw; values) {
		bool known;
		static foreach (name; FieldNameTuple!T) {
			if (key == name) {
				known = true;
				alias F = typeof(__traits(getMember, dto, name));
				try {
					static if (isSomeString!F) __traits(getMember, dto, name) = raw;
					else static if (is(F == string[]))
						__traits(getMember, dto, name) = raw.split(",").map!(s => s.strip).filter!(s => s.length > 0).array;
					else __traits(getMember, dto, name) = raw.strip.to!F;
				} catch (ConvException) {
					throw new ValidationException(name, "Invalid value '" ~ raw ~ "' for field '" ~ name ~ "'");
				}
			}
		}
		if (!known)
			throw new ValidationException(key, "Unknown field '" ~ key ~ "' for " ~ T.stringof);
	}
}

/// Renders every field of a DTO as string (arrays comma separated).
string[string] toStringValues(T)(const T dto) {
	import std.array : join;
	string[string] result;
	static foreach (name; FieldNameTuple!T) {
		{
			auto v = __traits(getMember, dto, name);
			static if (is(typeof(v) : const(string[]))) result[name] = v.join(",");
			else result[name] = v.to!string;
		}
	}
	return result;
}

unittest {
	import neko.eam.application.dtos.elementdtos;
	import neko.eam.domain.entities : Application;
	import neko.eam.domain.enumerations;
	ApplicationDto dto;
	dto.applyStringValues(["name": "ERP", "businessValue": "5", "capabilityIds": "a, b", "status": "PhaseOut"]);
	auto e = mapFields!Application(dto);
	assert(e.status == LifecycleStatus.PhaseOut && e.capabilityIds == ["a", "b"] && e.businessValue == 5);
	auto back = mapFields!ApplicationDto(e);
	assert(back.status == "PhaseOut");
	dto.status = "Bogus";
	bool failed;
	try mapFields!Application(dto); catch (ValidationException) failed = true;
	assert(failed);
}
