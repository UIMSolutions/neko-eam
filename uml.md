# Neko EAM – UML

Diagrams use [Mermaid](https://mermaid.js.org/) and render on GitHub, GitLab and in VS Code.
Module names refer to `backend/source/uim/myfiori/…`.

1. [Domain class diagram](#1-domain-class-diagram)
2. [Product catalogue & application groups](#2-product-catalogue--application-groups)
3. [Business architecture & service catalogue](#3-business-architecture--service-catalogue)
4. [IT landscape planning](#4-it-landscape-planning)
5. [Specifications](#5-specifications)
6. [Project management](#6-project-management)
7. [Access management](#7-access-management)
8. [Organisation structure](#8-organisation-structure)
9. [Platform: tenants, backup & restore](#9-platform-tenants-backup--restore)
10. [Processes, security & reporting](#10-processes-security--reporting)
11. [Comments (journal)](#11-comments-journal)
12. [Ports & use cases](#12-ports--use-cases)
13. [Component diagram (hexagonal architecture)](#13-component-diagram-hexagonal-architecture)
14. [Sequence: create an application via OData](#14-sequence-create-an-application-via-odata)
15. [Sequence: delete with referential integrity](#15-sequence-delete-with-referential-integrity)
16. [Sequence: WebView start-up](#16-sequence-webview-start-up)
17. [Sequence: Fiori shell start-up (user profile & meta model)](#17-sequence-fiori-shell-start-up-user-profile--meta-model)
18. [Sequence: edit on the object page (Edit → Save)](#18-sequence-edit-on-the-object-page-edit--save)
19. [Sequence: central search (shell bar)](#19-sequence-central-search-shell-bar)
20. [Sequence: CSV / XLSX import (check, then import)](#20-sequence-csv--xlsx-import-check-then-import)
21. [Deployment diagram](#21-deployment-diagram)
22. [Use case diagram](#22-use-case-diagram)
23. [State diagram: application lifecycle](#23-state-diagram-application-lifecycle)
24. [State diagram: measure planning status](#24-state-diagram-measure-planning-status)
25. [State diagram: work package status](#25-state-diagram-work-package-status)
26. [Sequence: authorization of a request](#26-sequence-authorization-of-a-request)
27. [Sequence: restore a backup](#27-sequence-restore-a-backup)

---

## 1. Domain class diagram

```mermaid
classDiagram
    direction LR

    class ArchitectureElementFields {
        <<mixin>>
        +string id
        +string name  «Required»
        +string description
        +string createdAt
        +string createdBy
        +string modifiedAt
        +string modifiedBy
    }

    class Application {
        +string release
        +LifecycleStatus status
        +Criticality criticality
        +TimeCategory timeCategory
        +int businessValue  1..5
        +int technicalFit  1..5
        +double annualCost
        +string goLiveDate  «DateField»
        +string retirementDate  «DateField»
        +string ownerOrganizationId  «References Organizations»
        +string[] capabilityIds  «References BusinessCapabilities»
        +string[] componentIds  «References ITComponents»
        +string levelId
        +ObjectState objectState
        +string applicationGroupId  «References ApplicationGroups»
        +string stakeholder
        +string[] usedProductIds  «References Products»
        +string[] assignedProductIds  «References Products»
        +int totalUsedProducts  «derived»
        +int totalAssignedProducts  «derived»
        +isOperational() bool
        +derive()
        +validate()
    }

    class BusinessCapability {
        +int level  1..5 (Level ID Number)
        +int strategicImportance  1..5
        +string parentId  «References BusinessCapabilities»
        +string ownerOrganizationId  «References Organizations»
        +string levelId
        +Criticality missionCriticality
        +string stakeholder
        +string hierarchyPath  «derived»
        +validate()
    }

    class ITComponent {
        +string vendor
        +string release
        +TechnologyCategory category
        +LifecycleStatus status
        +string endOfSupportDate  «DateField»
        +double licenseCost
        +isOutdated(today) bool
        +validate()
    }

    class InformationFlow {
        +string sourceApplicationId  «Required, References Applications»
        +string targetApplicationId  «Required, References Applications»
        +InterfaceType flowType
        +string dataObject
        +string frequency
        +validate()
    }

    class Organization {
        +OrganizationType orgType
        +string location
        +string parentId  «References Organizations»
        +string shortName
        +ObjectState status
        +string startDate / endDate  «DateField»
        +string architect / contact / stakeholder
        +int totalConsumedBusinessServices
        +int totalProvidedBusinessServices
        +int totalProvidedSupportServices
        +string hierarchyPath  «derived»
        +validate()
    }

    class Project {
        +ProjectStatus status
        +string startDate  «DateField»
        +string endDate  «DateField»
        +double budget
        +string sponsorOrganizationId  «References Organizations»
        +string[] affectedApplicationIds  «References Applications»
        +string projectNumber / projectManager
        +ProjectPhase phase
        +validate()
    }

    ArchitectureElementFields <|.. Application
    ArchitectureElementFields <|.. BusinessCapability
    ArchitectureElementFields <|.. ITComponent
    ArchitectureElementFields <|.. InformationFlow
    ArchitectureElementFields <|.. Organization
    ArchitectureElementFields <|.. Project
    ArchitectureElementFields <|.. Product
    ArchitectureElementFields <|.. ProductGroup
    ArchitectureElementFields <|.. ApplicationGroup
    ArchitectureElementFields <|.. BusinessProcess
    ArchitectureElementFields <|.. BusinessData
    ArchitectureElementFields <|.. ServiceProductGroup
    ArchitectureElementFields <|.. StrategicGuideline
    ArchitectureElementFields <|.. ServiceCapability
    ArchitectureElementFields <|.. MeasureGroup
    ArchitectureElementFields <|.. Measure
    ArchitectureElementFields <|.. ArchitecturePrinciple
    ArchitectureElementFields <|.. ArchitectureGuideline
    ArchitectureElementFields <|.. ReferenceArchitecture
    ArchitectureElementFields <|.. ArchitectureDocument
    ArchitectureElementFields <|.. SubProject
    ArchitectureElementFields <|.. WorkPackage
    ArchitectureElementFields <|.. Enterprise
    ArchitectureElementFields <|.. Member
    ArchitectureElementFields <|.. ITProcess
    ArchitectureElementFields <|.. ProcessStep
    ArchitectureElementFields <|.. ProcessKpi
    ArchitectureElementFields <|.. ProtectionRequirement
    ArchitectureElementFields <|.. SecurityRisk
    ArchitectureElementFields <|.. SecurityControl
    ArchitectureElementFields <|.. Report
    ArchitectureElementFields <|.. ReportBook
    ArchitectureElementFields <|.. User
    ArchitectureElementFields <|.. Role
    ArchitectureElementFields <|.. Permission

    Application "*" --> "0..1" Organization : owner
    Application "*" --> "*" BusinessCapability : supports
    Application "*" --> "*" ITComponent : uses
    InformationFlow "*" --> "1" Application : source
    InformationFlow "*" --> "1" Application : target
    BusinessCapability "*" --> "0..1" BusinessCapability : parent
    BusinessCapability "*" --> "0..1" Organization : owner
    Organization "*" --> "0..1" Organization : parent
    Project "*" --> "0..1" Organization : sponsor
    Project "*" --> "*" Application : changes
    Application "*" --> "0..1" ApplicationGroup : parent group
    Application "*" --> "*" Product : uses / assigned

    class LifecycleStatus {
        <<enumeration>>
        Plan
        Build
        Active
        PhaseOut
        Retired
    }
    class Criticality {
        <<enumeration>>
        Low
        Medium
        High
        MissionCritical
    }
    class TimeCategory {
        <<enumeration>>
        Tolerate
        Invest
        Migrate
        Eliminate
    }
    class TechnologyCategory {
        <<enumeration>>
        Software
        Platform
        Database
        Middleware
        Hardware
        Cloud
    }
    class InterfaceType {
        <<enumeration>>
        Api
        File
        Message
        Database
        Manual
    }
    class ProjectStatus {
        <<enumeration>>
        Proposed
        Approved
        InProgress
        Completed
        Cancelled
    }
    class OrganizationType {
        <<enumeration>>
        Company
        BusinessUnit
        Department
        Team
        External
    }
    class ObjectState {
        <<enumeration>>
        Draft
        Active
        Inactive
        Archived
    }

    class PortfolioAnalyzer {
        <<domain service>>
        +recommendTime(bv, tf)$ TimeCategory
        +assessTime(apps)$ TimeAssessment[]
        +technologyRisks(apps, comps, today)$ TechnologyRisk[]
        +coverage(caps, apps)$ CapabilityCoverage[]
    }
    class ImpactAnalyzer {
        <<domain service>>
        +analyze(app, flows, projects)$ Impact
    }
    PortfolioAnalyzer ..> Application
    PortfolioAnalyzer ..> ITComponent
    PortfolioAnalyzer ..> BusinessCapability
    ImpactAnalyzer ..> InformationFlow
    ImpactAnalyzer ..> Project

    class DomainException
    class ValidationException {
        +string field
    }
    class EntityNotFoundException {
        +string kind
        +string id
    }
    class ConflictException
    class ReferentialIntegrityException
    DomainException <|-- ValidationException
    DomainException <|-- EntityNotFoundException
    DomainException <|-- ConflictException
    DomainException <|-- ReferentialIntegrityException
```

`Product`, `ProductGroup` and `ApplicationGroup` are shown in detail in [section 2](#2-product-catalogue--application-groups),
`BusinessProcess`, `BusinessData` and `ServiceProductGroup` in [section 3](#3-business-architecture--service-catalogue),
`StrategicGuideline`, `ServiceCapability`, `MeasureGroup` and `Measure` in [section 4](#4-it-landscape-planning),
the specifications in [section 5](#5-specifications), sub projects and work packages in
[section 6](#6-project-management), users, roles and permissions in [section 7](#7-access-management), enterprises, units and members in
[section 8](#8-organisation-structure).
The stereotypes `«Required»`, `«DateField»` and `«References X»` are D user-defined attributes.
They drive generic validation (`validateAnnotatedFields`), the integrity checks
(`IntegrityService`, `DocumentRepository.findReferencing`) and the OData `$metadata` (`Edm.Date`, `Nullable="false"`).

---

## 2. Product catalogue & application groups

```mermaid
classDiagram
    direction LR

    class Product {
        +string componentId  «References ITComponents»
        +string productVersion
        +string majorVersion
        +VersionType versionType
        +string productGroupId  «References ProductGroups»
        +string vendor
        +string vendorWeblink
        +ProductStatus status
        +LifecycleStatus lifecycleStatus
        +ApprovalStatus approvalStatus
        +string cpeId / certlichId / pulsId
        +string startDate / endDate  «DateField»
        +string endOfSupport / endOfSecurity / endOfLife  «DateField»
        +string endOfSupportContract / bsiPermissionEndDate  «DateField»
        +string dueDateNextValidation  «DateField»
        +int eolReminderDays / eosuReminderDays / milestoneReminderDays
        +string eolReminderDate / eosuReminderDate  «derived»
        +double licenseCosts
        +bool isBlacklisted
        +RiskLevel riskEvaluation
        +ProtectionLevel protection / dataProtectionRequirements
        +double dataQualityIndex  0..100
        +int totalErrors / totalWarnings / totalHints
        +string technicalOrganizationId  «References Organizations»
        +… 40 further attributes (classification, licensing, usage, support)
        +derive()
        +isUsable() bool
        +validate()
    }

    class ProductGroup {
        +string capabilityId  «References BusinessCapabilities»
        +string levelId
        +ObjectState objectState
        +string parentGroupId  «References ProductGroups»
        +validate()
    }

    class ApplicationGroup {
        +string capabilityId  «References BusinessCapabilities»
        +string levelId
        +ObjectState objectState
        +string parentGroupId  «References ApplicationGroups»
        +string stakeholder
        +int totalUsedProducts  «rolled up»
        +int totalAssignedProducts  «rolled up»
        +validate()
    }

    class Application
    class ITComponent
    class BusinessCapability
    class Organization

    Product "*" --> "0..1" ProductGroup : group
    Product "*" --> "0..1" ITComponent : version of
    Product "*" --> "0..1" Organization : technical responsibility
    ProductGroup "*" --> "0..1" ProductGroup : parent
    ProductGroup "*" --> "0..1" BusinessCapability : IT capability
    ApplicationGroup "*" --> "0..1" ApplicationGroup : parent
    ApplicationGroup "*" --> "0..1" BusinessCapability : IT capability
    Application "*" --> "0..1" ApplicationGroup : parent group
    Application "*" --> "*" Product : used / assigned

    class ProductLifecycleMonitor {
        <<domain service>>
        +alerts(products, apps, today)$ ProductAlert[]
    }
    class ApplicationGroupRollup {
        <<domain service>>
        +int used
        +int assigned
        +compute(groupId, groups, apps)$ ApplicationGroupRollup
    }
    class ProductAlert {
        <<value object>>
        +string productId
        +ProductAlertKind kind
        +string date
        +RiskLevel severity
        +string message
        +string[] applicationIds
    }
    ProductLifecycleMonitor ..> Product
    ProductLifecycleMonitor ..> Application
    ProductLifecycleMonitor ..> ProductAlert
    ApplicationGroupRollup ..> ApplicationGroup
    ApplicationGroupRollup ..> Application

    class ProductAlertKind {
        <<enumeration>>
        EndOfSupport
        EndOfSecurity
        EndOfLife
        BsiPermissionExpired
        Blacklisted
        ReminderDue
        ValidationOverdue
    }
    class ApprovalStatus {
        <<enumeration>>
        Requested
        InReview
        Approved
        ApprovedWithConditions
        Rejected
    }
    class ProductStatus {
        <<enumeration>>
        Draft
        Released
        Deprecated
        Withdrawn
    }
    class ProtectionLevel {
        <<enumeration>>
        Normal
        High
        VeryHigh
    }
    class RiskLevel {
        <<enumeration>>
        Low
        Medium
        High
        Critical
    }
    class VersionType {
        <<enumeration>>
        Major
        Minor
        Patch
        ServicePack
        Build
    }
```

* **Derived values** are computed by the entity's `derive()` before validation. They are
  `totalUsedProducts` and `totalAssignedProducts` (distinct product references) and the reminder dates
  `eolReminderDate = endOfLife − eolReminderDays` and `eosuReminderDate = endOfSupport − eosuReminderDays`.
* **Roll-up**: the application group totals are computed at read time by an *enricher* that
  `composition.d` registers on the group interactor (`ApplicationGroupRollup` over the group subtree,
  with cycle protection), so they are never stale.
* Rules: a blacklisted product cannot be (conditionally) approved, weblinks must be http(s), and the
  data-quality index must be 0..100.

---

## 3. Business architecture & service catalogue

```mermaid
classDiagram
    direction LR

    class Organization {
        +string hierarchyPath  «derived: Organisation»
        +string shortName
        +ObjectState status
        +string startDate / endDate
        +string architect / contact / stakeholder
        +int totalConsumedBusinessServices
        +int totalProvidedBusinessServices
        +int totalProvidedSupportServices
        +validate()
    }
    class BusinessCapability {
        +string hierarchyPath  «derived: Business Capability»
        +string levelId
        +int level  «Level ID Number»
        +Criticality missionCriticality
        +string stakeholder
    }
    class BusinessProcess {
        +string hierarchyPath  «derived: Business Process»
        +string levelId
        +LifecycleStatus status
        +string processOwner
        +string processManager
        +string parentProcessId  «References BusinessProcesses»
        +validate()
    }
    class BusinessData {
        +string dataVersion  «Version»
        +string businessObject
        +DpiaRating dpiaRating
        +string capabilityId  «References BusinessCapabilities»
        +string[] informationFlowIds  «References InformationFlows»
        +string ownerOrganizationId  «References Organizations»
        +validate()
    }
    class ServiceProductGroup {
        +string hierarchyPath  «derived: Catalog»
        +string shortName
        +CatalogType catalogType
        +string catalogVersion  «Version»
        +ProductStatus status
        +string catalogueManager
        +string releaseDate  «DateField»
        +string parentId  «References ServiceProductGroups»
        +validate()
    }
    class DpiaRating {
        <<enumeration>>
        NotAssessed
        NotRequired
        Low
        Medium
        High
    }
    class CatalogType {
        <<enumeration>>
        BusinessService
        TechnicalService
        SupportService
        ServiceProduct
    }
    class hierarchyPath {
        <<domain service>>
        +hierarchyPath!(parentField)(element, all, separator)$ string
    }

    Organization "*" --> "0..1" Organization : parent
    BusinessCapability "*" --> "0..1" BusinessCapability : parent
    BusinessProcess "*" --> "0..1" BusinessProcess : parent
    ServiceProductGroup "*" --> "0..1" ServiceProductGroup : parent catalog
    BusinessData "*" --> "0..1" Organization : owner
    BusinessData "*" --> "0..1" BusinessCapability : business capability
    BusinessData "*" --> "*" InformationFlow : transported by
    BusinessData ..> DpiaRating
    ServiceProductGroup ..> CatalogType
    hierarchyPath ..> Organization
    hierarchyPath ..> BusinessCapability
    hierarchyPath ..> BusinessProcess
    hierarchyPath ..> ServiceProductGroup
```

The first column of the Neko reports (*Organisation*, *Business Capability*, *Business Process*,
*Catalog*) is the **hierarchy path**. It is not stored: the composition root registers a read-time
enricher per set (`ManageElementsInteractor.enrichWith`) that walks the parent chain with
`hierarchyPath!"parentId"` (cycle-safe). Rules: an organisation past its end date cannot be *Active*,
an *Active* process needs an owner, business data rated *Medium*/*High* in the DPIA needs an owner, and a
*Released* catalogue needs a date of release.

---

## 4. IT landscape planning

```mermaid
classDiagram
    direction LR

    class StrategicGuideline {
        +string hierarchyPath  «derived: Strategic Guideline»
        +string shortName
        +GuidelineCategory category
        +PlanningPriority priority
        +ObjectState status
        +string rationale
        +string implications
        +string guidelineOwner
        +string ownerOrganizationId  «References Organizations»
        +string validFrom  «DateField»
        +string validUntil  «DateField»
        +string parentId  «References StrategicGuidelines»
        +string[] capabilityIds  «References BusinessCapabilities»
        +validate()
    }
    class ServiceCapability {
        +string hierarchyPath  «derived: Service Capability»
        +string shortName
        +string levelId
        +LifecycleStatus status
        +Criticality missionCriticality
        +int currentMaturity  «1-5»
        +int targetMaturity  «1-5»
        +int maturityGap  «derived»
        +string stakeholder
        +string ownerOrganizationId  «References Organizations»
        +string parentId  «References ServiceCapabilities»
        +string businessCapabilityId  «References BusinessCapabilities»
        +string[] serviceProductGroupIds  «References ServiceProductGroups»
        +string[] applicationIds  «References Applications»
        +derive()
        +validate()
    }
    class MeasureGroup {
        +string hierarchyPath  «derived: Measure Group»
        +string shortName
        +PlanningStatus status
        +string responsible
        +string ownerOrganizationId  «References Organizations»
        +string startDate / endDate  «DateField»
        +double budget
        +string parentGroupId  «References MeasureGroups»
        +string[] strategicGuidelineIds  «References StrategicGuidelines»
        +int totalMeasures  «rolled up»
        +double totalEstimatedCost  «rolled up»
        +validate()
    }
    class Measure {
        +string shortName
        +MeasureType measureType
        +PlanningPriority priority
        +PlanningStatus status
        +int progress  «0-100 %»
        +string responsible
        +string ownerOrganizationId  «References Organizations»
        +string startDate / endDate  «DateField»
        +double estimatedCost
        +string expectedBenefit
        +string measureGroupId  «References MeasureGroups»
        +string projectId  «References Projects»
        +string[] strategicGuidelineIds  «References StrategicGuidelines»
        +string[] serviceCapabilityIds  «References ServiceCapabilities»
        +string[] affectedApplicationIds  «References Applications»
        +string[] affectedComponentIds  «References ITComponents»
        +validate()
    }
    class MeasureGroupRollup {
        <<domain service>>
        +int measures
        +double estimatedCost
        +compute(groupId, groups, measures)$ MeasureGroupRollup
    }
    class GuidelineCategory {
        <<enumeration>>
        Business
        Architecture
        Technology
        Data
        Security
        Sourcing
        Compliance
    }
    class PlanningStatus {
        <<enumeration>>
        Draft
        Proposed
        Approved
        InProgress
        Completed
        Rejected
        Cancelled
    }
    class MeasureType {
        <<enumeration>>
        Introduce
        Modernize
        Migrate
        Consolidate
        Retire
        Optimize
        Invest
    }
    class PlanningPriority {
        <<enumeration>>
        Low
        Medium
        High
        Critical
    }

    StrategicGuideline "*" --> "0..1" StrategicGuideline : parent
    StrategicGuideline "*" --> "*" BusinessCapability : applies to
    StrategicGuideline "*" --> "0..1" Organization : responsible
    ServiceCapability "*" --> "0..1" ServiceCapability : parent
    ServiceCapability "*" --> "0..1" BusinessCapability : supports
    ServiceCapability "*" --> "*" ServiceProductGroup : offered in
    ServiceCapability "*" --> "*" Application : realised by
    MeasureGroup "*" --> "0..1" MeasureGroup : parent
    MeasureGroup "*" --> "*" StrategicGuideline : implements
    Measure "*" --> "0..1" MeasureGroup : group
    Measure "*" --> "0..1" Project : implemented by
    Measure "*" --> "*" StrategicGuideline : implements
    Measure "*" --> "*" ServiceCapability : improves
    Measure "*" --> "*" Application : changes
    Measure "*" --> "*" ITComponent : changes
    MeasureGroupRollup ..> MeasureGroup
    MeasureGroupRollup ..> Measure
    StrategicGuideline ..> GuidelineCategory
    Measure ..> MeasureType
    Measure ..> PlanningStatus
    MeasureGroup ..> PlanningStatus
```

The **IT landscape planning** (*IT-Bebauungsplanung*) links the IT strategy to concrete changes:
strategic guidelines (principles such as *Cloud first*) are implemented by measure groups (roadmap streams)
and measures; measures improve service capabilities and change applications and IT components; a project
can implement several measures. Derived at read time: the hierarchy paths, the **maturity gap** of a service
capability (target − current, never negative) and the **totals of a measure group** (number and estimated
cost of the measures of its subtree, rejected and cancelled measures excluded).
Rules: an *Active* guideline needs an owner and a rationale; maturity levels are 1–5; an *Approved* group or
an *Approved* / *InProgress* measure needs a responsible person; a running measure needs a start date; a
*Completed* measure is at 100 %; *Retire* and *Migrate* measures must name the affected applications or
IT components. ArchiMate export: Principle, Capability, Grouping and WorkPackage.

---

## 5. Specifications

```mermaid
classDiagram
    direction LR

    class ArchitecturePrinciple {
        +string shortName
        +ArchitectureDomain domain
        +PlanningPriority priority
        +SpecificationStatus status
        +string specVersion  «Version»
        +string statement
        +string rationale
        +string implications
        +string principleOwner
        +string ownerOrganizationId  «References Organizations»
        +string validFrom / validUntil  «DateField»
        +string[] strategicGuidelineIds  «References StrategicGuidelines»
        +validate()
    }
    class ArchitectureGuideline {
        +string shortName
        +ArchitectureDomain domain
        +ObligationLevel obligation
        +SpecificationStatus status
        +string specVersion  «Version»
        +string applicability
        +string verification  «Compliance Verification»
        +string guidelineOwner
        +string ownerOrganizationId  «References Organizations»
        +string validFrom / validUntil  «DateField»
        +string[] principleIds  «References ArchitecturePrinciples»
        +string[] standardProductIds  «References Products»
        +string[] componentIds  «References ITComponents»
        +validate()
    }
    class ReferenceArchitecture {
        +string hierarchyPath  «derived: Reference Architecture»
        +string shortName
        +ArchitectureDomain domain
        +SpecificationStatus status
        +string specVersion  «Version»
        +string scopeDescription  «Scope»
        +string architect
        +string ownerOrganizationId  «References Organizations»
        +string validFrom / validUntil  «DateField»
        +string parentId  «References ReferenceArchitectures»
        +string[] principleIds / guidelineIds
        +string[] capabilityIds / componentIds / standardProductIds / applicationIds
        +int totalDocuments  «derived»
        +validate()
    }
    class ArchitectureDocument {
        +string documentNumber
        +DocumentType documentType
        +SpecificationStatus status
        +string docVersion  «Version»
        +Confidentiality confidentiality
        +string author / approver
        +string approvalDate / nextReviewDate  «DateField»
        +string documentLink  «http(s)»
        +string ownerOrganizationId  «References Organizations»
        +string[] referenceArchitectureIds / principleIds / guidelineIds / applicationIds
        +bool reviewOverdue  «derived»
        +isReviewOverdue(status, nextReviewDate, today)$ bool
        +validate()
    }
    class SpecificationStatus {
        <<enumeration>>
        Draft
        InReview
        Approved
        Deprecated
        Withdrawn
    }
    class ArchitectureDomain {
        <<enumeration>>
        Business
        Data
        Application
        Technology
        Security
        Integration
    }
    class ObligationLevel {
        <<enumeration>>
        Mandatory
        Recommended
        Optional
    }
    class DocumentType {
        <<enumeration>>
        Concept
        Specification
        Standard
        Decision
        Policy
        Manual
        Template
        Report
    }

    ArchitecturePrinciple "*" --> "*" StrategicGuideline : derived from
    ArchitectureGuideline "*" --> "*" ArchitecturePrinciple : derived from
    ArchitectureGuideline "*" --> "*" Product : standard products
    ArchitectureGuideline "*" --> "*" ITComponent : applies to
    ReferenceArchitecture "*" --> "0..1" ReferenceArchitecture : parent
    ReferenceArchitecture "*" --> "*" ArchitecturePrinciple : follows
    ReferenceArchitecture "*" --> "*" ArchitectureGuideline : follows
    ReferenceArchitecture "*" --> "*" ITComponent : building blocks
    ReferenceArchitecture "*" --> "*" Product : standard products
    ReferenceArchitecture "*" --> "*" Application : implemented by
    ArchitectureDocument "*" --> "*" ReferenceArchitecture : describes
    ArchitectureDocument "*" --> "*" ArchitecturePrinciple : describes
    ArchitectureDocument "*" --> "*" ArchitectureGuideline : describes
    ArchitectureDocument ..> DocumentType
    ArchitectureGuideline ..> ObligationLevel
    ArchitecturePrinciple ..> SpecificationStatus
    ReferenceArchitecture ..> ArchitectureDomain
```

The **specifications** form a chain from strategy to solution: strategic guidelines → architecture
principles (statement, rationale, implications) → architecture guidelines (checkable rules, optionally with
standard products) → reference architectures (blueprints from building blocks) → applications that implement
them. Architecture documents (concepts, specifications, decisions/ADRs, policies …) describe all of them.
Derived at read time: the hierarchy path and the **number of documents** of a reference architecture, and
**Review Overdue** of a document (*Approved* and next review date in the past).
Rules: an *Approved* principle needs owner, statement and rationale; an *Approved* guideline needs an owner;
a *Mandatory* guideline is derived from at least one principle; an *Approved* reference architecture needs an
architect and at least one principle or guideline; an *Approved* document needs approver and approval date;
the document link must be an http(s) URL. ArchiMate export: Principle, Constraint (mandatory guideline) /
Requirement, Grouping and Representation.

---

## 6. Project management

```mermaid
classDiagram
    direction LR

    class Project {
        +string projectNumber
        +ProjectStatus status
        +ProjectPhase phase
        +PlanningPriority priority
        +string projectManager
        +string startDate / endDate  «DateField»
        +double budget
        +double actualCost
        +string sponsorOrganizationId  «References Organizations»
        +string[] affectedApplicationIds  «References Applications»
        +int totalSubProjects  «rolled up»
        +int totalWorkPackages  «rolled up»
        +double plannedEffortDays  «rolled up»
        +int progress  «rolled up, %»
        +validate()
    }
    class SubProject {
        +string hierarchyPath  «derived: Sub Project»
        +string shortName
        +string projectId  «Required, References Projects»
        +string parentSubProjectId  «References SubProjects»
        +ProjectStatus status
        +string subProjectManager
        +string startDate / endDate  «DateField»
        +double budget
        +string ownerOrganizationId  «References Organizations»
        +string[] affectedApplicationIds  «References Applications»
        +int totalWorkPackages  «rolled up»
        +double plannedEffortDays  «rolled up»
        +int progress  «rolled up, %»
        +validate()
    }
    class WorkPackage {
        +string wbsCode
        +string projectId  «Required, References Projects»
        +string subProjectId  «References SubProjects»
        +WorkPackageStatus status
        +string responsible
        +string startDate / endDate  «DateField»
        +double plannedEffortDays / actualEffortDays
        +double plannedCost / actualCost
        +int progress  «0-100 %»
        +string deliverables
        +string[] predecessorIds  «References WorkPackages»
        +string[] measureIds  «References Measures»
        +string[] affectedApplicationIds  «References Applications»
        +bool delayed  «derived»
        +isDelayed(status, endDate, today)$ bool
        +validate()
    }
    class ProjectRollup {
        <<domain service>>
        +int subProjects
        +int workPackages
        +double plannedEffortDays
        +int progress
        +forProject(projectId, subProjects, workPackages)$ ProjectRollup
        +forSubProject(subProjectId, subProjects, workPackages)$ ProjectRollup
    }
    class ProjectPhase {
        <<enumeration>>
        Initiation
        Planning
        Execution
        Closing
    }
    class WorkPackageStatus {
        <<enumeration>>
        NotStarted
        InProgress
        OnHold
        Completed
        Cancelled
    }

    SubProject "*" --> "1" Project : part of
    SubProject "*" --> "0..1" SubProject : parent
    WorkPackage "*" --> "1" Project : part of
    WorkPackage "*" --> "0..1" SubProject : part of
    WorkPackage "*" --> "*" WorkPackage : predecessors
    WorkPackage "*" --> "*" Measure : implements
    Measure "*" --> "0..1" Project : implemented by
    ProjectRollup ..> Project
    ProjectRollup ..> SubProject
    ProjectRollup ..> WorkPackage
    Project ..> ProjectPhase
    WorkPackage ..> WorkPackageStatus
```

**Project management** structures a project into (nested) sub projects and work packages (WBS). Derived at
read time: the path *project / sub project / …*, the number of sub projects and work packages, the planned
effort and the **progress** – the planned-effort weighted mean of the work package progress (unweighted if
no effort is planned; cancelled work packages ignored). For a sub project the work packages of its nested
sub projects count as well. A work package is **Delayed** when it is neither *Completed* nor *Cancelled*
and its end date has passed. Rules: a work package and a sub project need a project; a running sub project
needs a manager; a running work package needs a responsible person and a start date; a *Completed* work
package is at 100 %; a work package cannot be its own predecessor; efforts and costs ≥ 0; a *Completed*
project needs an end date. ArchiMate export: WorkPackage with Composition (project → sub project → work
package) and Triggering (predecessor → successor).

---

## 7. Access management

```mermaid
classDiagram
    direction LR

    class User {
        +string userName  «Required, unique»
        +string email
        +bool active
        +string validUntil  «DateField»
        +string organizationId  «References Organizations»
        +string[] roleIds  «References Roles»
        +string effectiveRights  «derived»
        +isEnabled(today) bool
        +validate()
    }
    class Role {
        +string roleKey
        +ObjectState status
        +string[] permissionIds  «References Permissions»
        +int totalUsers  «derived»
    }
    class Permission {
        +EntitySetName entitySet
        +bool canRead / canCreate / canUpdate / canDelete
        +int totalRoles  «derived»
        +validate()
    }
    class EffectiveRights {
        <<domain service>>
        +bool unrestricted
        +SetRights allSets
        +SetRights[string] perSet
        +can(setName, action) bool
        +resolve(user, roles, permissions, today)$ EffectiveRights
        +summary() string
    }
    class IAccessControl {
        <<interface / driving port>>
        +rightsFor(AccessSubjectDto) AccessRightsDto
        +useCasesFor(AccessSubjectDto) IEamUseCases
    }
    class AccessControlInteractor
    class SecuredEamFacade {
        <<decorator>>
        +search() hits of readable sets
        +transfer() skips / rejects per set
        +analysis() needs read Applications
        +archimate() needs read on all sets
    }
    class SecuredManageElements~TDto~ {
        <<decorator>>
        +list() / get() / count()  «Read»
        +create()  «Create»
        +update()  «Update»
        +remove()  «Delete»
    }
    class AccessSubjectDto {
        +string userName
        +string email
        +bool administrator
    }
    class AccessDeniedException

    User "*" --> "*" Role : roles
    Role "*" --> "*" Permission : permissions
    EffectiveRights ..> User
    EffectiveRights ..> Role
    EffectiveRights ..> Permission
    IAccessControl <|.. AccessControlInteractor
    AccessControlInteractor ..> EffectiveRights : resolves
    AccessControlInteractor ..> SecuredEamFacade : creates
    IEamUseCases <|.. SecuredEamFacade
    SecuredEamFacade *-- SecuredManageElements~TDto~
    SecuredManageElements~TDto~ ..> AccessDeniedException : throws
    AccessControlInteractor ..> AccessSubjectDto
```

**Authorization** is part of the application core, not of a single adapter. Each adapter turns its caller into
an `AccessSubjectDto` (HTTP: JWT user name / e-mail and `Admin` scope, or the `eam-dev-user` cookie locally;
CLI `--user`; desktop `EAM_USER`) and asks `IAccessControl.useCasesFor(subject)` for the use cases. For an
administrator these are the plain use cases; otherwise a `SecuredEamFacade` whose `SecuredManageElements`
check *read / create / update / delete* per entity set and throw `AccessDeniedException` (HTTP 403).
Effective rights = union of the permissions of the user's *active* roles; *All* covers every set except
Users, Roles and Permissions. Without any users in the repository everybody may read (bootstrap). The
`EntitySetName` enumeration is checked against the DTO registry at compile time.

---

## 8. Organisation structure

```mermaid
classDiagram
    direction LR

    class Enterprise {
        +string hierarchyPath  «derived: Organisation»
        +string shortName
        +string legalForm
        +string registrationNumber / vatId
        +string headquarters / country / industry
        +string website  «http(s)»
        +string foundingDate  «DateField»
        +ObjectState status
        +string parentEnterpriseId  «References Enterprises»
        +double ownershipShare  «0-100 %»
        +string managingDirector  «derived»
        +int totalUnits  «derived»
        +int totalMembers  «derived»
        +validate()
    }
    class Organization {
        +string hierarchyPath  «derived: Organisation»
        +OrganizationType orgType
        +string parentId  «References Organizations»
        +string enterpriseId  «References Enterprises»
        +string costCenter
        +string headOfUnit  «derived»
        +int totalMembers  «derived»
        +double totalCapacity  «derived, FTE»
    }
    class Member {
        +string personnelNumber  «unique»
        +string jobTitle
        +string organizationId  «Required, References Organizations»
        +MemberFunction memberFunction
        +EmploymentType employmentType
        +int capacity  «1-100 %»
        +string email / phone / location
        +string startDate / endDate  «DateField»
        +string managerId  «References Members»
        +string userId  «References Users»
        +bool current  «derived»
        +isCurrent(today) bool
        +validate()
    }
    class UnitStaffing {
        <<domain service>>
        +string head
        +int members
        +double capacityFte
        +compute(unitId, members, today)$ UnitStaffing
        +forEnterprise(enterpriseId, units, members, today, units, members, managingDirector)$
    }
    class MemberFunction {
        <<enumeration>>
        Head
        Deputy
        Employee
        Assistant
    }
    class EmploymentType {
        <<enumeration>>
        Internal
        External
        Contractor
        Trainee
    }

    Enterprise "*" --> "0..1" Enterprise : parent (group structure)
    Organization "*" --> "0..1" Enterprise : legal entity
    Organization "*" --> "0..1" Organization : parent
    Member "*" --> "1" Organization : unit
    Member "*" --> "0..1" Member : line manager
    Member "*" --> "0..1" User : user account
    UnitStaffing ..> Member
    UnitStaffing ..> Organization
    Member ..> MemberFunction
    Member ..> EmploymentType
```

The **organisation structure** (*Aufbau*) separates the legal view (enterprises with group structure and
ownership shares) from the management view (the organisational unit hierarchy – a unit may belong to a
different legal entity than its parent unit, e.g. *Group IT* under the group but employed by the IT
subsidiary). Members are people in a unit; only **current** members (today within start / end date) count.
Derived at read time: head of unit, member count and capacity in FTE per unit; units, members and the
**managing director** of an enterprise – the current head of its top-level unit(s). The managing director is
deliberately not a stored reference: Enterprise → Member → Unit → Enterprise would be a cycle that a CSV / XLSX
import into an empty repository cannot resolve. Rules: at most one current *Head* per unit (checked against the
other members), unique personnel numbers, capacity 1–100 %, an end date for external members, contractors and
trainees. Members contain personal data: they are not exported to ArchiMate, and access is controlled by
permissions on the *Members* set.

---

## 9. Platform: tenants, backup & restore

```mermaid
classDiagram
    direction LR

    class IEamPlatform {
        <<interface / driving port>>
        +resolveTenant(subject, requested) string
        +tenantUseCases(tenantId) IEamUseCases
        +tenantsFor(subject) TenantRefDto[]
        +canBackup(tenantId, subject) bool
        +listTenants() / createTenant() / updateTenant() / deleteTenant()
        +listBackups() / createBackup() / backupFile() / deleteBackup()
        +restoreBackup(tenantId, backupId, checkOnly, subject) RestoreResultDto
        +restoreUpload(tenantId, file, checkOnly, keep, subject) RestoreResultDto
        +runScheduledBackups() size_t
    }
    class EamPlatform {
        -Open[string] open  «storage + use cases per tenant»
        -takeBackup(tenant, kind, comment, actor)
        -restore(tenant, snapshot, checkOnly, subject)
        -applyRetention(tenant)
    }
    class Tenant {
        +string id  «slug, file name»
        +string name
        +TenantStatus status
        +string zoneId  «XSUAA identity zone»
        +validate()
    }
    class TenantRoutingUseCases {
        <<decorator>>
        every call -> use cases of the current tenant
    }
    class BackupCodec {
        <<application service>>
        +encodeBackup(info, collections) bytes  «gzip JSON + SHA-256»
        +decodeBackup(file) BackupSnapshot  «verifies checksum / version»
        +checksumOf(collections) string  «canonical JSON»
    }
    class ITenantRegistry {
        <<driven port>>
        +all() / find() / save() / remove()
    }
    class ITenantStorageProvider {
        <<driven port>>
        +open(tenantId) IDocumentStorage
        +destroy(tenantId)
    }
    class IBackupStore {
        <<driven port>>
        +list() / save() / load() / remove() / exists()
    }
    class IDocumentStorage {
        <<driven port>>
        +replaceAll(collections)  «atomic restore»
    }
    class TenantRegistry
    class FileTenantStorageProvider
    class BackupFileStore

    IEamPlatform <|.. EamPlatform
    EamPlatform --> ITenantRegistry
    EamPlatform --> ITenantStorageProvider
    EamPlatform --> IBackupStore
    EamPlatform ..> BackupCodec
    EamPlatform ..> Tenant
    EamPlatform ..> IDocumentStorage
    ITenantRegistry <|.. TenantRegistry
    ITenantStorageProvider <|.. FileTenantStorageProvider
    IBackupStore <|.. BackupFileStore
    TenantRoutingUseCases ..> IEamPlatform
```

The **platform** sits above the tenants. The composition root builds one `EamPlatform` with a factory that
creates the complete use cases of a tenant on its storage (`EamContainer`). The HTTP adapters receive a
`TenantRoutingUseCases`: OData, REST, transfer and web cockpit keep working with "the" use cases, every call
reaches the tenant resolved for the request (zone → selection → `default`). CLI and desktop resolve the tenant
once per process. Because the repositories cache their records, a restore replaces the storage content in one
atomic write (`replaceAll`) and rebuilds the tenant's use cases.

---

## 10. Processes, security & reporting

```mermaid
classDiagram
    direction LR

    class ITProcess {
        +string hierarchyPath  «derived: IT Process»
        +ProcessFramework framework
        +LifecycleStatus status
        +string processOwner / processManager
        +int currentMaturity / targetMaturity  «1-5»
        +string parentProcessId  «References ITProcesses»
        +string[] businessProcessIds  «References BusinessProcesses»
        +string[] serviceProductGroupIds  «References ServiceProductGroups»
        +int totalSteps  «derived»
        +KpiStatus kpiStatus  «derived: worst KPI»
    }
    class ProcessStep {
        +string processId  «Required, References ITProcesses»
        +int sequenceNo  «unique per process»
        +StepType stepType
        +AutomationLevel automationLevel
        +string performerRole
        +string[] applicationIds  «References Applications»
        +double durationHours
    }
    class ProcessKpi {
        +string processId  «Required, References ITProcesses»
        +KpiDirection direction
        +double targetValue / thresholdValue / actualValue
        +bool measured
        +KpiStatus kpiStatus  «derived»
        +double achievement  «derived, %»
        +evaluate(direction, target, threshold, actual, measured)$ KpiStatus
    }
    class ProtectionRequirement {
        +string applicationId / businessDataId / componentId  «exactly one»
        +ProtectionLevel confidentiality / integrity / availability
        +ProtectionLevel overallLevel  «derived: maximum principle»
        +SpecificationStatus status
        +bool reviewOverdue  «derived»
    }
    class SecurityRisk {
        +int likelihood / impact  «1-5»
        +int riskScore  «derived»
        +RiskLevel riskLevel  «derived»
        +int residualLikelihood / residualImpact
        +RiskLevel residualLevel  «derived»
        +RiskTreatment treatment
        +RiskStatus status
        +string[] controlIds  «References SecurityControls»
        +string[] applicationIds / componentIds / businessDataIds
    }
    class SecurityControl {
        +string controlReference
        +ControlFramework framework
        +ControlType controlType
        +ImplementationStatus implementationStatus
        +int effectiveness  «0-5»
        +bool overdue  «derived»
        +int mitigatedRisks  «derived»
    }
    class Report {
        +EntitySetName entitySet
        +string[] columns
        +string filter  «$filter»
        +string orderBy  «$orderby»
        +string groupBy / sumField
        +int maxRows
    }
    class ReportBook {
        +string[] reportIds  «References Reports»
    }
    class ReportingInteractor {
        <<use case>>
        +run(reportId) ReportResultDto
        +runBook(bookId) ReportResultDto[]
        +runDefinition(definition) ReportResultDto
    }
    class QueryEngine {
        <<application service>>
        +applyQuery(items, options)  «$filter / $orderby, shared with OData»
    }
    class PdfReportRenderer {
        <<infrastructure / IReportRenderer>>
    }

    ITProcess "*" --> "0..1" ITProcess : parent
    ProcessStep "*" --> "1" ITProcess : step of
    ProcessKpi "*" --> "1" ITProcess : measures
    ITProcess "*" --> "*" BusinessProcess : supports
    ProcessStep "*" --> "*" Application : supported by
    ProtectionRequirement "*" --> "0..1" Application : assesses
    ProtectionRequirement "*" --> "0..1" BusinessData : assesses
    SecurityRisk "*" --> "*" SecurityControl : mitigated by
    SecurityRisk "*" --> "*" Application : affects
    SecurityControl "*" --> "*" ITComponent : applies to
    ReportBook "*" --> "*" Report : contains
    ReportingInteractor ..> Report
    ReportingInteractor ..> QueryEngine
    PdfReportRenderer ..> ReportingInteractor : renders results
```

**Processes**: IT processes (ITIL 4 practices) with ordered steps and KPIs; a KPI is *OnTrack* when the target is
met, *AtRisk* up to the threshold, *OffTrack* beyond it; the process shows its worst KPI. **Security**: the
protection requirement follows the maximum principle (BSI 200-2); risk score = likelihood × impact (1–4 Low,
5–9 Medium, 10–16 High, 17–25 Critical), residual risk after the controls. **Reporting**: report definitions are
executed by the `ReportingInteractor` against the (checked) use cases of the caller with the OData query engine,
which was moved from the OData adapter into the application layer for this purpose; results are rendered as
XLSX / CSV (table codecs) or PDF (`PdfReportRenderer`).

---

## 11. Comments (journal)

```mermaid
classDiagram
    direction LR

    class Comment {
        +string id
        +string elementSet  «any entity set»
        +string elementId
        +string text  «max 4,000»
        +string createdAt  «date, set automatically»
        +string createdBy  «author, signed-in user»
        +validate()
    }
    class IComments {
        <<interface / driving port>>
        +list(set, id, actor) CommentDto[]  «newest first»
        +add(set, id, text, actor) CommentDto
        +remove(commentId, actor)
        +count(set, id) size_t
    }
    class CommentsInteractor {
        unrestricted: on the plain use cases
        checked: on the caller's use cases
    }
    class ICommentRepository {
        <<driven port>>
        +forElement(set, id) Comment[]
        +save() / remove() / removeForElement()
    }
    class CommentRepository {
        collection "Comments" of the tenant storage
    }
    class ManageElementsInteractor {
        +onRemoved(callback)
    }

    IComments <|.. CommentsInteractor
    CommentsInteractor --> ICommentRepository
    ICommentRepository <|.. CommentRepository
    CommentsInteractor ..> Comment
    ManageElementsInteractor ..> ICommentRepository : removeForElement on delete
    Comment ..> "1" ArchitectureElement : documents (set + id)
```

The journal is **polymorphic**: a comment refers to any element by entity set and id. It is append-only.
Authorization reuses the element: the checked `CommentsInteractor` looks the element up through the caller's
use cases (read permission), deleting another user's comment needs the delete permission on that set. Every
`ManageElementsInteractor` calls `onRemoved` after a delete, which removes the element's comments. The comments
live in the tenant storage and are therefore part of backups and restores.

---

## 12. Ports & use cases

```mermaid
classDiagram
    direction TB

    class IEamUseCases {
        <<interface / driving port>>
        +applications() IManageElements~ApplicationDto~
        +capabilities() IManageElements~BusinessCapabilityDto~
        +components() IManageElements~ITComponentDto~
        +flows() IManageElements~InformationFlowDto~
        +organizations() IManageElements~OrganizationDto~
        +projects() IManageElements~ProjectDto~
        +products() IManageElements~ProductDto~
        +productGroups() IManageElements~ProductGroupDto~
        +applicationGroups() IManageElements~ApplicationGroupDto~
        +businessProcesses() IManageElements~BusinessProcessDto~
        +businessData() IManageElements~BusinessDataDto~
        +serviceProductGroups() IManageElements~ServiceProductGroupDto~
        +strategicGuidelines() IManageElements~StrategicGuidelineDto~
        +serviceCapabilities() IManageElements~ServiceCapabilityDto~
        +measureGroups() IManageElements~MeasureGroupDto~
        +measures() IManageElements~MeasureDto~
        +architecturePrinciples() IManageElements~ArchitecturePrincipleDto~
        +architectureGuidelines() IManageElements~ArchitectureGuidelineDto~
        +referenceArchitectures() IManageElements~ReferenceArchitectureDto~
        +architectureDocuments() IManageElements~ArchitectureDocumentDto~
        +subProjects() IManageElements~SubProjectDto~
        +workPackages() IManageElements~WorkPackageDto~
        +enterprises() IManageElements~EnterpriseDto~
        +members() IManageElements~MemberDto~
        +itProcesses() / processSteps() / processKpis()
        +protectionRequirements() / securityRisks() / securityControls()
        +reports() / reportBooks()
        +reporting() IReporting
        +comments() IComments
        +users() IManageElements~UserDto~
        +roles() IManageElements~RoleDto~
        +permissions() IManageElements~PermissionDto~
        +access() IAccessControl
        +search() ISearchElements
        +transfer() ITransferElements
        +analysis() IAnalyzePortfolio
        +seeder() ISeedSampleData
        +archimate() IArchiMateExport
    }
    class IManageElements~TDto~ {
        <<interface>>
        +kind() string
        +list() TDto[]
        +get(id) TDto
        +create(dto, actor) TDto
        +update(id, dto, actor) TDto
        +remove(id)
        +count() size_t
    }
    class IAnalyzePortfolio {
        <<interface>>
        +portfolio() PortfolioReportDto
        +impact(appId) ImpactReportDto
        +coverage() CapabilityCoverageDto[]
        +technologyRisks() TechnologyRiskDto[]
        +productAlerts() ProductAlertDto[]
    }
    class IArchiMateExport {
        <<interface>>
        +exportModel() string
    }
    class ISeedSampleData {
        <<interface>>
        +seed() size_t
    }
    class ITransferElements {
        <<interface>>
        +exportSet(set, technicalHeaders) TableDto
        +exportAll(technicalHeaders) TableDto[]
        +importSet(set, table, actor, dryRun) ImportResultDto
        +importAll(sheets, actor, dryRun) ImportResultDto[]
    }
    class ITableCodec {
        <<interface / port>>
        +format() string
        +mimeType() string
        +encode(TableDto[]) ubyte[]
        +decode(ubyte[]) TableDto[]
    }
    class CsvCodec
    class XlsxCodec
    ITableCodec <|.. CsvCodec
    ITableCodec <|.. XlsxCodec
    class TransferElementsInteractor {
        -sandbox() IEamUseCases
        -planImport(S)(uc, table, actor) RowJob[]
        -runJobs(jobs) retries referential errors
    }
    ITransferElements <|.. TransferElementsInteractor
    TransferElementsInteractor --> IEamUseCases : regular use cases (validation, integrity)
    class ISearchElements {
        <<interface>>
        +search(query, top) SearchHitDto[]
    }

    class IElementRepositoryBase {
        <<interface / driven port>>
        +kind() string
        +exists(id) bool
        +count() size_t
        +findReferencing(kind, id) string[]
    }
    class IElementRepository~TEntity~ {
        <<interface>>
        +findAll() TEntity[]
        +findById(id) TEntity
        +save(entity)
        +remove(id) bool
    }
    class IRepositoryRegistry {
        <<interface>>
        +byKind(kind)
        +all()
    }
    class IDocumentStorage {
        <<interface>>
        +load(c) Json[]
        +store(c, docs)
        +collections()
        +location()
    }
    class IEventPublisher {
        <<interface>>
        +publish(DomainEvent)
    }

    IElementRepositoryBase <|-- IElementRepository~TEntity~

    class EamFacade
    class ManageElementsInteractor~TEntity,TDto~ {
        +enrichWith(delegate)
        -derive(entity)
    }
    class AnalyzePortfolioInteractor
    class SeedSampleDataInteractor
    class SearchElementsInteractor {
        -scoreOf(S)(dto, query, terms) SearchHitDto
    }
    class ArchiMateExporter
    class IntegrityService {
        +checkReferences(T)(entity)
        +checkNotReferenced(kind, id)
    }

    IEamUseCases <|.. EamFacade
    IManageElements~TDto~ <|.. ManageElementsInteractor~TEntity,TDto~
    IAnalyzePortfolio <|.. AnalyzePortfolioInteractor
    ISeedSampleData <|.. SeedSampleDataInteractor
    ISearchElements <|.. SearchElementsInteractor
    IArchiMateExport <|.. ArchiMateExporter

    ManageElementsInteractor~TEntity,TDto~ --> IElementRepository~TEntity~
    ManageElementsInteractor~TEntity,TDto~ --> IntegrityService
    ManageElementsInteractor~TEntity,TDto~ --> IEventPublisher
    IntegrityService --> IRepositoryRegistry
    AnalyzePortfolioInteractor --> IElementRepository~TEntity~
    SeedSampleDataInteractor --> IEamUseCases
    SearchElementsInteractor --> IEamUseCases : list() of all EamDtoSets

    class DocumentRepository~TEntity,TRecord~
    class RepositoryRegistry
    class JsonFileStorage
    class MemoryStorage
    class LoggingEventPublisher
    IElementRepository~TEntity~ <|.. DocumentRepository~TEntity,TRecord~
    IRepositoryRegistry <|.. RepositoryRegistry
    IDocumentStorage <|.. MemoryStorage
    MemoryStorage <|-- JsonFileStorage
    IEventPublisher <|.. LoggingEventPublisher
    DocumentRepository~TEntity,TRecord~ --> IDocumentStorage
```

---

## 13. Component diagram (hexagonal architecture)

```mermaid
flowchart LR
    subgraph Clients
        FIORI["Fiori 3 UI<br/>(OpenUI5: ShellBar, SideNavigation,<br/>meta-model driven pages)"]
        WV["WebView<br/>(WebKit2GTK)"]
        BROWSER["Browser<br/>(web cockpit)"]
        SHELL["Shell / CI"]
        INTEG["Integrations<br/>(OData / REST clients)"]
    end

    subgraph Presentation["presentation (driving adapters)"]
        HTTP["http<br/>router, health, static files,<br/>auth guard, TLS"]
        ODATA["odata<br/>service · metadata · query"]
        REST["rest<br/>analyses · /model · /me · /search<br/>http/transfer: CSV / XLSX up- and download"]
        WEB["web<br/>Diet + daisyUI"]
        CLI["cli<br/>commands, --remote"]
        GUI["gui<br/>GtkD desktop · webview"]
    end

    subgraph Application["application"]
        FACADE["EamFacade<br/>(IEamUseCases)"]
        UC["ManageElementsInteractor×12<br/>AnalyzePortfolioInteractor<br/>SearchElementsInteractor<br/>TransferElementsInteractor<br/>SeedSampleDataInteractor"]
        SVC["IntegrityService<br/>ArchiMateExporter"]
        DTO["dtos · registry ·<br/>modelinfo (describeModel)"]
    end

    subgraph Domain["domain"]
        ENT["entities"]
        DSVC["PortfolioAnalyzer · ImpactAnalyzer<br/>ProductLifecycleMonitor<br/>ApplicationGroupRollup"]
        TYP["types · enumerations · exceptions"]
    end

    subgraph Ports["ports"]
        PUC["usecases / services"]
        PREPO["repositories / storages / messaging"]
    end

    subgraph Persistence["persistence (driven adapters)"]
        REPO["DocumentRepository<br/>RepositoryRegistry"]
        MAP["mappers · records"]
        STORE["JsonFileStorage<br/>MemoryStorage"]
    end

    subgraph Infrastructure["infrastructure"]
        CFG["configuration<br/>(json · env · VCAP)"]
        SEC["security<br/>(XSUAA JWT RS256)"]
        LOG["logging · audit"]
        WRK["workers<br/>(health timer)"]
        CLT["clients<br/>(ODataClient)"]
        FMT["formats<br/>(CsvCodec · XlsxCodec)"]
    end

    FILE[("data/eam.json")]

    FIORI --> HTTP
    WV --> HTTP
    BROWSER --> HTTP
    INTEG --> HTTP
    SHELL --> CLI
    HTTP --> ODATA & REST & WEB
    ODATA & REST & WEB & CLI & GUI --> PUC
    PUC -.implemented by.-> FACADE
    FACADE --> UC --> SVC
    UC --> DSVC
    UC --> ENT
    UC --> PREPO
    PREPO -.implemented by.-> REPO
    REPO --> MAP --> STORE --> FILE
    HTTP --> SEC
    CLI --> CLT
    CLT -.OData.-> HTTP
    WRK --> PUC
    REST & CLI & GUI --> FMT
    UC --> LOG
```

**Composition root:** `composition.d` (`EamContainer`) creates storage → repositories → registry →
integrity service → interactors (plus the application group roll-up enricher) → facade. `app.d` selects the
channel: `serve`, `gui`, `webview` or CLI.

## 14. Sequence: create an application via OData

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as Fiori UI (ODataListBinding)
    participant AR as Approuter
    participant OD as ODataService
    participant AU as Authenticator
    participant UC as ManageElementsInteractor<Application>
    participant IN as IntegrityService
    participant RP as DocumentRepository
    participant ST as JsonFileStorage
    participant EV as LoggingEventPublisher

    User->>UI: Add → fill dialog → Save
    UI->>AR: POST /odata/v4/eam/Applications (JSON, X-CSRF-Token)
    AR->>AR: check session, scope $XSAPPNAME.Admin
    AR->>OD: POST … + Authorization: Bearer JWT
    OD->>AU: authenticate(header, write=true)
    AU-->>OD: Principal (signature, exp, aud, scope ok)
    OD->>OD: dtoFromJson!ApplicationDto(body)
    OD->>UC: create(dto)
    UC->>UC: mapFields!Application(dto) (enum parsing)
    UC->>UC: id = UUID, timestamps, entity.validate()
    UC->>IN: checkReferences(entity)
    IN->>RP: registry.byKind("Organizations").exists(ownerId)
    UC->>RP: save(entity)
    RP->>ST: store("Applications", docs)
    ST->>ST: write eam.json.tmp → rename (atomic)
    UC->>EV: publish(Created)
    UC-->>OD: ApplicationDto
    OD-->>AR: 201 Created, Location, @odata.context
    AR-->>UI: 201
    UI-->>User: MessageToast "Application created", KPIs reloaded via REST
```

## 15. Sequence: delete with referential integrity

```mermaid
sequenceDiagram
    autonumber
    actor Architect
    participant CLI as eam CLI
    participant UC as ManageElementsInteractor<ITComponent>
    participant IN as IntegrityService
    participant RR as RepositoryRegistry
    participant R as DocumentRepository (each kind)

    Architect->>CLI: eam delete ITComponents tc-oracle11
    CLI->>UC: remove("tc-oracle11")
    UC->>UC: require(id) (EntityNotFoundException if missing)
    UC->>IN: checkNotReferenced("ITComponents", id)
    IN->>RR: all()
    loop every repository
        IN->>R: findReferencing("ITComponents", id)
        R-->>IN: ids whose @References("ITComponents") fields contain id
    end
    IN-->>UC: throw ReferentialIntegrityException("… referenced by Applications('app-legacycrm'), Applications('app-bi')")
    UC-->>CLI: exception
    CLI-->>Architect: "error (ReferentialIntegrity): …", exit code 1
    Note over CLI,UC: The same exception becomes HTTP 409 in OData/REST and an error dialog in the GtkD GUI
```

## 16. Sequence: WebView start-up

```mermaid
sequenceDiagram
    autonumber
    participant Main as app.d (main thread)
    participant T as Server thread
    participant V as vibe.d event loop
    participant G as GTK main loop
    participant W as WebKitWebView

    Main->>Main: loadConfiguration()
    alt no --url / webviewUrl
        Main->>T: new Thread (daemon)
        T->>T: EamContainer.fromConfig()
        T->>V: startHttpServer() + runEventLoop()
        loop up to 5 s
            Main->>V: TCP connect 127.0.0.1:port
        end
    end
    Main->>G: Main.init()
    Main->>W: dlopen libwebkit2gtk-4.1 → webkit_web_view_new()
    Main->>W: webkit_web_view_load_uri(http://127.0.0.1:port/index.html)
    Main->>G: MainWindow.add(Widget(webView)), Main.run()
    W->>V: HTTP: index.html, $metadata, Applications, /api/v1/analysis/…
    G-->>Main: window closed → exit (daemon server thread ends)
```

## 17. Sequence: Fiori shell start-up (user profile & meta model)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant C as Component.js
    participant SB as App view (ShellBar + SideNavigation)
    participant RE as EamRestApi
    participant AU as Authenticator
    participant OD as ODataService

    User->>C: open index.html (OpenUI5 1.120, theme sap_fiori_3)
    par user profile
        C->>RE: GET /api/v1/me
        RE->>AU: authenticate(Authorization)
        AU-->>RE: Principal (sub, given_name, family_name, email, scopes)
        RE-->>C: UserInfoDto (displayName, initials, roles, canEdit)
        C->>SB: user model → Avatar initials, read-only UI without Admin scope
    and meta model
        C->>RE: GET /api/v1/model
        RE-->>C: EntitySetInfoDto[] (fields: label, group, type, reference, choices, defaults)
        C->>OD: GET /{Set}?$select=id,name (all sets)
        OD-->>C: lookup model (id → name, option lists)
    and KPIs
        C->>RE: GET /api/v1/analysis/portfolio + /coverage
        RE-->>C: report → KPI tiles, ShellBar notification count
    end
    User->>SB: SideNavigation → Products
    SB->>C: router.navTo("list", {set: "Products"})
    C->>OD: GET /Products?$count=true&$select=id,<@ListColumn fields>&$orderby=name
```

## 18. Sequence: edit on the object page (Edit → Save)

```mermaid
sequenceDiagram
    autonumber
    actor Architect
    participant OP as ElementDetail (ObjectPage)
    participant M as models.js
    participant OD as ODataService
    participant UC as ManageElementsInteractor<Product>

    Architect->>OP: open sets/Products/prd-oracle-11
    OP->>M: readEntity(Products, id)
    M->>OD: GET /Products('prd-oracle-11')
    OD-->>OP: JSON → "obj" model, display controls (links, status, dates)
    Architect->>OP: Edit, change fields, Save
    OP->>OP: normalize() and diff against the original
    OP->>M: updateEntity(changes)
    M->>OD: HEAD / (X-CSRF-Token: Fetch), first call only
    M->>OD: PATCH /Products('prd-oracle-11') {changed fields}
    OD->>UC: update(id, merged dto, actor = principal.name)
    UC->>UC: derive() → reminder dates, validate()
    alt validation error
        UC-->>OD: ValidationException(field)
        OD-->>OP: 400 {"error": {"code", "message", "target": field}}
        OP-->>Architect: field highlighted (ValueState Error), MessageBox
    else ok
        UC-->>OD: ProductDto (modifiedBy, modifiedAt)
        OD-->>OP: 200 entity
        OP-->>Architect: display mode, toast, lists, KPIs and lookup refreshed
    end
```


## 19. Sequence: central search (shell bar)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant SB as App view (ShellBar SearchManager)
    participant SR as Search view
    participant RE as EamRestApi
    participant SE as SearchElementsInteractor
    participant UC as IManageElements (readable sets)

    User->>SB: types "cust"
    SB->>SB: suggest event, debounce 200 ms, ignore stale responses
    SB->>RE: GET /api/v1/search?q=cust&top=8
    RE->>SE: search("cust", 8)
    loop static foreach S in EamDtoSets
        SE->>UC: manage!S.list() (enriched DTOs)
        SE->>SE: every term in name / id / free-text field? score, matched field, snippet
    end
    SE-->>RE: SearchHitDto[] sorted by score
    RE-->>SB: suggestions (name, set label, icon, matched field)
    alt suggestion chosen
        SB->>SB: router.navTo("detail", {set, id})
    else Enter
        SB->>SR: router.navTo("search", {query})
        SR->>RE: GET /api/v1/search?q=cust&top=200
        RE-->>SR: hits → list + type filter (counts per set)
        User->>SR: press hit → object page
    end
```

---

## 20. Sequence: CSV / XLSX import (check, then import)

```mermaid
sequenceDiagram
    autonumber
    actor Architect
    participant D as ImportDialog (TransferHelper)
    participant H as http/transfer
    participant C as ITableCodec (Csv / Xlsx)
    participant T as TransferElementsInteractor
    participant SB as Sandbox (EamContainer in memory)
    participant UC as IManageElements<Set>

    Architect->>D: Import → choose orgs.xlsx → Check
    D->>H: POST /api/v1/transfer/Organizations?dryRun=true (raw file, X-CSRF-Token)
    H->>C: codecForContent(bytes) → "PK" = XLSX, else CSV
    C-->>H: TableDto[] (sheets: header + rows)
    H->>T: importSet(set, pickSheet(), actor, dryRun = true)
    T->>SB: sandbox() → copy of the repository
    T->>T: map headers (label or name), normalizeCell (dates, yes/no, enums, decimals)
    loop until no progress
        T->>SB: get(id) → update(changed columns) or create
        SB-->>T: ok / ValidationException / ReferentialIntegrityException (retry next round)
    end
    T-->>D: ImportResultDto (created, updated, unchanged, failed, issues with row / field)
    Architect->>D: Import
    D->>H: POST /api/v1/transfer/Organizations
    H->>T: importSet(…, dryRun = false)
    T->>UC: same jobs against the real use cases (modifiedBy = user)
    T-->>D: result → toast, list, lookup and KPIs refreshed
```

---

## 21. Deployment diagram

```mermaid
flowchart TB
    subgraph Workstation["Architect workstation (Linux)"]
        EAMBIN["eam (desktop build)<br/>serve · gui · webview · CLI"]
        GTK["GTK 3 / WebKit2GTK 4.1<br/>(runtime, dlopen)"]
        JSON1[("data/eam.json")]
        EAMBIN --- GTK
        EAMBIN --- JSON1
    end

    subgraph BTP["SAP BTP – Cloud Foundry space"]
        subgraph APPR["eam-approuter (nodejs_buildpack)"]
            ROUTER["@sap/approuter<br/>xs-app.json"]
            RES["resources/ = frontend (Fiori 3)"]
        end
        subgraph BE["eam-backend (binary_buildpack)"]
            HEADLESS["eam-headless serve<br/>PORT from CF, authMode=xsuaa"]
            JSON2[("data/eam.json<br/>(ephemeral – use volume/DB)")]
        end
        XSUAA[["XSUAA service<br/>xs-security.json"]]
    end

    USER(("Browser user")) -->|HTTPS| ROUTER
    ROUTER -->|OAuth2 login| XSUAA
    ROUTER -->|"destination eam-backend<br/>+ forwarded JWT"| HEADLESS
    HEADLESS -->|verificationkey from VCAP_SERVICES| XSUAA
    HEADLESS --- JSON2
    EAMBIN -.->|"CLI --remote / webview --url"| ROUTER
```

---

## 22. Use case diagram

```mermaid
flowchart LR
    EA(["Enterprise Architect<br/>(EAM_Architect)"])
    VI(["Stakeholder / Viewer<br/>(EAM_Viewer)"])
    OPS(["Operator / CI"])

    subgraph EAM["Neko EAM"]
        U1(("Maintain applications"))
        U2(("Maintain capability map"))
        U3(("Maintain IT components"))
        U4(("Maintain information flows"))
        U5(("Maintain organizations & projects"))
        U13(("Maintain product catalogue<br/>& product groups"))
        U14(("Maintain application groups<br/>& product assignments"))
        U15(("Product lifecycle alerts"))
        U16(("Manage own profile<br/>(language, theme)"))
        U17(("Maintain process map, business data<br/>& organisations"))
        U18(("Maintain service catalogue"))
        U19(("Central search"))
        U20(("Import / export<br/>CSV & Excel"))
        U21(("Plan IT landscape<br/>(guidelines, service capabilities,<br/>measures)"))
        U24(("Manage users, roles<br/>& permissions"))
        U25(("Maintain organisation structure<br/>(organisations, units, members)"))
        U28(("Manage IT processes<br/>& KPIs"))
        U29(("Information security<br/>(protection, risks, controls)"))
        U30(("Run & export reports"))
        U31(("Comment elements<br/>(journal)"))
        U26(("Back up & restore<br/>the tenant"))
        U27(("Manage tenants"))
        U23(("Manage projects<br/>(sub projects, work packages,<br/>progress)"))
        U22(("Maintain specifications<br/>(principles, guidelines,<br/>reference architectures, documents)"))
        U6(("Browse repository"))
        U7(("TIME portfolio assessment"))
        U8(("Technology risk analysis"))
        U9(("Capability coverage"))
        U10(("Impact analysis"))
        U11(("Export ArchiMate"))
        U12(("Seed demo data / health check"))
    end

    EA --> U1 & U2 & U3 & U4 & U5 & U13 & U14 & U17 & U18 & U20 & U21 & U22 & U23 & U24 & U25 & U26 & U28 & U29 & U30
    VI --> U30 & U31
    OPS --> U27 & U26
    EA --> U7 & U10 & U11
    VI --> U6 & U7 & U8 & U9 & U10 & U15 & U16 & U19
    OPS --> U12 & U11
```

## 23. State diagram: application lifecycle

```mermaid
stateDiagram-v2
    [*] --> Plan
    Plan --> Build : project approved
    Build --> Active : go-live (goLiveDate)
    Active --> PhaseOut : TIME = Migrate / Eliminate
    PhaseOut --> Active : decision reverted
    PhaseOut --> Retired : switched off (retirementDate required)
    Plan --> Retired : cancelled
    Retired --> [*]

    note right of Active
        isOperational() = Active or PhaseOut
        counts toward cost, coverage and technology risk
    end note
```

## 24. State diagram: measure planning status

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Proposed : submitted to the architecture board
    Proposed --> Approved : approved (responsible required)
    Proposed --> Rejected : violates a guideline / no budget
    Approved --> InProgress : started (start date required)
    InProgress --> Completed : progress = 100 %
    Approved --> Cancelled
    InProgress --> Cancelled
    Rejected --> [*]
    Cancelled --> [*]
    Completed --> [*]

    note right of Rejected
        Rejected and cancelled measures are
        excluded from the measure group totals
    end note
```

## 25. State diagram: work package status

```mermaid
stateDiagram-v2
    [*] --> NotStarted
    NotStarted --> InProgress : started (responsible and start date required)
    InProgress --> OnHold
    OnHold --> InProgress
    InProgress --> Completed : progress = 100 %
    NotStarted --> Cancelled
    InProgress --> Cancelled
    OnHold --> Cancelled
    Completed --> [*]
    Cancelled --> [*]

    note right of InProgress
        Delayed = not Completed / Cancelled
        and end date in the past
    end note
```

## 26. Sequence: authorization of a request

```mermaid
sequenceDiagram
    autonumber
    actor User as Fiori user (EAM_Viewer)
    participant AR as Approuter
    participant OD as ODataService
    participant AU as Authenticator
    participant AC as AccessControlInteractor
    participant SF as SecuredEamFacade
    participant UC as ManageElementsInteractor

    User->>AR: PATCH /odata/v4/eam/Applications('app-crm')
    AR->>AR: login, scope $XSAPPNAME.Display, CSRF
    AR->>OD: request + JWT
    OD->>AU: authenticate(JWT)
    AU-->>OD: Principal (user name, e-mail, scopes)
    OD->>AC: useCasesFor(subject)
    AC->>AC: find user (name / e-mail), active roles -> EffectiveRights
    alt Admin scope
        AC-->>OD: plain use cases
    else repository user
        AC-->>OD: SecuredEamFacade(rights)
    end
    OD->>SF: applications.update(id, dto, actor)
    alt Applications: Update granted
        SF->>UC: update(...)
        UC-->>OD: ApplicationDto
        OD-->>User: 200 OK
    else not granted
        SF-->>OD: AccessDeniedException
        OD-->>User: 403 Forbidden "No permission to update Applications"
    end
```

## 27. Sequence: restore a backup

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Tenant administrator
    participant UI as Fiori Backups page
    participant SR as System routes (/api/v1/backups)
    participant PL as EamPlatform
    participant BS as BackupFileStore
    participant BC as BackupCodec
    participant ST as Tenant storage (JsonFileStorage)

    Admin->>UI: Restore (row)
    UI->>SR: POST /backups/{id}/restore?check=true
    SR->>PL: restoreBackup(tenant, id, checkOnly=true, subject)
    PL->>PL: canBackup(tenant, subject)?
    PL->>BS: load(tenant, id)
    PL->>BC: decodeBackup(file)
    BC-->>PL: snapshot (format, version, SHA-256 verified)
    PL->>PL: test load of every set into an in-memory container
    PL-->>UI: RestoreResultDto (counts, warnings)
    UI->>Admin: confirm "all current data will be replaced"
    Admin->>UI: Restore
    UI->>SR: POST /backups/{id}/restore
    SR->>PL: restoreBackup(tenant, id, checkOnly=false, subject)
    PL->>BS: save(PreRestore safety backup of the current state)
    PL->>ST: replaceAll(collections)  (tmp file + rename)
    PL->>PL: rebuild the tenant's use cases (repository caches)
    PL-->>UI: restored, safetyBackupId
    UI->>UI: reload the app
```
