module neko.eam.domain.entities.architectureelement;

import neko.eam;

class ArchitectureElement {
    this() {
        this.initialize();
    }

    this(Json initData) {
        this.initialize(initData);
    }

    private bool initialize(Json initData = Json(null)) {
        // If initData is not null and not an object, initialization fails.
        if (!initData.isNull && !initData.isObject)
            return false;

        id = initData.getString("id", "");
        name = initData.getString("name", "");
        description = initData.getString("description", "");
        createdAt = initData.getString("createdAt", "");
        createdBy = initData.getString("createdBy", "");
        modifiedAt = initData.getString("modifiedAt", "");
        modifiedBy = initData.getString("modifiedBy", "");

        return true;
    }

	/// Technical identity of the element.
	string id;

	/// Human readable name (mandatory).
	@Required string name;

	/// Free text description.
	string description;

	/// ISO timestamp of creation (set by use cases).
	string createdAt;

	/// User who created the element (set by use cases).
	string createdBy;

	/// ISO timestamp of the last modification (set by use cases).
	string modifiedAt;

	/// User who performed the last modification (set by use cases).
	string modifiedBy;
}