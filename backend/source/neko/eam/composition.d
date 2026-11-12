/// Composition root: wires persistence, application services and use cases (dependency injection by hand).
module neko.eam.composition;

import std.format : format;
import neko.eam.domain;
import neko.eam.application;
import neko.eam.ports;
import neko.eam.persistence;
import neko.eam.infrastructure;

/// One hasher for all tenants (stateless).
private IPasswordHasher passwordHasher() {
	static IPasswordHasher hasher;
	if (hasher is null) hasher = new Pbkdf2PasswordHasher;
	return hasher;
}

/// Fully wired application core.
final class EamContainer {
	AppConfig config;
	IDocumentStorage storage;
	RepositoryRegistry registry;
	EamFacade useCases;

	this(AppConfig config, IDocumentStorage storage, IEventPublisher events = null) {
		this.config = config;
		this.storage = storage;
		registry = new RepositoryRegistry;

		auto apps = new DocumentRepository!(Application, ApplicationRecord)("Applications", storage);
		auto caps = new DocumentRepository!(BusinessCapability, BusinessCapabilityRecord)("BusinessCapabilities", storage);
		auto comps = new DocumentRepository!(ITComponent, ITComponentRecord)("ITComponents", storage);
		auto flows = new DocumentRepository!(InformationFlow, InformationFlowRecord)("InformationFlows", storage);
		auto orgs = new DocumentRepository!(Organization, OrganizationRecord)("Organizations", storage);
		auto projects = new DocumentRepository!(Project, ProjectRecord)("Projects", storage);
		auto products = new DocumentRepository!(Product, ProductRecord)("Products", storage);
		auto productGroups = new DocumentRepository!(ProductGroup, ProductGroupRecord)("ProductGroups", storage);
		auto appGroups = new DocumentRepository!(ApplicationGroup, ApplicationGroupRecord)("ApplicationGroups", storage);
		auto processes = new DocumentRepository!(BusinessProcess, BusinessProcessRecord)("BusinessProcesses", storage);
		auto data = new DocumentRepository!(BusinessData, BusinessDataRecord)("BusinessData", storage);
		auto catalogs = new DocumentRepository!(ServiceProductGroup, ServiceProductGroupRecord)("ServiceProductGroups", storage);
		auto guidelines = new DocumentRepository!(StrategicGuideline, StrategicGuidelineRecord)("StrategicGuidelines", storage);
		auto serviceCaps = new DocumentRepository!(ServiceCapability, ServiceCapabilityRecord)("ServiceCapabilities", storage);
		auto measureGroups = new DocumentRepository!(MeasureGroup, MeasureGroupRecord)("MeasureGroups", storage);
		auto measures = new DocumentRepository!(Measure, MeasureRecord)("Measures", storage);
		auto itProcesses = new DocumentRepository!(ITProcess, ITProcessRecord)("ITProcesses", storage);
		auto processSteps = new DocumentRepository!(ProcessStep, ProcessStepRecord)("ProcessSteps", storage);
		auto processKpis = new DocumentRepository!(ProcessKpi, ProcessKpiRecord)("ProcessKpis", storage);
		auto protection = new DocumentRepository!(ProtectionRequirement, ProtectionRequirementRecord)("ProtectionRequirements", storage);
		auto risks = new DocumentRepository!(SecurityRisk, SecurityRiskRecord)("SecurityRisks", storage);
		auto controls = new DocumentRepository!(SecurityControl, SecurityControlRecord)("SecurityControls", storage);
		auto reports = new DocumentRepository!(Report, ReportRecord)("Reports", storage);
		auto reportBooks = new DocumentRepository!(ReportBook, ReportBookRecord)("ReportBooks", storage);
		auto enterprises = new DocumentRepository!(Enterprise, EnterpriseRecord)("Enterprises", storage);
		auto members = new DocumentRepository!(Member, MemberRecord)("Members", storage);
		auto users = new DocumentRepository!(User, UserRecord)("Users", storage);
		auto roles = new DocumentRepository!(Role, RoleRecord)("Roles", storage);
		auto permissions = new DocumentRepository!(Permission, PermissionRecord)("Permissions", storage);
		auto subProjects = new DocumentRepository!(SubProject, SubProjectRecord)("SubProjects", storage);
		auto workPackages = new DocumentRepository!(WorkPackage, WorkPackageRecord)("WorkPackages", storage);
		auto principles = new DocumentRepository!(ArchitecturePrinciple, ArchitecturePrincipleRecord)("ArchitecturePrinciples", storage);
		auto archGuidelines = new DocumentRepository!(ArchitectureGuideline, ArchitectureGuidelineRecord)("ArchitectureGuidelines", storage);
		auto refArchs = new DocumentRepository!(ReferenceArchitecture, ReferenceArchitectureRecord)("ReferenceArchitectures", storage);
		auto documents = new DocumentRepository!(ArchitectureDocument, ArchitectureDocumentRecord)("ArchitectureDocuments", storage);
		foreach (IElementRepositoryBase r; [cast(IElementRepositoryBase) apps, caps, comps, flows, orgs, projects,
				products, productGroups, appGroups, processes, data, catalogs, guidelines, serviceCaps, measureGroups, measures,
				principles, archGuidelines, refArchs, documents, subProjects, workPackages, users, roles, permissions,
				enterprises, members, itProcesses, processSteps, processKpis, protection, risks, controls, reports, reportBooks])
			registry.register(r);

		auto integrity = new IntegrityService(registry);
		auto f = useCases = new EamFacade;
		f._apps = new ManageElementsInteractor!(Application, ApplicationDto)(apps, integrity, events);
		auto capUc = new ManageElementsInteractor!(BusinessCapability, BusinessCapabilityDto)(caps, integrity, events);
		capUc.enrichWith((BusinessCapability c) { c.hierarchyPath = hierarchyPath!"parentId"(c, caps.findAll); });
		f._caps = capUc;
		f._comps = new ManageElementsInteractor!(ITComponent, ITComponentDto)(comps, integrity, events);
		f._flows = new ManageElementsInteractor!(InformationFlow, InformationFlowDto)(flows, integrity, events);
		auto orgUc = new ManageElementsInteractor!(Organization, OrganizationDto)(orgs, integrity, events);
		orgUc.enrichWith((Organization o) {
			o.hierarchyPath = hierarchyPath!"parentId"(o, orgs.findAll);
			auto s = UnitStaffing.compute(o.id, members.findAll, todayIso());
			o.headOfUnit = s.head;
			o.totalMembers = s.members;
			o.totalCapacity = s.capacityFte;
		});
		f._orgs = orgUc;
		// project management: totals and progress are rolled up from sub projects and work packages
		auto projectUc = new ManageElementsInteractor!(Project, ProjectDto)(projects, integrity, events);
		projectUc.enrichWith((Project p) {
			auto r = ProjectRollup.forProject(p.id, subProjects.findAll, workPackages.findAll);
			p.totalSubProjects = r.subProjects;
			p.totalWorkPackages = r.workPackages;
			p.plannedEffortDays = r.plannedEffortDays;
			p.progress = r.progress;
		});
		f._projects = projectUc;
		auto subProjectUc = new ManageElementsInteractor!(SubProject, SubProjectDto)(subProjects, integrity, events);
		subProjectUc.enrichWith((SubProject s) {
			auto all = subProjects.findAll;
			auto path = hierarchyPath!"parentSubProjectId"(s, all);
			if (auto prj = projects.findById(s.projectId)) path = prj.name ~ " / " ~ path;
			s.hierarchyPath = path;
			auto r = ProjectRollup.forSubProject(s.id, all, workPackages.findAll);
			s.totalWorkPackages = r.workPackages;
			s.plannedEffortDays = r.plannedEffortDays;
			s.progress = r.progress;
		});
		f._subProjects = subProjectUc;
		auto workPackageUc = new ManageElementsInteractor!(WorkPackage, WorkPackageDto)(workPackages, integrity, events);
		workPackageUc.enrichWith((WorkPackage w) { w.delayed = WorkPackage.isDelayed(w.status, w.endDate, todayIso()); });
		f._workPackages = workPackageUc;
		f._products = new ManageElementsInteractor!(Product, ProductDto)(products, integrity, events);
		f._productGroups = new ManageElementsInteractor!(ProductGroup, ProductGroupDto)(productGroups, integrity, events);
		auto groupUc = new ManageElementsInteractor!(ApplicationGroup, ApplicationGroupDto)(appGroups, integrity, events);
		// product totals of a group are rolled up from the applications of its subtree at read time
		groupUc.enrichWith((ApplicationGroup g) {
			auto r = ApplicationGroupRollup.compute(g.id, appGroups.findAll, apps.findAll);
			g.totalUsedProducts = r.used;
			g.totalAssignedProducts = r.assigned;
		});
		f._applicationGroups = groupUc;
		auto processUc = new ManageElementsInteractor!(BusinessProcess, BusinessProcessDto)(processes, integrity, events);
		processUc.enrichWith((BusinessProcess p) { p.hierarchyPath = hierarchyPath!"parentProcessId"(p, processes.findAll); });
		f._businessProcesses = processUc;
		f._businessData = new ManageElementsInteractor!(BusinessData, BusinessDataDto)(data, integrity, events);
		auto catalogUc = new ManageElementsInteractor!(ServiceProductGroup, ServiceProductGroupDto)(catalogs, integrity, events);
		catalogUc.enrichWith((ServiceProductGroup g) { g.hierarchyPath = hierarchyPath!"parentId"(g, catalogs.findAll); });
		f._serviceProductGroups = catalogUc;
		// IT landscape planning
		auto guidelineUc = new ManageElementsInteractor!(StrategicGuideline, StrategicGuidelineDto)(guidelines, integrity, events);
		guidelineUc.enrichWith((StrategicGuideline g) { g.hierarchyPath = hierarchyPath!"parentId"(g, guidelines.findAll); });
		f._strategicGuidelines = guidelineUc;
		auto serviceCapUc = new ManageElementsInteractor!(ServiceCapability, ServiceCapabilityDto)(serviceCaps, integrity, events);
		serviceCapUc.enrichWith((ServiceCapability c) {
			c.derive();
			c.hierarchyPath = hierarchyPath!"parentId"(c, serviceCaps.findAll);
		});
		f._serviceCapabilities = serviceCapUc;
		auto measureGroupUc = new ManageElementsInteractor!(MeasureGroup, MeasureGroupDto)(measureGroups, integrity, events);
		measureGroupUc.enrichWith((MeasureGroup g) {
			auto all = measureGroups.findAll;
			g.hierarchyPath = hierarchyPath!"parentGroupId"(g, all);
			auto r = MeasureGroupRollup.compute(g.id, all, measures.findAll);
			g.totalMeasures = r.measures;
			g.totalEstimatedCost = r.estimatedCost;
		});
		f._measureGroups = measureGroupUc;
		f._measures = new ManageElementsInteractor!(Measure, MeasureDto)(measures, integrity, events);
		// specifications
		f._architecturePrinciples = new ManageElementsInteractor!(ArchitecturePrinciple, ArchitecturePrincipleDto)(principles, integrity, events);
		f._architectureGuidelines = new ManageElementsInteractor!(ArchitectureGuideline, ArchitectureGuidelineDto)(archGuidelines, integrity, events);
		auto refArchUc = new ManageElementsInteractor!(ReferenceArchitecture, ReferenceArchitectureDto)(refArchs, integrity, events);
		refArchUc.enrichWith((ReferenceArchitecture r) {
			import std.algorithm : canFind, count;
			r.hierarchyPath = hierarchyPath!"parentId"(r, refArchs.findAll);
			r.totalDocuments = cast(int) documents.findAll.count!(d => d.referenceArchitectureIds.canFind(r.id));
		});
		f._referenceArchitectures = refArchUc;
		auto documentUc = new ManageElementsInteractor!(ArchitectureDocument, ArchitectureDocumentDto)(documents, integrity, events);
		documentUc.enrichWith((ArchitectureDocument d) {
			d.reviewOverdue = ArchitectureDocument.isReviewOverdue(d.status, d.nextReviewDate, todayIso());
		});
		f._architectureDocuments = documentUc;
		// organisation structure: enterprises (legal entities) and members of the organisational units
		auto enterpriseUc = new ManageElementsInteractor!(Enterprise, EnterpriseDto)(enterprises, integrity, events);
		enterpriseUc.enrichWith((Enterprise e) {
			e.hierarchyPath = hierarchyPath!"parentEnterpriseId"(e, enterprises.findAll);
			UnitStaffing.forEnterprise(e.id, orgs.findAll, members.findAll, todayIso(), e.totalUnits, e.totalMembers,
				e.managingDirector);
		});
		f._enterprises = enterpriseUc;
		auto memberUc = new ManageElementsInteractor!(Member, MemberDto)(members, integrity, events);
		memberUc.validateWith((Member m) {
			auto today = todayIso();
			foreach (other; members.findAll) {
				if (other.id == m.id) continue;
				if (m.personnelNumber.length && other.personnelNumber == m.personnelNumber)
					throw new ValidationException("personnelNumber", "Personnel number '" ~ m.personnelNumber ~ "' is already used by " ~ other.id);
				if (m.memberFunction == MemberFunction.Head && other.memberFunction == MemberFunction.Head
						&& other.organizationId == m.organizationId && m.isCurrent(today) && other.isCurrent(today))
					throw new ValidationException("memberFunction", "The unit already has a head: " ~ other.name);
			}
		});
		memberUc.enrichWith((Member m) { m.current = m.isCurrent(todayIso()); });
		f._members = memberUc;
		// processes: IT processes with steps and KPIs
		auto itProcessUc = new ManageElementsInteractor!(ITProcess, ITProcessDto)(itProcesses, integrity, events);
		itProcessUc.enrichWith((ITProcess p) {
			import std.algorithm : count;
			p.hierarchyPath = hierarchyPath!"parentProcessId"(p, itProcesses.findAll);
			p.totalSteps = cast(int) processSteps.findAll.count!(s => s.processId == p.id);
			KpiStatus[] states;
			foreach (k; processKpis.findAll) if (k.processId == p.id) { k.derive(); states ~= k.kpiStatus; }
			p.kpiStatus = worstKpiStatus(states);
		});
		f._itProcesses = itProcessUc;
		auto stepUc = new ManageElementsInteractor!(ProcessStep, ProcessStepDto)(processSteps, integrity, events);
		stepUc.validateWith((ProcessStep s) {
			foreach (o; processSteps.findAll)
				if (o.id != s.id && o.processId == s.processId && o.sequenceNo == s.sequenceNo)
					throw new ValidationException("sequenceNo", format("Sequence no. %s is already used by step '%s'", s.sequenceNo, o.name));
		});
		f._processSteps = stepUc;
		auto kpiUc = new ManageElementsInteractor!(ProcessKpi, ProcessKpiDto)(processKpis, integrity, events);
		kpiUc.enrichWith((ProcessKpi k) { k.derive(); });
		f._processKpis = kpiUc;
		// security: protection requirements, risks, controls
		auto protectionUc = new ManageElementsInteractor!(ProtectionRequirement, ProtectionRequirementDto)(protection, integrity, events);
		protectionUc.validateWith((ProtectionRequirement p) {
			foreach (o; protection.findAll)
				if (o.id != p.id && o.objectKey == p.objectKey)
					throw new ValidationException("applicationId", "This object already has a protection requirement: " ~ o.id);
		});
		protectionUc.enrichWith((ProtectionRequirement p) {
			p.derive();
			p.reviewOverdue = p.status == SpecificationStatus.Approved && p.nextReviewDate.length && p.nextReviewDate < todayIso();
		});
		f._protectionRequirements = protectionUc;
		auto riskUc = new ManageElementsInteractor!(SecurityRisk, SecurityRiskDto)(risks, integrity, events);
		riskUc.enrichWith((SecurityRisk r) { r.derive(); });
		f._securityRisks = riskUc;
		auto controlUc = new ManageElementsInteractor!(SecurityControl, SecurityControlDto)(controls, integrity, events);
		controlUc.enrichWith((SecurityControl c) {
			import std.algorithm : canFind, count;
			c.overdue = SecurityControl.isOverdue(c.implementationStatus, c.dueDate, todayIso());
			c.mitigatedRisks = cast(int) risks.findAll.count!(r => r.controlIds.canFind(c.id));
		});
		f._securityControls = controlUc;
		// reporting: definitions are checked against the meta model when saved
		auto reportUc = new ManageElementsInteractor!(Report, ReportDto)(reports, integrity, events);
		reportUc.validateWith((Report r) { validateReportDefinition(mapFields!ReportDto(r)); });
		f._reports = reportUc;
		f._reportBooks = new ManageElementsInteractor!(ReportBook, ReportBookDto)(reportBooks, integrity, events);
		f._reporting = new ReportingInteractor(useCases);
		// comment journal of all elements; deleting an element removes its comments
		auto comments = new CommentRepository(storage);
		f._comments = new CommentsInteractor(useCases, comments);
		static foreach (S; EamDtoSets) {{
			auto interactor = cast(ManageElementsInteractor!(S.Entity, S.Dto)) manage!S(useCases);
			if (interactor !is null) interactor.onRemoved((string id) { comments.removeForElement(S.setName, id); });
		}}
		// access management: users, roles, permissions and the access control built on them
		AccessControlInteractor accessControl;
		auto userUc = new ManageElementsInteractor!(User, UserDto)(users, integrity, events);
		userUc.validateWith((User u) {
			import std.string : toLower;
			foreach (other; users.findAll)
				if (other.id != u.id && other.userName.toLower == u.userName.toLower)
					throw new ValidationException("userName", "User name '" ~ u.userName ~ "' is already used by " ~ other.id);
		});
		userUc.enrichWith((User u) { u.effectiveRights = accessControl.rightsOfUser(u).summary; });
		f._users = userUc;
		auto roleUc = new ManageElementsInteractor!(Role, RoleDto)(roles, integrity, events);
		roleUc.enrichWith((Role r) {
			import std.algorithm : canFind, count;
			r.totalUsers = cast(int) users.findAll.count!(u => u.roleIds.canFind(r.id));
		});
		f._roles = roleUc;
		auto permissionUc = new ManageElementsInteractor!(Permission, PermissionDto)(permissions, integrity, events);
		permissionUc.enrichWith((Permission p) {
			import std.algorithm : canFind, count;
			p.totalRoles = cast(int) roles.findAll.count!(r => r.permissionIds.canFind(p.id));
		});
		f._permissions = permissionUc;
		f._search = new SearchElementsInteractor(useCases);
		// dry-run imports run against a throw-away in-memory copy of the repository
		IEamUseCases delegate() sandbox = () {
			auto copy = new MemoryStorage;
			foreach (c; storage.collections) {
				Json[] docs;
				foreach (d; storage.load(c)) docs ~= d.clone;
				copy.store(c, docs);
			}
			return cast(IEamUseCases) new EamContainer(AppConfig.init, copy).useCases;
		};
		f._transfer = new TransferElementsInteractor(useCases, sandbox);
		accessControl = new AccessControlInteractor(useCases, users, roles, permissions, sandbox,
			new CredentialRepository(storage), passwordHasher);
		f._access = accessControl;
		userUc.onRemoved((string id) { accessControl.userRemoved(id); });
		f._analysis = new AnalyzePortfolioInteractor(apps, caps, comps, flows, projects, products, registry);
		f._archimate = new ArchiMateExporter(apps, caps, comps, flows, orgs, projects, products, productGroups, appGroups,
			processes, data, catalogs, guidelines, serviceCaps, measureGroups, measures,
			principles, archGuidelines, refArchs, documents, subProjects, workPackages, enterprises,
			itProcesses, processSteps, risks, controls);
		f._seeder = new SeedSampleDataInteractor(useCases);
	}

	/// Container backed by the configured JSON file; seeds demo data if configured and empty.
	static EamContainer fromConfig(AppConfig config, bool audit = true) {
		auto c = new EamContainer(config, new JsonFileStorage(config.dataFile),
			audit ? new LoggingEventPublisher : null);
		if (config.seedOnEmpty) {
			auto n = c.useCases.seeder.seed();
			if (n) logInfo("Seeded %s sample architecture elements into %s", n, config.dataFile);
		}
		return c;
	}

	/// Platform with all tenants (one data file each), tenant registry and backup store from the configuration.
	/// The default tenant is seeded with demo data if configured and empty.
	static EamPlatform platformFromConfig(AppConfig config, bool audit = true) {
		auto events = audit ? new LoggingEventPublisher : null;
		auto platform = new EamPlatform(new TenantRegistry(new JsonFileStorage(config.tenantRegistryFile)),
			new FileTenantStorageProvider(config.dataFile, config.tenantDirectory),
			new BackupFileStore(config.backupDirectory),
			(IDocumentStorage s) => cast(IEamUseCases) new EamContainer(config, s, events).useCases,
			config.backupRetention);
		if (config.seedOnEmpty) {
			auto n = platform.tenantUseCases(defaultTenantId).seeder.seed();
			if (n) logInfo("Seeded %s sample architecture elements into %s", n, config.dataFile);
		}
		return platform;
	}

	/// Volatile platform (tests): tenants, registry and backups in memory.
	static EamPlatform inMemoryPlatform() {
		return new EamPlatform(new TenantRegistry(new MemoryStorage), new MemoryTenantStorageProvider,
			new MemoryBackupStore, (IDocumentStorage s) => cast(IEamUseCases) new EamContainer(AppConfig.init, s).useCases, 3);
	}

	/// Volatile container (tests).
	static EamContainer inMemory() {
		return new EamContainer(AppConfig.init, new MemoryStorage);
	}
}
