/// Portfolio analysis interactor (TIME, technology risks, capability coverage, impact).
module neko.eam.application.usecases.analyzeportfolio;

import std.algorithm : count, filter, map, sum;
import std.array : array;
import std.conv : to;
import std.datetime : Clock;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.ports.repositories;
import neko.eam.ports.usecases;

class AnalyzePortfolioInteractor : IAnalyzePortfolio {
	private {
		IElementRepository!Application _apps;
		IElementRepository!BusinessCapability _caps;
		IElementRepository!ITComponent _comps;
		IElementRepository!InformationFlow _flows;
		IElementRepository!Project _projects;
		IElementRepository!Product _products;
		IRepositoryRegistry _registry;
	}

	this(IElementRepository!Application apps, IElementRepository!BusinessCapability caps,
		IElementRepository!ITComponent comps, IElementRepository!InformationFlow flows,
		IElementRepository!Project projects, IElementRepository!Product products, IRepositoryRegistry registry) {
		_apps = apps; _caps = caps; _comps = comps; _flows = flows; _projects = projects;
		_products = products; _registry = registry;
	}

	PortfolioReportDto portfolio() {
		auto apps = _apps.findAll;
		PortfolioReportDto r;
		r.generatedAt = Clock.currTime().toUTC().toISOExtString();
		foreach (repo; _registry.all) r.counts ~= KindCountDto(repo.kind, repo.count);
		r.operationalApplications = apps.count!(a => a.isOperational);
		r.missionCriticalApplications = apps.count!(a => a.isOperational && a.criticality == Criticality.MissionCritical);
		r.totalAnnualCost = apps.filter!(a => a.isOperational).map!(a => a.annualCost).sum(0.0);
		foreach (t; [__traits(allMembers, TimeCategory)]) r.applicationsByTime[t] = 0;
		foreach (s; [__traits(allMembers, LifecycleStatus)]) r.applicationsByStatus[s] = 0;
		foreach (a; apps) {
			r.applicationsByStatus[a.status.to!string]++;
			if (a.status != LifecycleStatus.Retired) r.applicationsByTime[a.timeCategory.to!string]++;
		}
		auto cov = coverage();
		r.capabilityGaps = cov.count!(c => c.gap);
		r.capabilityRedundancies = cov.count!(c => c.redundant);
		r.timeAssessments = PortfolioAnalyzer.assessTime(apps).map!(t => mapFields!TimeAssessmentDto(t)).array;
		r.timeDeviations = r.timeAssessments.count!(t => t.deviates);
		r.technologyRisks = technologyRisks();
		r.technologyRiskCount = r.technologyRisks.length;
		r.productAlerts = productAlerts();
		r.productAlertCount = r.productAlerts.length;
		r.criticalProductAlerts = r.productAlerts.count!(a => a.severity == "Critical");
		return r;
	}

	ImpactReportDto impact(string applicationId) {
		auto app = _apps.findById(applicationId);
		if (app is null) throw new EntityNotFoundException("Applications", applicationId);
		return mapFields!ImpactReportDto(ImpactAnalyzer.analyze(app, _flows.findAll, _projects.findAll));
	}

	CapabilityCoverageDto[] coverage() {
		return PortfolioAnalyzer.coverage(_caps.findAll, _apps.findAll)
			.map!(c => mapFields!CapabilityCoverageDto(c)).array;
	}

	TechnologyRiskDto[] technologyRisks() {
		return PortfolioAnalyzer.technologyRisks(_apps.findAll, _comps.findAll, todayIso())
			.map!(t => mapFields!TechnologyRiskDto(t)).array;
	}

	ProductAlertDto[] productAlerts() {
		return ProductLifecycleMonitor.alerts(_products.findAll, _apps.findAll, todayIso())
			.map!(a => mapFields!ProductAlertDto(a)).array;
	}
}
