/// REST interface of the reporting (results as JSON; the file exports stay raw routes in
/// `presentation.http.reports` because they answer with XLSX / CSV / PDF):
///
///   GET  /api/v1/reports/{id}/run          result of a stored report definition
///   POST /api/v1/reports/run               run an unsaved definition (preview; body = the definition)
///   GET  /api/v1/reportbooks/{id}/run      results of all reports of the book, in its order
///
/// Reports run with the rights of the caller in the tenant of the request.
module neko.eam.presentation.rest.reports;

import vibe.data.json : Json;
import vibe.http.common : HTTPMethod;
import vibe.web.rest;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access : callerUseCases, currentSubject;
import neko.eam.presentation.http.jsoncodec : dtoFromJson;

@path("/api/v1")
interface IReportsApi {
@safe:
	@method(HTTPMethod.GET) @path("/reports/:id/run")
	ReportResultDto runReport(string _id);

	/// The body is the definition itself (same fields as the OData entity `Reports`).
	@method(HTTPMethod.POST) @path("/reports/run") @bodyParam("definition")
	ReportResultDto runDefinition(Json definition);

	@method(HTTPMethod.GET) @path("/reportbooks/:id/run")
	ReportResultDto[] runReportBook(string _id);
}

class ReportsApi : IReportsApi {
	private IEamUseCases _uc;

	this(IEamUseCases uc) { _uc = uc; }

	ReportResultDto runReport(string _id) @trusted {
		return callerUseCases(_uc).reporting.run(_id, currentSubject().userName);
	}

	ReportResultDto runDefinition(Json definition) @trusted {
		// same lenient field mapping as the OData service (unknown fields ignored, enums by name)
		auto d = dtoFromJson!ReportDto(definition);
		return callerUseCases(_uc).reporting.runDefinition(d, currentSubject().userName);
	}

	ReportResultDto[] runReportBook(string _id) @trusted {
		return callerUseCases(_uc).reporting.runBook(_id, currentSubject().userName);
	}
}
