/// HTTP endpoints of the report file exports (the JSON results are the REST interface
/// `presentation.rest.reports`):
///
///   GET  /api/v1/reports/{id}/export?format=xlsx|csv|pdf[&sep=;]
///   GET  /api/v1/reportbooks/{id}/export?format=xlsx|pdf
///
/// Reports run with the rights of the caller in the tenant of the request.
module neko.eam.presentation.http.reports;

import std.datetime : Clock, Date;
import vibe.http.router : URLRouter;
import vibe.http.server;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.ports.services : IReportRenderer, ITableCodec;
import neko.eam.application.usecases.reporting : reportTables;
import neko.eam.infrastructure.formats;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.errors;

void registerReportExportRoutes(URLRouter router, IEamUseCases uc) {
	router.get("/api/v1/reports/:id/export", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto r = callerUseCases(uc).reporting.run(req.params["id"], currentSubject().userName);
			send(req, res, r.name, [r]);
		});
	});
	router.get("/api/v1/reportbooks/:id/export", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto ucs = callerUseCases(uc);
			auto book = ucs.reportBooks.get(req.params["id"]);
			send(req, res, book.name, ucs.reporting.runBook(book.id, currentSubject().userName));
		});
	});
}

/// Report results as file: PDF (all reports), XLSX (one sheet per report + group summaries), CSV (first report).
immutable(ubyte)[] renderReport(string format, string title, ReportResultDto[] results, char separator = ',') {
	if (format == "pdf") return new PdfReportRenderer().render(title, results);
	auto tables = reportTables(results);
	if (format == "csv") {
		if (results.length != 1) throw new ValidationException("format", "CSV holds one report - use xlsx or pdf for report books");
		return new CsvCodec(separator).encode(tables[0 .. 1]);
	}
	if (format == "xlsx") return new XlsxCodec().encode(tables);
	throw new ValidationException("format", "Unknown format '" ~ format ~ "' (xlsx, csv, pdf)");
}

private void send(HTTPServerRequest req, HTTPServerResponse res, string title, ReportResultDto[] results) {
	auto format = req.query.get("format", "xlsx");
	auto sep = req.query.get("sep", ",") == ";" ? ';' : ',';
	auto bytes = renderReport(format, title, results, sep);
	auto mime = format == "pdf" ? "application/pdf" : format == "csv" ? "text/csv; charset=utf-8"
		: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
	auto stamp = (cast(Date) Clock.currTime()).toISOExtString();
	res.headers["Content-Disposition"] = `attachment; filename="` ~ safeName(title) ~ "-" ~ stamp ~ "." ~ format ~ `"`;
	res.headers["Cache-Control"] = "no-store";
	res.writeBody(bytes, mime);
}

/// File name from a report title (letters, digits, '-').
string safeName(string s) {
	import std.ascii : isAlphaNum;
	string r;
	foreach (char c; s) r ~= isAlphaNum(c) ? c : '-';
	return r.length ? r : "report";
}
