// Step 26: Backfill External_ID__c on existing demo records + deduplicate ApplicationTimeline
// Run BEFORE re-running any upsert loads on steps 11, 12, 16, 17.
// Safe to re-run: all DML is conditional on External_ID__c being null.

// ─── 1. ApplicationTimeline: keep oldest 25, delete the rest ──────────────────
List<ApplicationTimeline> allAT = [
    SELECT Id, Name, nepa_related_process__c, External_ID__c, CreatedDate
    FROM ApplicationTimeline
    WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'
    ORDER BY CreatedDate ASC, Id ASC
];

// Group by Name — keep the first occurrence (oldest), collect duplicates
Map<String, Id> firstById = new Map<String, Id>();
List<Id> atDuplicates = new List<Id>();
for (ApplicationTimeline at : allAT) {
    if (!firstById.containsKey(at.Name)) {
        firstById.put(at.Name, at.Id);
    } else {
        atDuplicates.add(at.Id);
    }
}
if (!atDuplicates.isEmpty()) {
    delete [SELECT Id FROM ApplicationTimeline WHERE Id IN :atDuplicates];
    System.debug('Deleted ' + atDuplicates.size() + ' duplicate ApplicationTimeline records');
}

// ─── 2. ApplicationTimeline: backfill External_ID__c on the survivors ─────────
// Map from Name → DEMO_AT_NNN (ordered by the canonical CSV sequence)
Map<String, String> atExtIds = new Map<String, String>{
    'Application Received'                                    => 'DEMO_AT_001',
    'Pre-Application ID Team Consultation Completed'          => 'DEMO_AT_002',
    'Section 106 Tribal Consultation Initiated'               => 'DEMO_AT_003',
    'Sage-Grouse Lek Survey Window Opens'                     => 'DEMO_AT_004',
    'Migratory Bird Survey Spring Window Deadline'            => 'DEMO_AT_005',
    'Sage-Grouse Lek Survey Completed'                        => 'DEMO_AT_006',
    'Section 106 Tribal Consultation Certified Complete'      => 'DEMO_AT_007',
    'Hydrology and Water Quality Assessment Completed'        => 'DEMO_AT_008',
    'IDWR Water Permit Application Initiated'                 => 'DEMO_AT_009',
    'Geology Soils and Access Road Assessment Completed'      => 'DEMO_AT_010',
    'EPA NPDES NOI IDG370000 Filed'                           => 'DEMO_AT_011',
    'Columbia Spotted Frog Riparian Survey Completed'         => 'DEMO_AT_012',
    'Botanical Survey First Site Visit Completed'             => 'DEMO_AT_013',
    'EPA NPDES Agency Objection Window Cleared'               => 'DEMO_AT_014',
    'Big Game Winter Range Assessment Completed'              => 'DEMO_AT_015',
    'Botanical Survey Second Site Visit Completed'            => 'DEMO_AT_016',
    'Preliminary EA Published for Public Comment'             => 'DEMO_AT_017',
    'Public Comment Period Closed'                            => 'DEMO_AT_018',
    'ICL Comment Response Incorporated into EA'               => 'DEMO_AT_019',
    'OSC Comment Response Incorporated into EA'               => 'DEMO_AT_020',
    'IDWR Water Permit Received'                              => 'DEMO_AT_021',
    'EPA NPDES Authorization Received'                        => 'DEMO_AT_022',
    'Required Document Registry All Five Documents Verified'  => 'DEMO_AT_023',
    'FONSI Signed'                                            => 'DEMO_AT_024',
    'Decision Record Issued'                                  => 'DEMO_AT_025'
};

List<ApplicationTimeline> atToUpdate = new List<ApplicationTimeline>();
for (ApplicationTimeline at : [
    SELECT Id, Name, External_ID__c
    FROM ApplicationTimeline
    WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'
      AND External_ID__c = null
]) {
    if (atExtIds.containsKey(at.Name)) {
        at.External_ID__c = atExtIds.get(at.Name);
        atToUpdate.add(at);
    }
}
if (!atToUpdate.isEmpty()) {
    update atToUpdate;
    System.debug('Backfilled External_ID__c on ' + atToUpdate.size() + ' ApplicationTimeline records');
}

// ─── 3. nepa_engagement__c: delete stale records, CSV will insert correct set ─
// Existing 5 records (Open House, Notice Nov-26, etc.) don't match the current CSV.
// Delete them all; step 11 upsert will then insert the correct 5 with External_IDs.
List<nepa_engagement__c> staleEng = [
    SELECT Id FROM nepa_engagement__c
    WHERE nepa_process__r.nepa_federal_unique_id__c = 'IDI-38709'
      AND External_ID__c = null
];
if (!staleEng.isEmpty()) {
    delete staleEng;
    System.debug('Deleted ' + staleEng.size() + ' stale nepa_engagement__c records (no External_ID__c)');
}

// ─── 4. PublicComplaint: backfill External_ID__c on ICL and OSC ───────────────
Map<String, String> pcExtIds = new Map<String, String>{
    'ICL Comment - Air Quality Mercury and Dust Particulate'       => 'DEMO_PC_001',
    'OSC Comment - Sage-Grouse Lek Buffer Departure Justification' => 'DEMO_PC_002'
};

List<PublicComplaint> pcToUpdate = new List<PublicComplaint>();
for (PublicComplaint pc : [
    SELECT Id, Subject, External_ID__c
    FROM PublicComplaint
    WHERE nepa_related_process__r.nepa_federal_unique_id__c = 'IDI-38709'
      AND External_ID__c = null
]) {
    if (pcExtIds.containsKey(pc.Subject)) {
        pc.External_ID__c = pcExtIds.get(pc.Subject);
        pcToUpdate.add(pc);
    }
}
if (!pcToUpdate.isEmpty()) {
    update pcToUpdate;
    System.debug('Backfilled External_ID__c on ' + pcToUpdate.size() + ' PublicComplaint records');
}

// ─── 5. nepa_litigation__c: backfill External_ID__c by Name ──────────────────
Map<String, String> litExtIds = new Map<String, String>{
    'Western Watersheds v. BLM - Owyhee Sage-Grouse ARMPA Reference'      => 'DEMO_LIT_001',
    'Idaho Conservation League v. USFS - Suction Dredge Mercury Analysis' => 'DEMO_LIT_002'
};

List<nepa_litigation__c> litToUpdate = new List<nepa_litigation__c>();
for (nepa_litigation__c lit : [
    SELECT Id, Name, External_ID__c
    FROM nepa_litigation__c
    WHERE External_ID__c = null
]) {
    if (litExtIds.containsKey(lit.Name)) {
        lit.External_ID__c = litExtIds.get(lit.Name);
        litToUpdate.add(lit);
    }
}
if (!litToUpdate.isEmpty()) {
    update litToUpdate;
    System.debug('Backfilled External_ID__c on ' + litToUpdate.size() + ' nepa_litigation__c records');
}

System.debug('Step 26 complete. Re-run loads for steps 11, 12, 16, 17 using upsert on External_ID__c.');
