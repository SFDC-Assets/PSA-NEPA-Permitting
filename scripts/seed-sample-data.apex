// seed-sample-data.apex
// Usage: sf apex run --file scripts/seed-sample-data.apex --target-org <alias>
//
// Creates: 3 projects (EIS, EA, CE), 3 processes, 3 documents, 4 public comments,
//          2 engagement events, 3 timeline events, 3 GIS data elements,
//          5 process team members, and 4 regulatory citations (RegulatoryCode).
// Not idempotent — project IDs are unique; re-running will fail on nepa_project_id__c.
// Clear existing seed data before re-running.

// ── 1. Agency accounts ────────────────────────────────────────────────────────
Account blm = new Account(Name = 'Bureau of Land Management');
Account doe = new Account(Name = 'Department of Energy');
Account fws = new Account(Name = 'Fish and Wildlife Service');
insert new List<Account>{ blm, doe, fws };

// RegulatoryAuthority required by RegulatoryCode.RegulatoryAuthorityId
RegulatoryAuthority raCeq = new RegulatoryAuthority(Name = 'CEQ');
RegulatoryAuthority raUsfws = new RegulatoryAuthority(Name = 'USFWS');
insert new List<RegulatoryAuthority>{ raCeq, raUsfws };

// ── 2. Projects (CEQ Entity 1: Project) ───────────────────────────────────────
Program eisProject = new Program();
eisProject.Name                    = 'Wind River Pipeline EIS';
eisProject.nepa_project_id__c      = 'BLM-WY-2026-EIS-001';
eisProject.nepa_project_title__c   = 'Wind River Pipeline EIS';
eisProject.nepa_lead_agency__c     = blm.Id;
eisProject.nepa_project_sector__c  = 'Energy';
eisProject.nepa_project_type__c    = 'EIS';
eisProject.nepa_current_status__c  = 'in progress';
eisProject.nepa_circuit__c         = '9th';
eisProject.nepa_project_description__c =
    'Proposed 47-mile natural gas pipeline across BLM-administered lands in Fremont County, WY. '
    + 'Project area includes potential raptor habitat and proximity to Wind River Indian Reservation.';

Program eaProject = new Program();
eaProject.Name                    = 'Solar Valley EA';
eaProject.nepa_project_id__c      = 'DOE-CA-2026-EA-007';
eaProject.nepa_project_title__c   = 'Solar Valley Photovoltaic EA';
eaProject.nepa_lead_agency__c     = doe.Id;
eaProject.nepa_project_sector__c  = 'Energy';
eaProject.nepa_project_type__c    = 'EA';
eaProject.nepa_current_status__c  = 'in progress';
eaProject.nepa_circuit__c         = '9th';
eaProject.nepa_project_description__c =
    '800-acre utility-scale solar PV facility on previously disturbed federal land. '
    + 'Requires BLM right-of-way and DOE interconnect authorization.';

Program ceProject = new Program();
ceProject.Name                    = 'Sage Creek Grazing Renewal CE';
ceProject.nepa_project_id__c      = 'BLM-MT-2026-CE-042';
ceProject.nepa_project_title__c   = 'Sage Creek Grazing Permit Renewal CE';
ceProject.nepa_lead_agency__c     = blm.Id;
ceProject.nepa_project_sector__c  = 'Agriculture and Natural';
ceProject.nepa_project_type__c    = 'CE';
ceProject.nepa_current_status__c  = 'in progress';
ceProject.nepa_circuit__c         = '9th';
ceProject.nepa_project_description__c =
    'Renewal of existing grazing permit for 1,200 AUMs on 4,800 acres. '
    + 'No change to existing allotment boundaries or stocking rates.';

insert new List<Program>{ eisProject, eaProject, ceProject };

// ── 3. Processes (CEQ Entity 2: Process) ─────────────────────────────────────
Date today = Date.today();

// LicenseTypeId is org-specific; get-or-create at runtime
Id licenseTypeId;
List<RegulatoryAuthorizationType> ratList = [
    SELECT Id FROM RegulatoryAuthorizationType
    WHERE Name = 'NEPA Environmental Review' LIMIT 1
];
if (ratList.isEmpty()) {
    RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
        Name = 'NEPA Environmental Review', RegulatoryAuthCategory = 'Permit'
    );
    insert rat;
    licenseTypeId = rat.Id;
} else {
    licenseTypeId = ratList[0].Id;
}

IndividualApplication eisProcess = new IndividualApplication();
eisProcess.Category                               = 'Permit';
eisProcess.LicenseTypeId                          = licenseTypeId;
eisProcess.nepa_related_project__c                = eisProject.Id;
eisProcess.nepa_review_type__c                    = 'EIS';
eisProcess.nepa_process_status__c                 = 'in progress';
eisProcess.nepa_process_stage__c                  = 'Draft EIS Preparation';
eisProcess.nepa_federal_unique_id__c              = 'DOI-BLM-WY-2026-EIS-001';
eisProcess.nepa_agency_id__c                      = 'BLM-WY-110-2026-EA-0001';
eisProcess.nepa_public_comment_period_start__c    = (DateTime) today.addDays(30);
eisProcess.nepa_public_comment_period_end_date__c = (DateTime) today.addDays(75);
eisProcess.nepa_start_date__c                     = today.addDays(-365);
eisProcess.nepa_last_stage_transition__c          = DateTime.now().addDays(-120);

IndividualApplication eaProcess = new IndividualApplication();
eaProcess.Category                               = 'Permit';
eaProcess.LicenseTypeId                          = licenseTypeId;
eaProcess.nepa_related_project__c                = eaProject.Id;
eaProcess.nepa_review_type__c                    = 'EA';
eaProcess.nepa_process_status__c                 = 'in progress';
eaProcess.nepa_process_stage__c                  = 'Comment Period';
eaProcess.nepa_federal_unique_id__c              = 'DOE-EERE-2026-EA-007';
eaProcess.nepa_agency_id__c                      = 'DOE-EERE-2026-007';
eaProcess.nepa_public_comment_period_start__c    = (DateTime) today.addDays(-5);
eaProcess.nepa_public_comment_period_end_date__c = (DateTime) today.addDays(25);
eaProcess.nepa_start_date__c                     = today.addDays(-90);
eaProcess.nepa_last_stage_transition__c          = DateTime.now().addDays(-45);

IndividualApplication ceProcess = new IndividualApplication();
ceProcess.Category                               = 'Permit';
ceProcess.LicenseTypeId                          = licenseTypeId;
ceProcess.nepa_related_project__c                = ceProject.Id;
ceProcess.nepa_review_type__c                    = 'CE';
ceProcess.nepa_process_status__c                 = 'in progress';
ceProcess.nepa_process_stage__c                  = 'Scoping';
ceProcess.nepa_federal_unique_id__c              = 'DOI-BLM-MT-2026-CE-042';
ceProcess.nepa_agency_id__c                      = 'BLM-MT-040-2026-CE-0042';
ceProcess.nepa_start_date__c                     = today.addDays(-14);

insert new List<IndividualApplication>{ eisProcess, eaProcess, ceProcess };

// ── 4. Documents (CEQ Entity 3) ───────────────────────────────────────────────
ContentVersion noi = new ContentVersion();
noi.Title                 = 'Notice of Intent — Wind River Pipeline EIS';
noi.PathOnClient          = 'NOI_Wind_River_Pipeline.pdf';
noi.VersionData           = Blob.valueOf('Placeholder: Notice of Intent content');
noi.nepa_document_type__c = 'NOI';
noi.nepa_status__c        = 'Final';
noi.nepa_publish_date__c  = today.addDays(-365);
noi.nepa_public_access__c = true;

ContentVersion deis = new ContentVersion();
deis.Title                 = 'Draft Environmental Impact Statement — Wind River Pipeline';
deis.PathOnClient          = 'DEIS_Wind_River_Pipeline.pdf';
deis.VersionData           = Blob.valueOf('Placeholder: Draft EIS content');
deis.nepa_document_type__c = 'DEIS';
deis.nepa_status__c        = 'Draft';
deis.nepa_publish_date__c  = today.addDays(-30);
deis.nepa_public_access__c = true;

ContentVersion ea = new ContentVersion();
ea.Title                 = 'Environmental Assessment — Solar Valley PV';
ea.PathOnClient          = 'EA_Solar_Valley.pdf';
ea.VersionData           = Blob.valueOf('Placeholder: Environmental Assessment content');
ea.nepa_document_type__c = 'EA';
ea.nepa_status__c        = 'Draft';
ea.nepa_publish_date__c  = today.addDays(-45);
ea.nepa_public_access__c = true;

insert new List<ContentVersion>{ noi, deis, ea };

List<ContentVersion> withIds = [
    SELECT Id, ContentDocumentId
    FROM ContentVersion
    WHERE Id IN (:noi.Id, :deis.Id, :ea.Id)
];

insert new List<ContentDocumentLink>{
    new ContentDocumentLink(ContentDocumentId = withIds[0].ContentDocumentId,
        LinkedEntityId = eisProcess.Id, ShareType = 'V', Visibility = 'AllUsers'),
    new ContentDocumentLink(ContentDocumentId = withIds[1].ContentDocumentId,
        LinkedEntityId = eisProcess.Id, ShareType = 'V', Visibility = 'AllUsers'),
    new ContentDocumentLink(ContentDocumentId = withIds[2].ContentDocumentId,
        LinkedEntityId = eaProcess.Id, ShareType = 'V', Visibility = 'AllUsers')
};

// ── 5. Public Comments (CEQ Entity 4) ────────────────────────────────────────
insert new List<PublicComplaint>{
    new PublicComplaint(
        nepa_related_process__c   = eisProcess.Id,
        nepa_comment_body__c      =
            'The proposed pipeline corridor crosses cultural sites sacred to the Eastern Shoshone Tribe. '
            + 'Treaty rights under the 1868 Fort Bridger Treaty must be respected. '
            + 'We request government-to-government consultation before any further NEPA review proceeds.',
        nepa_commenter_name__c    = 'Eastern Shoshone Tribe Environmental Office',
        nepa_commenter_org__c     = 'Eastern Shoshone Tribe',
        nepa_date_submitted__c    = today.addDays(-15),
        nepa_submission_method__c = 'Written',
        nepa_public_access__c     = false
    ),
    new PublicComplaint(
        nepa_related_process__c   = eisProcess.Id,
        nepa_comment_body__c      =
            'The DEIS underestimates cumulative air quality impacts on the fence line community '
            + 'in Riverton, WY — a majority-minority, low-income environmental justice community '
            + 'already experiencing disproportionate impacts from existing energy infrastructure.',
        nepa_commenter_name__c    = 'Riverton EJ Coalition',
        nepa_commenter_org__c     = 'Riverton Environmental Justice Coalition',
        nepa_date_submitted__c    = today.addDays(-10),
        nepa_submission_method__c = 'Email',
        nepa_public_access__c     = false
    ),
    new PublicComplaint(
        nepa_related_process__c   = eaProcess.Id,
        nepa_comment_body__c      =
            'I support the Solar Valley project. The clean energy benefits and job creation '
            + 'for the region outweigh the temporary visual impact during construction.',
        nepa_commenter_name__c    = 'James Whitfield',
        nepa_commenter_org__c     = '',
        nepa_date_submitted__c    = today.addDays(-3),
        nepa_submission_method__c = 'Web Form',
        nepa_public_access__c     = true
    ),
    new PublicComplaint(
        nepa_related_process__c   = eaProcess.Id,
        nepa_comment_body__c      =
            'The EA fails to adequately analyze impacts to the Mojave Desert Tortoise, '
            + 'a threatened species under the Endangered Species Act. The Biological Assessment '
            + 'does not address construction-season restrictions per 40 CFR 1502.25.',
        nepa_commenter_name__c    = 'Desert Wildlife Legal Center',
        nepa_commenter_org__c     = 'Desert Wildlife Legal Center',
        nepa_date_submitted__c    = today.addDays(-2),
        nepa_submission_method__c = 'Written',
        nepa_public_access__c     = false
    )
};

// ── 6. Engagement Events (CEQ Entity 5) ──────────────────────────────────────
insert new List<nepa_engagement__c>{
    new nepa_engagement__c(
        nepa_process__c          = eisProcess.Id,
        nepa_engagement_type__c  = 'Public Hearing',
        nepa_location_format__c  = 'Hybrid',
        nepa_start_datetime__c   = DateTime.now().addDays(32),
        nepa_end_datetime__c     = DateTime.now().addDays(32).addHours(3),
        nepa_public_access__c    = true,
        nepa_registration_url__c = 'https://www.blm.gov/wind-river-eis-hearing'
    ),
    new nepa_engagement__c(
        nepa_process__c          = eaProcess.Id,
        nepa_engagement_type__c  = 'Public Meeting',
        nepa_location_format__c  = 'Virtual',
        nepa_start_datetime__c   = DateTime.now().addDays(7),
        nepa_end_datetime__c     = DateTime.now().addDays(7).addHours(2),
        nepa_public_access__c    = true,
        nepa_registration_url__c = 'https://www.energy.gov/solar-valley-ea-meeting'
    )
};

// ── 7. Timeline Events (CEQ Entity 6) ────────────────────────────────────────
insert new List<ApplicationTimeline>{
    new ApplicationTimeline(
        Name                    = 'Notice of Intent Published',
        nepa_related_process__c = eisProcess.Id,
        nepa_event_type__c      = 'NOI',
        nepa_status__c          = 'Completed',
        nepa_tier__c            = '1',
        nepa_source__c          = 'Federal Register',
        nepa_start_date__c      = today.addDays(-365),
        nepa_end_date__c        = today.addDays(-365),
        nepa_public_access__c   = true
    ),
    new ApplicationTimeline(
        Name                    = 'Scoping Period',
        nepa_related_process__c = eisProcess.Id,
        nepa_event_type__c      = 'Scoping',
        nepa_status__c          = 'Completed',
        nepa_tier__c            = '1',
        nepa_source__c          = 'Agency',
        nepa_start_date__c      = today.addDays(-335),
        nepa_end_date__c        = today.addDays(-305),
        nepa_public_access__c   = true
    ),
    new ApplicationTimeline(
        Name                    = 'Draft EIS Public Comment Period',
        nepa_related_process__c = eisProcess.Id,
        nepa_event_type__c      = 'Comment Period',
        nepa_status__c          = 'Planned',
        nepa_tier__c            = '1',
        nepa_source__c          = 'Agency',
        nepa_start_date__c      = today.addDays(30),
        nepa_end_date__c        = today.addDays(75),
        nepa_public_access__c   = true
    )
};

// ── 8. GIS Data Elements (CEQ Entity 7) ──────────────────────────────────────
insert new List<nepa_gis_data_element__c>{
    new nepa_gis_data_element__c(
        nepa_purpose__c             = 'Project Boundary',
        nepa_format__c              = 'GeoJSON',
        nepa_access_method__c       = 'URL',
        nepa_coordinate_system__c   = 'WGS84',
        nepa_access_information__c  = 'https://gis.blm.gov/arcgis/rest/services/lands/BLM_Natl_SMA_Grazing_Allotments/FeatureServer/0',
        nepa_bounding_box__c        = '-109.5,42.5,-107.8,43.8',
        nepa_database_reference__c  = true,
        nepa_data_source_agency__c  = 'Bureau of Land Management',
        nepa_data_source_system__c  = 'BLM GeoCommunicator',
        nepa_data_record_version__c = '3.2',
        nepa_retrieved_timestamp__c = DateTime.now()
    ),
    new nepa_gis_data_element__c(
        nepa_purpose__c             = 'Resource Layer',
        nepa_format__c              = 'GeoJSON',
        nepa_access_method__c       = 'API',
        nepa_coordinate_system__c   = 'WGS84',
        nepa_access_information__c  = 'https://services.arcgis.com/QVENGdaPbd4LUkLV/arcgis/rest/services/USFWS_Critical_Habitat/FeatureServer/0',
        nepa_bounding_box__c        = '-110.0,42.0,-107.0,44.5',
        nepa_database_reference__c  = true,
        nepa_data_source_agency__c  = 'Fish and Wildlife Service',
        nepa_data_source_system__c  = 'USFWS IPaC',
        nepa_data_record_version__c = '2024.1',
        nepa_retrieved_timestamp__c = DateTime.now()
    ),
    new nepa_gis_data_element__c(
        nepa_purpose__c             = 'Resource Layer',
        nepa_format__c              = 'GeoTIFF',
        nepa_access_method__c       = 'URL',
        nepa_coordinate_system__c   = 'WGS84',
        nepa_access_information__c  = 'https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer',
        nepa_bounding_box__c        = '-109.5,42.5,-107.8,43.8',
        nepa_database_reference__c  = true,
        nepa_data_source_agency__c  = 'FEMA',
        nepa_data_source_system__c  = 'FEMA NFHL',
        nepa_data_record_version__c = '2.3.3',
        nepa_retrieved_timestamp__c = DateTime.now()
    )
};

// ── 9. Process Team Members (CEQ Entity 8) ────────────────────────────────────
// Note: LicenseTypeId is required for IndividualApplication; reuse process Ids
// seeded above. nepa_process_team_member__c is MasterDetail to IndividualApplication.
insert new List<nepa_process_team_member__c>{
    new nepa_process_team_member__c(
        nepa_process__c              = eisProcess.Id,
        nepa_user__c                 = UserInfo.getUserId(),
        nepa_role_type__c            = 'Lead NEPA Coordinator',
        nepa_active__c               = true,
        nepa_start_date__c           = today.addDays(-365),
        nepa_data_source_agency__c   = 'Bureau of Land Management',
        nepa_data_source_system__c   = 'eNEPA',
        nepa_data_record_version__c  = '1.0'
    ),
    new nepa_process_team_member__c(
        nepa_process__c              = eisProcess.Id,
        nepa_user__c                 = UserInfo.getUserId(),
        nepa_role_type__c            = 'Tribal Liaison',
        nepa_active__c               = true,
        nepa_start_date__c           = today.addDays(-300),
        nepa_notes__c                = 'Primary contact for Eastern Shoshone Tribe government-to-government consultation per NHPA Section 106.',
        nepa_data_source_agency__c   = 'Bureau of Land Management',
        nepa_data_source_system__c   = 'eNEPA',
        nepa_data_record_version__c  = '1.0'
    ),
    new nepa_process_team_member__c(
        nepa_process__c              = eaProcess.Id,
        nepa_user__c                 = UserInfo.getUserId(),
        nepa_role_type__c            = 'Lead NEPA Coordinator',
        nepa_active__c               = true,
        nepa_start_date__c           = today.addDays(-90),
        nepa_data_source_agency__c   = 'Department of Energy',
        nepa_data_source_system__c   = 'eNEPA',
        nepa_data_record_version__c  = '1.0'
    ),
    new nepa_process_team_member__c(
        nepa_process__c              = eaProcess.Id,
        nepa_user__c                 = UserInfo.getUserId(),
        nepa_role_type__c            = 'GIS Specialist',
        nepa_active__c               = true,
        nepa_start_date__c           = today.addDays(-60),
        nepa_notes__c                = 'Responsible for Mojave Desert Tortoise habitat proximity analysis.',
        nepa_data_source_agency__c   = 'Department of Energy',
        nepa_data_source_system__c   = 'eNEPA',
        nepa_data_record_version__c  = '1.0'
    ),
    new nepa_process_team_member__c(
        nepa_process__c              = ceProcess.Id,
        nepa_user__c                 = UserInfo.getUserId(),
        nepa_role_type__c            = 'Preparer',
        nepa_active__c               = true,
        nepa_start_date__c           = today.addDays(-14),
        nepa_data_source_agency__c   = 'Bureau of Land Management',
        nepa_data_source_system__c   = 'eNEPA',
        nepa_data_record_version__c  = '1.0'
    )
};

// ── 10. Regulatory Citations (CEQ Entity 9 — PSS RegulatoryCode) ──────────────
RegulatoryCode ceq_nepa = new RegulatoryCode(
    RegulatoryAuthorityId = raCeq.Id,
    Name             = '42 U.S.C. 4332',
    Subject          = 'NEPA — Federal Agency Action Requirements',
    Description      = 'Requires all federal agencies to prepare detailed environmental impact statements for major federal actions significantly affecting the quality of the human environment.',
    EffectiveFrom    = DateTime.newInstance(1970, 1, 1, 0, 0, 0),
    nepa_compliance_requirements__c = 'Prepare EIS for major federal actions; consider alternatives; disclose environmental consequences.',
    nepa_text_content__c = 'Sec. 102(2)(C): include in every recommendation or report on proposals for legislation and other major Federal actions significantly affecting the quality of the human environment, a detailed statement by the responsible official on (i) the environmental impact of the proposed action...',
    nepa_data_source_agency__c  = 'CEQ',
    nepa_data_source_system__c  = 'U.S. Code',
    nepa_data_record_version__c = '2025.1',
    nepa_record_owner_agency__c = 'CEQ',
    nepa_retrieved_timestamp__c = DateTime.now()
);

RegulatoryCode ceq_ce = new RegulatoryCode(
    RegulatoryAuthorityId = raCeq.Id,
    Name             = '40 CFR 1501.4',
    Subject          = 'CE Determination — Categorical Exclusion',
    Description      = 'Establishes the process for determining whether a proposed federal action qualifies for a categorical exclusion from further NEPA review.',
    EffectiveFrom    = DateTime.newInstance(2022, 9, 14, 0, 0, 0),
    nepa_compliance_requirements__c = 'Determine extraordinary circumstances; consult agency CX list; document determination in administrative record.',
    nepa_data_source_agency__c  = 'CEQ',
    nepa_data_source_system__c  = 'eCFR',
    nepa_data_record_version__c = '2022.1',
    nepa_record_owner_agency__c = 'CEQ',
    nepa_retrieved_timestamp__c = DateTime.now()
);

RegulatoryCode ceq_eis = new RegulatoryCode(
    RegulatoryAuthorityId = raCeq.Id,
    Name             = '40 CFR 1502.1',
    Subject          = 'EIS Purpose and Function',
    Description      = 'Defines the purpose of an Environmental Impact Statement: to serve as an action-forcing device ensuring agencies consider environmental effects and inform decision-makers and the public.',
    EffectiveFrom    = DateTime.newInstance(2022, 9, 14, 0, 0, 0),
    nepa_compliance_requirements__c = 'EIS must be analytic rather than encyclopedic; rigorously explore alternatives; circulate for public comment.',
    nepa_data_source_agency__c  = 'CEQ',
    nepa_data_source_system__c  = 'eCFR',
    nepa_data_record_version__c = '2022.1',
    nepa_record_owner_agency__c = 'CEQ',
    nepa_retrieved_timestamp__c = DateTime.now()
);

RegulatoryCode esa_7 = new RegulatoryCode(
    RegulatoryAuthorityId = raUsfws.Id,
    Name             = '16 U.S.C. 1536',
    Subject          = 'ESA Section 7 — Interagency Cooperation',
    Description      = 'Requires federal agencies to consult with USFWS or NMFS to ensure actions are not likely to jeopardize listed species or destroy critical habitat.',
    EffectiveFrom    = DateTime.newInstance(1973, 12, 28, 0, 0, 0),
    nepa_compliance_requirements__c = 'Initiate formal or informal consultation with USFWS/NMFS when action may affect listed species; obtain Biological Opinion if formal consultation required.',
    nepa_data_source_agency__c  = 'USFWS',
    nepa_data_source_system__c  = 'U.S. Code',
    nepa_data_record_version__c = '2023.1',
    nepa_record_owner_agency__c = 'USFWS',
    nepa_retrieved_timestamp__c = DateTime.now()
);

insert new List<RegulatoryCode>{ ceq_nepa, ceq_ce, ceq_eis, esa_7 };

// RegulatoryCode is standalone Entity 9 — no FK wiring to IndividualApplication needed.

System.debug('=== Seed complete ===');
System.debug('EIS: ' + eisProcess.Id + ' | EA: ' + eaProcess.Id + ' | CE: ' + ceProcess.Id);
System.debug('GIS layers: 3 | Team members: 5 | Regulatory citations: 4');
