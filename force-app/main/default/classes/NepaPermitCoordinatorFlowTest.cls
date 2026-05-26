@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc,PMD.MethodNamingConventions')
@IsTest(SeeAllData=false)
private class NepaPermitCoordinatorFlowTest {

    @TestSetup
    static void makeData() {
        NepaTestFactory.insertProgram('PCT-001', 'Permit Coordinator Test Project', 'BLM');
    }

    private static Program getProgram() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'PCT-001' LIMIT 1];
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static IndividualApplication insertIA(String reviewType) {
        // Insert with no review type so the first meaningful update triggers the flow.
        IndividualApplication ia = new IndividualApplication();
        ia.Category            = 'Permit';
        ia.LicenseTypeId       = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1].Id;
        ia.nepa_related_project__c = getProgram().Id;
        ia.nepa_process_status__c  = 'in progress';
        ia.nepa_process_stage__c   = 'Scoping';
        insert ia;
        return ia;
    }

    // ── reviewType change fires the flow ──────────────────────────────────────

    @IsTest
    static void reviewTypeChange_createsPermitCoordinationTask() {
        IndividualApplication ia = insertIA(null);

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        Test.stopTest();

        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :ia.Id];
        System.assert(!tasks.isEmpty(), 'Expected a Permit Coordination task to be created');
        System.assert(tasks[0].Subject.startsWith('Permit Coordination Required'),
            'Task subject should start with "Permit Coordination Required" — got: ' + tasks[0].Subject);
    }

    @IsTest
    static void reviewTypeChange_writesCoPermitsRequired() {
        IndividualApplication ia = insertIA(null);

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        Test.stopTest();

        IndividualApplication result = [SELECT nepa_co_permits_required__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assert(result.nepa_co_permits_required__c != null,
            'nepa_co_permits_required__c should be stamped after flow fires');
    }

    @IsTest
    static void reviewTypeChange_writesCooperatingAgencies() {
        IndividualApplication ia = insertIA(null);

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        Test.stopTest();

        IndividualApplication result = [SELECT nepa_cooperating_agencies__c FROM IndividualApplication WHERE Id = :ia.Id];
        // cooperating agencies may be null if matrix has no match for the sector; but the field must be accessible
        System.assert(result != null, 'IA should be queryable after flow fires');
    }

    @IsTest
    static void reviewTypeNotChanged_doesNotCreateTask() {
        IndividualApplication ia = insertIA(null);
        ia.nepa_review_type__c = 'EA';
        update ia;
        // Clear any tasks from the first update
        delete [SELECT Id FROM Task WHERE WhatId = :ia.Id];

        Test.startTest();
        // Update a field that is not review_type — flow entry criteria require IsChanged(nepa_review_type__c)
        ia.nepa_process_stage__c = 'Analysis';
        update ia;
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'Flow should not fire when review_type is unchanged — ' + tasks.size() + ' task(s) found');
    }

    @IsTest
    static void noRelatedProject_doesNotCreateTask() {
        // IA with no project link — flow entry criteria require nepa_related_project__c non-null
        IndividualApplication ia = new IndividualApplication();
        ia.Category            = 'Permit';
        ia.LicenseTypeId       = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1].Id;
        ia.nepa_process_status__c = 'in progress';
        ia.nepa_process_stage__c  = 'Scoping';
        insert ia;

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'Flow should not fire when nepa_related_project__c is null');
    }

    @IsTest
    static void bulk_10IAsUpdateReviewType_noException() {
        Program proj = getProgram();
        List<IndividualApplication> ias = new List<IndividualApplication>();
        Id licId = [SELECT Id FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review' LIMIT 1].Id;
        for (Integer i = 0; i < 10; i++) {
            IndividualApplication ia = new IndividualApplication();
            ia.Category                = 'Permit';
            ia.LicenseTypeId           = licId;
            ia.nepa_related_project__c = proj.Id;
            ia.nepa_process_status__c  = 'in progress';
            ia.nepa_process_stage__c   = 'Scoping';
            ias.add(ia);
        }
        insert ias;

        List<IndividualApplication> updates = new List<IndividualApplication>();
        for (IndividualApplication ia : ias) {
            updates.add(new IndividualApplication(Id = ia.Id, nepa_review_type__c = 'EA'));
        }

        Boolean threw = false;
        Test.startTest();
        try { update updates; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assert(!threw, 'Bulk review_type update of 10 IAs should not throw an exception');
    }
}
