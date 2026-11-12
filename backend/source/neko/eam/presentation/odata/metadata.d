/// OData v4 CSDL ($metadata) and service document generated from the DTO registry.
module neko.eam.presentation.odata.metadata;

import std.array : appender;
import std.traits : FieldNameTuple, hasUDA;
import vibe.data.json;
import neko.eam.application.dtos;
import neko.eam.domain.types : DateField, Required;

enum odataNamespace = "EamService";

/// EDM type name of a DTO field.
template edmType(T, string name) {
	alias F = typeof(__traits(getMember, T, name));
	static if (hasUDA!(__traits(getMember, T, name), DateField)) enum edmType = "Edm.Date";
	else static if (is(F == string)) enum edmType = "Edm.String";
	else static if (is(F == int)) enum edmType = "Edm.Int32";
	else static if (is(F == double)) enum edmType = "Edm.Double";
	else static if (is(F == bool)) enum edmType = "Edm.Boolean";
	else static if (is(F == string[])) enum edmType = "Collection(Edm.String)";
	else static assert(0, "No EDM mapping for " ~ F.stringof);
}

string buildMetadata() {
	auto x = appender!string;
	x ~= `<?xml version="1.0" encoding="utf-8"?>` ~ "\n";
	x ~= `<edmx:Edmx Version="4.0" xmlns:edmx="http://docs.oasis-open.org/odata/ns/edmx">` ~ "\n";
	x ~= `  <edmx:DataServices>` ~ "\n";
	x ~= `    <Schema Namespace="` ~ odataNamespace ~ `" xmlns="http://docs.oasis-open.org/odata/ns/edm">` ~ "\n";
	static foreach (S; EamDtoSets) {
		x ~= `      <EntityType Name="` ~ S.typeName ~ `">` ~ "\n";
		x ~= `        <Key><PropertyRef Name="id"/></Key>` ~ "\n";
		static foreach (name; FieldNameTuple!(S.Dto)) {
			x ~= `        <Property Name="` ~ name ~ `" Type="` ~ edmType!(S.Dto, name) ~ `"`
				~ ((name == "id" || hasUDA!(__traits(getMember, S.Dto, name), Required)) ? ` Nullable="false"` : ``)
				~ `/>` ~ "\n";
		}
		x ~= `      </EntityType>` ~ "\n";
	}
	x ~= `      <EntityContainer Name="Container">` ~ "\n";
	static foreach (S; EamDtoSets)
		x ~= `        <EntitySet Name="` ~ S.setName ~ `" EntityType="` ~ odataNamespace ~ `.` ~ S.typeName ~ `"/>` ~ "\n";
	x ~= `      </EntityContainer>` ~ "\n";
	x ~= `    </Schema>` ~ "\n  </edmx:DataServices>\n</edmx:Edmx>\n";
	return x.data;
}

Json buildServiceDocument() {
	auto sets = Json.emptyArray;
	static foreach (S; EamDtoSets)
		sets ~= Json(["name": Json(S.setName), "kind": Json("EntitySet"), "url": Json(S.setName)]);
	return Json(["@odata.context": Json("$metadata"), "value": sets]);
}

unittest {
	import std.algorithm : canFind;
	auto m = buildMetadata();
	assert(m.canFind(`<EntitySet Name="Applications" EntityType="EamService.Application"/>`));
	assert(m.canFind(`<Property Name="goLiveDate" Type="Edm.Date"/>`));
	assert(m.canFind(`<Property Name="capabilityIds" Type="Collection(Edm.String)"/>`));
}
