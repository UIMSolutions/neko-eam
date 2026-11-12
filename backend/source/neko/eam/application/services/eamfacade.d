/// Facade bundling all driving ports for the presentation adapters.
module neko.eam.application.services.eamfacade;

import neko.eam.ports.usecases;

class EamFacade : IEamUseCases {
	IManageElements!ApplicationDto _apps;
	IManageElements!BusinessCapabilityDto _caps;
	IManageElements!ITComponentDto _comps;
	IManageElements!InformationFlowDto _flows;
	IManageElements!OrganizationDto _orgs;
	IManageElements!ProjectDto _projects;
	IManageElements!ProductDto _products;
	IManageElements!ProductGroupDto _productGroups;
	IManageElements!ApplicationGroupDto _applicationGroups;
	IManageElements!BusinessProcessDto _businessProcesses;
	IManageElements!BusinessDataDto _businessData;
	IManageElements!ServiceProductGroupDto _serviceProductGroups;
	IManageElements!StrategicGuidelineDto _strategicGuidelines;
	IManageElements!ServiceCapabilityDto _serviceCapabilities;
	IManageElements!MeasureGroupDto _measureGroups;
	IManageElements!MeasureDto _measures;
	IManageElements!ArchitecturePrincipleDto _architecturePrinciples;
	IManageElements!ArchitectureGuidelineDto _architectureGuidelines;
	IManageElements!ReferenceArchitectureDto _referenceArchitectures;
	IManageElements!ArchitectureDocumentDto _architectureDocuments;
	IManageElements!SubProjectDto _subProjects;
	IManageElements!WorkPackageDto _workPackages;
	IManageElements!EnterpriseDto _enterprises;
	IManageElements!MemberDto _members;
	IManageElements!ITProcessDto _itProcesses;
	IManageElements!ProcessStepDto _processSteps;
	IManageElements!ProcessKpiDto _processKpis;
	IManageElements!ProtectionRequirementDto _protectionRequirements;
	IManageElements!SecurityRiskDto _securityRisks;
	IManageElements!SecurityControlDto _securityControls;
	IManageElements!ReportDto _reports;
	IManageElements!ReportBookDto _reportBooks;
	IManageElements!UserDto _users;
	IManageElements!RoleDto _roles;
	IManageElements!PermissionDto _permissions;
	IAccessControl _access;
	ISearchElements _search;
	ITransferElements _transfer;
	IAnalyzePortfolio _analysis;
	ISeedSampleData _seeder;
	IArchiMateExport _archimate;

	IManageElements!ApplicationDto applications() { return _apps; }
	IManageElements!BusinessCapabilityDto capabilities() { return _caps; }
	IManageElements!ITComponentDto components() { return _comps; }
	IManageElements!InformationFlowDto flows() { return _flows; }
	IManageElements!OrganizationDto organizations() { return _orgs; }
	IManageElements!ProjectDto projects() { return _projects; }
	IManageElements!ProductDto products() { return _products; }
	IManageElements!ProductGroupDto productGroups() { return _productGroups; }
	IManageElements!ApplicationGroupDto applicationGroups() { return _applicationGroups; }
	IManageElements!BusinessProcessDto businessProcesses() { return _businessProcesses; }
	IManageElements!BusinessDataDto businessData() { return _businessData; }
	IManageElements!ServiceProductGroupDto serviceProductGroups() { return _serviceProductGroups; }
	IManageElements!StrategicGuidelineDto strategicGuidelines() { return _strategicGuidelines; }
	IManageElements!ServiceCapabilityDto serviceCapabilities() { return _serviceCapabilities; }
	IManageElements!MeasureGroupDto measureGroups() { return _measureGroups; }
	IManageElements!MeasureDto measures() { return _measures; }
	IManageElements!ArchitecturePrincipleDto architecturePrinciples() { return _architecturePrinciples; }
	IManageElements!ArchitectureGuidelineDto architectureGuidelines() { return _architectureGuidelines; }
	IManageElements!ReferenceArchitectureDto referenceArchitectures() { return _referenceArchitectures; }
	IManageElements!ArchitectureDocumentDto architectureDocuments() { return _architectureDocuments; }
	IManageElements!SubProjectDto subProjects() { return _subProjects; }
	IManageElements!WorkPackageDto workPackages() { return _workPackages; }
	IManageElements!EnterpriseDto enterprises() { return _enterprises; }
	IManageElements!MemberDto members() { return _members; }
	IManageElements!ITProcessDto itProcesses() { return _itProcesses; }
	IManageElements!ProcessStepDto processSteps() { return _processSteps; }
	IManageElements!ProcessKpiDto processKpis() { return _processKpis; }
	IManageElements!ProtectionRequirementDto protectionRequirements() { return _protectionRequirements; }
	IManageElements!SecurityRiskDto securityRisks() { return _securityRisks; }
	IManageElements!SecurityControlDto securityControls() { return _securityControls; }
	IManageElements!ReportDto reports() { return _reports; }
	IManageElements!ReportBookDto reportBooks() { return _reportBooks; }
	IManageElements!UserDto users() { return _users; }
	IManageElements!RoleDto roles() { return _roles; }
	IManageElements!PermissionDto permissions() { return _permissions; }
	IAccessControl access() { return _access; }
	IReporting _reporting;
	IReporting reporting() { return _reporting; }
	IComments _comments;
	IComments comments() { return _comments; }
	ISearchElements search() { return _search; }
	ITransferElements transfer() { return _transfer; }
	IAnalyzePortfolio analysis() { return _analysis; }
	ISeedSampleData seeder() { return _seeder; }
	IArchiMateExport archimate() { return _archimate; }
}
