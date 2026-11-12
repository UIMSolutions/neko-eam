/// Background tasks.
module neko.eam.infrastructure.workers;

import core.time : seconds;
import vibe.core.core : setTimer, Timer;
import neko.eam.infrastructure.logging;
import neko.eam.ports.usecases;

/// Periodically evaluates the architecture health and logs findings (gaps, technology risks).
Timer startArchitectureHealthWorker(IAnalyzePortfolio analysis, uint intervalSeconds) {
	if (intervalSeconds == 0) return Timer.init;
	return setTimer(intervalSeconds.seconds, () nothrow {
		try {
			auto r = analysis.portfolio();
			logInfo("[health] %s operational apps, %s technology risks, %s capability gaps, %s TIME deviations",
				r.operationalApplications, r.technologyRiskCount, r.capabilityGaps, r.timeDeviations);
			foreach (risk; r.technologyRisks)
				logWarn("[health] %s uses %s: %s", risk.applicationName, risk.componentName, risk.reason);
		} catch (Exception e) {
			try logError("[health] analysis failed: %s", e.msg); catch (Exception) {}
		}
	}, true);
}

/// Takes a scheduled backup of every active tenant every `intervalHours` hours (0 = off).
Timer startBackupWorker(IEamPlatform platform, uint intervalHours) {
	import core.time : hours;
	if (intervalHours == 0) return Timer.init;
	return setTimer(intervalHours.hours, () nothrow {
		try {
			auto n = platform.runScheduledBackups();
			logInfo("[backup] scheduled backup of %s tenant(s) written", n);
		} catch (Exception e) {
			try logError("[backup] scheduled backup failed: %s", e.msg); catch (Exception) {}
		}
	}, true);
}
