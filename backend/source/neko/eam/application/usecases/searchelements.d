/// Central search: case insensitive full text search over the textual fields of all element kinds.
module neko.eam.application.usecases.searchelements;

import std.algorithm : all, any, canFind, sort, startsWith, min, max;
import std.array : split;
import std.string : strip, toLower, indexOf;
import std.traits : FieldNameTuple, hasUDA, getUDAs, isSomeString;
import neko.eam.domain.types : References;
import neko.eam.application.dtos;
import neko.eam.ports.usecases;
import neko.eam.domain.exceptions : AccessDeniedException;

class SearchElementsInteractor : ISearchElements {
	private IEamUseCases _uc;

	this(IEamUseCases uc) { _uc = uc; }

	SearchHitDto[] search(string query, size_t top = 50) {
		auto q = query.strip.toLower;
		if (q.length == 0) return [];
		auto terms = q.split;
		SearchHitDto[] hits;
		static foreach (S; EamDtoSets) {{
			S.Dto[] items;
			try items = manage!S(_uc).list;
			catch (AccessDeniedException) {} // sets the caller may not read are not searched
			foreach (dto; items) {
				auto h = scoreOf!S(dto, q, terms);
				if (h.score > 0) hits ~= h;
			}
		}}
		hits.sort!((a, b) => a.score > b.score || (a.score == b.score && a.name < b.name));
		return hits.length > top ? hits[0 .. top] : hits;
	}

	/// Every term must occur in some searchable field (AND); the name and the id weigh most.
	private static SearchHitDto scoreOf(alias S)(S.Dto dto, string q, string[] terms) {
		SearchHitDto h;
		auto name = dto.name.toLower, id = dto.id.toLower;
		foreach (t; terms) {
			int best;
			string field, text;
			if (name.startsWith(t)) best = 80;
			else if (name.canFind(t)) best = 60;
			else if (id.canFind(t)) best = 50;
			static foreach (f; FieldNameTuple!(S.Dto)) {
				static if (isSearchable!(S, f)) {
					if (best < 20 && __traits(getMember, dto, f).toLower.canFind(t)) {
						best = 20;
						field = labelOf!(S.Dto, f);
						text = __traits(getMember, dto, f);
					}
				}
			}
			if (best == 0) return SearchHitDto.init;
			h.score += best;
			if (field.length && h.matchedField.length == 0) { h.matchedField = field; h.snippet = snippetOf(text, t); }
		}
		if (name == q || id == q) h.score += 100;
		h.setName = S.setName;
		h.typeLabel = S.label;
		h.icon = S.icon;
		h.id = dto.id;
		h.name = dto.name;
		h.description = shorten(dto.description, 120);
		return h;
	}

	/// Free text fields only: no references (ids), no enumeration codes, no administrative data.
	private template isSearchable(alias S, string f) {
		static if (f == "id" || f == "name" || f == "createdAt" || f == "modifiedAt" || f == "createdBy" || f == "modifiedBy")
			enum isSearchable = false;
		else static if (!isSomeString!(typeof(__traits(getMember, S.Dto, f))))
			enum isSearchable = false;
		else static if (hasUDA!(__traits(getMember, S.Dto, f), References))
			enum isSearchable = false;
		else static if (__traits(hasMember, S.Entity, f) && is(typeof(__traits(getMember, S.Entity, f)) == enum))
			enum isSearchable = false;
		else
			enum isSearchable = true;
	}

	private static string labelOf(T, string f)() {
		static if (hasUDA!(__traits(getMember, T, f), Label)) return getUDAs!(__traits(getMember, T, f), Label)[0].text;
		else return f;
	}

	private static string shorten(string text, size_t maxChars) {
		import std.conv : to;
		auto d = text.to!dstring;
		return d.length > maxChars ? d[0 .. maxChars - 3].to!string ~ "..." : text;
	}

	/// Text around the first occurrence of `term` (works on code points, so umlauts are never cut).
	private static string snippetOf(string text, string term) {
		import std.conv : to;
		import std.typecons : No;
		auto d = text.to!dstring;
		if (d.length <= 80) return text;
		auto pos = d.indexOf(term.to!dstring, No.caseSensitive);
		if (pos < 0) pos = 0;
		size_t from = pos > 30 ? pos - 30 : 0, upto = min(d.length, pos + term.length + 40);
		return (from > 0 ? "..." : "") ~ d[from .. upto].to!string ~ (upto < d.length ? "..." : "");
	}
}
