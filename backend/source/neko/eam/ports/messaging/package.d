/// Driven ports for domain events.
module neko.eam.ports.messaging;

/// A change of an architecture element.
struct DomainEvent {
	string type;      /// Created | Updated | Deleted
	string kind;      /// entity set name
	string id;
	string name;
	string timestamp;
	string actor;      /// user who made the change ("system" if unknown)
	string createdBy;  /// creator of the element
	string modifiedBy; /// last editor before this change
	string[] fields;   /// changed fields (Updated)
}

interface IEventPublisher {
	void publish(DomainEvent event);
}
