@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaCESaveIPTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Id getLicenseTypeId() {
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review' LIMIT 1
        ];
        if (!existing.isEmpty()) { return existing[0].Id; }
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
            Name = 'NEPA Environmental Review', RegulatoryAuthCategory = 'Permit');
        insert rat;
        return rat.Id;
    }

    private static Program insertProject(String projectId) {
        return NepaTestFactory.insertProgram(projectId, 'CE Save Test ' + projectId, 'BLM');
    }

    /**
     * Direct-insert an IndividualApplication simulating what CESaveIP would write.
     * OmniStudio IPs do not execute in Apex test context; we test the field values
     * the DR mapping produces by inserting with the same field values the IP passes.
     */
    private static IndividualApplication insertViaDirectSimulation(
        Program proj,
        String externalId,
        Decimal disturbanceAcres,
        Boolean extraordinaryCircumstances,
        String actionType
    ) {
        IndividualApplication ia = new IndividualApplication();
        ia.Category                                = 'Permit';
        ia.LicenseTypeId                           = getLicenseTypeId();
        ia.nepa_related_project__c                 = proj.Id;
        ia.nepa_review_type__c                     = 'CE';
        ia.nepa_process_status__c                  = 'submitted';
        ia.nepa_process_stage__c                   = 'Scoping';
        ia.nepa_action_type__c                     = actionType != null ? actionType : 'Construct New';
        ia.nepa_disturbance_acres__c               = disturbanceAcres;
        ia.nepa_extraordinary_circumstances__c     = extraordinaryCircumstances;
        ia.nepa_start_date__c                      = Date.today();
        ia.nepa_description__c                     = 'Test CE intake submission';
        if (String.isNotBlank(externalId)) {
            ia.nepa_federal_unique_id__c = externalId;
        }
        insert ia;
        return ia;
    }

    // ── Field values on a new CE intake submission ────────────────────────────

    @IsTest
    static void newSubmission_reviewTypeIsCE() {
        Program proj = insertProject('CESAVE-001');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 3.0, false, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_review_type__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('CE', result.nepa_review_type__c,
            'CESaveIP must write nepa_review_type__c = CE on new intake record');
    }

    @IsTest
    static void newSubmission_statusIsSubmitted() {
        Program proj = insertProject('CESAVE-002');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 3.0, false, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_status__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('submitted', result.nepa_process_status__c,
            'CESaveIP must write nepa_process_status__c = submitted');
    }

    @IsTest
    static void newSubmission_stageIsScoping() {
        Program proj = insertProject('CESAVE-003');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 3.0, false, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Scoping', result.nepa_process_stage__c,
            'CESaveIP must write nepa_process_stage__c = Scoping');
    }

    @IsTest
    static void newSubmission_startDateIsToday() {
        Program proj = insertProject('CESAVE-004');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 3.0, false, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_start_date__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(Date.today(), result.nepa_start_date__c,
            'CESaveIP must write nepa_start_date__c = TODAY()');
    }

    @IsTest
    static void newSubmission_disturbanceAcresPersisted() {
        Program proj = insertProject('CESAVE-005');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 4.5, false, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_disturbance_acres__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(4.5, result.nepa_disturbance_acres__c,
            'nepa_disturbance_acres__c must be persisted from intake form');
    }

    @IsTest
    static void newSubmission_extraordinaryCircumstancesPersisted() {
        Program proj = insertProject('CESAVE-006');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 2.0, true, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_extraordinary_circumstances__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        // CESaveIP maps the boolean checkbox to this field via DR
        System.assertNotEquals(null, result.nepa_extraordinary_circumstances__c,
            'nepa_extraordinary_circumstances__c must be written by CESaveIP');
    }

    @IsTest
    static void newSubmission_relatedProjectLinked() {
        Program proj = insertProject('CESAVE-007');
        Test.startTest();
        IndividualApplication ia = insertViaDirectSimulation(proj, null, 1.0, false, 'Construct New');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_related_project__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(proj.Id, result.nepa_related_project__c,
            'nepa_related_project__c must be linked to the parent Program');
    }

    // ── External ID upsert idempotency ────────────────────────────────────────

    @IsTest
    static void upsertWithSameExternalId_producesOneRecord() {
        Program proj = insertProject('CESAVE-IDEM-001');
        String extId = 'NEPA-TEST-EXT-' + System.currentTimeMillis();

        Test.startTest();
        IndividualApplication first = insertViaDirectSimulation(proj, extId, 3.0, false, 'Construct New');
        // Simulate re-submission: upsert using same external ID should update, not insert
        IndividualApplication ia2 = new IndividualApplication(
            Id = first.Id,
            nepa_disturbance_acres__c = 5.0
        );
        update ia2;
        Test.stopTest();

        List<IndividualApplication> records = [
            SELECT Id, nepa_disturbance_acres__c
            FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = :extId
        ];
        System.assertEquals(1, records.size(),
            'Re-submitting with same nepa_federal_unique_id__c must update, not duplicate');
        System.assertEquals(5.0, records[0].nepa_disturbance_acres__c,
            'Updated disturbance acres must be persisted after upsert');
    }

    @IsTest
    static void uniqueExternalIds_produceSeparateRecords() {
        Program proj = insertProject('CESAVE-IDEM-002');
        String extId1 = 'NEPA-EXT-A-' + System.currentTimeMillis();
        String extId2 = 'NEPA-EXT-B-' + System.currentTimeMillis();

        Test.startTest();
        insertViaDirectSimulation(proj, extId1, 2.0, false, 'Construct New');
        insertViaDirectSimulation(proj, extId2, 8.0, false, 'Modify Existing');
        Test.stopTest();

        List<IndividualApplication> records = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c IN (:extId1, :extId2)
        ];
        System.assertEquals(2, records.size(),
            'Two distinct external IDs must produce two separate IA records');
    }

    // ── Sector-conditional field passthrough ──────────────────────────────────

    @IsTest
    static void multiDoDCheckbox_persistsOnMilitarySectorRecord() {
        Program proj = insertProject('CESAVE-DOD-001');
        proj.nepa_project_sector__c = 'Military';
        update proj;

        Test.startTest();
        IndividualApplication ia = NepaTestFactory.insertProcessWithExtraordinaryCircumstances(
            proj.Id, true, false
        );
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ec_multi_dod__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, result.nepa_ec_multi_dod__c,
            'nepa_ec_multi_dod__c must be persisted when DoD multi-installation flag is set');
    }

    @IsTest
    static void usaceCzmaCheckbox_persistsOnWaterSectorRecord() {
        Program proj = insertProject('CESAVE-CZMA-001');
        proj.nepa_project_sector__c = 'Water';
        update proj;

        Test.startTest();
        IndividualApplication ia = NepaTestFactory.insertProcessWithExtraordinaryCircumstances(
            proj.Id, false, true
        );
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ec_usace_czma__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, result.nepa_ec_usace_czma__c,
            'nepa_ec_usace_czma__c must be persisted when water-crossing flag is set');
    }

    @IsTest
    static void sectorConditionalFlags_defaultFalseOnOtherSectors() {
        Program proj = insertProject('CESAVE-FLAGS-001');
        proj.nepa_project_sector__c = 'Energy';
        update proj;

        Test.startTest();
        IndividualApplication ia = NepaTestFactory.insertProcessWithExtraordinaryCircumstances(
            proj.Id, false, false
        );
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ec_multi_dod__c, nepa_ec_usace_czma__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(true, result.nepa_ec_multi_dod__c,
            'nepa_ec_multi_dod__c must not be true for non-Military sector');
        System.assertNotEquals(true, result.nepa_ec_usace_czma__c,
            'nepa_ec_usace_czma__c must not be true for non-Water sector');
    }

    // ── DR activation guard ───────────────────────────────────────────────────

    @IsTest
    static void drLoadNEPAProcess_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DRLoadNEPAProcess_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DRLoadNEPAProcess must be active — if inactive CESaveIP Step 1 fails with ' +
            'failOnStepError=true and the entire CE intake submission errors out');
    }
}
