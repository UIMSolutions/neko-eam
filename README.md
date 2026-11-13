# Neko EAM – Enterprise Architecture Management

An Enterprise Architecture Management (EAM) application modelled on the ideas of tools such as
*Neko*: an architecture **repository** with application portfolio management (applications and
application groups), a **product catalogue** (software product versions and product groups with
lifecycle, licensing, compliance and data-quality attributes), business architecture (capability map,
process map, business data with DPIA rating, organisations), a **service catalogue** (service product
groups), **IT landscape planning** (strategic guidelines, service capabilities with maturity, measure
groups and measures), **architecture specifications** (principles, guidelines, reference architectures,
documents), technology lifecycle management, information flows and transformation projects with **project management** (sub projects, work packages, progress roll-up), a **central
search** across all of it, plus **analyses** (Gartner TIME,
technology risk, product lifecycle alerts, capability coverage, impact analysis) and an
**ArchiMate 3.1** export.

One D/vibe.d core, six ways to use it:

| Channel | How | Purpose |
|---|---|---|
| **OData v4** | `GET /odata/v4/eam/` | Standards-based API for SAP Fiori / UI5 and integrations |
| **Fiori 3 UI** | `http://localhost:8080/` | OpenUI5 browser UI: Fiori 3 shell bar with central search and user profile, side navigation, generic list and object pages |
| **WebView** | `eam webview` | The Fiori UI in a native desktop window (WebKit2GTK) |
| **GtkD GUI** | `eam gui` | Native desktop client that calls the use cases directly (no HTTP) |
| **CLI** | `eam list Applications` | Scripting, administration, CI, remote access via OData |
| **Android** | [`android/`](android/README.md) | Native Kotlin/Compose app: browse, search, edit any set, notifications (OData + REST) |

In addition: vibe.d **REST** interfaces (`/api/v1/...`: analyses, meta model, search, user, notifications,
comments, reports, tenants, backups, passwords - typed D interfaces in `presentation/rest`, usable with
`RestInterfaceClient`) and a server-side rendered **web cockpit** (`/web`, Diet templates + daisyUI).

> See [uml.md](uml.md) for class, component, sequence and deployment diagrams, and
> [nafv4.md](nafv4.md) for the NATO Architecture Framework v4 description.

---

## 1. Domain model (meta model)

| Element | Key attributes | Relations |
|---|---|---|
| **Application** | release, lifecycle status, object state, level ID, stakeholder, criticality, TIME category, business value (1‑5), technical fit (1‑5), annual cost, go-live / retirement date, *Insgesamt genutzte / zugewiesene Produkte* (derived) | parent → ApplicationGroup, owner → Organization, IT capability → BusinessCapability\*, uses → ITComponent\*, used / assigned → Product\* |
| **ApplicationGroup** | level ID, object state, stakeholder, *Insgesamt genutzte / zugewiesene Produkte* (rolled up from the applications of the subtree) | parent → ApplicationGroup, IT capability → BusinessCapability |
| **Product** | ~80 attributes in 11 groups – general (version, major version, version type, edition, type, vendor, weblinks, status, lifecycle and approval status), classification (CPE, CERTlich ID, PuLS ID, Maximo path, software class …), lifecycle (start/end, end of support/security/life, support contract, BSI permission, next validation, update cycle), reminders, licensing, security & compliance (blacklist, risk, protection requirements, IPv6, public cloud …), data quality, usage, responsibilities & support | component → ITComponent, group → ProductGroup, technical organisation → Organization |
| **ProductGroup** | level ID, object state | parent → ProductGroup, IT capability → BusinessCapability |
| **BusinessCapability** | *Business Capability* (hierarchy path, derived), level ID, level ID number (1‑5), mission criticality, strategic importance, stakeholder | parent → BusinessCapability, owner → Organization |
| **BusinessProcess** | *Business Process* (hierarchy path, derived), level ID, status, process owner, process manager | parent → BusinessProcess |
| **BusinessData** | version, business object, DPIA rating, *Creator* | owner → Organization, business capability → BusinessCapability, information flows → InformationFlow\* |
| **ITComponent** | vendor, release, category, lifecycle status, end-of-support date, license cost | – |
| **InformationFlow** | flow type (Api/File/Message/Database/Manual), data object, frequency | source → Application, target → Application |
| **ServiceProductGroup** | *Catalog* (hierarchy path, derived), short name, catalog type, version, status, catalogue manager, date of release | parent catalog → ServiceProductGroup |
| **Project** | project number, status, phase (Initiation/Planning/Execution/Closing), priority, project manager, start/end date, budget, actual cost; *Total Sub Projects*, *Total Work Packages*, *Planned Effort*, *Progress* (rolled up) | sponsor → Organization, changes → Application\* |
| **SubProject** | *Sub Project* (path project / sub project, derived), short name, status, sub project manager, start/end date, budget; work packages, planned effort and progress rolled up incl. nested sub projects | project → Project (required), parent → SubProject, responsible → Organization, changes → Application\* |
| **WorkPackage** | WBS code, status (NotStarted/InProgress/OnHold/Completed/Cancelled), responsible, start/end date, planned / actual effort (days), planned / actual cost, progress %, deliverables, *Delayed* (derived) | project → Project (required), sub project → SubProject, predecessors → WorkPackage\*, implements → Measure\*, changes → Application\* |

**IT landscape planning** (*IT-Bebauungsplanung*, own sidebar group):

| Element | Key attributes | Relations |
|---|---|---|
| **StrategicGuideline** | *Strategic Guideline* (hierarchy path, derived), short name, category (Business/Architecture/Technology/Data/Security/Sourcing/Compliance), priority, status, rationale, implications, guideline owner, valid from / until | parent → StrategicGuideline, responsible → Organization, applies to → BusinessCapability\* |
| **ServiceCapability** | *Service Capability* (hierarchy path, derived), short name, level ID, status, mission criticality, current / target maturity (1‑5), *Maturity Gap* (derived), stakeholder | parent → ServiceCapability, responsible → Organization, business capability → BusinessCapability, service catalogues → ServiceProductGroup\*, realised by → Application\* |
| **MeasureGroup** | *Measure Group* (hierarchy path, derived), short name, status, responsible, planning period, budget, *Total Measures* / *Total Estimated Cost* (rolled up from the measures of the subtree) | parent → MeasureGroup, responsible → Organization, implements → StrategicGuideline\* |
| **Measure** | short name, measure type (Introduce/Modernize/Migrate/Consolidate/Retire/Optimize/Invest), priority, status (Draft → Proposed → Approved → InProgress → Completed, or Rejected/Cancelled), progress %, responsible, start/end date, estimated cost, expected benefit | group → MeasureGroup, implemented by → Project, implements → StrategicGuideline\*, improves → ServiceCapability\*, changes → Application\* and ITComponent\* |

**Specifications** (*Spezifikationen*, own sidebar group):

| Element | Key attributes | Relations |
|---|---|---|
| **ArchitecturePrinciple** | short name, architecture domain (Business/Data/Application/Technology/Security/Integration), priority, status (Draft → InReview → Approved → Deprecated/Withdrawn), version, statement, rationale, implications, principle owner, valid from / until | responsible → Organization, derived from → StrategicGuideline\* |
| **ArchitectureGuideline** | short name, domain, obligation (Mandatory/Recommended/Optional), status, version, applicability, compliance verification, guideline owner, valid from / until | responsible → Organization, derived from → ArchitecturePrinciple\*, standard products → Product\*, applies to → ITComponent\* |
| **ReferenceArchitecture** | *Reference Architecture* (hierarchy path, derived), short name, domain, status, version, scope, architect, valid from / until, *Total Documents* (derived) | parent → ReferenceArchitecture, responsible → Organization, follows → ArchitecturePrinciple\* / ArchitectureGuideline\*, supports → BusinessCapability\*, building blocks → ITComponent\*, standard products → Product\*, implemented by → Application\* |
| **ArchitectureDocument** | document number, document type (Concept/Specification/Standard/Decision/Policy/Manual/Template/Report), status, version, confidentiality, document link, author, approver, approval date, next review date, *Review Overdue* (derived) | responsible → Organization, describes → ReferenceArchitecture\* / ArchitecturePrinciple\* / ArchitectureGuideline\* / Application\* |

**Organisation structure** (*Aufbau*, own sidebar group):

| Element | Key attributes | Relations |
|---|---|---|
| **Enterprise** (*Organisation*, legal entity) | *Organisation* (group path, derived), short name, legal form, commercial register number, VAT ID, headquarters, country, industry, website, founding date, status, ownership share (%); *Managing Director* (head of its top-level unit), *Organisational Units*, *Members* (derived) | parent → Enterprise (group structure) |
| **Organization** (*Organisationseinheit*) | *Organisation* (hierarchy path, derived), short name, status, type, location, start/end date, architect, contact, stakeholder, total consumed / provided business services, total provided support services, cost center; *Head of Unit*, *Members*, *Capacity (FTE)* (derived from the current members) | parent → Organization, legal entity → Enterprise |
| **Member** (*Mitglied*) | personnel number (unique), name, job title, function (Head/Deputy/Employee/Assistant), employment type (Internal/External/Contractor/Trainee), capacity %, e-mail, phone, location, start/end date, *Current* (derived) | unit → Organization (required), line manager → Member, user account → User |

**Processes** (*Prozesse*, own sidebar group – with the business processes):

| Element | Key attributes | Relations |
|---|---|---|
| **ITProcess** | *IT Process* (hierarchy path, derived), short name, level ID, framework (ITIL4/COBIT/ISO20000/IT4IT/Internal), status, purpose, process owner / manager, current / target maturity (1‑5); *Steps*, *KPI Status* (worst KPI, derived) | parent → ITProcess, responsible → Organization, supported business processes → BusinessProcess\*, services → ServiceProductGroup\* |
| **ProcessStep** | sequence no. (unique per process), step type (Activity/Decision/Approval/Automated/Handover), automation level, performer role, duration (h), inputs, outputs | process → ITProcess (required), responsible → Organization, supporting applications → Application\* |
| **ProcessKpi** | unit, direction (higher / lower is better), target, threshold, actual value, measured (at), frequency, KPI owner; *Status* (OnTrack/AtRisk/OffTrack/NoData) and *Achievement %* (derived) | process → ITProcess (required) |

**Security** (*Sicherheit*, own sidebar group):

| Element | Key attributes | Relations |
|---|---|---|
| **ProtectionRequirement** (*Schutzbedarfsfeststellung*, BSI 200-2) | confidentiality, integrity, availability (Normal/High/VeryHigh), *Overall Protection Level* (maximum principle, derived), justification, status, assessed by / on, next review, *Review Overdue* (derived) | exactly one of application → Application, business data → BusinessData, IT component → ITComponent (one assessment per object) |
| **SecurityRisk** (ISO 27005) | risk number, threat, vulnerability, likelihood × impact (1‑5) = *Risk Score* / *Risk Level* (derived), treatment (Mitigate/Accept/Transfer/Avoid), status, risk owner, due date, residual likelihood / impact → *Residual Score / Level* | controls → SecurityControl\*, affected applications / IT components / business data |
| **SecurityControl** | control reference (e.g. ISO 27001 A.8.13, BSI OPS.1.1.3), framework, type (Preventive/Detective/Corrective), implementation status, effectiveness (1‑5), owner, due date, last review; *Overdue*, *Mitigated Risks* (derived) | applications → Application\*, IT components → ITComponent\* |

**Reporting** (own sidebar group – see [Reports](#reports)):

| Element | Key attributes | Relations |
|---|---|---|
| **Report** | category, entity set, columns (field names), filter (`$filter`), order by (`$orderby`), group by, sum field, max rows, report owner | – (runs on the chosen set) |
| **ReportBook** (*Berichtsmappe*) | audience, report owner | reports → Report\* (in order) |

**Access management** (*Zugriffsverwaltung*, own sidebar group – see [Users, roles & permissions](#users-roles--permissions)):

| Element | Key attributes | Relations |
|---|---|---|
| **User** | user name (login, unique, case-insensitive), name, e-mail, active, valid until, *Effective Rights* (derived) | organization → Organization, roles → Role\* |
| **Role** | role key, status (only *Active* roles grant rights), *Total Users* (derived) | permissions → Permission\* |
| **Permission** | entity set (one of the 25 sets or *All*), read / create / update / delete, *Total Roles* (derived) | – |

Every element also has `id`, `name`, `description`, `createdAt` (*Creation Date*), `createdBy`
(*Creator*), `modifiedAt` (*Last Update*) and `modifiedBy` (*Last Update User* / *Last Updated by User*
– the authenticated user, `<user>@cli` or `<user>@gui`). `eam fields <Set>` (or `GET /api/v1/model`) lists every field with label, type, group and
allowed values. Notes on the mapping of the requested attribute lists:

* `version` is a D keyword, so the product's *Version* is called `productVersion`.
* Duplicate attributes in the request (*Number of days before EOL reminder shall be send*, *Reminder
  EoSu (in Days)*) exist once.
* *Parent Product Group* of applications and application groups is modelled as **Parent Application
  Group**. *Capability: IT Capability* references the capability map (the demo adds an
  *IT Platform Services* branch). The application keeps its multi-valued capability list.
* The first column of the Neko reports for organisations, capabilities, processes and catalogues
  (*Organisation*, *Business Capability*, *Business Process*, *Catalog*) is the element's **hierarchy
  path** (`hierarchyPath`, e.g. `ACME Group / Group IT / IT Operations`). It is computed at read time from
  the parent chain and not stored. Business processes and service product groups got a parent reference for it.
* *Level ID Number* of a capability is the existing `level` (1‑5); *Level ID* is a free-text code.
* *Total Consumed/Provided Business Services* and *Total Provided Support Services* are maintained
  numbers – the repository has no business service element yet to count them from.
* *Creation Date* of business data is the common `createdAt`, *Creator* the new common `createdBy`.
* No attribute lists were given for the IT landscape planning and the specifications; their attributes follow
  the usual Neko planning objects (principles, IT capability maturity, measure bundles, measures) and TOGAF
  (principle = statement / rationale / implications). Rejected and cancelled measures do not count toward the
  measure group totals. `scope` is a D keyword, so the *Scope* of a reference architecture is `scopeDescription`.

**Business rules** (enforced in the domain / application layer, so they apply to *every* channel):

* Mandatory fields (`@Required`), ISO dates (`@DateField`), value ranges (scores 1‑5, non-negative costs).
* Date order (go-live ≤ retirement, start ≤ end); a retired application needs a retirement date.
* Level 1 capabilities have no parent; no self-parenting (capabilities, product and application groups).
* Products: a blacklisted product cannot be approved; weblinks must be http(s) URLs; data-quality
  index 0‑100; counters, reminder lead times and costs must not be negative. *Reminder EoL / EoSu (Date)*
  are derived: milestone date minus the reminder days.
* An active application cannot be archived (object state).
* Organisations: start ≤ end, service totals ≥ 0; an organisation whose end date has passed cannot be *Active*.
* An *Active* business process needs a process owner.
* Business data rated *Medium* or *High* in the DPIA needs an owner.
* A *Released* service product group needs a date of release.
* IT landscape planning: an *Active* strategic guideline needs an owner and a rationale (valid from ≤ until);
  service capability maturity is 1‑5; an *Approved* measure group and an *Approved*/*InProgress* measure need
  a responsible person; a running measure needs a start date; a *Completed* measure is at 100 %; progress
  is 0‑100; *Retire* and *Migrate* measures must name the affected applications or IT components.
* Project management: sub projects and work packages need a project; a running sub project needs a manager;
  a running work package needs a responsible person and a start date; a *Completed* work package is at 100 %
  (progress 0‑100); a work package cannot be its own predecessor; efforts and costs ≥ 0; a *Completed* project
  needs an end date. Project / sub project **progress** is the planned-effort weighted mean of the work package
  progress (cancelled ones ignored); a work package is **Delayed** when it is open after its end date.
* Processes: an *Active* IT process needs an owner; maturity 1‑5; step sequence numbers are unique per process;
  automated steps need a supporting application; KPI thresholds lie on the "worse" side of the target; a
  measured KPI needs its measurement date.
* Security: a protection requirement assesses exactly one object, and each object at most once; an *Approved*
  assessment needs assessor and date, and a justification above *Normal*; likelihood / impact 1‑5, the residual
  risk cannot exceed the risk; only risks with treatment *Accept* can be *Accepted*, they need an owner and must
  not be *Critical*; mitigated risks in treatment need a control; implemented controls need an owner, controls in
  progress a due date, *NotApplicable* ones a justification.
* Reporting: columns, group-by and sum fields must exist in the set (sum fields numeric), filter and order by are
  syntax-checked when the report is saved.
* Organisation structure: a unit has at most one current *Head*; personnel numbers are unique; capacity
  1‑100 %; external members, contractors and trainees need an end date; nobody is their own line manager;
  an ownership share (0‑100 %) needs a parent organisation; websites are http(s) URLs. Only *current* members
  (today between start and end date) count for heads, members and FTE.
* Access management: user names are unique and contain no blanks; a permission that allows create, update
  or delete must also allow read.
* Specifications: an *Approved* principle needs owner, statement and rationale; an *Approved* guideline needs an
  owner, and a *Mandatory* guideline must be derived from at least one principle; an *Approved* reference
  architecture needs an architect and at least one principle or guideline; an *Approved* document needs approver
  and approval date (approval ≤ next review); the document link must be an http(s) URL.
* **Referential integrity** (driven by `@References("Kind")` annotations): references must exist, and
  an element that is still referenced cannot be deleted (HTTP 409 / CLI exit code 1).

**Analyses**

* **TIME**: recommendation from business value × technical fit (threshold 3):
  Invest (high/high), Migrate (high value/poor fit), Tolerate (low value/good fit), Eliminate (low/low).
  Deviations from the maintained TIME category are reported.
* **Technology risks**: operational applications using components that are out of vendor support or being phased out.
* **Capability coverage**: a *gap* is a capability where neither it nor any sub-capability is
  supported by an operational application. A capability is *redundant* when more than one application supports it directly.
* **Product lifecycle alerts**: end of life / security / support reached, BSI permission expired,
  reminder dates reached, validation overdue, and blacklisted products in use. Severity is capped at
  *Medium* when no operational application uses or is assigned the product.
* **CSV / Excel import and export** for every entity set (REST, Fiori list page and overview, CLI,
  GtkD, web cockpit links). See [Import & export](#import--export-csv-xlsx) below.
* **Central search** (`GET /api/v1/search?q=…&top=…`, shell bar, `eam search`, GtkD header bar):
  case-insensitive search over all sets the user may read. Every term must occur in the name, id or a free-text
  field (AND); ranking: exact name/id > name prefix > name contains > id contains > other text field.
  Reference ids, enumeration codes and administrative fields are not searched, so "act" does not hit every
  *Active* element. Hits carry the set, icon, matched field label and a text snippet.
* **Impact analysis**: incoming/outgoing flows, providing and dependent applications, capabilities, components, projects.
* **ArchiMate export**: Open Exchange Format (BusinessActor for organisations and organisational units – members
  are personal data and are not exported –, BusinessProcess for IT processes and process steps, Assessment for
  security risks, Requirement for security controls, Capability, ApplicationComponent,
  SystemSoftware/Device for components and products, Grouping for product/application/service product and measure groups,
  BusinessProcess, BusinessObject for business data, WorkPackage for projects, sub projects, work packages and measures (Composition, Triggering for predecessors), Principle for
  strategic guidelines and architecture principles, Constraint / Requirement for mandatory / other architecture
  guidelines, Grouping for reference architectures, Representation for architecture documents,
  Capability also for service capabilities,
  plus Composition/Aggregation/Realization/Serving/Flow/Association relationships).

---

## 2. Project structure

```
neko/
├── mta.yaml                     MTA descriptor (backend + frontend + approuter + XSUAA)
├── README.md  uml.md  nafv4.md  documentation
├── backend/                     D 2.11x / vibe.d 0.10.3 (hexagonal / Clean Architecture)
│   ├── dub.json                 configurations: desktop (default, GtkD), headless, unittest
│   ├── config/default.json      default configuration
│   ├── views/                   Diet templates (web cockpit)
│   ├── tests/                   cross-layer integration tests
│   ├── build/                   binaries (eam, eam-headless, eam-test)
│   └── source/
│       ├── app.d                entry point: serve | gui | webview | <cli>
│       └── neko/eam/
│           ├── composition.d    composition root (manual dependency injection)
│           ├── domain/          entities, types (UDAs, value objects), enumerations, services, exceptions
│           ├── application/     usecases (interactors), services (integrity, ArchiMate, facade), dtos (+ registry)
│           ├── ports/           usecases, services, repositories, storages, messaging, gateways
│           ├── infrastructure/  configuration, logging, security (XSUAA/JWT, PBKDF2 passwords, sign-in sessions),
│           │                    workers, clients (OData client),
│           │                    formats (CSV / XLSX codecs)
│           ├── persistence/     records, mappers, storages (JSON file / memory), repositories
│           └── presentation/    odata, rest (vibe.d REST interfaces + services), http (router, guard, files,
│                                sign-in), web, cli, gui (GtkD + WebView), unix (reserved)
├── frontend/                    SAP Fiori 3 / OpenUI5 1.120 LTS (OData V4)
│   ├── index.html  Component.js  manifest.json  img/logo.svg
│   ├── login.html  logout.html  standalone.js   sign-in / sign-out pages (Login, Logout views, no app shell)
│   ├── view/                    App (ToolPage: ShellBar + SideNavigation), Overview, Analysis,
│   │                            ElementList, ElementDetail, Search (result page), UserProfile.fragment,
│   │                            ImportDialog.fragment (+ controller/TransferHelper.js), Login, Logout,
│   │                            PasswordDialog.fragment (+ controller/PasswordHelper.js)
│   ├── controller/  i18n/ (en, de)  css/
│   ├── model/                   models (REST/OData helpers), auth (sign-in calls), formatter, fieldFactory
│   ├── localService/            metadata.xml + mockdata (generated from the backend)
│   └── test/                    QUnit (unit) + OPA5 (integration)
└── approuter/                   @sap/approuter: xs-app.json, xs-security.json, default-env.json (local only, git-ignored)
```

### Layer rules

* **domain** depends on nothing (only Phobos).
* **application** depends on domain and ports only.
* **ports** hold the interfaces; adapters implement them (persistence) or call them (presentation).
* **presentation** only talks to `IEamUseCases` (driving ports), never to repositories.
* **composition.d** is the only module that knows all concrete classes.

The DTO registry (`application/dtos/registry.d`) lists all entity sets once. OData `$metadata`,
the OData router, the CLI, the web cockpit and the GtkD client are all **generated at compile time**
from it. DTO fields carry presentation UDAs (`@Label`, `@Group`, `@ReadOnly`, `@ListColumn`,
`@Multiline`). `describeModel()` turns them, together with the domain UDAs and the entity's enum
types, into the meta model at `GET /api/v1/model`. The Fiori list and object pages and the GtkD
dialogs build their columns, sections and editors from it, so no UI code is written per entity.
A new element kind needs an entity, a DTO, a record, one registry line, its kind in `entityKindOf`, a few
lines in `composition.d`, one entry in the GtkD `sidebarOrder` and, for the Fiori sidebar, one
`NavigationListItem` plus its i18n texts. The central search, CLI, OData `$metadata`, meta model and web
cockpit pick it up automatically.

---

## 3. Build & run

Prerequisites: `dmd` or `ldc2`, `dub`, OpenSSL 3. For the desktop configuration you also need
GTK 3 and, for `webview`, `libwebkit2gtk-4.1-0`. Both are loaded at runtime, so no `-dev` packages are needed.

```bash
cd backend
dub build                 # desktop configuration -> build/eam (server + CLI + GtkD + WebView)
dub build -c headless     # without GUI dependencies -> build/eam-headless (servers / containers / CF)
dub test  -c unittest     # unit tests of all layers + integration test
```

### Server

```bash
./build/eam serve                 # http://127.0.0.1:8080  (port: --port 9000 or EAM_PORT)
```

| URL | Content |
|---|---|
| `/` | Fiori 3 app |
| `/odata/v4/eam/` and `/odata/v4/eam/$metadata` | OData v4 service document and CSDL |
| `/api/v1/analysis/{portfolio,coverage,risks,products,impact/:id}` | REST analyses |
| `/api/v1/model` | meta model: sets, field labels, groups, types, references, enumeration values, defaults |
| `/api/v1/search?q=…&top=…` | central search over all sets (best hits first, `top` 1–200) |
| `/api/v1/me` | signed-in user (name, initials, e-mail, roles) for the shell bar profile |
| `/login.html`, `/logout.html` | sign-in and sign-out views (local sign-in, see [Sign-in](#sign-in-login--logout)) |
| `/auth/info`, `POST /auth/login`, `POST /auth/logout` | local sign-in: mode, session start / end |
| `POST /api/v1/me/password` | change the own password `{currentPassword, newPassword}` |
| `GET` / `PUT` / `DELETE /api/v1/users/{userName}/password` | password state / set `{password, mustChange}` / remove (user administration) |
| `/api/v1/export/archimate` | ArchiMate 3.1 XML |
| `/web` | server-side web cockpit (daisyUI) |
| `/health` | health check |

On first start, a demo architecture (213 elements: ACME Group with 6 organisations, CRM, S/4HANA, BI, legacy
systems, Oracle 11g/Java 8 risks, projects, 6 products in 4 product groups, 3 application groups,
6 business processes, 4 business data objects, a service catalogue with 4 service product groups, and an IT landscape plan with 5 strategic guidelines,
5 service capabilities, 4 measure groups and 7 measures, and specifications with 4 architecture principles,
4 architecture guidelines, 3 reference architectures and 4 architecture documents, and 4 sub projects and
7 work packages for the two projects, 7 users with 10 roles and 26 permissions, and 3 organisations (group, IT subsidiary, joint venture) with
11 members of the 6 organisational units, 5 IT processes with 8 steps and 5 KPIs, 5 protection requirements,
4 security risks and 5 controls, 6 reports and 2 report books, and 5 comments) is
loaded into `data/eam.json` when `seedOnEmpty` is true. Seeding only happens while **all** sets are empty:
to get the new demo data, delete or rename an older `data/eam.json`, or copy single sets over with
the import (e.g. `EAM_DATA_FILE=/tmp/demo.json eam export all /tmp/demo.xlsx`, then
`eam import Measures /tmp/demo.xlsx` per set, referenced sets first).

### OData v4 examples

```bash
B=http://localhost:8080/odata/v4/eam
curl "$B/Applications?\$filter=status eq 'Active' and businessValue ge 4&\$orderby=annualCost desc&\$select=name,timeCategory&\$count=true"
curl "$B/Applications?\$filter=componentIds/any(c:c eq 'tc-oracle11')"
curl "$B/Applications('app-crm')"
curl -X POST  $B/Applications -H 'Content-Type: application/json' -d '{"name":"HR Suite","ownerOrganizationId":"org-group"}'
curl -X PATCH "$B/Applications('app-bi')" -H 'Content-Type: application/json' -d '{"technicalFit":4}'
curl -X DELETE "$B/Applications('app-portal')"     # 409 while flows/projects reference it
curl "$B/ITComponents/\$count"
curl "$B/Products?\$filter=isBlacklisted eq false and lifecycleStatus eq 'Active'&\$select=name,productVersion,endOfSupport"
curl "$B/ApplicationGroups?\$select=name,totalUsedProducts,totalAssignedProducts"
curl "$B/Applications?\$filter=usedProductIds/any(p:p eq 'prd-oracle-11')"
```

Supported: service document, `$metadata` (generated), entity set / entity GET, POST, PATCH, PUT,
DELETE, `/$count`, `$filter` (`eq ne gt ge lt le and or not ( )`, `contains startswith endswith
tolower toupper length`, lambda `any` on collections), `$orderby`, `$select`, `$top`, `$skip`,
`$count`, `$search`. Errors use the OData error format `{"error":{"code","message","target"}}`.
`target` names the field that failed validation, and the object page highlights it.
Not supported: `$batch` (the UI5 model is configured with `groupId: "$direct"`), `$expand`, navigation properties
(relations are id references / string collections).

### CLI

```bash
./build/eam help
./build/eam sets
./build/eam fields Products                        # labels, types, groups, allowed values
./build/eam list Applications --filter "timeCategory eq 'Invest'" --orderby "annualCost desc" --fields id,name,annualCost
./build/eam show Applications app-crm
./build/eam create Applications name="Data Platform" businessValue=4 technicalFit=5 capabilityIds=cap-reporting
./build/eam update Applications app-bi timeCategory=Invest technicalFit=4
./build/eam delete WorkPackages wp-bi-migration
./build/eam analyze portfolio | coverage | products | impact app-s4
./build/eam update Products prd-k8s-131 endOfLife=2027-02-28 eolReminderDays=60
./build/eam export archimate model.xml
./build/eam search customer --top 10              # central search over all sets
./build/eam export Products products.xlsx         # one set as Excel (or .csv; --sep ';' --headers names)
./build/eam export all repository.xlsx            # every set, one sheet each
./build/eam import Organizations orgs.csv --dry-run
./build/eam import all repository.xlsx            # exit code 1 if rows failed
./build/eam list Applications --json
./build/eam list Applications --remote http://localhost:8080/odata/v4/eam [--token JWT]
```

Exit codes: `0` ok, `1` business/technical error, `2` invalid configuration, `3` GUI not available in this build.

### Import & export (CSV, XLSX)

Every entity set can be exported and imported as **CSV** or **Excel (XLSX)**; the whole repository as one
workbook with one sheet per set.

| Channel | Export | Import |
|---|---|---|
| REST | `GET /api/v1/transfer/{Set}?format=csv\|xlsx[&sep=;][&headers=names]`, `GET /api/v1/transfer?format=xlsx` | `POST /api/v1/transfer/{Set}[?dryRun=true]`, `POST /api/v1/transfer[?dryRun=true]` – raw file body or multipart field |
| Fiori | list page *Export* menu (XLSX, CSV, CSV with `;`), overview *Export all (Excel)* | *Import* dialog: choose file → **Check** (dry run) → **Import** |
| CLI | `eam export <Set\|all> <file.csv\|.xlsx>` | `eam import <Set\|all> <file> [--dry-run]` |
| GtkD | header bar *Export…* (visible set, or all on the analysis page) | *Import…* with a dry-run preview before saving |
| Web cockpit | *Excel* / *CSV* links per set | – |

* **Columns**: every field of the element. Headers are the field labels (`Last Update User`, `Insgesamt
  genutzte Produkte` …) or, with `headers=names`, the technical names. Imports accept both, case-insensitive,
  in any order; unknown columns are reported as warnings and ignored.
* **Upsert by ID**: a row with a known ID updates that element, **only with the columns in the file** (a file
  with `ID;Contact` changes contacts only); a row with a new or empty ID creates an element. Rows without
  changes are counted as *unchanged*. Read-only columns (creation/update info, derived totals, hierarchy paths)
  are ignored. All imports go through the regular use cases: validation, referential integrity, `createdBy` /
  `modifiedBy` (the importing user).
* **Errors per row**: invalid rows are skipped and reported with row number, ID, field and message; the
  other rows are imported. **Dry run** (`dryRun=true`, *Check*, `--dry-run`) runs the complete import against
  an in-memory copy of the repository, so its result is exactly what the real import will do – nothing is saved.
* **Order**: workbooks are processed in dependency order (organisations, capabilities, components, product
  groups, products, application groups, applications, flows, …). Rows that reference elements further down in
  the file (e.g. a child before its parent) are retried until no more progress is made.
* **Spreadsheet conventions accepted on import**: yes/no, ja/nein, x, 1/0, WAHR/FALSCH for booleans; decimal
  commas; dates as Excel dates, `YYYY-MM-DD`, `dd.mm.yyyy` or `mm/dd/yyyy`; enumeration values in any case
  (`phase out` → `PhaseOut`); collections separated by `,` or `;`.
* **CSV**: UTF-8 with BOM (Excel opens it correctly); separator `,` or `;` (auto-detected on import, tab too);
  files saved as Windows-1252 by older Excel versions are converted. Text cells starting with `=` `+` `-` `@`
  are written with a leading apostrophe so spreadsheet programs do not execute them as formulas (CSV injection).
* **XLSX**: written and read with Phobos only (`std.zip` + a small XML scanner, no external library). Bold
  frozen header with auto filter, column widths, numbers/booleans as typed cells, dates as real Excel dates.
  Reads shared strings, inline strings, rich text and formula results, so files saved by Excel or LibreOffice
  work. Uploads are limited to 32 MB.
* Import and export follow the [permissions](#users-roles--permissions): the workbook export leaves out sets
  the user may not read, and import rows of sets without create / update permission fail with a row error.

### Users, roles & permissions

What a user may **see** and **change** is maintained in the application itself (sidebar group
*Access Management*): a **permission** grants read / create / update / delete on one entity set or on *All*
sets, a **role** bundles permissions, a **user** gets roles. *All* does not include the access management sets
(Users, Roles, Permissions) – they always need an explicit permission.

The checks run in the application layer (`AccessControlInteractor` hands every adapter a checked view of the
use cases), so OData, REST, import/export, search, web cockpit, CLI and desktop behave the same:

| Caller | Rights |
|---|---|
| XSUAA token with the `Admin` scope (`EAM_Architect`), or local operation without impersonation | **unrestricted** (administrator – initial set-up, break-glass) |
| XSUAA token with `Display` only (`EAM_Viewer`) | rights of the repository user with the same user name or e-mail (case-insensitive), from its *active* roles |
| user not found / inactive / past *valid until* | no access (HTTP 403) |
| no users defined yet (fresh installation) | read access to everything except access management, no changes |

* Missing rights → HTTP 403 (`Forbidden`, message e.g. `No permission to update Applications`), CLI exit code 1.
* Search and the workbook export silently skip sets that may not be read; the analyses need read access to
  Applications, the ArchiMate export read access to all architecture sets, `seed` administrator rights.
* The Fiori app shows only readable sets in the side navigation and enables *Create*, *Edit*, *Delete* and
  *Import* per set; the profile shows the roles and the effective rights (e.g. `All: R; Applications: RCUD`).
* **Signing in with a password** (`authMode=local`): see [Sign-in](#sign-in-login--logout).
* **Trying it locally** (`authMode=none`): the profile popover offers *Act as* with the repository users (sets
  the cookie `eam-dev-user`, ignored with XSUAA). CLI: `--user <userName>`, desktop: `EAM_USER=<userName>`.

```bash
./build/eam rights j.becker                                   # effective rights of a user
./build/eam --user s.yilmaz update Applications app-bi technicalFit=3   # -> error (Forbidden), exit 1
EAM_USER=a.krueger ./build/eam gui                            # desktop client with the rights of a.krueger
```

Demo roles: *EAM Administrator* (everything incl. access management), *Enterprise Architect* (maintain all),
*Viewer* (read all), *Application Owner*, *Product Manager*, *IT Planner*, *Project Manager* (read all + maintain
their sets), *Project Team Member* (only sees and updates work packages) and the inactive *Legacy Editor*.

### Sign-in (login & logout)

How users sign in depends on `authMode`:

| `authMode` | Sign-in | Sign-out |
|---|---|---|
| `none` (default, development) | none – the OS user is administrator (*Act as* for testing rights) | – |
| `local` | **login view** (`login.html`): user name + password of a repository user (*Access Management → Users*) | profile → *Sign Out* → **logout view** (`logout.html`) |
| `xsuaa` | SAP approuter / identity provider | profile → *Sign Out* → approuter `/do/logout` → logout view |

With `authMode=local`:

* Users sign in to **one tenant** (field *Tenant*, shown when there are several); users, roles and passwords are
  per tenant. Only enabled users (active, not past *valid until*) can sign in.
* The built-in **administrator** (`EAM_ADMIN_USER`, default `admin`, password `EAM_ADMIN_PASSWORD`) is
  system administrator: initial set-up, tenants, break-glass. Without `EAM_ADMIN_PASSWORD` there is none.
* **Passwords**: at least 10 characters with letters and digits or special characters, not containing the user
  name. Stored only as salted **PBKDF2-HMAC-SHA256** hash (120,000 iterations) in the tenant's data file
  (collection `Credentials`, part of backups) – never in OData, the workbook export, reports or the search.
* **Setting passwords**: users with update permission on *Users* use *Set Password* on the user's object page
  (or `eam password <userName>`). The user then has to choose an own password after signing in (the profile
  opens *Change Password*); `--keep` / unchecking the box skips that. Users change their password in the profile.
  Deleting a user removes the password; setting or removing it signs the user out everywhere.
* **Sessions**: server-side, cookie `eam-session` (HttpOnly, SameSite=Strict, Secure with TLS), new id on every
  sign-in, idle timeout `sessionTimeoutMinutes` (default 60) and at most 12 hours. Kept in memory – a restart
  signs everybody out. Modifying requests need the session's **CSRF token** (`X-CSRF-Token`, fetched with
  `X-CSRF-Token: Fetch`, same protocol as the approuter – the Fiori app handles it).
* **Brute force**: after 5 failed attempts for a user name (20 per client address) further attempts are refused
  with HTTP 429 for 30 s, doubling up to 15 min. The error never tells whether a user exists.
* Signed-out browsers are sent to the login view (also from `/web`), and back to the page they came from
  afterwards (only targets of this app – no open redirect). An expired session shows a hint on the login view.

```bash
EAM_AUTH_MODE=local EAM_ADMIN_PASSWORD='choose a long one' ./build/eam serve
./build/eam password m.weber            # set a password (asked twice, hidden); must be changed at first sign-in
echo 'Archi tect 2026' | ./build/eam password m.weber --keep   # from stdin, no forced change
./build/eam password m.weber --check    # has the user a password?
./build/eam password m.weber --remove   # sign-in no longer possible
```

### Comments (journal)

Every element of every set has a running **comment journal** to document its current state and changes:
date and author (the signed-in user) are recorded automatically, the text is free (max. 4,000 characters).

* Append-only: entries are not edited afterwards. The author may delete an own entry; other entries can be
  deleted by users with the delete permission on the element's set.
* Reading and writing need read access to the element (so stakeholders can contribute); without read access
  the comments of an element are not visible either (HTTP 403).
* Deleting an element removes its comments. Comments are stored per tenant (collection `Comments`) and are part
  of every backup.
* Fiori: section *Comments (n)* on every object page (newest first, input on top). Desktop: *Comments…* in the
  header bar for the selected element. CLI and REST:

```bash
./build/eam comments Applications app-legacycrm                      # newest first
./build/eam --user m.weber comment Applications app-legacycrm "Shutdown confirmed for 30 June 2027"
./build/eam comment delete cmt-1a2b3c4d-5e6f
```

REST: `GET /api/v1/comments/{set}/{id}`, `POST /api/v1/comments/{set}/{id}` (`{"text": "..."}`),
`DELETE /api/v1/comments/{commentId}`.

### Notifications

The bell of the Fiori shell bar shows the unread notifications of the signed-in user, in two groups:

* **Alerts** – due or overdue items computed from the data, for everybody who may read the set: product
  lifecycle alerts of severity *Medium* or higher (end of support / security updates / life, expired BSI
  permission, blacklisted product in use, reminders, validations), architecture documents and protection
  requirements whose review is overdue, delayed work packages, overdue security controls, open security risks
  past their due date, KPIs off track. They are computed once per change of the repository (and day).
* **Activity** – changes, deletions and comments of *other* users on elements the user created, last edited
  or commented on (a user whose account was changed is told as well). Changes list the changed fields.
  Creating an element concerns nobody yet; nobody is notified about own changes.

Selecting a notification opens the element and marks it as read; the close button (per item or group) or
*Clear all* removes notifications from the user's list. The app polls every 60 s while the tab is visible;
these polls do not restart the idle timeout of the local sign-in. Activities (newest 5,000 of the last 90 days)
and the read / dismissed state per user are stored per tenant (collections `Activities`, `NotificationStates`)
and are part of every backup. In-app only – no e-mail.

REST: `GET /api/v1/notifications` (`{unread, items}`), `POST /api/v1/notifications/read` and
`POST /api/v1/notifications/dismiss` (each `{"ids": [...]}` or `{"all": true}`, answer: the updated list).

### Reports

A **report** is a stored query over one entity set: columns, a filter in OData `$filter` syntax (e.g.
`riskScore ge 10`, `status eq 'Deprecated' or isBlacklisted eq true`, `capabilityIds/any(c:c eq 'cap-crm')`),
`$orderby`, max rows and an optional **group by** with count and sum. References are shown with their names,
derived values (risk score, KPI status, totals …) can be filtered and grouped like stored ones. A **report book**
combines several reports. Reports run with the rights of the caller: a report on *Users* needs read access to
users, and referenced names of unreadable sets are shown as ids.

* Fiori: *Run* on the object page of a report or report book → result page with table, group summary and
  export (Excel with one sheet per report and summary, CSV, PDF).
* PDF: A4 landscape, header row repeated on every page, page numbers – written without an external library.

```bash
./build/eam report run rep-portfolio
./build/eam report export rep-risks risks.pdf          # .xlsx, .csv or .pdf
./build/eam reportbook export rb-board board.xlsx
```

REST: `GET /api/v1/reports/{id}/run`, `GET /api/v1/reports/{id}/export?format=xlsx|csv|pdf`,
`POST /api/v1/reports/run` (unsaved definition), `GET /api/v1/reportbooks/{id}/run|export?format=xlsx|pdf`.

### Tenants, backup & restore

**Tenants (Mandanten).** Each tenant is an isolated repository: its own data file, its own users, roles and
permissions. The tenant `default` uses the configured `dataFile` (existing installations keep working
unchanged); further tenants live in `tenantDirectory/<id>.json` and are listed in `tenantRegistryFile`.

| How the tenant of a request is chosen | |
|---|---|
| 1. XSUAA identity zone (`zid` claim) mapped to a tenant (*Identity Zone*) | always wins – one subaccount = one tenant |
| 2. header `X-EAM-Tenant`, cookie `eam-tenant` (Fiori profile *Tenant*), CLI `--tenant`, desktop `EAM_TENANT` | only if the caller is a user of that tenant (or a system administrator) |
| 3. otherwise | `default` |

* **System administrators** (XSUAA scope `SystemAdmin`, role collection `EAM_SystemAdministrator`; locally the
  OS user) create, change, suspend and delete tenants and may enter every tenant. A new tenant can get demo
  data and an administrator user (role *Tenant Administrator*); creating a tenant is all or nothing.
* Suspended tenants can only be entered by system administrators; deleting a tenant takes a final backup first
  (kept), the default tenant cannot be deleted or suspended.

**Backup (Datensicherung).** A backup is a snapshot of all data of one tenant – incl. users, roles and
permissions – as gzip-compressed JSON (`.eambackup`) with a manifest (tenant, time, user, kind, comment,
element counts) and a **SHA-256 checksum** over a canonical serialisation of the data.

* Kinds: *Manual*, *Scheduled* (every `backupIntervalHours`, newest `backupRetention` kept per tenant),
  *PreRestore* and *PreDelete* (automatic safety backups, kept), *Upload*.
* Stored in `backupDirectory/<tenant>/<id>.eambackup`; downloadable for off-site storage.

**Restore (Wiederherstellung).** Always in two steps: **check** (format and version, checksum, test load of
every set into the current meta model, warnings – e.g. "you will no longer be administrator") and, after
confirmation, **restore**: a *PreRestore* safety backup of the current state is taken, then all data of the
tenant is replaced in one atomic write and the tenant's use cases are rebuilt. A backup of another tenant can be
restored (= copy a tenant) only by a system administrator.

* Who: administrators of the tenant (full rights on everything incl. users, roles and permissions, or the XSUAA
  `Admin` scope) for their tenant; system administrators for every tenant.
* Fiori: *System → Backup & Restore* (create with comment, download, check, restore, delete, restore from a
  file) and *System → Tenants*; the shell bar shows the current tenant, the profile switches it.

```bash
./build/eam tenants create acme name="ACME Corp" --admin acme.admin --admin-email it@acme.example
./build/eam --tenant acme backup create "before the yearly clean-up"
./build/eam --tenant acme backup list
./build/eam --tenant acme backup restore 20261112-150316-manual --check   # check only
./build/eam --tenant acme backup restore 20261112-150316-manual           # safety backup + restore
./build/eam --tenant acme backup restore ~/eam-acme.eambackup             # restore a downloaded file
./build/eam backup run                                                    # scheduled backup of all tenants (cron)
```

REST: `GET/POST /api/v1/tenants`, `PATCH/DELETE /api/v1/tenants/{id}`, `GET/POST /api/v1/backups`,
`GET/DELETE /api/v1/backups/{id}`, `POST /api/v1/backups/{id}/restore[?check=true]`,
`POST /api/v1/backups/restore[?check=true]` (file as body) – all for the tenant of the request.

### Desktop

```bash
./build/eam gui                                  # native GtkD client: sidebar per element kind, search field, user button,
                                                 # tabbed edit dialogs (combo boxes for enums/references), analysis, export
./build/eam webview                              # starts an embedded server and opens the Fiori app in WebKit
./build/eam webview --url https://eam.example.com  # or connects to a remote server/approuter
```

### Frontend tests

With the server running, open `http://localhost:8080/test/testsuite.qunit.html`:
unit tests (formatters, field factory) and OPA5 journeys run against the live backend. The journeys cover the shell bar
user, the profile popover, sidebar navigation to Products, running a report, to the measure groups (IT landscape planning) to the reference architectures (specifications) and to the work packages (project management), to the roles (access management), to the members (organisation structure), the object page, the central search
(type filter), opening a search hit, and the export menu / import dialog of the list page.

### Fiori UI

* **Shell**: `sap.tnt.ToolPage` with a Fiori 3 `sap.f.ShellBar` (menu toggle, logo, **central search**,
  **notifications** (see [Notifications](#notifications)), ArchiMate export, **help**, **user avatar**) and a `sap.tnt.SideNavigation`
  grouped into Application Portfolio, Product Catalogue, Business Architecture, Organisation Structure
  (Organisations, Organisation Units, Members), Processes (Business Processes, IT Processes, Process Steps,
  Process KPIs), Security (Protection Requirements, Security Risks, Security Controls), Reporting (Reports,
  Report Books), System (Backup & Restore, Tenants), Service Catalogue,
  IT Landscape Planning (Strategic Guidelines, Service Capabilities, Measure Groups, Measures),
  Specifications (Architecture Principles, Architecture Guidelines, Reference Architectures, Architecture Documents),
  Project Management (Projects, Sub Projects, Work Packages), Integration (Information Flows) and Analysis.
* **Context help** (shell bar *?* or **F1**): a panel beside the page (full width on phones) with help for
  the current page – for list and object pages also what the entity set is for – general topics (getting
  started, navigation, search, notifications, permissions, keyboard) and a searchable list of all fields of the
  set. Field help combines a curated text (`helpField_<field>` / `helpField_<Set>_<field>` in the i18n files)
  with type, mandatory flag, allowed values, reference and *calculated* from the meta model; on object pages
  it is the tooltip of the field label. English and German; the panel stays open across reloads.
* **Import / export**: *Export* menu and *Import* dialog on every list page, *Export all (Excel)* and
  *Import workbook* on the overview (see [Import & export](#import--export-csv-xlsx)).
* **Central search** (`sap.f.SearchManager`): type-ahead suggestions (top 8 hits, debounced, with type and
  matched field) open the object page directly; *Enter* opens the result page `#/search/<query>` with a
  filter by element type and the matched text per hit.
* **User profile** (avatar): name, e-mail, roles and effective rights (from the access management), language
  (EN/DE), theme (Fiori 3, Fiori 3 Dark, High Contrast Black/White, remembered in the browser), *Change
  Password* (local sign-in), *Sign Out* (local sign-in and approuter) and – with `authMode=none` only – *Act as*
  another repository user. Navigation entries and the *Create*,
  *Edit*, *Delete* and *Import* buttons follow the user's permissions per set.
* **Generic pages** (`ElementList`, `ElementDetail`) for all thirty-five sets: list columns from `@ListColumn`,
  object page sections from `@Group`, display mode with links to referenced elements, **Edit → Save/Cancel**
  (one PATCH with the changed fields), create via the same page (`#/sets/<Set>/new`), and a **Where Used**
  section with all elements that reference the current one. Applications also show the impact analysis.
* **Login / logout views** (`login.html`, `logout.html`): Fiori 3 sign-in card (user name, password, tenant
  when there are several, messages for wrong credentials, lock-out and expired sessions) and the sign-out
  confirmation – both outside the app shell, in the theme chosen in the app.
* Runs on **OpenUI5 1.120 LTS** from `sdk.openui5.org`, the last line that still ships the SAP Fiori 3 themes.

---

## 4. Configuration

Precedence (lowest → highest): built-in defaults → `config/default.json` (or `EAM_CONFIG`) →
environment variables → `VCAP_SERVICES`.

| Key (`default.json`) | Environment | Default |
|---|---|---|
| `bindAddress` | `EAM_BIND_ADDRESS` | `127.0.0.1` (`0.0.0.0` when `PORT` is set) |
| `port` | `EAM_PORT`, `PORT` (CF) | `8080` |
| `logLevel` | `EAM_LOG_LEVEL` | `info` |
| `dataFile` | `EAM_DATA_FILE` | `data/eam.json` |
| `seedOnEmpty` | `EAM_SEED_ON_EMPTY` | `true` |
| `frontendPath` | `EAM_FRONTEND_PATH` | `../frontend` |
| `authMode` (`none`/`local`/`xsuaa`) | `EAM_AUTH_MODE`; set to `xsuaa` automatically when an XSUAA binding exists. Other values are rejected at start-up | `none` |
| `sessionTimeoutMinutes` | `EAM_SESSION_TIMEOUT_MINUTES` | `60` (idle timeout of local sign-in sessions, 1–1440) |
| `localAdminUser` | `EAM_ADMIN_USER` | `admin` (built-in administrator of the local sign-in) |
| `localAdminPassword` | `EAM_ADMIN_PASSWORD` (prefer the environment; a `pbkdf2-sha256$…` hash is accepted too) | – (no built-in administrator) |
| `xsuaa.{xsappname,clientid,url,verificationkey}` | `VCAP_SERVICES.xsuaa[0].credentials` | – |
| `tlsCertificateFile`, `tlsPrivateKeyFile` | `EAM_TLS_CERT`, `EAM_TLS_KEY` | – (HTTPS when both are set) |
| `healthCheckIntervalSeconds` | – | `300` (background architecture health worker, 0 = off) |
| `webviewUrl` | `EAM_WEBVIEW_URL` | – (embedded server) |
| `tenantRegistryFile` | `EAM_TENANT_REGISTRY` | `data/tenants.json` (tenants; created on first start with `default`) |
| `tenantDirectory` | `EAM_TENANT_DIR` | `data/tenants` (data files of the tenants other than `default`) |
| `backupDirectory` | `EAM_BACKUP_DIR` | `data/backups` |
| `backupRetention` | `EAM_BACKUP_RETENTION` | `10` (scheduled backups kept per tenant) |
| `backupIntervalHours` | `EAM_BACKUP_INTERVAL_HOURS` | `24` (scheduled backups of all tenants, 0 = off) |
| `persistDelayMilliseconds` | `EAM_PERSIST_DELAY_MS` | `500` (changes made in the server are written to the data file at most this late, all changes of that window in one write; pending changes are written on shutdown; 0 = write every change at once) |

### Security

* `authMode=none` (local development): every request runs as the OS user (`$USER`) with full rights, unless a
  repository user is selected with *Act as* (cookie `eam-dev-user`). **Never expose it to a network.**
* `authMode=local`: login view with repository users and passwords, server-side sessions, CSRF tokens and
  sign-in throttling (see [Sign-in](#sign-in-login--logout)). Use TLS (`tlsCertificateFile`/`tlsPrivateKeyFile`
  or a reverse proxy) so that passwords and session cookies are not sent in clear text.
* **Authorization** is defined by the EAM users, roles and permissions (see
  [Users, roles & permissions](#users-roles--permissions)), enforced in the application layer for every channel.
* `authMode=xsuaa`: OData, REST and web routes require a bearer JWT. The backend checks the
  **RS256 signature** (OpenSSL, against the XSUAA `verificationkey`), expiry and client/audience.
  `<xsappname>.Display` is needed to sign in; what the user may read or change comes from the repository
  permissions. `<xsappname>.Admin` makes the user an administrator who bypasses them. The user's
  `given_name`, `family_name` and `email` claims feed the shell bar profile (`/api/v1/me`). The approuter
  additionally requires `Display` per route (`xs-app.json`, for all methods – write access is decided by the
  backend) and handles CSRF. Only the logout view and its resources are public (`logoutPage: /logout.html`).
* Role collections: `EAM_Viewer` (EAM user – rights from the access management), `EAM_Architect` (administrator
  of the tenant), `EAM_SystemAdministrator` (scope `SystemAdmin`: tenants, backup / restore of every tenant)
  (`approuter/xs-security.json`).
* **Tenant isolation**: separate data files and access management per tenant; a tenant other than the one of
  the caller's identity zone can only be entered as a user of that tenant or as system administrator.
  Backup and tenant ids are validated before they are used in file names (no path traversal).
* `approuter/default-env.json` holds secrets and is git-ignored. Replace the placeholders with a service key.

---

## 5. SAP BTP / Cloud Foundry

```bash
mbt build            # builds backend (headless, release) and packages approuter + Fiori resources
cf deploy mta_archives/neko-eam_1.0.0.mtar
```

* `eam-backend` runs with the `binary_buildpack` (`./build/eam-headless serve`). Build it on a
  Linux system compatible with the CF stack (cflinuxfs4, OpenSSL 3).
* `eam-approuter` serves the Fiori app from `resources/` (copied from `frontend/` by the MTA build) and
  forwards `/odata`, `/api` and `/web` to the `eam-backend` destination with the user's token.
* Local: `cd approuter && npm install && npm start` (port 5000, backend on 8080 via `default-env.json`).

**Known limitations**

* Persistence is a JSON file (atomic write per change). On Cloud Foundry the container file system
  is ephemeral, so use a volume service, or add a database storage that implements `IDocumentStorage`
  (e.g. PostgreSQL via `vibe-d-postgresql`). Writes are serialized per process, so run one instance.
* `$batch`, `$expand` and navigation properties are not implemented. The object page therefore saves
  through plain OData requests (with CSRF token handling) instead of a deferred OData V4 update group.
* Product *Level ID* fields are free text and not derived from the hierarchy depth.
* `presentation/unix` and `ports/gateways` are placeholders for future adapters.
