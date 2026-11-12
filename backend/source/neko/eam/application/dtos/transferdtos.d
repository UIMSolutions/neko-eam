/// Format neutral tables for the CSV / XLSX import and export of entity sets.
module neko.eam.application.dtos.transferdtos;

/// One sheet: header row, column types (meta model types) and string cells.
struct TableDto {
	/// sheet name - the entity set name (e.g. "Applications")
	string name;
	/// column headers - field labels or technical field names
	string[] columns;
	/// meta model type per column (String, Int32, Double, Boolean, Date, StringCollection); may be empty on import
	string[] types;
	/// data rows; every row has at most `columns.length` cells
	string[][] rows;
}

/// A problem with one row (or with the whole sheet when `row` is 0).
struct ImportIssueDto {
	/// 1-based row number in the file including the header row (row 2 = first data row); 0 = sheet
	size_t row;
	string id;
	/// technical field name, if known
	string field;
	string message;
	/// "Error" (row not imported) or "Warning" (row imported, e.g. ignored column)
	string severity;
}

/// Outcome of importing one sheet.
struct ImportResultDto {
	string setName;
	size_t rows;
	size_t created;
	size_t updated;
	size_t unchanged;
	size_t failed;
	bool dryRun;
	ImportIssueDto[] issues;
}
