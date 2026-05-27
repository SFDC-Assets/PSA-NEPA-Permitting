// create-test-data.apex
// Usage: sf apex run --file scripts/create-test-data.apex --target-org <alias>
//
// Creates the three test projects and processes used by docs/TESTING-GUIDE.md:
//   - TEST-EIS  BLM / 10th Circuit / Energy / ESA+CWA   (Very High risk scenario)
//   - TEST-EA   FERC / DC Circuit                        (Moderate risk scenario)
//   - TEST-CE   BLM / 9th Circuit                        (CE scenario)
//
// Safe to re-run: Programs are upserted by nepa_project_id__c; IndividualApplications
// are only created if one does not already exist for the linked project.
//
// After running, record the IDs printed below — they are referenced throughout the
// testing guide (docs/TESTING-GUIDE.md).

// ── 1. Agency accounts ────────────────────────────────────────────────────────

List<Account> existingAgencies = [
    SELECT Id, Name FROM Account
    WHERE Name IN ('Bureau of Land Management', 'Federal Energy Regulatory Commission')
];
Map<String, Id> agencyIds = new Map<String, Id>();
for (Account a : existingAgencies) agencyIds.put(a.Name, a.Id);

List<Account> toInsertAgencies = new List<Account>();
if (!agencyIds.containsKey('Bureau of Land Management')) {
    toInsertAgencies.add(new Account(Name = 'Bureau of Land Management'));
}
if (!agencyIds.containsKey('Federal Energy Regulatory Commission')) {
    toInsertAgencies.add(new Account(Name = 'Federal Energy Regulatory Commission'));
}
if (!toInsertAgencies.isEmpty()) {
    insert toInsertAgencies;
    for (Account a : toInsertAgencies) agencyIds.put(a.Name, a.Id);
}

Id blmId  = agencyIds.get('Bureau of Land Management');
Id fercId = agencyIds.get('Federal Energy Regulatory Commission');

// ── 2. Programs (upsert by nepa_project_id__c) ───────────────────────────────

Program eisProject = new Program();
eisProject.Name                        = 'TEST-EIS BLM 10th Circuit';
eisProject.nepa_project_id__c          = 'TEST-BLM-EIS-001';
eisProject.nepa_project_title__c       = 'TEST-EIS BLM 10th Circuit';
eisProject.nepa_lead_agency__c         = blmId;
eisProject.nepa_record_owner_agency__c = 'BLM';
eisProject.nepa_circuit__c             = '10th';
eisProject.nepa_project_sector__c      = 'Energy';
eisProject.nepa_primary_sector__c      = 'Energy Production and Management';
eisProject.nepa_project_type__c        = 'EIS';
eisProject.nepa_current_status__c      = 'in progress';
eisProject.nepa_adjacent_statutes__c   = 'ESA;CWA';

Program eaProject = new Program();
eaProject.Name                        = 'TEST-EA FERC DC Circuit';
eaProject.nepa_project_id__c          = 'TEST-FERC-EA-001';
eaProject.nepa_project_title__c       = 'TEST-EA FERC DC Circuit';
eaProject.nepa_lead_agency__c         = fercId;
eaProject.nepa_record_owner_agency__c = 'FERC';
eaProject.nepa_circuit__c             = 'DC';
eaProject.nepa_project_type__c        = 'EA';
eaProject.nepa_current_status__c      = 'in progress';

Program ceProject = new Program();
ceProject.Name                        = 'TEST-CE BLM 9th Circuit';
ceProject.nepa_project_id__c          = 'TEST-BLM-CE-001';
ceProject.nepa_project_title__c       = 'TEST-CE BLM 9th Circuit';
ceProject.nepa_lead_agency__c         = blmId;
ceProject.nepa_record_owner_agency__c = 'BLM';
ceProject.nepa_circuit__c             = '9th';
ceProject.nepa_project_type__c        = 'CE';
ceProject.nepa_current_status__c      = 'in progress';

List<Program> programs = new List<Program>{ eisProject, eaProject, ceProject };
upsert programs nepa_project_id__c;

// Reload to get Ids after upsert
Map<String, Id> programIds = new Map<String, Id>();
for (Program p : [SELECT Id, nepa_project_id__c FROM Program
                   WHERE nepa_project_id__c IN ('TEST-BLM-EIS-001','TEST-FERC-EA-001','TEST-BLM-CE-001')]) {
    programIds.put(p.nepa_project_id__c, p.Id);
}

// ── 3. RegulatoryAuthorizationType (required by IndividualApplication) ────────

Id licenseTypeId;
List<RegulatoryAuthorizationType> rat = [
    SELECT Id FROM RegulatoryAuthorizationType
    WHERE Name = 'NEPA Environmental Review' LIMIT 1
];
if (!rat.isEmpty()) {
    licenseTypeId = rat[0].Id;
} else {
    RegulatoryAuthorizationType newRat = new RegulatoryAuthorizationType(
        Name = 'NEPA Environmental Review',
        RegulatoryAuthCategory = 'Permit'
    );
    insert newRat;
    licenseTypeId = newRat.Id;
}

// ── 4. IndividualApplication records (skip if already exist for each project) ─

Map<Id, IndividualApplication> existingIA = new Map<Id, IndividualApplication>();
for (IndividualApplication ia : [
        SELECT Id, nepa_related_project__c FROM IndividualApplication
        WHERE nepa_related_project__c IN :programIds.values()]) {
    existingIA.put(ia.nepa_related_project__c, ia);
}

List<IndividualApplication> toInsertIA = new List<IndividualApplication>();

if (!existingIA.containsKey(programIds.get('TEST-BLM-EIS-001'))) {
    IndividualApplication eisIA = new IndividualApplication();
    eisIA.Category                  = 'Permit';
    eisIA.LicenseTypeId             = licenseTypeId;
    eisIA.nepa_related_project__c   = programIds.get('TEST-BLM-EIS-001');
    // nepa_review_type__c intentionally left blank — tester sets it in the UI to
    // guarantee IsChanged=true fires the Risk Scorer flow (TESTING-GUIDE §2)
    eisIA.nepa_process_stage__c     = 'Draft EIS Preparation';
    eisIA.nepa_process_status__c    = 'in progress';
    eisIA.nepa_federal_unique_id__c = 'TEST-DOI-BLM-EIS-001';
    toInsertIA.add(eisIA);
}

if (!existingIA.containsKey(programIds.get('TEST-FERC-EA-001'))) {
    IndividualApplication eaIA = new IndividualApplication();
    eaIA.Category                  = 'Permit';
    eaIA.LicenseTypeId             = licenseTypeId;
    eaIA.nepa_related_project__c   = programIds.get('TEST-FERC-EA-001');
    eaIA.nepa_process_stage__c     = 'Comment Period';
    eaIA.nepa_process_status__c    = 'in progress';
    eaIA.nepa_federal_unique_id__c = 'TEST-FERC-EA-001';
    toInsertIA.add(eaIA);
}

if (!existingIA.containsKey(programIds.get('TEST-BLM-CE-001'))) {
    IndividualApplication ceIA = new IndividualApplication();
    ceIA.Category                  = 'Permit';
    ceIA.LicenseTypeId             = licenseTypeId;
    ceIA.nepa_related_project__c   = programIds.get('TEST-BLM-CE-001');
    ceIA.nepa_process_stage__c     = 'Scoping';
    ceIA.nepa_process_status__c    = 'in progress';
    ceIA.nepa_federal_unique_id__c = 'TEST-DOI-BLM-CE-001';
    toInsertIA.add(ceIA);
}

if (!toInsertIA.isEmpty()) insert toInsertIA;

// Reload IAs to get final Ids
Map<Id, Id> projectToIA = new Map<Id, Id>();
for (IndividualApplication ia : [
        SELECT Id, nepa_related_project__c FROM IndividualApplication
        WHERE nepa_related_project__c IN :programIds.values()]) {
    projectToIA.put(ia.nepa_related_project__c, ia.Id);
}

// ── 5. Print IDs for use in testing guide ────────────────────────────────────

System.debug('=== Test data ready ===');
System.debug('EIS Program  (TEST-BLM-EIS-001):  ' + programIds.get('TEST-BLM-EIS-001'));
System.debug('EA  Program  (TEST-FERC-EA-001):   ' + programIds.get('TEST-FERC-EA-001'));
System.debug('CE  Program  (TEST-BLM-CE-001):    ' + programIds.get('TEST-BLM-CE-001'));
System.debug('EIS IndividualApplication:         ' + projectToIA.get(programIds.get('TEST-BLM-EIS-001')));
System.debug('EA  IndividualApplication:         ' + projectToIA.get(programIds.get('TEST-FERC-EA-001')));
System.debug('CE  IndividualApplication:         ' + projectToIA.get(programIds.get('TEST-BLM-CE-001')));
System.debug('=== Use the IDs above when prompted in docs/TESTING-GUIDE.md ===');
