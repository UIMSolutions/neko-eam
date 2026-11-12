/// Architecture document - concept, specification, standard, architecture decision record, policy ...
/// with author / approver, review cycle and a link to the document store.
module neko.eam.domain.entities.architecturedocument;

import std.algorithm : startsWith;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ArchitectureDocument {
	mixin ArchitectureElementFields;

	string documentNumber;            /// Document Number
	DocumentType documentType = DocumentType.Concept; /// Document Type
	SpecificationStatus status = SpecificationStatus.Draft; /// Status
	string docVersion;                /// Version
	Confidentiality confidentiality = Confidentiality.Internal; /// Confidentiality
	string author;                    /// Author
	string approver;                  /// Approver
	@DateField string approvalDate;   /// Approval Date
	@DateField string nextReviewDate; /// Next Review Date
	string documentLink;              /// Document Link
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@References("ReferenceArchitectures") string[] referenceArchitectureIds; /// Reference Architectures
	@References("ArchitecturePrinciples") string[] principleIds; /// Architecture Principles
	@References("ArchitectureGuidelines") string[] guidelineIds; /// Architecture Guidelines
	@References("Applications") string[] applicationIds; /// Applications
	bool reviewOverdue;               /// Review Overdue (derived)

	/// Approved documents whose next review date has passed.
	static bool isReviewOverdue(SpecificationStatus status, string nextReviewDate, string today) pure @safe {
		return status == SpecificationStatus.Approved && nextReviewDate.length && nextReviewDate < today;
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkDateOrder("approvalDate", approvalDate, "nextReviewDate", nextReviewDate);
		if (documentLink.length && !documentLink.startsWith("http://") && !documentLink.startsWith("https://"))
			throw new ValidationException("documentLink", "Field 'documentLink' must be an http(s) URL");
		if (status == SpecificationStatus.Approved) {
			if (approver.length == 0)
				throw new ValidationException("approver", "An approved document needs an approver");
			if (approvalDate.length == 0)
				throw new ValidationException("approvalDate", "An approved document needs an approval date");
		}
	}
}

unittest {
	auto d = new ArchitectureDocument;
	d.name = "ADR-007 Event streaming platform";
	d.status = SpecificationStatus.Approved;
	d.approver = "Architecture Board";
	bool failed;
	try d.validate(); catch (ValidationException e) failed = e.field == "approvalDate";
	assert(failed);
	d.approvalDate = "2026-02-01";
	d.documentLink = "file://share/adr7.docx";
	failed = false;
	try d.validate(); catch (ValidationException e) failed = e.field == "documentLink";
	assert(failed);
	d.documentLink = "https://wiki.acme.example/adr-007";
	d.validate();
	assert(ArchitectureDocument.isReviewOverdue(d.status, "2026-01-01", "2026-11-12"));
	assert(!ArchitectureDocument.isReviewOverdue(SpecificationStatus.Draft, "2026-01-01", "2026-11-12"));
}
