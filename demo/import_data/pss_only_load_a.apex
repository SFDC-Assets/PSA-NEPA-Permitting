// PSS-only load — Part A: Accounts, Program, IndividualApplication
// Run: sf apex run --file demo/import_data/pss_only_load_a.apex --target-org NEPA_INNOVATOR

// ─── 1. Accounts ─────────────────────────────────────────────────────────────

Map<String, Account> acctByName = new Map<String, Account>();
for (Account a : [
    SELECT Id, Name FROM Account
    WHERE Name IN (
        'BLM Owyhee Field Office',
        'Sam Uhler and David Smith - Carrie Placer Mine',
        'Idaho Conservation League',
        'Office of Species Conservation',
        'Shoshone-Paiute Tribes',
        'U.S. Fish and Wildlife Service',
        'U.S. Army Corps of Engineers'
    )
]) { acctByName.put(a.Name, a); }

List<Account> acctInsert = new List<Account>();
if (!acctByName.containsKey('BLM Owyhee Field Office'))
    acctInsert.add(new Account(Name='BLM Owyhee Field Office', Type='Government',
        BillingStreet='3948 Development Ave', BillingCity='Marsing', BillingState='ID',
        BillingPostalCode='83639', BillingCountry='US', Phone='208-896-5912'));
if (!acctByName.containsKey('Sam Uhler and David Smith - Carrie Placer Mine'))
    acctInsert.add(new Account(Name='Sam Uhler and David Smith - Carrie Placer Mine', Type='Customer',
        BillingCity='Jordan Valley', BillingState='OR', BillingPostalCode='97910'));
if (!acctByName.containsKey('Idaho Conservation League'))
    acctInsert.add(new Account(Name='Idaho Conservation League', Type='Other',
        BillingCity='Boise', BillingState='ID', BillingPostalCode='83701', Phone='208-345-6933'));
if (!acctByName.containsKey('Office of Species Conservation'))
    acctInsert.add(new Account(Name='Office of Species Conservation', Type='Government',
        BillingCity='Boise', BillingState='ID', BillingPostalCode='83720', Phone='208-334-2920'));
if (!acctByName.containsKey('Shoshone-Paiute Tribes'))
    acctInsert.add(new Account(Name='Shoshone-Paiute Tribes', Type='Other',
        BillingCity='Owyhee', BillingState='NV'));
if (!acctByName.containsKey('U.S. Fish and Wildlife Service'))
    acctInsert.add(new Account(Name='U.S. Fish and Wildlife Service', Type='Government',
        BillingCity='Washington', BillingState='DC'));
if (!acctByName.containsKey('U.S. Army Corps of Engineers'))
    acctInsert.add(new Account(Name='U.S. Army Corps of Engineers', Type='Government',
        BillingCity='Washington', BillingState='DC'));
if (!acctInsert.isEmpty()) insert acctInsert;

for (Account a : [
    SELECT Id, Name FROM Account
    WHERE Name IN (
        'BLM Owyhee Field Office', 'Sam Uhler and David Smith - Carrie Placer Mine',
        'Idaho Conservation League', 'Office of Species Conservation',
        'Shoshone-Paiute Tribes', 'U.S. Fish and Wildlife Service',
        'U.S. Army Corps of Engineers'
    )
]) { acctByName.put(a.Name, a); }

Id blmId = acctByName.get('BLM Owyhee Field Office').Id;
System.debug('Accounts ready. BLM=' + blmId);

// ─── 2. Program ──────────────────────────────────────────────────────────────

Id programId;
List<Program> existingProg = [SELECT Id FROM Program WHERE nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA' LIMIT 1];
Program prog = existingProg.isEmpty() ? new Program() : existingProg[0];
prog.Name                          = 'Carrie Placer Mine Plan of Operations';
prog.Status                        = 'Active';
prog.StartDate                     = Date.newInstance(2019, 3, 12);
prog.EndDate                       = Date.newInstance(2019, 11, 27);
prog.nepa_project_id__c            = 'DOI-BLM-ID-B030-2019-0014-EA';
prog.nepa_lead_agency__c           = blmId;
prog.nepa_location_text__c         = 'T. 6 S., R. 5 W., Section 28, Jordan Creek watershed, Owyhee County, Idaho';
prog.nepa_primary_sector__c        = 'Agriculture and Natural Resource Management';
prog.nepa_project_type__c          = 'Mineral Extraction - Placer Mining';
prog.nepa_project_description__c   = 'Placer gold mining Plan of Operations on 15 acres of BLM-administered land in T. 6 S. R. 5 W. Section 28 Owyhee County Idaho. Adjacent to Jordan Creek approximately 9 miles southeast of Jordan Valley Oregon.';
prog.nepa_record_owner_agency__c   = 'BLM';
prog.nepa_circuit__c               = '9th';
prog.nepa_location_lat__c          = 42.8701;
prog.nepa_location_lon__c          = -116.9227;
if (existingProg.isEmpty()) { insert prog; } else { update prog; }
programId = prog.Id;
System.debug('Program: ' + programId);

// ─── 3. IndividualApplication ────────────────────────────────────────────────

Id licenseTypeId;
List<RegulatoryAuthorizationType> ratList = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1];
if (ratList.isEmpty()) {
    RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(Name='NEPA Environmental Review', RegulatoryAuthCategory='Permit');
    insert rat;
    licenseTypeId = rat.Id;
} else { licenseTypeId = ratList[0].Id; }

Id appId;
List<IndividualApplication> existingApp = [SELECT Id FROM IndividualApplication WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1];
IndividualApplication app = existingApp.isEmpty() ? new IndividualApplication() : existingApp[0];
app.LicenseTypeId                           = licenseTypeId;
app.Category                                = 'License';
app.Status                                  = 'Approved';
app.nepa_federal_unique_id__c               = 'IDI-38709';
app.nepa_related_project__c                 = programId;
app.nepa_start_date__c                      = Date.newInstance(2019, 3, 12);
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
app.nepa_description__c                     = 'Sam Uhler and David Smith propose a 5-10 year placer gold mining operation on 15 acres of BLM-administered land adjacent to Jordan Creek in Owyhee County, Idaho. The project involves new surface disturbance for placer gold extraction from alluvial deposits.';
app.nepa_purpose_need__c                    = 'Authorize placer gold mining on 15 acres of BLM-administered land in Owyhee County Idaho to provide economic benefit to the proponent consistent with FLPMA multiple-use principles.';
app.nepa_disturbance_acres__c               = 15;
app.nepa_extraordinary_circumstances__c     = 'true';
app.nepa_esa_consultation_status__c         = 'Biological Opinion Issued';
app.nepa_co_permits_required__c             = 'CWA Section 404;NHPA Section 106';
app.nepa_regulatory_citation__c             = '43 CFR Part 46; FLPMA Section 302';
app.nepa_public_comment_period_start__c     = Date.newInstance(2019, 7, 1);
app.nepa_public_comment_period_end_date__c  = Date.newInstance(2019, 7, 28);
app.nepa_target_completion_date__c          = Date.newInstance(2019, 12, 31);
app.nepa_record_owner_agency__c             = 'BLM';
app.nepa_data_source_agency__c              = 'BLM';
app.nepa_data_source_system__c              = 'ePlanning';
app.nepa_data_record_version__c             = '1';
app.nepa_risk_score__c                      = 85;
app.nepa_risk_tier__c                       = 'Very High';
app.nepa_plaintiff_risk_flag__c             = true;
app.nepa_tribal_plaintiff_flag__c           = true;
app.nepa_defensibility_score__c             = 91;
app.nepa_total_pages__c                     = 47;
app.nepa_waiver_invoked__c                  = false;
app.nepa_connected_actions_identified__c    = true;
app.nepa_circuit_court__c                   = '9th';
app.nepa_project_sector__c                  = 'Mining';
app.nepa_cooperating_agencies__c            = 'USFWS; USACE';
app.nepa_litigation_duration_cost__c        = 0.63;
app.nepa_ec_multi_dod__c                    = false;
app.nepa_ec_usace_czma__c                   = false;
app.nepa_process_outcome__c                 = 'FONSI issued. No significant impact found. CWA 404 and IDWR appropriation permits required prior to ground disturbance.';
if (existingApp.isEmpty()) { insert app; } else { update app; }
appId = app.Id;
System.debug('IndividualApplication: ' + appId);
System.debug('Part A complete. appId=' + appId + ' programId=' + programId);
