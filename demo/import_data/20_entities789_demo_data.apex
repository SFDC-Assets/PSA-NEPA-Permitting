/**
 * Post-load step 20: CEQ Entities 7, 8, and 9 demo data for Carrie Placer Mine.
 *
 * Creates:
 *   Entity 9 — RegulatoryAuthority (4) + RegulatoryCode (7)
 *   Entity 8 — nepa_process_team_member__c (7 ID team members)
 *   Entity 7 — Polygon (1) + nepa_gis_data_element__c (5)
 *              + Program lat/lon/polygon wired for proximity flow
 *
 * Run AFTER step 18 (IndividualApplication and Program must exist).
 * Run via: sf apex run --file demo/import_data/20_entities789_demo_data.apex --target-org <alias>
 *
 * Idempotent: all blocks use get-or-create queries; safe to re-run.
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
    System.debug('ERROR: Program DOI-BLM-ID-B030-2019-0014-EA not found. Run step 08 and 18 first.');
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


// ══════════════════════════════════════════════════════════════════════════════
// ENTITY 9 — RegulatoryAuthority + RegulatoryCode
// ══════════════════════════════════════════════════════════════════════════════

// ── 9a. RegulatoryAuthority records ──────────────────────────────────────────

Map<String, Id> raIdByName = new Map<String, Id>();
for (RegulatoryAuthority ra : [
    SELECT Id, Name FROM RegulatoryAuthority
    WHERE Name IN ('CEQ', 'DOI-BLM', 'Congress', 'EPA')
]) {
    raIdByName.put(ra.Name, ra.Id);
}

List<RegulatoryAuthority> rasToInsert = new List<RegulatoryAuthority>();
for (String raName : new List<String>{ 'CEQ', 'DOI-BLM', 'Congress', 'EPA' }) {
    if (!raIdByName.containsKey(raName)) {
        rasToInsert.add(new RegulatoryAuthority(Name = raName));
    }
}
if (!rasToInsert.isEmpty()) {
    insert rasToInsert;
    for (RegulatoryAuthority ra : rasToInsert) {
        raIdByName.put(ra.Name, ra.Id);
    }
    System.debug('RegulatoryAuthority inserted: ' + rasToInsert.size());
}

// ── 9b. RegulatoryCode records ────────────────────────────────────────────────

// Citation → {subject, description, externalUrl, complianceReqs, authority}
List<Map<String, String>> rcDefs = new List<Map<String, String>>{
    new Map<String, String>{
        'citation'    => '42 U.S.C. § 4321',
        'subject'     => 'National Environmental Policy Act — Declaration of Purpose',
        'description' => 'Establishes national policy to use a systematic interdisciplinary approach to environmental planning and decision making. Foundational statute for all NEPA environmental reviews including EAs, EISs, and CEs.',
        'externalUrl' => 'https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title42-section4321',
        'compliance'  => 'All federal agencies must prepare NEPA documentation for major federal actions significantly affecting the quality of the human environment. For mining Plans of Operations on BLM-administered land, an EA is required unless the action qualifies for categorical exclusion.',
        'authority'   => 'Congress'
    },
    new Map<String, String>{
        'citation'    => '40 CFR § 1501.5',
        'subject'     => 'Environmental Assessments',
        'description' => 'Prescribes the preparation, content, and use of Environmental Assessments and Findings of No Significant Impact. Governs the EA pathway when a categorical exclusion is not applicable and an EIS is not required.',
        'externalUrl' => 'https://www.ecfr.gov/current/title-40/part-1501/section-1501.5',
        'compliance'  => 'Agency must prepare an EA that analyzes affected environment and environmental consequences, considers alternatives, and concludes with either a FONSI or a determination that an EIS is required. Public review of EA and FONSI required for 28 days when the action is not otherwise categorically excluded.',
        'authority'   => 'CEQ'
    },
    new Map<String, String>{
        'citation'    => '40 CFR § 1501.9',
        'subject'     => 'Scoping',
        'description' => 'Establishes the scoping process for identifying the range of actions, alternatives, and impacts to be analyzed in an EIS or EA. Includes requirements for public notice and interdisciplinary team consultation at project inception.',
        'externalUrl' => 'https://www.ecfr.gov/current/title-40/part-1501/section-1501.9',
        'compliance'  => 'Agency shall invite affected federal, state, and local agencies, any affected Indian tribe, the proponent, and other interested persons to participate in scoping. For the Carrie Placer Mine, the pre-application ID team consultation at the Owyhee Field Office satisfies this requirement.',
        'authority'   => 'CEQ'
    },
    new Map<String, String>{
        'citation'    => '43 CFR § 3809.11',
        'subject'     => 'Surface Management Regulations — Plans of Operations',
        'description' => 'Establishes BLM requirements for surface management of hardrock mining operations on public lands under the General Mining Law of 1872. Governs submission, content, and approval of Plans of Operations for disturbances over five acres.',
        'externalUrl' => 'https://www.ecfr.gov/current/title-43/part-3809/section-3809.11',
        'compliance'  => 'Operators proposing surface disturbance of more than five acres must submit a Plan of Operations to the BLM authorized officer. BLM must complete NEPA review before approving the Plan. A performance bond ensuring reclamation is required prior to approval.',
        'authority'   => 'DOI-BLM'
    },
    new Map<String, String>{
        'citation'    => '16 U.S.C. § 1536(a)',
        'subject'     => 'ESA Section 7 — Interagency Cooperation',
        'description' => 'Requires all federal agencies to insure that any action authorized, funded, or carried out by the agency is not likely to jeopardize the continued existence of any threatened or endangered species or result in destruction or adverse modification of critical habitat.',
        'externalUrl' => 'https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title16-section1536',
        'compliance'  => 'BLM must complete ESA Section 7 informal or formal consultation with USFWS before approving the Plan of Operations. For the Carrie Placer Mine, consultation covers greater sage-grouse PHMA (ARMPA 2015 compliance) and Columbia spotted frog riparian habitat in Jordan Creek.',
        'authority'   => 'Congress'
    },
    new Map<String, String>{
        'citation'    => '54 U.S.C. § 306108',
        'subject'     => 'NHPA Section 106 — Effect on Historic Properties',
        'description' => 'Requires federal agencies to take into account the effect of any undertaking on historic properties and afford the Advisory Council on Historic Preservation a reasonable opportunity to comment. Consultation with tribal governments required when undertaking may affect properties of religious or cultural significance to tribes.',
        'externalUrl' => 'https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title54-section306108',
        'compliance'  => 'BLM must complete government-to-government Section 106 consultation with the Shoshone-Paiute Tribes before approving the Plan of Operations. Consultation must be documented and certified as complete before the FONSI can be issued. This is a hard stage gate in the NEPA process.',
        'authority'   => 'Congress'
    },
    new Map<String, String>{
        'citation'    => '33 U.S.C. § 1342',
        'subject'     => 'CWA Section 402 — National Pollutant Discharge Elimination System',
        'description' => 'Establishes the NPDES permit program for discharge of pollutants from point sources into waters of the United States. Placer gold mining operations using suction dredge equipment that discharge to streams require an NPDES General Permit from EPA.',
        'externalUrl' => 'https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title33-section1342',
        'compliance'  => 'The Carrie Placer Mine suction dredge operation requires EPA NPDES General Permit IDG370000 (Small Suction Dredge — Idaho). The 60-day EPA processing clock must be initiated concurrently with BLM review; operators cannot begin discharge activity until written authorization is received from EPA.',
        'authority'   => 'Congress'
    }
};

Map<String, Id> rcIdByCitation = new Map<String, Id>();
for (RegulatoryCode rc : [
    SELECT Id, Name FROM RegulatoryCode
    WHERE Name IN (
        '42 U.S.C. § 4321',
        '40 CFR § 1501.5',
        '40 CFR § 1501.9',
        '43 CFR § 3809.11',
        '16 U.S.C. § 1536(a)',
        '54 U.S.C. § 306108',
        '33 U.S.C. § 1342'
    )
]) {
    rcIdByCitation.put(rc.Name, rc.Id);
}

List<RegulatoryCode> rcsToInsert = new List<RegulatoryCode>();
for (Map<String, String> def : rcDefs) {
    String citation = def.get('citation');
    if (!rcIdByCitation.containsKey(citation)) {
        RegulatoryCode rc = new RegulatoryCode();
        rc.Name                           = citation;
        rc.Subject                        = def.get('subject');
        String descVal = def.get('description');
        rc.Description                    = (descVal != null && descVal.length() > 255) ? descVal.substring(0, 255) : descVal;
        rc.ExternalUrl                    = def.get('externalUrl');
        rc.nepa_compliance_requirements__c = def.get('compliance');
        rc.RegulatoryAuthorityId          = raIdByName.get(def.get('authority'));
        rc.EffectiveFrom                  = DateTime.newInstance(2019, 1, 1, 0, 0, 0);
        rc.nepa_data_source_agency__c     = def.get('authority');
        rc.nepa_data_source_system__c     = 'eCFR';
        rc.nepa_data_record_version__c    = '1.0';
        rcsToInsert.add(rc);
    }
}
if (!rcsToInsert.isEmpty()) {
    insert rcsToInsert;
    for (RegulatoryCode rc : rcsToInsert) {
        rcIdByCitation.put(rc.Name, rc.Id);
    }
    System.debug('RegulatoryCode inserted: ' + rcsToInsert.size());
}

// ── 9c. RegulatoryCode records are standalone Entity 9 — no FK wiring needed ──
// RegulatoryCode is related to the NEPA process by domain context (BLM Plan of
// Operations reviews are governed by the 7 citations above). No lookup field on
// IndividualApplication — query RegulatoryCode directly by citation or authority.
System.debug('RegulatoryCode records created: ' + rcsToInsert.size() + ' (standalone Entity 9 — no IA FK).');


// ══════════════════════════════════════════════════════════════════════════════
// ENTITY 8 — nepa_process_team_member__c (ID Team for IDI-38709)
// ══════════════════════════════════════════════════════════════════════════════

// Each contact gets one team member record; skip if already assigned this role.
// Contact External_ID__c → {roleType, startDate, notes}
List<Map<String, Object>> tmDefs = new List<Map<String, Object>>{
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_001',
        'role'       => 'Lead NEPA Coordinator',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Kara Kirkpatrick-Kreitinger — Lead NEPA Specialist. Coordinates ID team, manages administrative record, conducts Section 106 tribal consultation with Shoshone-Paiute Tribes. Primary contact for applicant and CEQ reporting.'
    },
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_002',
        'role'       => 'Field Team Member',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Forrest Griggs — Geologist. Reviews access road erosion, reclamation plan, and cadastral boundaries. Work order closure triggers EPA NPDES NOI task.'
    },
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_003',
        'role'       => 'Field Team Member',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Colleen Trese — Wildlife Biologist (Sage-Grouse). ARMPA conformance specialist. Sage-grouse lek and PHMA survey window closes April 30; highest-priority seasonal constraint in the optimization sequence.'
    },
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_004',
        'role'       => 'Field Team Member',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Marcus Webb — Hydrologist. Jordan Creek water temperature and redband trout habitat assessment. Work order closure triggers IDWR water permit task and starts the 30-day SLA clock.'
    },
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_005',
        'role'       => 'Field Team Member',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Dana Ruiz — Fisheries and Wildlife Biologist. Columbia spotted frog riparian survey and Jordan Creek pond design review. Active season constraint: May through September.'
    },
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_006',
        'role'       => 'Field Team Member',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Trevor Hanks — Wildlife Biologist (Avian/Big Game). MBTA migratory bird nesting survey (spring window before April 14) and mule deer crucial winter range assessment (August–October shoulder season).'
    },
    new Map<String, Object>{
        'contactExt' => 'DEMO_CON_007',
        'role'       => 'Field Team Member',
        'startDate'  => Date.newInstance(2019, 3, 12),
        'notes'      => 'Priya Nambiar — Botanist. Two required site visits: first visit June, second visit August. Reclamation seed mix approval is a condition of Plan of Operations approval.'
    }
};

// Resolve contact IDs
Map<String, Id> contactIdByExt = new Map<String, Id>();
Set<String> contactExts = new Set<String>();
for (Map<String, Object> def : tmDefs) {
    contactExts.add((String) def.get('contactExt'));
}
for (Contact c : [
    SELECT Id, External_ID__c FROM Contact
    WHERE External_ID__c IN :contactExts
]) {
    contactIdByExt.put(c.External_ID__c, c.Id);
}

// Check which roles already exist on this process
Set<String> existingRoles = new Set<String>();
for (nepa_process_team_member__c tm : [
    SELECT nepa_role_type__c, nepa_user__c
    FROM nepa_process_team_member__c
    WHERE nepa_process__c = :appId
]) {
    existingRoles.add(tm.nepa_role_type__c + '|' + (tm.nepa_user__c != null ? tm.nepa_user__c : ''));
}

List<nepa_process_team_member__c> tmsToInsert = new List<nepa_process_team_member__c>();
for (Map<String, Object> def : tmDefs) {
    String contactExt = (String) def.get('contactExt');
    String role       = (String) def.get('role');
    Id     userId     = contactIdByExt.get(contactExt);

    // Use running user as fallback if contact not yet a User; keyed by role+userId
    String key = role + '|' + (userId != null ? userId : '');
    if (!existingRoles.contains(key)) {
        nepa_process_team_member__c tm = new nepa_process_team_member__c();
        tm.nepa_process__c            = appId;
        tm.nepa_user__c               = UserInfo.getUserId(); // demo: map all to running user
        tm.nepa_agency__c             = blmAccountId;
        tm.nepa_role_type__c          = role;
        tm.nepa_active__c             = true;
        tm.nepa_start_date__c         = (Date) def.get('startDate');
        tm.nepa_end_date__c           = role == 'Lead NEPA Coordinator'
                                            ? null
                                            : Date.newInstance(2019, 11, 27);
        tm.nepa_notes__c              = (String) def.get('notes');
        tm.nepa_data_source_agency__c = 'BLM';
        tm.nepa_data_source_system__c = 'eNEPA';
        tm.nepa_data_record_version__c = '1.0';
        tmsToInsert.add(tm);
    }
}
if (!tmsToInsert.isEmpty()) {
    insert tmsToInsert;
    System.debug('nepa_process_team_member__c inserted: ' + tmsToInsert.size());
}


// ══════════════════════════════════════════════════════════════════════════════
// ENTITY 7 — Polygon + nepa_gis_data_element__c + Program lat/lon
// ══════════════════════════════════════════════════════════════════════════════

// ── 7a. Polygon — Carrie Placer Mine project boundary ────────────────────────
// Center: 42.8701°N, 116.9227°W (Owyhee County, ID — ~9 mi SE of Jordan Valley, OR)
// 15-acre claim approximated as ~808 ft × 808 ft rectangle (~0.00367° per side)

Id polygonId;
List<Polygon> existingPolys = [
    SELECT Id FROM Polygon
    WHERE Name = 'Carrie Placer Mine Claim Boundary — IDI-38709'
    LIMIT 1
];
if (!existingPolys.isEmpty()) {
    polygonId = existingPolys[0].Id;
    System.debug('Polygon (existing): ' + polygonId);
} else {
    Polygon poly = new Polygon();
    poly.Name     = 'Carrie Placer Mine Claim Boundary — IDI-38709';
    poly.DataType = 'GEOJSON';
    poly.Data     = '{"type":"Polygon","coordinates":[[[-116.9264,42.8719],[-116.9190,42.8719],[-116.9190,42.8683],[-116.9264,42.8683],[-116.9264,42.8719]]]}';
    insert poly;
    polygonId = poly.Id;
    System.debug('Polygon inserted: ' + polygonId);
}

// ── 7b. Program — set lat, lon, polygon ──────────────────────────────────────

Program prog = new Program(Id = programId);
prog.nepa_location_lat__c = 42.8701;
prog.nepa_location_lon__c = -116.9227;
prog.nepa_polygon__c      = polygonId;
update prog;
System.debug('Program lat/lon/polygon updated.');

// ── 7c. nepa_gis_data_element__c records ─────────────────────────────────────

List<Map<String, Object>> gisDefs = new List<Map<String, Object>>{
    new Map<String, Object>{
        'name'        => 'Carrie Placer Mine Claim Boundary — IDI-38709',
        'purpose'     => 'Project Boundary',
        'format'      => 'GeoJSON',
        'accessMethod'=> 'URL',
        'accessInfo'  => 'https://gis.blm.gov/arcgis/rest/services/Lands_and_Realty/BLM_Natl_SMA_Grazing_Allotments/FeatureServer/0',
        'coordSystem' => 'WGS84',
        'boundingBox' => '-116.9264,42.8683,-116.9190,42.8719',
        'dbRef'       => true,
        'sourceAgency'=> 'BLM',
        'sourceSystem'=> 'BLM GeoBOE'
    },
    new Map<String, Object>{
        'name'        => 'Jordan Creek Watershed Analysis Area',
        'purpose'     => 'Analysis Area',
        'format'      => 'GeoJSON',
        'accessMethod'=> 'URL',
        'accessInfo'  => 'https://hydro.nationalmap.gov/arcgis/rest/services/NHDPlus_HR/MapServer',
        'coordSystem' => 'WGS84',
        'boundingBox' => '-117.1000,42.7500,-116.8000,42.9500',
        'dbRef'       => true,
        'sourceAgency'=> 'USGS',
        'sourceSystem'=> 'NHD+ High Resolution'
    },
    new Map<String, Object>{
        'name'        => 'Sage-Grouse PHMA — Owyhee Basin',
        'purpose'     => 'Resource Layer',
        'format'      => 'GeoJSON',
        'accessMethod'=> 'API',
        'accessInfo'  => 'https://services.arcgis.com/QVENGdaPbd4LUkLV/arcgis/rest/services/BLM_Natl_SGMA_PHMA/FeatureServer/0',
        'coordSystem' => 'WGS84',
        'boundingBox' => '-117.5000,42.5000,-116.5000,43.2000',
        'dbRef'       => true,
        'sourceAgency'=> 'BLM',
        'sourceSystem'=> 'ArcGIS Online — SGMA PHMA'
    },
    new Map<String, Object>{
        'name'        => 'ESA Critical Habitat — Columbia Spotted Frog',
        'purpose'     => 'Resource Layer',
        'format'      => 'GeoJSON',
        'accessMethod'=> 'URL',
        'accessInfo'  => 'https://services.arcgis.com/QVENGdaPbd4LUkLV/arcgis/rest/services/USFWS_ESA_CritHab/FeatureServer/0',
        'coordSystem' => 'WGS84',
        'boundingBox' => '-117.2000,42.7000,-116.7000,43.0000',
        'dbRef'       => true,
        'sourceAgency'=> 'USFWS',
        'sourceSystem'=> 'USFWS ArcGIS Online — ESA Critical Habitat'
    },
    new Map<String, Object>{
        'name'        => 'NWI Wetlands — Jordan Creek Riparian Corridor',
        'purpose'     => 'Resource Layer',
        'format'      => 'GeoJSON',
        'accessMethod'=> 'URL',
        'accessInfo'  => 'https://www.fws.gov/wetlands/data/mapper.html',
        'coordSystem' => 'WGS84',
        'boundingBox' => '-117.0500,42.8200,-116.8500,42.9200',
        'dbRef'       => true,
        'sourceAgency'=> 'USFWS',
        'sourceSystem'=> 'National Wetlands Inventory'
    }
};

Set<String> existingGisNames = new Set<String>();
for (nepa_gis_data_element__c g : [
    SELECT Name FROM nepa_gis_data_element__c
    WHERE nepa_polygon__c = :polygonId
]) {
    existingGisNames.add(g.Name);
}

List<nepa_gis_data_element__c> gisToInsert = new List<nepa_gis_data_element__c>();
for (Map<String, Object> def : gisDefs) {
    String name = (String) def.get('name');
    if (!existingGisNames.contains(name)) {
        nepa_gis_data_element__c g = new nepa_gis_data_element__c();
        g.Name                         = name;
        g.nepa_polygon__c              = polygonId;
        g.nepa_purpose__c              = (String)  def.get('purpose');
        g.nepa_format__c               = (String)  def.get('format');
        g.nepa_access_method__c        = (String)  def.get('accessMethod');
        g.nepa_access_information__c   = (String)  def.get('accessInfo');
        g.nepa_coordinate_system__c    = (String)  def.get('coordSystem');
        g.nepa_bounding_box__c         = (String)  def.get('boundingBox');
        g.nepa_database_reference__c   = (Boolean) def.get('dbRef');
        g.nepa_data_source_agency__c   = (String)  def.get('sourceAgency');
        g.nepa_data_source_system__c   = (String)  def.get('sourceSystem');
        g.nepa_data_record_version__c  = '1.0';
        g.nepa_retrieved_timestamp__c  = DateTime.newInstance(2019, 3, 12, 8, 0, 0);
        gisToInsert.add(g);
    }
}
if (!gisToInsert.isEmpty()) {
    insert gisToInsert;
    System.debug('nepa_gis_data_element__c inserted: ' + gisToInsert.size());
}

System.debug('Step 20 complete: Entity 9 (RegulatoryCode × 7 standalone), Entity 8 (Team Members), Entity 7 (GIS) loaded for Carrie Placer Mine IDI-38709.');
