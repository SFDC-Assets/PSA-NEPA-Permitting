/**
 * Post-load step 22: GIS proximity results + auto-assembled team + auto-generated work orders
 * for Carrie Placer Mine IDI-38709.
 *
 * In production, NEPA_GIS_Proximity_Check fires when lat/lon are set (step 20), calls the
 * NEPA_GISProximityIP OmniIntegrationProcedure, and NEPA_Team_Assembly_Orchestrator assembles
 * the team. In demo, the ArcGIS callouts cannot run without live named credentials, so this
 * script pre-seeds the exact records those flows would produce.
 *
 * Creates:
 *   nepa_detected_protection_layer__c — 4 records (one per active GIS layer):
 *     NWI_Wetlands        → HIT  (Freshwater Emergent Wetland, EC triggered)
 *     FWS_Critical_Habitat → HIT  (Greater Sage-Grouse — Designated CH)
 *     EPA_Superfund_NPL   → MISS (0 features — rural Owyhee County, no NPL sites)
 *     EJScreen_EJ_Index   → HIT  (EJ Index = 18.3 — informational, no EC)
 *   nepa_process_team_member__c — 3 GIS_Auto_Assembly records (Hydrologist, Wildlife Biologist,
 *     NEPA Specialist); all map to DEMO_SR_001 (FSL 1-Technician-per-User constraint)
 *   WorkOrder — 3 auto-generated records (nepa_auto_generated__c = true)
 *   Program — nepa_gis_proximity_complete__c set true; protection areas text written
 *
 * Run AFTER step 21 (ServiceResource.nepa_discipline__c must be set).
 * Run via: sf apex run --file demo/import_data/22_postload_gis_team_assembly.apex --target-org <alias>
 *
 * Idempotent: upserts detected layers on nepa_upsert_key__c; checks for existing
 * GIS_Auto_Assembly team members; skips auto-generated WOs if they already exist.
 */

// ── Resolve parent records ────────────────────────────────────────────────────

Id programId;
for (Program p : [
    SELECT Id FROM Program
    WHERE nepa_project_id__c = 'DOI-BLM-ID-B030-2019-0014-EA'
    LIMIT 1
]) {
    programId = p.Id;
}
if (programId == null) {
    System.debug('ERROR: Program DOI-BLM-ID-B030-2019-0014-EA not found. Run steps 08 and 18 first.');
    return;
}

Id appId;
for (IndividualApplication ia : [
    SELECT Id FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709'
    LIMIT 1
]) {
    appId = ia.Id;
}
if (appId == null) {
    System.debug('ERROR: IndividualApplication IDI-38709 not found. Run step 18 first.');
    return;
}

Id blmAccountId;
for (Account a : [SELECT Id FROM Account WHERE External_ID__c = 'DEMO_ACCT_001' LIMIT 1]) {
    blmAccountId = a.Id;
}

Id demoSRId;
for (ServiceResource sr : [
    SELECT Id FROM ServiceResource WHERE External_ID__c = 'DEMO_SR_001' LIMIT 1
]) {
    demoSRId = sr.Id;
}
if (demoSRId == null) {
    System.debug('WARN: DEMO_SR_001 not found. Team member service resource links will be null. Run step 18 first.');
}

Id demoTerritoryId;
for (ServiceTerritory st : [
    SELECT Id FROM ServiceTerritory WHERE External_ID__c = 'DEMO_TERR_001' LIMIT 1
]) {
    demoTerritoryId = st.Id;
}

DateTime gisRunTs = DateTime.newInstance(2019, 3, 12, 14, 23, 0);


// ══════════════════════════════════════════════════════════════════════════════
// 1 — nepa_detected_protection_layer__c (upsert on nepa_upsert_key__c)
// ══════════════════════════════════════════════════════════════════════════════
// Coordinates: 42.8701°N, 116.9227°W — Owyhee County, Idaho
//
// NWI Wetlands:       Jordan Creek riparian corridor falls within the 1-mile buffer.
//                     3 Freshwater Emergent Wetland polygons detected. EC keyword
//                     "WETLANDS" → extraordinary circumstances flag set.
// FWS Critical Habitat: Greater Sage-Grouse PHMA (Priority Habitat Mgmt Area) 2015
//                     designated critical habitat covers the Owyhee Basin.
//                     EC keyword "CRITICAL HABITAT" → flag set.
// EPA Superfund NPL:  No NPL sites within 1 mile of this rural Idaho location.
// EJScreen EJ Index:  EJ Index 18.3 returned (percentile for Owyhee County).
//                     Informational only — no EC keyword configured.

List<nepa_detected_protection_layer__c> layerRecords = new List<nepa_detected_protection_layer__c>{

    new nepa_detected_protection_layer__c(
        nepa_program__c                              = programId,
        nepa_layer_developer_name__c                 = 'NWI_Wetlands',
        nepa_layer_label__c                          = 'NWI Wetlands',
        nepa_feature_name__c                         = 'Freshwater Emergent Wetland (+ 2 more)',
        nepa_feature_count__c                        = 3,
        nepa_is_hit__c                               = true,
        nepa_ec_triggered__c = true,
        nepa_gis_run_timestamp__c                    = gisRunTs
    ),

    new nepa_detected_protection_layer__c(
        nepa_program__c                              = programId,
        nepa_layer_developer_name__c                 = 'FWS_Critical_Habitat',
        nepa_layer_label__c                          = 'FWS Critical Habitat',
        nepa_feature_name__c                         = 'Greater Sage-Grouse — Designated Critical Habitat (PHMA)',
        nepa_feature_count__c                        = 1,
        nepa_is_hit__c                               = true,
        nepa_ec_triggered__c = true,
        nepa_gis_run_timestamp__c                    = gisRunTs
    ),

    new nepa_detected_protection_layer__c(
        nepa_program__c                              = programId,
        nepa_layer_developer_name__c                 = 'EPA_Superfund_NPL',
        nepa_layer_label__c                          = 'EPA Superfund NPL Site',
        nepa_feature_name__c                         = null,
        nepa_feature_count__c                        = 0,
        nepa_is_hit__c                               = false,
        nepa_ec_triggered__c = false,
        nepa_gis_run_timestamp__c                    = gisRunTs
    ),

    new nepa_detected_protection_layer__c(
        nepa_program__c                              = programId,
        nepa_layer_developer_name__c                 = 'EJScreen_EJ_Index',
        nepa_layer_label__c                          = 'EJScreen EJ Index',
        nepa_feature_name__c                         = 'EJ Index = 18.3',
        nepa_feature_count__c                        = 1,
        nepa_is_hit__c                               = true,
        nepa_ec_triggered__c = false,
        nepa_gis_run_timestamp__c                    = gisRunTs
    )
};

// nepa_upsert_key__c is a formula: programId + '_' + layerDeveloperName
// For upsert we must set it explicitly (formula fields are not writeable on insert).
// Strategy: upsert by querying existing records by programId + developerName, then
// update-or-insert manually to work around the formula-as-upsert-key limitation.

Map<String, nepa_detected_protection_layer__c> existingByKey =
    new Map<String, nepa_detected_protection_layer__c>();
for (nepa_detected_protection_layer__c existing : [
    SELECT Id, nepa_layer_developer_name__c
    FROM nepa_detected_protection_layer__c
    WHERE nepa_program__c = :programId
]) {
    existingByKey.put(existing.nepa_layer_developer_name__c, existing);
}

List<nepa_detected_protection_layer__c> toInsert = new List<nepa_detected_protection_layer__c>();
List<nepa_detected_protection_layer__c> toUpdate = new List<nepa_detected_protection_layer__c>();

for (nepa_detected_protection_layer__c layer : layerRecords) {
    nepa_detected_protection_layer__c existing = existingByKey.get(layer.nepa_layer_developer_name__c);
    if (existing != null) {
        layer.Id = existing.Id;
        toUpdate.add(layer);
    } else {
        toInsert.add(layer);
    }
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('nepa_detected_protection_layer__c inserted: ' + toInsert.size());
}
if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('nepa_detected_protection_layer__c updated: ' + toUpdate.size());
}

// Reload to get Ids for all 4 layers (newly inserted + previously existing)
Map<String, Id> layerIdByDeveloperName = new Map<String, Id>();
for (nepa_detected_protection_layer__c layer : [
    SELECT Id, nepa_layer_developer_name__c
    FROM nepa_detected_protection_layer__c
    WHERE nepa_program__c = :programId
]) {
    layerIdByDeveloperName.put(layer.nepa_layer_developer_name__c, layer.Id);
}

Id nwiLayerId   = layerIdByDeveloperName.get('NWI_Wetlands');
Id fwsLayerId   = layerIdByDeveloperName.get('FWS_Critical_Habitat');
Id ejLayerId    = layerIdByDeveloperName.get('EJScreen_EJ_Index');


// ══════════════════════════════════════════════════════════════════════════════
// 2 — Program: write protection areas summary + set gis_proximity_complete flag
// ══════════════════════════════════════════════════════════════════════════════

String protectionAreasSummary =
    'NWI Wetlands: Freshwater Emergent Wetland (+ 2 more)\n' +
    'FWS Critical Habitat: Greater Sage-Grouse — Designated Critical Habitat (PHMA)\n' +
    'EPA Superfund NPL Site: [no features within 1 mile]\n' +
    'EJScreen EJ Index: EJ Index = 18.3';

update new Program(
    Id                              = programId,
    nepa_protection_areas__c        = protectionAreasSummary,
    nepa_gis_last_checked__c        = gisRunTs,
    nepa_extraordinary_circumstances__c = true,
    nepa_gis_proximity_complete__c  = true
);
System.debug('Program GIS fields updated: protection areas, timestamp, EC flag, proximity complete.');


// ══════════════════════════════════════════════════════════════════════════════
// 3 — nepa_process_team_member__c (GIS_Auto_Assembly records)
// ══════════════════════════════════════════════════════════════════════════════
// Three disciplines triggered by the 3 hit layers:
//   NWI_Wetlands        → Hydrologist        (Marcus Webb → DEMO_SR_001 in demo)
//   FWS_Critical_Habitat → Wildlife Biologist (Sage-Grouse) (Colleen Trese → DEMO_SR_001 in demo)
//   EJScreen_EJ_Index   → NEPA Specialist    (Kara Kirkpatrick-Kreitinger → DEMO_SR_001 in demo)
//
// All map to DEMO_SR_001 due to FSL 1-Technician-per-User demo constraint.
// nepa_assembly_source__c = 'GIS_Auto_Assembly' distinguishes from the manually
// added team members in step 20.

// Skip if GIS_Auto_Assembly members already exist for this process
Set<String> existingAutoDisciplines = new Set<String>();
for (nepa_process_team_member__c tm : [
    SELECT nepa_discipline__c
    FROM nepa_process_team_member__c
    WHERE nepa_process__c = :appId
    AND nepa_assembly_source__c = 'GIS_Auto_Assembly'
]) {
    existingAutoDisciplines.add(tm.nepa_discipline__c);
}

List<Map<String, Object>> autoTMDefs = new List<Map<String, Object>>{
    new Map<String, Object>{
        'discipline'   => 'Hydrologist',
        'role'         => 'Field Team Member',
        'notes'        => 'Auto-assembled by GIS proximity check: NWI Wetlands detected within 1 mile (Freshwater Emergent Wetland × 3). Jordan Creek riparian corridor falls within project buffer. CWA Section 404 jurisdictional determination and NPDES permit requirements must be assessed.',
        'triggerLayer' => nwiLayerId
    },
    new Map<String, Object>{
        'discipline'   => 'Wildlife Biologist (Sage-Grouse)',
        'role'         => 'Field Team Member',
        'notes'        => 'Auto-assembled by GIS proximity check: USFWS Critical Habitat detected within 1 mile (Greater Sage-Grouse — Designated PHMA). ESA Section 7 informal or formal consultation required. ARMPA 2015 conformance check and lek disturbance buffer assessment (3.1 miles per Idaho ARMPA).',
        'triggerLayer' => fwsLayerId
    },
    new Map<String, Object>{
        'discipline'   => 'NEPA Specialist',
        'role'         => 'Field Team Member',
        'notes'        => 'Auto-assembled by GIS proximity check: EJScreen EJ Index returned (EJ Index = 18.3). Environmental justice analysis required per E.O. 12898 and CEQ EJ Guidance. Assess disproportionate impacts on overburdened communities and incorporate into the EA alternatives analysis.',
        'triggerLayer' => ejLayerId
    }
};

List<nepa_process_team_member__c> autoTMsToInsert = new List<nepa_process_team_member__c>();
for (Map<String, Object> def : autoTMDefs) {
    String discipline = (String) def.get('discipline');
    if (!existingAutoDisciplines.contains(discipline)) {
        nepa_process_team_member__c tm = new nepa_process_team_member__c();
        tm.nepa_process__c             = appId;
        tm.nepa_user__c                = UserInfo.getUserId();
        tm.nepa_agency__c              = blmAccountId;
        tm.nepa_role_type__c           = (String) def.get('role');
        tm.nepa_active__c              = true;
        tm.nepa_start_date__c          = Date.newInstance(2019, 3, 12);
        tm.nepa_assembly_source__c     = 'GIS_Auto_Assembly';
        tm.nepa_discipline__c          = discipline;
        tm.nepa_service_resource__c    = demoSRId;
        tm.nepa_trigger_layer__c       = (Id) def.get('triggerLayer');
        tm.nepa_notes__c               = (String) def.get('notes');
        tm.nepa_data_source_agency__c  = 'BLM';
        tm.nepa_data_source_system__c  = 'NEPA_Team_Assembly_Orchestrator';
        tm.nepa_data_record_version__c = '1.0';
        autoTMsToInsert.add(tm);
    }
}
if (!autoTMsToInsert.isEmpty()) {
    insert autoTMsToInsert;
    System.debug('GIS_Auto_Assembly team members inserted: ' + autoTMsToInsert.size());
} else {
    System.debug('GIS_Auto_Assembly team members already exist — skipped.');
}


// ══════════════════════════════════════════════════════════════════════════════
// 4 — WorkOrder (auto-generated, nepa_auto_generated__c = true)
// ══════════════════════════════════════════════════════════════════════════════
// Three WOs corresponding to the three hit-layer disciplines.
// These are distinct from the manually planned WOs in step 13: the GIS-triggered WOs
// represent the scoping-phase field assessment work orders issued immediately after
// GIS proximity detection, before the full ID team work order sequence is scheduled.
//
// WorkType mapping from NEPA_Layer_Discipline__mdt:
//   NWI_Wetlands        → DEMO_WT_001 (Hydrology and Water Quality)
//   FWS_Critical_Habitat → DEMO_WT_002 (Sage-Grouse / Wildlife)
//   EJScreen_EJ_Index   → DEMO_WT_001 (NEPA Specialist / EJ analysis)
//
// Status: New (GIS assembly creates WOs in scoping state; demo reflects initial creation)

Map<String, Id> workTypeIdByExt = new Map<String, Id>();
for (WorkType wt : [
    SELECT Id, External_ID__c FROM WorkType
    WHERE External_ID__c IN ('DEMO_WT_001', 'DEMO_WT_002')
]) {
    workTypeIdByExt.put(wt.External_ID__c, wt.Id);
}

// Check which auto-generated WOs already exist
Set<String> existingAutoWOSubjects = new Set<String>();
for (WorkOrder wo : [
    SELECT Subject FROM WorkOrder
    WHERE nepa_auto_generated__c = true
    AND nepa_process__c = :appId
]) {
    existingAutoWOSubjects.add(wo.Subject);
}

String projectName = 'Carrie Placer Mine';

List<Map<String, Object>> autoWODefs = new List<Map<String, Object>>{
    new Map<String, Object>{
        'subject'      => 'Hydrology and Water Quality Assessment - ' + projectName,
        'description'  => 'Field hydrology assessment triggered by NWI Wetlands GIS proximity detection (NWI Wetlands). Review water resources, wetland buffers, jurisdictional determination, and CWA Section 404 compliance for the project footprint. Assess NPDES permit requirements and document any wetland mitigation sequencing needs.',
        'workTypeExt'  => 'DEMO_WT_001',
        'duration'     => 480,
        'priority'     => 'High',
        'discipline'   => 'Hydrologist',
        'triggerLayer' => nwiLayerId
    },
    new Map<String, Object>{
        'subject'      => 'Critical Habitat and Species Survey - ' + projectName,
        'description'  => 'Wildlife survey triggered by USFWS Critical Habitat GIS proximity detection (FWS Critical Habitat). Assess listed species presence, critical habitat unit boundaries, and ESA Section 7 formal consultation requirements. Evaluate ARMPA conformance for sage-grouse PHMA and RHMA designations. Document seasonal survey windows and any required lek disturbance buffers.',
        'workTypeExt'  => 'DEMO_WT_002',
        'duration'     => 480,
        'priority'     => 'High',
        'discipline'   => 'Wildlife Biologist (Sage-Grouse)',
        'triggerLayer' => fwsLayerId
    },
    new Map<String, Object>{
        'subject'      => 'Environmental Justice Analysis - ' + projectName,
        'description'  => 'Environmental justice analysis triggered by EJScreen EJ Index GIS proximity detection (EJScreen EJ Index). Assess disproportionate and adverse impacts on overburdened EJ communities per Executive Order 12898 and CEQ Environmental Justice Guidance. Document cumulative impacts, mitigation measures, and meaningful public engagement opportunities. Review Title VI compliance and disparate impact analysis requirements. Findings must be incorporated into the alternatives analysis and mitigation sections of the NEPA document.',
        'workTypeExt'  => 'DEMO_WT_001',
        'duration'     => 240,
        'priority'     => 'Normal',
        'discipline'   => 'NEPA Specialist',
        'triggerLayer' => ejLayerId
    }
};

List<WorkOrder> autoWOsToInsert = new List<WorkOrder>();
for (Map<String, Object> def : autoWODefs) {
    String subject = (String) def.get('subject');
    if (!existingAutoWOSubjects.contains(subject)) {
        WorkOrder wo = new WorkOrder();
        wo.Subject               = subject;
        wo.Description           = (String) def.get('description');
        wo.Status                = 'New';
        wo.Priority              = (String) def.get('priority');
        wo.Duration              = (Integer) def.get('duration');
        wo.DurationType          = 'Minutes';
        wo.AccountId             = blmAccountId;
        wo.ServiceTerritoryId    = demoTerritoryId;
        wo.WorkTypeId            = workTypeIdByExt.get((String) def.get('workTypeExt'));
        wo.nepa_process__c       = appId;
        wo.nepa_discipline__c    = (String) def.get('discipline');
        wo.nepa_trigger_layer__c = (Id) def.get('triggerLayer');
        wo.nepa_auto_generated__c = true;
        autoWOsToInsert.add(wo);
    }
}
if (!autoWOsToInsert.isEmpty()) {
    insert autoWOsToInsert;
    System.debug('Auto-generated WorkOrders inserted: ' + autoWOsToInsert.size());
} else {
    System.debug('Auto-generated WorkOrders already exist — skipped.');
}


// ══════════════════════════════════════════════════════════════════════════════
// Summary
// ══════════════════════════════════════════════════════════════════════════════
System.debug('Step 22 complete: GIS proximity results, auto-assembled team, and auto-generated work orders loaded for Carrie Placer Mine IDI-38709.');
System.debug('  Detected layers: ' + layerIdByDeveloperName.size());
System.debug('  Auto team members inserted: ' + autoTMsToInsert.size());
System.debug('  Auto work orders inserted: ' + autoWOsToInsert.size());
System.debug('  Program extraordinary circumstances: true (NWI Wetlands + FWS Critical Habitat)');
