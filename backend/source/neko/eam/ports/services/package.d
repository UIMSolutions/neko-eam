/// Driving ports of application services.
module neko.eam.ports.services;

/// Exports the architecture repository as ArchiMate 3.1 Open Exchange Format.
interface IArchiMateExport {
	string exportModel();
}

import neko.eam.application.dtos.transferdtos : TableDto;

/// File format of tables (CSV, XLSX). Implementations are pure (no I/O).
interface ITableCodec {
	/// "csv" or "xlsx"
	string format();
	string mimeType();
	/// Serialises the sheets. Formats with a single sheet (CSV) accept exactly one table.
	immutable(ubyte)[] encode(TableDto[] sheets);
	/// Parses all sheets; throws ValidationException on malformed input.
	TableDto[] decode(const(ubyte)[] data);
}

/// Driven port: storage of backup files (one directory per tenant on disk).
interface IBackupStore {
	/// Ids of the stored backups of `tenant`, newest first.
	string[] list(string tenant);
	void save(string tenant, string id, const(ubyte)[] data);
	immutable(ubyte)[] load(string tenant, string id);
	void remove(string tenant, string id);
	bool exists(string tenant, string id);
	string location(string tenant);
}

import neko.eam.application.dtos.platformdtos : ReportResultDto;

/// Driven port: renders executed reports as a document (PDF).
interface IReportRenderer {
	string format();
	string mimeType();
	immutable(ubyte)[] render(string title, ReportResultDto[] results);
}

/// Driven port: one-way password hashing with salt (implemented with OpenSSL in the infrastructure).
interface IPasswordHasher {
	/// Encoded hash of `password` with a fresh random salt.
	string hash(string password);
	/// Constant-time check of `password` against an encoded hash; false for malformed hashes.
	bool verify(string password, string encoded);
	/// The hash was made with weaker parameters than the current ones (re-hash after a successful sign-in).
	bool needsRehash(string encoded);
}
