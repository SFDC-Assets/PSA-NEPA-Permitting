// seed-sample-data.apex
// Usage: sf apex run --file scripts/seed-sample-data.apex --target-org <alias>
//
// Creates: 3 projects (EIS, EA, CE), 3 processes, 3 documents, 4 public comments,
//          2 engagement events, and 3 timeline events.
// Safe to run multiple times — project IDs are unique so duplicates will cause a
// DUPLICATE_VALUE error on nepa_project_id__c if run twice. Clear data first if needed.

// ── 1. Agency accounts ────────────────────────────────────────────────────────
Account blm = new Account(Name = 'Bureau of Land Management');
Account doe = new Account(Name = 'Department of Energy');
Account fws = new Account(Name = 'Fish and Wildlife Service');
insert new List<Account>{ blm, doe, fws };

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

IndividualApplication eisProcess = new IndividualApplication();
eisProcess.Category                               = 'Permit';
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

System.debug('=== Seed complete ===');
System.debug('EIS: ' + eisProcess.Id + ' | EA: ' + eaProcess.Id + ' | CE: ' + ceProcess.Id);
