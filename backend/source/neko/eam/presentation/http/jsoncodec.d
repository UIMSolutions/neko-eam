/// JSON representation of DTOs shared by the HTTP adapters (OData, REST, Web, CLI --json).
module neko.eam.presentation.http.jsoncodec;

import std.conv : to;
import std.traits : FieldNameTuple, hasUDA, isSomeString;
import vibe.data.json;
import neko.eam.domain.types : DateField;
import neko.eam.domain.exceptions : ValidationException;

/// DTO -> JSON. Empty dates become `null` (OData Edm.Date).
Json dtoToJson(T)(const T dto) {
	auto j = Json.emptyObject;
	static foreach (name; FieldNameTuple!T) {
		{
			auto v = __traits(getMember, dto, name);
			static if (hasUDA!(__traits(getMember, T, name), DateField))
				j[name] = v.length ? Json(v) : Json(null);
			else static if (is(typeof(v) : const(string[]))) {
				auto arr = Json.emptyArray;
				foreach (s; v) arr ~= Json(s);
				j[name] = arr;
			} else j[name] = Json(v);
		}
	}
	return j;
}

/// JSON -> DTO, starting from `base` (allows PATCH semantics). Unknown members are rejected.
T dtoFromJson(T)(Json j, T base = T.init) {
	if (j.type != Json.Type.object) throw new ValidationException("", "JSON object expected");
	T dto = base;
	foreach (string key, value; j) {
		if (key.length && key[0] == '@') continue; // OData annotations
		bool known;
		static foreach (name; FieldNameTuple!T) {
			if (key == name) {
				known = true;
				alias F = typeof(__traits(getMember, dto, name));
				try {
					if (value.type == Json.Type.null_) __traits(getMember, dto, name) = F.init;
					else static if (isSomeString!F) __traits(getMember, dto, name) = value.get!string;
					else static if (is(F == string[])) {
						string[] arr;
						foreach (e; value) arr ~= e.get!string;
						__traits(getMember, dto, name) = arr;
					} else static if (is(F == double)) __traits(getMember, dto, name) = value.to!double;
					else static if (is(F == int)) __traits(getMember, dto, name) = cast(int) value.to!long;
					else static if (is(F == bool)) __traits(getMember, dto, name) = value.get!bool;
				} catch (Exception e) {
					throw new ValidationException(name, "Invalid value for field '" ~ name ~ "': " ~ e.msg);
				}
			}
		}
		if (!known) throw new ValidationException(key, "Unknown property '" ~ key ~ "'");
	}
	return dto;
}

unittest {
	import neko.eam.application.dtos;
	ApplicationDto a;
	a.name = "x";
	auto j = dtoToJson(a);
	assert(j["goLiveDate"].type == Json.Type.null_);
	auto b = dtoFromJson!ApplicationDto(parseJsonString(`{"businessValue": 5, "capabilityIds": ["c"]}`), a);
	assert(b.name == "x" && b.businessValue == 5 && b.capabilityIds == ["c"]);
}
