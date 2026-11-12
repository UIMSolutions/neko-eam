/// Driven ports for domain events.
module neko.eam.ports.messaging;

/// A change of an architecture element.
struct DomainEvent {
	string type;      /// Created | Updated | Deleted
	string kind;      /// entity set name
	string id;
	string name;
	string timestamp;
}

interface IEventPublisher {
	void publish(DomainEvent event);
}
