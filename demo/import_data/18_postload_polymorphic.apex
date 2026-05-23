/**
 * Post-load script: create records that require runtime org IDs.
 *
 * Run AFTER all CSVs are loaded (files 01–19 via load-demo-data.sh).
 * Handles objects that cannot be loaded via CSV due to:
 *   - LicenseTypeId (IndividualApplication) — org-specific RegulatoryAuthorizationType ID
 *   - RelatedRecordId (ServiceResource) — requires User ID, not Contact
 *   - STM (ServiceTerritoryMember) — depends on ServiceResources created here
 *   - ContentVersion — requires VersionData Blob; cannot be loaded via Bulk API v2 CSV
 *   - Visit (field surveys) — created here with ContextId = IndividualApplication
 *
 * Run via: sf apex run --file demo/import_data/18_postload_polymorphic.apex --target-org <alias>
 */

// ── 0. RegulatoryAuthorizationType for IndividualApplication ─────────────────

Id licenseTypeId;
List<RegulatoryAuthorizationType> ratList = [
    SELECT Id FROM RegulatoryAuthorizationType
    WHERE Name = 'NEPA Environmental Review'
    LIMIT 1
];
if (ratList.isEmpty()) {
    RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
        Name                    = 'NEPA Environmental Review',
        RegulatoryAuthCategory  = 'Permit'
    );
    insert rat;
    licenseTypeId = rat.Id;
} else {
    licenseTypeId = ratList[0].Id;
}
System.debug('LicenseTypeId: ' + licenseTypeId);

// ── 1. IndividualApplication upsert ──────────────────────────────────────────

Id programId;
for (Program p : [
    SELECT Id, nepa_project_id__c
    FROM Program
    WHERE nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'
    LIMIT 1
]) {
    programId = p.Id;
}

Id applicantContactId;
for (Contact c : [SELECT Id FROM Contact WHERE External_ID__c = 'DEMO_CON_008' LIMIT 1]) {
    applicantContactId = c.Id;
}

Id appId;
List<IndividualApplication> existingApps = [
    SELECT Id FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709'
    LIMIT 1
];

IndividualApplication app = existingApps.isEmpty()
    ? new IndividualApplication()
    : existingApps[0];

app.LicenseTypeId                           = licenseTypeId;
app.Category                                = 'License';
app.Status                                  = 'Approved';
app.nepa_federal_unique_id__c               = 'IDI-38709';
app.nepa_related_project__c                 = programId;
app.nepa_applicant_contact__c               = applicantContactId;
app.nepa_start_date__c                      = Date.newInstance(2017, 10, 18);
app.nepa_completion_date__c                 = Date.newInstance(2019, 11, 27);
app.nepa_review_type__c                     = 'EA';
app.nepa_review_timeline_type__c            = 'Standard';
app.nepa_action_type__c                     = 'Modify Existing';
app.nepa_agency_id__c                       = 'BLM-ID-B030';
app.nepa_process_status__c                  = 'completed';
app.nepa_process_stage__c                   = 'Decision';
app.nepa_process_code__c                    = 'IDI-38709';
app.nepa_decision_document_type__c          = 'FONSI';
app.nepa_submission_complete__c             = true;
app.nepa_description__c                     = 'Sam Uhler and David Smith propose a 5-10 year placer gold mining operation on 15 acres of BLM-administered land adjacent to Jordan Creek in Owyhee County Idaho. The plan includes a seasonal mining window (March 1 - November 30) use of the existing 1.7-mile two-track access road a 50-foot Jordan Creek buffer silt fencing and full reclamation bonded to BLM botanist approval. Water withdrawal from Jordan Creek requires separate IDWR permit. Suction dredge requires EPA NPDES General Permit IDG370000.';
app.nepa_purpose_need__c                    = 'Authorize placer gold mining on 15 acres of BLM-administered land in Owyhee County Idaho to provide economic benefit to the proponent consistent with FLPMA multiple-use principles.';
app.nepa_disturbance_acres__c               = 15;
app.nepa_extraordinary_circumstances__c     = 'true';
app.nepa_esa_consultation_status__c         = 'Biological Opinion Issued';
app.nepa_co_permits_required__c             = 'CWA Section 404;NHPA Section 106';
app.nepa_regulatory_citation__c             = '43 CFR Part 46; FLPMA Section 302';
app.nepa_public_comment_period_start__c     = Date.newInstance(2018, 8, 15);
app.nepa_public_comment_period_end_date__c  = Date.newInstance(2018, 9, 15);
app.nepa_target_completion_date__c          = Date.newInstance(2019, 12, 31);
app.nepa_record_owner_agency__c             = 'BLM';
app.nepa_data_source_agency__c              = 'BLM';
app.nepa_data_source_system__c              = 'ePlanning';
app.nepa_data_record_version__c             = '1';
app.nepa_risk_score__c                      = 87.40;
app.nepa_risk_tier__c                       = 'High';
app.nepa_plaintiff_risk_flag__c             = true;
app.nepa_defensibility_score__c             = 91;
app.nepa_total_pages__c                     = 47;
app.nepa_waiver_invoked__c                  = false;
app.nepa_connected_actions_identified__c    = true;
app.nepa_supplementation_review_complete__c = false;
app.nepa_record_completeness__c             = 100;
app.nepa_phase2_applicable__c               = false;
app.nepa_climate_assessment_required__c     = false;
app.nepa_climate_assessment_complete__c     = true;
app.nepa_process_outcome__c                 = 'FONSI issued. No significant impact found. CWA 404 and IDWR appropriation permits required prior to ground disturbance.';

if (existingApps.isEmpty()) {
    insert app;
    System.debug('IndividualApplication inserted: ' + app.Id);
} else {
    update app;
    System.debug('IndividualApplication updated: ' + app.Id);
}
appId = app.Id;

// ── 1b. Location (required PlaceId for Visit records) ────────────────────────
// Visit.PlaceId (polymorphic to Location/Address/ContactPointAddress) is required.
// Create or reuse a Location record for the BLM Owyhee Field Office.
Id demoLocationId;
for (Schema.Location loc : [
    SELECT Id FROM Location WHERE Name = 'BLM Owyhee Field Office' LIMIT 1
]) {
    demoLocationId = loc.Id;
}
if (demoLocationId == null) {
    Schema.Location loc = new Schema.Location(
        Name              = 'BLM Owyhee Field Office',
        LocationType      = 'Business Site',
        IsInventoryLocation = false
    );
    insert loc;
    demoLocationId = loc.Id;
    System.debug('Location created: ' + demoLocationId);
} else {
    System.debug('Location (existing): ' + demoLocationId);
}

// ── 2. ServiceResource (linked to running user for demo) ─────────────────────
// Salesforce enforces exactly 1 Technician ServiceResource per User.
// All 7 DEMO_SR_* slots are mapped to a single SR for the running user.
// STMs in step 3 all reference this SR Id.

Id runningUserId = UserInfo.getUserId();
Id demoSRId;

// Find or create the one demo Technician SR for this user
List<ServiceResource> existingSR = [
    SELECT Id, External_ID__c, Name
    FROM ServiceResource
    WHERE External_ID__c = 'DEMO_SR_001'
    LIMIT 1
];
if (!existingSR.isEmpty()) {
    demoSRId = existingSR[0].Id;
    System.debug('ServiceResource (existing): ' + demoSRId);
} else {
    // Check if a Technician SR already exists for this user under a different External_ID__c
    List<ServiceResource> techSR = [
        SELECT Id FROM ServiceResource
        WHERE RelatedRecordId = :runningUserId AND ResourceType = 'T'
        LIMIT 1
    ];
    if (!techSR.isEmpty()) {
        ServiceResource sr = techSR[0];
        sr.External_ID__c = 'DEMO_SR_001';
        sr.Name           = 'NEPA Review Team (Demo)';
        sr.IsActive       = true;
        update sr;
        demoSRId = sr.Id;
        System.debug('ServiceResource (tagged existing): ' + demoSRId);
    } else {
        ServiceResource sr = new ServiceResource(
            External_ID__c  = 'DEMO_SR_001',
            Name            = 'NEPA Review Team (Demo)',
            ResourceType    = 'T',
            IsActive        = true,
            RelatedRecordId = runningUserId
        );
        insert sr;
        demoSRId = sr.Id;
        System.debug('ServiceResource (inserted): ' + demoSRId);
    }
}

// All 7 DEMO_SR_* slots resolve to the same SR for demo purposes
Map<String, Id> srIdByExt = new Map<String, Id>{
    'DEMO_SR_001' => demoSRId,
    'DEMO_SR_002' => demoSRId,
    'DEMO_SR_003' => demoSRId,
    'DEMO_SR_004' => demoSRId,
    'DEMO_SR_005' => demoSRId,
    'DEMO_SR_006' => demoSRId,
    'DEMO_SR_007' => demoSRId
};

// ── 3. ServiceTerritoryMember (one entry linking the demo SR to the territory) ─
// All 7 specialist slots map to the same SR (demoSRId); one STM is sufficient.

Id terrId;
for (ServiceTerritory st : [
    SELECT Id FROM ServiceTerritory WHERE External_ID__c = 'DEMO_TERR_001' LIMIT 1
]) {
    terrId = st.Id;
}

if (terrId != null) {
    List<ServiceTerritoryMember> existingSTM = [
        SELECT Id FROM ServiceTerritoryMember
        WHERE External_ID__c = 'DEMO_STM_001'
        LIMIT 1
    ];
    if (existingSTM.isEmpty()) {
        ServiceTerritoryMember stm = new ServiceTerritoryMember(
            External_ID__c     = 'DEMO_STM_001',
            ServiceTerritoryId = terrId,
            ServiceResourceId  = demoSRId,
            TerritoryType      = 'P',
            EffectiveStartDate = Date.newInstance(2019, 1, 1)
        );
        insert stm;
        System.debug('ServiceTerritoryMember inserted: ' + stm.Id);
    } else {
        System.debug('ServiceTerritoryMember already exists: ' + existingSTM[0].Id);
    }
}

// ── 4. Field Survey Visits (one per discipline/survey — replaces WorkOrder/SA/AR) ────
// Each specialist discipline gets a completed Visit representing the field work
// performed during the Carrie Placer Mine EA. Visits link to IndividualApplication
// via ContextId (polymorphic) and nepa_process__c (direct lookup).

List<Map<String,Object>> visitDefs = new List<Map<String,Object>>{
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_001','discipline'=>'Wildlife Biologist (Sage-Grouse)',
        'priority'=>'High','start'=>DateTime.newInstance(2019,4,15,8,0,0),
        'end'=>DateTime.newInstance(2019,4,18,17,0,0),
        'instructions'=>'Sage-Grouse Lek and PHMA Survey — Carrie Placer Mine',
        'remarks'=>'Sage-grouse lek and PHMA survey T. 6 S. R. 5 W. Sec. 28. Completed Apr 15-18 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_002','discipline'=>'Hydrologist',
        'priority'=>'High','start'=>DateTime.newInstance(2019,4,22,8,0,0),
        'end'=>DateTime.newInstance(2019,4,25,17,0,0),
        'instructions'=>'Hydrology and Water Quality Assessment — Carrie Placer Mine',
        'remarks'=>'Hydrology and water quality assessment. Jordan Creek riparian corridor and water withdrawal points. Completed Apr 22-25 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_003','discipline'=>'Geologist',
        'priority'=>'High','start'=>DateTime.newInstance(2019,5,6,8,0,0),
        'end'=>DateTime.newInstance(2019,5,12,17,0,0),
        'instructions'=>'Geology, Soils and Access Road Assessment — Carrie Placer Mine',
        'remarks'=>'Geology soils and access road assessment. 1.7-mile access road erosion and reclamation bond review. Completed May 6-12 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_004','discipline'=>'Wildlife Biologist (Avian/Big Game)',
        'priority'=>'High','start'=>DateTime.newInstance(2019,4,10,6,0,0),
        'end'=>DateTime.newInstance(2019,4,12,12,0,0),
        'instructions'=>'Migratory Bird Nesting Survey — Carrie Placer Mine',
        'remarks'=>'Migratory bird nesting survey spring window. Pre-nesting season survey Apr 10-12 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_005','discipline'=>'Fisheries and Wildlife Biologist (Aquatic)',
        'priority'=>'High','start'=>DateTime.newInstance(2019,5,20,8,0,0),
        'end'=>DateTime.newInstance(2019,5,28,17,0,0),
        'instructions'=>'Columbia Spotted Frog and Riparian Survey — Carrie Placer Mine',
        'remarks'=>'Columbia spotted frog and riparian corridor survey. Active amphibian season May 20-28 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_006','discipline'=>'Botanist',
        'priority'=>'High','start'=>DateTime.newInstance(2019,6,17,8,0,0),
        'end'=>DateTime.newInstance(2019,6,20,17,0,0),
        'instructions'=>'Botanical Survey Site Visit 1 — Carrie Placer Mine',
        'remarks'=>'Special status plant survey site visit 1 of 2. Peak identification season Jun 17-20 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_007','discipline'=>'Botanist',
        'priority'=>'High','start'=>DateTime.newInstance(2019,8,25,8,0,0),
        'end'=>DateTime.newInstance(2019,8,28,17,0,0),
        'instructions'=>'Botanical Survey Site Visit 2 — Carrie Placer Mine',
        'remarks'=>'Special status plant survey site visit 2 of 2. Reclamation seed mix approval. Aug 25-28 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_008','discipline'=>'Wildlife Biologist (Avian/Big Game)',
        'priority'=>'High','start'=>DateTime.newInstance(2019,8,19,8,0,0),
        'end'=>DateTime.newInstance(2019,8,22,17,0,0),
        'instructions'=>'Big Game Winter Range Assessment — Carrie Placer Mine',
        'remarks'=>'Mule deer crucial winter range mapping. Shoulder season assessment Aug 19-22 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_009','discipline'=>'NEPA Specialist',
        'priority'=>'High','start'=>DateTime.newInstance(2019,7,29,8,0,0),
        'end'=>DateTime.newInstance(2019,8,15,17,0,0),
        'instructions'=>'ICL Comment Response — Carrie Placer Mine',
        'remarks'=>'Idaho Conservation League substantive comment response. Dust mitigation analysis added to EA. Jul 29 - Aug 15 2019.'},
    new Map<String,Object>{
        'ext'=>'DEMO_FSV_010','discipline'=>'NEPA Specialist',
        'priority'=>'High','start'=>DateTime.newInstance(2019,7,29,8,0,0),
        'end'=>DateTime.newInstance(2019,8,15,17,0,0),
        'instructions'=>'OSC Comment Response — Carrie Placer Mine',
        'remarks'=>'Office of Species Conservation ARMPA justifiable departure memo. Jul 29 - Aug 15 2019.'}
};

Set<String> existingVisitExts = new Set<String>();
for (Visit v : [
    SELECT External_ID__c FROM Visit
    WHERE External_ID__c LIKE 'DEMO_FSV_%'
]) {
    existingVisitExts.add(v.External_ID__c);
}

List<Visit> fieldSurveyVisits = new List<Visit>();
for (Map<String,Object> def : visitDefs) {
    String ext = (String) def.get('ext');
    if (!existingVisitExts.contains(ext)) {
        Visit v = new Visit();
        v.External_ID__c          = ext;
        v.PlaceId                 = demoLocationId;
        v.ContextId               = appId;
        v.nepa_process__c         = appId;
        v.Status                  = 'Completed';
        v.VisitPriority           = (String) def.get('priority');
        v.PlannedVisitStartTime   = (DateTime) def.get('start');
        v.PlannedVisitEndTime     = (DateTime) def.get('end');
        v.ActualVisitStartTime    = (DateTime) def.get('start');
        v.ActualVisitEndTime      = (DateTime) def.get('end');
        v.InstructionDescription  = (String) def.get('instructions');
        v.StatusRemarks           = (String) def.get('remarks');
        v.nepa_discipline__c      = (String) def.get('discipline');
        v.nepa_auto_generated__c  = false;
        v.nepa_hard_gate__c       = false;
        fieldSurveyVisits.add(v);
    }
}
if (!fieldSurveyVisits.isEmpty()) {
    insert fieldSurveyVisits;
    System.debug('Field survey Visits inserted: ' + fieldSurveyVisits.size());
} else {
    System.debug('Field survey Visits already exist — skipped.');
}

// ── 5. ContentVersion — create placeholders then wire nepa_process__c ─────────

// Minimal 1-byte placeholder blob (a space character) used as VersionData so
// Salesforce accepts the insert.  Real documents would replace these via Files.
Blob placeholder = Blob.valueOf(' ');


List<Map<String,Object>> cvDefs = new List<Map<String,Object>>{
    new Map<String,Object>{
        'title'    => 'Carrie Placer Mine Plan of Operations - Environmental Assessment',
        'path'     => 'Carrie_Placer_Mine_EA.pdf',
        'docType'  => 'Environmental Assessment',
        'main'     => true,
        'status'   => 'Approved',
        'pubDate'  => Date.newInstance(2019, 7, 1),
        'prepBy'   => 'BLM Owyhee Field Office - Kara Kirkpatrick-Kreitinger',
        'pubAccess'=> true,
        'arIncl'   => true,
        'category' => 'Supporting Analysis',
        'summary'  => 'Environmental Assessment for DOI-BLM-ID-B030-2019-0014-EA. Analyzes impacts on Jordan Creek water quality, redband trout habitat, sage-grouse PHMA, Columbia spotted frog riparian zone, and mule deer crucial winter range.'
    },
    new Map<String,Object>{
        'title'    => 'Finding of No Significant Impact - Carrie Placer Mine',
        'path'     => 'Carrie_Placer_Mine_FONSI.pdf',
        'docType'  => 'FONSI',
        'main'     => false,
        'status'   => 'Approved',
        'pubDate'  => Date.newInstance(2019, 11, 20),
        'prepBy'   => 'BLM Owyhee Field Office - Forrest Griggs and Colleen Trese',
        'pubAccess'=> true,
        'arIncl'   => true,
        'category' => 'Decision Record',
        'summary'  => 'FONSI confirming no significant impact under Alternative A with required design features: 50-foot Jordan Creek buffer, silt fencing, steep-shoreline pond design, seasonal mining window March 1 - November 30, and full reclamation bond.'
    },
    new Map<String,Object>{
        'title'    => 'Decision Record - Carrie Placer Mine Plan of Operations',
        'path'     => 'Carrie_Placer_Mine_Decision_Record.pdf',
        'docType'  => 'Other',
        'main'     => false,
        'status'   => 'Approved',
        'pubDate'  => Date.newInstance(2019, 11, 27),
        'prepBy'   => 'BLM Owyhee Field Office - Field Manager',
        'pubAccess'=> true,
        'arIncl'   => true,
        'category' => 'Decision Record',
        'summary'  => 'Decision Record approving Alternative A for the Carrie Placer Mine Plan of Operations with full suite of required design features. Signed by BLM Owyhee Field Manager November 27 2019.'
    },
    new Map<String,Object>{
        'title'    => 'Affected Environment and Environmental Consequences Summary - Carrie Placer Mine',
        'path'     => 'Carrie_Placer_Mine_Affected_Resources.pdf',
        'docType'  => 'Alternatives Analysis',
        'main'     => false,
        'status'   => 'Approved',
        'pubDate'  => Date.newInstance(2019, 11, 20),
        'prepBy'   => 'BLM Owyhee Field Office Interdisciplinary Team',
        'pubAccess'=> true,
        'arIncl'   => true,
        'category' => 'Supporting Analysis',
        'summary'  => 'Summary of affected resources documenting baseline conditions across all seven resource disciplines: hydrology/water quality, wildlife, geology/soils, and botanical/cultural resources.'
    },
    new Map<String,Object>{
        'title'    => 'Section 106 Tribal Consultation Certification - Shoshone-Paiute Tribes',
        'path'     => 'Carrie_Placer_Mine_Tribal_Consultation.pdf',
        'docType'  => 'Other',
        'main'     => false,
        'status'   => 'Approved',
        'pubDate'  => Date.newInstance(2019, 3, 16),
        'prepBy'   => 'Kara Kirkpatrick-Kreitinger - BLM Owyhee Field Office',
        'pubAccess'=> true,
        'arIncl'   => true,
        'category' => 'Agency Communication',
        'summary'  => 'Certification of completed government-to-government Section 106 NHPA consultation with Shoshone-Paiute Tribes. No historic properties affected determination.'
    },
    // Required by FONSI Issued gate: EA_Comment_Response CMT expects a Comment Response doc
    new Map<String,Object>{
        'title'    => 'Public Comment Response Summary - Carrie Placer Mine EA',
        'path'     => 'Carrie_Placer_Mine_Comment_Response.pdf',
        'docType'  => 'Comment Response',
        'main'     => false,
        'status'   => 'Approved',
        'pubDate'  => Date.newInstance(2019, 8, 15),
        'prepBy'   => 'BLM Owyhee Field Office - Kara Kirkpatrick-Kreitinger',
        'pubAccess'=> true,
        'arIncl'   => true,
        'category' => 'Supporting Analysis',
        'summary'  => 'Comment response summary addressing ICL air quality / mercury particulate comments and OSC sage-grouse lek buffer departure justification comments on the preliminary EA and FONSI.'
    }
};

// Check which titles already exist (idempotent re-run)
Set<String> existingTitles = new Set<String>();
for (ContentVersion existing : [
    SELECT Title FROM ContentVersion
    WHERE Title IN (
        'Carrie Placer Mine Plan of Operations - Environmental Assessment',
        'Finding of No Significant Impact - Carrie Placer Mine',
        'Decision Record - Carrie Placer Mine Plan of Operations',
        'Affected Environment and Environmental Consequences Summary - Carrie Placer Mine',
        'Section 106 Tribal Consultation Certification - Shoshone-Paiute Tribes',
        'Public Comment Response Summary - Carrie Placer Mine EA'
    )
    AND IsLatest = true
]) {
    existingTitles.add(existing.Title);
}

List<ContentVersion> cvsToInsert = new List<ContentVersion>();
for (Map<String,Object> def : cvDefs) {
    String title = (String) def.get('title');
    if (!existingTitles.contains(title)) {
        ContentVersion cv = new ContentVersion();
        cv.Title                    = title;
        cv.PathOnClient             = (String)  def.get('path');
        cv.VersionData              = placeholder;
        cv.nepa_document_type__c    = (String)  def.get('docType');
        cv.nepa_main_document__c    = (Boolean) def.get('main');
        cv.nepa_status__c           = (String)  def.get('status');
        cv.nepa_publish_date__c     = (Date)    def.get('pubDate');
        cv.nepa_prepared_by__c      = (String)  def.get('prepBy');
        cv.nepa_public_access__c    = (Boolean) def.get('pubAccess');
        cv.nepa_ar_included__c      = (Boolean) def.get('arIncl');
        cv.nepa_record_category__c  = (String)  def.get('category');
        cv.nepa_document_summary__c = (String)  def.get('summary');
        cv.nepa_process__c          = appId;
        cvsToInsert.add(cv);
    }
}
if (!cvsToInsert.isEmpty()) {
    insert cvsToInsert;
    System.debug('ContentVersion inserted: ' + cvsToInsert.size());
}

// Wire nepa_process__c on any pre-existing records that lack it
List<ContentVersion> cvs = [
    SELECT Id, Title, nepa_process__c
    FROM ContentVersion
    WHERE Title IN (
        'Carrie Placer Mine Plan of Operations - Environmental Assessment',
        'Finding of No Significant Impact - Carrie Placer Mine',
        'Decision Record - Carrie Placer Mine Plan of Operations',
        'Affected Environment and Environmental Consequences Summary - Carrie Placer Mine',
        'Section 106 Tribal Consultation Certification - Shoshone-Paiute Tribes',
        'Public Comment Response Summary - Carrie Placer Mine EA'
    )
    AND IsLatest = true
    AND nepa_process__c = null
];
for (ContentVersion cv : cvs) {
    cv.nepa_process__c = appId;
}
if (!cvs.isEmpty()) {
    update cvs;
    System.debug('ContentVersion.nepa_process__c back-wired: ' + cvs.size());
}

// ── 6. Wire engagement and timeline records to IndividualApplication ──────────
// These were inserted as plain records; now link nepa_process__c / nepa_related_process__c

// nepa_engagement__c.Name is auto-generated — match by null process instead
List<nepa_engagement__c> engagements = [
    SELECT Id, nepa_process__c
    FROM nepa_engagement__c
    WHERE nepa_process__c = null
    LIMIT 50
];
for (nepa_engagement__c e : engagements) {
    e.nepa_process__c = appId;
}
if (!engagements.isEmpty()) {
    update engagements;
    System.debug('nepa_engagement__c.nepa_process__c updated: ' + engagements.size());
}

List<ApplicationTimeline> timelines = [
    SELECT Id, Name, nepa_related_process__c
    FROM ApplicationTimeline
    WHERE Name IN (
        'Application Received',
        'Pre-Application ID Team Consultation Completed',
        'Section 106 Tribal Consultation Initiated',
        'Sage-Grouse Lek Survey Window Opens',
        'Migratory Bird Survey Spring Window Deadline',
        'Sage-Grouse Lek Survey Completed',
        'Section 106 Tribal Consultation Certified Complete',
        'Hydrology and Water Quality Assessment Completed',
        'IDWR Water Permit Application Initiated',
        'Geology Soils and Access Road Assessment Completed',
        'EPA NPDES NOI IDG370000 Filed',
        'Columbia Spotted Frog Riparian Survey Completed',
        'Botanical Survey First Site Visit Completed',
        'EPA NPDES Agency Objection Window Cleared',
        'Big Game Winter Range Assessment Completed',
        'Botanical Survey Second Site Visit Completed',
        'Preliminary EA Published for Public Comment',
        'Public Comment Period Closed',
        'ICL Comment Response Incorporated into EA',
        'OSC Comment Response Incorporated into EA',
        'IDWR Water Permit Received',
        'EPA NPDES Authorization Received',
        'Required Document Registry All Five Documents Verified',
        'FONSI Signed',
        'Decision Record Issued'
    )
];
for (ApplicationTimeline tl : timelines) {
    tl.nepa_related_process__c = appId;
}
if (!timelines.isEmpty()) {
    List<Database.SaveResult> tlResults = Database.update(timelines, false);
    Integer tlOk = 0;
    for (Database.SaveResult sr : tlResults) { if (sr.isSuccess()) tlOk++; }
    System.debug('ApplicationTimeline.nepa_related_process__c updated: ' + tlOk + '/' + timelines.size());
    for (Integer i = 0; i < tlResults.size(); i++) {
        if (!tlResults[i].isSuccess()) {
            System.debug('Timeline skip (' + timelines[i].Name + '): ' + tlResults[i].getErrors()[0].getMessage().left(120));
        }
    }
}

List<PublicComplaint> complaints = [
    SELECT Id, nepa_related_process__c
    FROM PublicComplaint
    WHERE Subject IN (
        'ICL Comment - Air Quality Mercury and Dust Particulate',
        'OSC Comment - Sage-Grouse Lek Buffer Departure Justification'
    )
];
for (PublicComplaint pc : complaints) {
    pc.nepa_related_process__c = appId;
}
if (!complaints.isEmpty()) {
    update complaints;
    System.debug('PublicComplaint.nepa_related_process__c updated: ' + complaints.size());
}

// ── 7. nepa_litigation__c → Program ──────────────────────────────────────────

List<nepa_litigation__c> litCases = [
    SELECT Id, nepa_related_project__c
    FROM nepa_litigation__c
    WHERE nepa_citation__c IN (
        'Western Watersheds Project v. Bernhardt 958 F.3d 1124 (9th Cir. 2020)',
        'Idaho Conservation League v. U.S. Forest Service 843 F.3d 1232 (9th Cir. 2016)'
    )
];
for (nepa_litigation__c lit : litCases) {
    lit.nepa_related_project__c = programId;
}
if (!litCases.isEmpty()) {
    update litCases;
    System.debug('nepa_litigation__c.nepa_related_project__c updated: ' + litCases.size());
}

System.debug('Post-load complete.');
