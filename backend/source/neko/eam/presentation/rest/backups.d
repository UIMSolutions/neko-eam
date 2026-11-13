/// REST interface of the backups of the current tenant - tenant administrators:
///
///   GET    /api/v1/backups                          backups of the current tenant
///   POST   /api/v1/backups                          create  {comment}  -> 201
///   DELETE /api/v1/backups/{id}
///   POST   /api/v1/backups/{id}/restore[?check=true]  restore (check = validate only)
///
/// Download (`GET /api/v1/backups/{id}`) and upload restore (`POST /api/v1/backups/restore`) move files and
/// stay raw routes in `presentation.http.system`. The tenant comes from the request (zone, header
/// X-EAM-Tenant or cookie eam-tenant).
module neko.eam.presentation.rest.backups;

import vibe.http.common : HTTPMethod;
import vibe.web.rest;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access : currentSubject, currentTenant;
import neko.eam.presentation.rest.support : created, flag;

@path("/api/v1")
interface IBackupsApi {
@safe:
	@method(HTTPMethod.GET) @path("/backups")
	BackupInfoDto[] getBackups();

	@method(HTTPMethod.POST) @path("/backups") @after!(created!BackupInfoDto)()
	BackupInfoDto createBackup(string comment = "");

	@method(HTTPMethod.DELETE) @path("/backups/:id")
	void deleteBackup(string _id);

	@method(HTTPMethod.POST) @path("/backups/:id/restore") @queryParam("check", "check")
	RestoreResultDto restoreBackup(string _id, string check = "false");
}

class BackupsApi : IBackupsApi {
	private IEamPlatform _platform;

	this(IEamPlatform platform) { _platform = platform; }

	BackupInfoDto[] getBackups() @trusted { return _platform.listBackups(currentTenant(), currentSubject()); }

	BackupInfoDto createBackup(string comment = "") @trusted {
		return _platform.createBackup(currentTenant(), comment, currentSubject());
	}

	void deleteBackup(string _id) @trusted { _platform.deleteBackup(currentTenant(), _id, currentSubject()); }

	RestoreResultDto restoreBackup(string _id, string check = "false") @trusted {
		return _platform.restoreBackup(currentTenant(), _id, flag(check), currentSubject());
	}
}
