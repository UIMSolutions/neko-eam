/// Technical logging & tracing.
module neko.eam.infrastructure.logging;

public import vibe.core.log : logInfo, logWarn, logError, logDebug, logDiagnostic;
import vibe.core.log : setLogLevel, LogLevel;
import neko.eam.ports.messaging;

/// Sets the global log level from its configuration name.
void configureLogging(string level) {
	switch (level) {
		case "trace": setLogLevel(LogLevel.trace); break;
		case "debug": setLogLevel(LogLevel.debug_); break;
		case "diagnostic": setLogLevel(LogLevel.diagnostic); break;
		case "warn": setLogLevel(LogLevel.warn); break;
		case "error": setLogLevel(LogLevel.error); break;
		case "none": setLogLevel(LogLevel.none); break;
		default: setLogLevel(LogLevel.info);
	}
}

/// Event publisher writing domain events to the audit log.
class LoggingEventPublisher : IEventPublisher {
	void publish(DomainEvent e) {
		logInfo("[audit] %s %s('%s') \"%s\" by %s at %s", e.type, e.kind, e.id, e.name, e.actor.length ? e.actor : "system", e.timestamp);
	}
}
