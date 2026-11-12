/// Runtime description of the meta model (entity sets and their fields), generated at compile time
/// from the DTO / entity annotations. Consumed by generic UIs (Fiori, GtkD, CLI).
module neko.eam.application.dtos.modelinfo;

import std.ascii : isUpper, toUpper;
import std.traits : FieldNameTuple, getUDAs, hasUDA;
import neko.eam.domain.types : DateField, References, Required;
import neko.eam.application.dtos.annotations;
import neko.eam.application.dtos.registry;

struct FieldInfoDto {
	string name;
	string label;
	/// String, Int32, Double, Boolean, Date or StringCollection
	string type;
	string group;
	bool required;
	bool readOnly;
	bool listColumn;
	bool multiline;
	/// referenced entity set (empty if none)
	string reference;
	/// allowed values of enumerations (empty if free text)
	string[] choices;
	/// initial value of a new element, rendered as string ("" for none)
	string defaultValue;
}

struct EntitySetInfoDto {
	string name;
	string typeName;
	string label;
	string icon;
	FieldInfoDto[] fields;
}

/// "endOfSupport" -> "End Of Support" (fallback label).
string humanize(string name) @safe pure {
	string r;
	foreach (i, char c; name) {
		if (i == 0) r ~= toUpper(c);
		else { if (isUpper(c)) r ~= ' '; r ~= c; }
	}
	return r;
}

FieldInfoDto[] describeFields(alias S)() {
	FieldInfoDto[] fields;
	static foreach (name; FieldNameTuple!(S.Dto)) {{
		alias member = __traits(getMember, S.Dto, name);
		alias F = typeof(member);
		FieldInfoDto f;
		f.name = name;
		static if (hasUDA!(member, Label)) f.label = getUDAs!(member, Label)[0].text;
		else f.label = humanize(name);
		static if (hasUDA!(member, Group)) f.group = getUDAs!(member, Group)[0].name;
		else f.group = "General";
		static if (hasUDA!(member, DateField)) f.type = "Date";
		else static if (is(F == int)) f.type = "Int32";
		else static if (is(F == double)) f.type = "Double";
		else static if (is(F == bool)) f.type = "Boolean";
		else static if (is(F == string[])) f.type = "StringCollection";
		else f.type = "String";
		f.required = hasUDA!(member, Required);
		f.readOnly = hasUDA!(member, ReadOnly);
		f.listColumn = hasUDA!(member, ListColumn);
		f.multiline = hasUDA!(member, Multiline);
		static if (hasUDA!(member, References)) f.reference = getUDAs!(member, References)[0].kind;
		static if (__traits(hasMember, S.Entity, name)) {
			alias E = typeof(__traits(getMember, S.Entity, name));
			static if (is(E == enum)) f.choices = [__traits(allMembers, E)];
		}
		{
			import std.conv : to;
			auto init = __traits(getMember, S.Dto.init, name);
			static if (is(F == string)) f.defaultValue = init;
			else static if (!is(F == string[])) f.defaultValue = init.to!string;
		}
		fields ~= f;
	}}
	return fields;
}

/// Description of all entity sets in registry order.
EntitySetInfoDto[] describeModel() {
	EntitySetInfoDto[] sets;
	static foreach (S; EamDtoSets)
		sets ~= EntitySetInfoDto(S.setName, S.typeName, S.label, S.icon, describeFields!S());
	return sets;
}

/// Description of one entity set by name (null if unknown).
EntitySetInfoDto* describeSet(string setName) {
	foreach (ref s; describeModel()) if (s.name == setName) return new EntitySetInfoDto(s.tupleof);
	return null;
}

unittest {
	import std.algorithm : find;
	auto model = describeModel();
	auto products = model.find!(s => s.name == "Products")[0];
	auto lc = products.fields.find!(f => f.name == "lifecycleStatus")[0];
	assert(lc.label == "Lifecycle Status" && lc.choices.length == 5 && lc.listColumn);
	auto eol = products.fields.find!(f => f.name == "eolReminderDate")[0];
	assert(eol.type == "Date" && eol.readOnly && eol.group == "Reminders");
	assert(products.fields.find!(f => f.name == "componentId")[0].reference == "ITComponents");
	assert(humanize("endOfSupport") == "End Of Support");
}
