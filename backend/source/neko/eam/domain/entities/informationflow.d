/// Information flow - an interface transporting a business object from one application to another.
module neko.eam.domain.entities.informationflow;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class InformationFlow {
	mixin ArchitectureElementFields;

	@Required @References("Applications") string sourceApplicationId;
	@Required @References("Applications") string targetApplicationId;
	InterfaceType flowType = InterfaceType.Api;
	string dataObject;     /// transported business object, e.g. "Customer"
	string frequency;      /// e.g. "realtime", "daily"

	void validate() const {
		validateAnnotatedFields(this);
		if (sourceApplicationId == targetApplicationId)
			throw new ValidationException("targetApplicationId", "Source and target application must differ");
	}
}
