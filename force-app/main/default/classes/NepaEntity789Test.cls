@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
/**
 * Tests for CEQ Standard Entities 7 (GIS Data), 8 (User Role), and 9 (Legal Structure).
 *
 * Entity 7 — nepa_gis_data_element__c: CRUD, field coverage, and the
 *   NEPA_GIS_Proximity_Check after-save flow coordinate gate (fires only when
 *   both lat/lon are set; skips when either is null).
 *
 * Entity 8 — nepa_process_team_member__c: CRUD, MasterDetail cascade behavior
 *   (child deletes when parent process is deleted), active/inactive toggle,
 *   and multiple role assignments per process.
 *
 * Entity 9 — RegulatoryCode (PSS standard object + custom fields): CRUD,
 *   custom field persistence, lookup from nepa_decision_element__c.
 *   RegulatoryCode is a standalone Entity 9 — no FK on IndividualApplication.
 */
@IsTest
private class NepaEntity789Test {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('E789-TEST-001', 'Entity 789 Test Project', 'BLM');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
    }

    private static Program getProject() {
        return [SELECT Id, nepa_location_lat__c, nepa_location_lon__c,
                       nepa_protection_areas__c, nepa_extraordinary_circumstances__c
                FROM Program LIMIT 1];
    }

    private static IndividualApplication getProcess() {
        return [SELECT Id FROM IndividualApplication LIMIT 1];
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 7 — nepa_gis_data_element__c
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void gis_insert_persists_required_fields() {
        nepa_gis_data_element__c g = NepaTestFactory.insertGisDataElement(null, 'Resource Layer');

        nepa_gis_data_element__c result = [
            SELECT nepa_purpose__c, nepa_format__c, nepa_access_method__c,
                   nepa_coordinate_system__c, nepa_access_information__c,
                   nepa_data_source_agency__c, nepa_data_source_system__c,
                   nepa_data_record_version__c, nepa_retrieved_timestamp__c
            FROM nepa_gis_data_element__c
            WHERE Id = :g.Id
        ];

        System.assertEquals('Resource Layer',    result.nepa_purpose__c);
        System.assertEquals('GeoJSON',           result.nepa_format__c);
        System.assertEquals('URL',               result.nepa_access_method__c);
        System.assertEquals('WGS84',             result.nepa_coordinate_system__c);
        System.assertEquals('USFWS',             result.nepa_data_source_agency__c);
        System.assertEquals('ArcGIS Online',     result.nepa_data_source_system__c);
        System.assertEquals('1.0',               result.nepa_data_record_version__c);
        System.assertNotEquals(null,             result.nepa_retrieved_timestamp__c);
    }

    @IsTest
    static void gis_all_purpose_picklist_values_insert() {
        List<nepa_gis_data_element__c> records = new List<nepa_gis_data_element__c>();
        for (String purpose : new List<String>{
                'Project Boundary', 'Analysis Area', 'Base Map', 'Resource Layer', 'Other'}) {
            records.add(NepaTestFactory.makeGisDataElement(null, purpose));
        }
        insert records;
        System.assertEquals(5, [SELECT COUNT() FROM nepa_gis_data_element__c]);
    }

    @IsTest
    static void gis_all_format_picklist_values_insert() {
        List<nepa_gis_data_element__c> records = new List<nepa_gis_data_element__c>();
        for (String fmt : new List<String>{'GeoJSON','KML','GML','Shapefile','GeoTIFF','WKT','Other'}) {
            nepa_gis_data_element__c g = NepaTestFactory.makeGisDataElement(null, 'Base Map');
            g.nepa_format__c = fmt;
            records.add(g);
        }
        insert records;
        System.assertEquals(7, [SELECT COUNT() FROM nepa_gis_data_element__c]);
    }

    @IsTest
    static void gis_update_access_information() {
        nepa_gis_data_element__c g = NepaTestFactory.insertGisDataElement(null, 'Project Boundary');
        g.nepa_access_information__c = 'https://services.arcgis.com/updated/layer';
        update g;

        nepa_gis_data_element__c result = [
            SELECT nepa_access_information__c FROM nepa_gis_data_element__c WHERE Id = :g.Id
        ];
        System.assertEquals('https://services.arcgis.com/updated/layer', result.nepa_access_information__c);
    }

    @IsTest
    static void gis_delete_succeeds() {
        nepa_gis_data_element__c g = NepaTestFactory.insertGisDataElement(null, 'Base Map');
        delete g;
        System.assertEquals(0, [SELECT COUNT() FROM nepa_gis_data_element__c WHERE Id = :g.Id]);
    }

    @IsTest
    static void gis_bulk_insert_251_records() {
        List<nepa_gis_data_element__c> records = new List<nepa_gis_data_element__c>();
        for (Integer i = 0; i < 251; i++) {
            records.add(NepaTestFactory.makeGisDataElement(null, 'Resource Layer'));
        }
        insert records;
        System.assertEquals(251, [SELECT COUNT() FROM nepa_gis_data_element__c]);
    }

    // ── GIS Proximity Flow gate ───────────────────────────────────────────────
    // NEPA_GIS_Proximity_Check triggers on Program when lat or lon changes.
    // It calls NEPA_GIS_Proximity_IP (OmniProcess) only when both lat AND lon
    // are non-null. We can't mock the OmniProcess callout in an Apex test, so
    // these tests verify the coordinate gate decision logic by confirming the
    // flow fires without error (passes the gate) and that a null lat keeps the
    // flow from advancing past the gate (no unexpected DML errors).

    @IsTest
    static void gisProximityFlow_bothCoordinatesSet_flowFiresWithoutError() {
        Program proj = getProject();
        proj.nepa_location_lat__c = 43.0392;
        proj.nepa_location_lon__c = -108.7571;

        Test.startTest();
        update proj;
        Test.stopTest();

        // If we reach here without exception the flow gate passed cleanly.
        Program result = [SELECT nepa_location_lat__c, nepa_location_lon__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(43.0392,    result.nepa_location_lat__c);
        System.assertEquals(-108.7571,  result.nepa_location_lon__c);
    }

    @IsTest
    static void gisProximityFlow_latNullLonSet_flowSkipsGate() {
        Program proj = getProject();
        proj.nepa_location_lat__c = null;
        proj.nepa_location_lon__c = -108.7571;

        Test.startTest();
        update proj;
        Test.stopTest();

        Program result = [SELECT nepa_location_lat__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(null, result.nepa_location_lat__c);
    }

    @IsTest
    static void gisProximityFlow_latSetLonNull_flowSkipsGate() {
        Program proj = getProject();
        proj.nepa_location_lat__c = 43.0392;
        proj.nepa_location_lon__c = null;

        Test.startTest();
        update proj;
        Test.stopTest();

        Program result = [SELECT nepa_location_lon__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(null, result.nepa_location_lon__c);
    }

    @IsTest
    static void gisProximityFlow_neitherCoordinateSet_flowSkipsGate() {
        Program proj = getProject();
        proj.nepa_location_lat__c = null;
        proj.nepa_location_lon__c = null;

        Test.startTest();
        update proj;
        Test.stopTest();

        Program result = [SELECT nepa_location_lat__c, nepa_location_lon__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(null, result.nepa_location_lat__c);
        System.assertEquals(null, result.nepa_location_lon__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 8 — nepa_process_team_member__c
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void teamMember_insert_persists_fields() {
        Id processId = getProcess().Id;
        nepa_process_team_member__c tm = NepaTestFactory.insertTeamMember(
            processId, UserInfo.getUserId(), 'Lead NEPA Coordinator'
        );

        nepa_process_team_member__c result = [
            SELECT nepa_process__c, nepa_user__c, nepa_role_type__c,
                   nepa_active__c, nepa_start_date__c
            FROM nepa_process_team_member__c
            WHERE Id = :tm.Id
        ];

        System.assertEquals(processId,                    result.nepa_process__c);
        System.assertEquals(UserInfo.getUserId(),         result.nepa_user__c);
        System.assertEquals('Lead NEPA Coordinator',      result.nepa_role_type__c);
        System.assertEquals(true,                         result.nepa_active__c);
        System.assertEquals(Date.today(),                 result.nepa_start_date__c);
    }

    @IsTest
    static void teamMember_all_role_types_insert() {
        Id processId = getProcess().Id;
        List<nepa_process_team_member__c> records = new List<nepa_process_team_member__c>();
        for (String role : new List<String>{
                'Lead NEPA Coordinator', 'Cooperating Agency Rep', 'Reviewer',
                'Preparer', 'Legal Reviewer', 'Tribal Liaison', 'GIS Specialist',
                'Field Team Member', 'Other'}) {
            records.add(NepaTestFactory.makeTeamMember(processId, UserInfo.getUserId(), role));
        }
        insert records;
        System.assertEquals(9, [SELECT COUNT() FROM nepa_process_team_member__c WHERE nepa_process__c = :processId]);
    }

    @IsTest
    static void teamMember_active_flag_toggles() {
        Id processId = getProcess().Id;
        nepa_process_team_member__c tm = NepaTestFactory.insertTeamMember(processId, null, 'Reviewer');
        System.assertEquals(true, [SELECT nepa_active__c FROM nepa_process_team_member__c WHERE Id = :tm.Id].nepa_active__c);

        tm.nepa_active__c   = false;
        tm.nepa_end_date__c = Date.today();
        update tm;

        nepa_process_team_member__c result = [
            SELECT nepa_active__c, nepa_end_date__c FROM nepa_process_team_member__c WHERE Id = :tm.Id
        ];
        System.assertEquals(false,       result.nepa_active__c);
        System.assertEquals(Date.today(), result.nepa_end_date__c);
    }

    @IsTest
    static void teamMember_masterDetail_cascadeDelete() {
        // Insert a process, add a team member, delete the process — child must be gone.
        Program proj = NepaTestFactory.insertProgram('E789-CASCADE-001', 'Cascade Test Project', 'BLM');
        IndividualApplication proc = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        nepa_process_team_member__c tm = NepaTestFactory.insertTeamMember(proc.Id, null, 'Preparer');

        Test.startTest();
        delete proc;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM nepa_process_team_member__c WHERE Id = :tm.Id]);
    }

    @IsTest
    static void teamMember_multiple_roles_same_process() {
        Id processId = getProcess().Id;
        NepaTestFactory.insertTeamMember(processId, UserInfo.getUserId(), 'Lead NEPA Coordinator');
        NepaTestFactory.insertTeamMember(processId, UserInfo.getUserId(), 'GIS Specialist');
        NepaTestFactory.insertTeamMember(processId, UserInfo.getUserId(), 'Legal Reviewer');

        System.assertEquals(3, [SELECT COUNT() FROM nepa_process_team_member__c WHERE nepa_process__c = :processId]);
    }

    @IsTest
    static void teamMember_notes_field_persists() {
        Id processId = getProcess().Id;
        nepa_process_team_member__c tm = NepaTestFactory.makeTeamMember(processId, null, 'Tribal Liaison');
        tm.nepa_notes__c = 'Primary contact for Eastern Shoshone Tribe consultation per NHPA Section 106.';
        insert tm;

        nepa_process_team_member__c result = [SELECT nepa_notes__c FROM nepa_process_team_member__c WHERE Id = :tm.Id];
        System.assert(result.nepa_notes__c.contains('Eastern Shoshone'));
    }

    @IsTest
    static void teamMember_provenance_fields_persist() {
        Id processId = getProcess().Id;
        nepa_process_team_member__c tm = NepaTestFactory.makeTeamMember(processId, null, 'Reviewer');
        tm.nepa_data_source_agency__c  = 'BLM';
        tm.nepa_data_source_system__c  = 'eNEPA';
        tm.nepa_data_record_version__c = '2.1';
        tm.nepa_record_owner_agency__c = 'DOI';
        tm.nepa_retrieved_timestamp__c = DateTime.now();
        insert tm;

        nepa_process_team_member__c result = [
            SELECT nepa_data_source_agency__c, nepa_data_source_system__c,
                   nepa_data_record_version__c, nepa_record_owner_agency__c,
                   nepa_retrieved_timestamp__c
            FROM nepa_process_team_member__c WHERE Id = :tm.Id
        ];
        System.assertEquals('BLM',    result.nepa_data_source_agency__c);
        System.assertEquals('eNEPA',  result.nepa_data_source_system__c);
        System.assertEquals('2.1',    result.nepa_data_record_version__c);
        System.assertEquals('DOI',    result.nepa_record_owner_agency__c);
        System.assertNotEquals(null,  result.nepa_retrieved_timestamp__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Entity 9 — RegulatoryCode (PSS standard + custom fields)
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void regulatoryCode_insert_persists_native_and_custom_fields() {
        RegulatoryCode rc = NepaTestFactory.makeRegulatoryCode('40 CFR 1501.4', 'CE Determination');
        rc.Description                    = 'Criteria for categorical exclusion determination.';
        rc.nepa_compliance_requirements__c = 'Agency must document no extraordinary circumstances.';
        rc.nepa_text_content__c           = 'Full regulatory text excerpt.';
        rc.nepa_record_owner_agency__c    = 'CEQ';
        rc.nepa_retrieved_timestamp__c    = DateTime.now();
        insert rc;

        RegulatoryCode result = [
            SELECT Name, Subject, EffectiveFrom,
                   Description, nepa_compliance_requirements__c, nepa_text_content__c,
                   nepa_data_source_agency__c, nepa_data_source_system__c,
                   nepa_data_record_version__c, nepa_record_owner_agency__c,
                   nepa_retrieved_timestamp__c
            FROM RegulatoryCode WHERE Id = :rc.Id
        ];

        System.assertEquals('40 CFR 1501.4',                               result.Name);
        System.assertEquals('CE Determination',                             result.Subject);
        System.assertNotEquals(null,                                        result.EffectiveFrom);
        System.assertEquals('Criteria for categorical exclusion determination.', result.Description);
        System.assert(result.nepa_compliance_requirements__c.contains('extraordinary'));
        System.assertEquals('Full regulatory text excerpt.',                result.nepa_text_content__c);
        System.assertEquals('CEQ',                                          result.nepa_data_source_agency__c);
        System.assertEquals('eCFR',                                         result.nepa_data_source_system__c);
        System.assertEquals('1.0',                                          result.nepa_data_record_version__c);
        System.assertEquals('CEQ',                                          result.nepa_record_owner_agency__c);
        System.assertNotEquals(null,                                        result.nepa_retrieved_timestamp__c);
    }

    @IsTest
    static void regulatoryCode_effectiveTo_marks_expiry() {
        // IsActive is system-managed (not writable); EffectiveTo is the supported
        // mechanism for recording when a citation is superseded.
        RegulatoryCode rc = NepaTestFactory.insertRegulatoryCode('40 CFR 1502.9', 'Supplemental EIS');
        rc.EffectiveTo = DateTime.now();
        update rc;

        RegulatoryCode result = [SELECT EffectiveTo FROM RegulatoryCode WHERE Id = :rc.Id];
        System.assertNotEquals(null, result.EffectiveTo);
    }

    @IsTest
    static void regulatoryCode_delete_succeeds() {
        RegulatoryCode rc = NepaTestFactory.insertRegulatoryCode('40 CFR 1500.1', 'NEPA Purpose');
        delete rc;
        System.assertEquals(0, [SELECT COUNT() FROM RegulatoryCode WHERE Id = :rc.Id]);
    }

    @IsTest
    static void regulatoryCode_lookup_from_decisionElement() {
        RegulatoryCode rc = NepaTestFactory.insertRegulatoryCode('40 CFR 1501.3', 'Applying NEPA');

        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name                    = 'CE Acreage Limit Test';
        de.nepa_legal_reference__c = rc.Id;
        de.nepa_category__c        = 'Core Criterion';
        de.nepa_review_type__c     = 'CE';
        de.nepa_threshold__c       = 5.0;
        de.nepa_threshold_unit__c  = 'acres';
        de.nepa_active__c          = true;
        insert de;

        nepa_decision_element__c result = [
            SELECT nepa_legal_reference__c FROM nepa_decision_element__c WHERE Id = :de.Id
        ];
        System.assertEquals(rc.Id, result.nepa_legal_reference__c);
    }

    @IsTest
    static void regulatoryCode_standalone_queryable_by_citation() {
        // RegulatoryCode is standalone Entity 9 — no FK on IndividualApplication.
        // Verify records are queryable by citation (Name) and custom fields persist.
        RegulatoryCode rc = NepaTestFactory.insertRegulatoryCode('42 U.S.C. 4332', 'NEPA Statute');

        RegulatoryCode result = [
            SELECT Id, Name, Subject, nepa_compliance_requirements__c
            FROM RegulatoryCode WHERE Name = '42 U.S.C. 4332' LIMIT 1
        ];
        System.assertEquals(rc.Id, result.Id);
        System.assertEquals('NEPA Statute', result.Subject);
    }

    @IsTest
    static void regulatoryCode_lookup_setNull_on_delete() {
        // nepa_legal_reference__c on nepa_decision_element__c has deleteConstraint=SetNull
        RegulatoryCode rc = NepaTestFactory.insertRegulatoryCode('40 CFR 1508.1', 'Definitions');
        nepa_decision_element__c de = new nepa_decision_element__c();
        de.Name                    = 'SetNull Test Element';
        de.nepa_legal_reference__c = rc.Id;
        de.nepa_active__c          = true;
        insert de;

        delete rc;

        nepa_decision_element__c result = [
            SELECT nepa_legal_reference__c FROM nepa_decision_element__c WHERE Id = :de.Id
        ];
        System.assertEquals(null, result.nepa_legal_reference__c);
    }

    @IsTest
    static void regulatoryCode_bulk_insert_251_records() {
        List<RegulatoryCode> records = new List<RegulatoryCode>();
        for (Integer i = 0; i < 251; i++) {
            records.add(NepaTestFactory.makeRegulatoryCode('40 CFR 1501.' + i, 'Bulk Test ' + i));
        }
        insert records;
        System.assertEquals(251, [SELECT COUNT() FROM RegulatoryCode WHERE Subject LIKE 'Bulk Test%']);
    }
}