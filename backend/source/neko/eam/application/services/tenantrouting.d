/// IEamUseCases that forwards every call to the use cases of the current tenant. The presentation adapters
/// keep working with "the" use cases; which tenant they reach is decided per request (or per process).
module neko.eam.application.services.tenantrouting;

import std.conv : to;
import neko.eam.application.dtos;
import neko.eam.ports.usecases;

class TenantRoutingUseCases : IEamUseCases {
	private IEamUseCases delegate() _current;

	this(IEamUseCases delegate() current) { _current = current; }

	static foreach (i, S; EamDtoSets)
		mixin("IManageElements!(EamDtoSets[" ~ i.to!string ~ "].Dto) " ~ S.accessor ~ "() { return _current()." ~ S.accessor ~ "(); }");

	ISearchElements search() { return _current().search; }
	ITransferElements transfer() { return _current().transfer; }
	IAnalyzePortfolio analysis() { return _current().analysis; }
	ISeedSampleData seeder() { return _current().seeder; }
	IArchiMateExport archimate() { return _current().archimate; }
	IAccessControl access() { return _current().access; }
	IReporting reporting() { return _current().reporting; }
	IComments comments() { return _current().comments; }
	INotifications notifications() { return _current().notifications; }
}
