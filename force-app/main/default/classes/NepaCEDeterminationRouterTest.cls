@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaCEDeterminationRouterTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('CEDR-001', 'CE Determination Router Test', 'BLM');
    }

    private static Program getProgram() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'CEDR-001' LIMIT 1];
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static IndividualApplication insertBaseIA() {
        Program proj = getProgram();
        return NepaTestFactory.insertProcess(proj.Id, 'CE', null, null);
    }

    private static void setScreeningFields(IndividualApplication ia, String recommendation, String confidence) {
        ia.nepa_ce_pathway_recommendation__c = recommendation;
        ia.nepa_screening_confidence__c      = confidence;
        ia.nepa_classification_basis__c      = 'AI Screening';
        update ia;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void highConfidenceCE_createsTimelineEventAndTask() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'CE-Recommended', 'High');
        Test.stopTest();

        List<ApplicationTimeline> events = [
            SELECT Id, nepa_event_type__c FROM ApplicationTimeline
            WHERE nepa_related_process__c = :ia.Id
            AND nepa_event_type__c = 'CE Determination'
        ];
        System.assert(events.size() > 0, 'CE Determination ApplicationTimeline event must be created for High confidence CE');

        List<Task> tasks = [
            SELECT Subject FROM Task WHERE WhatId = :ia.Id
            AND Subject = 'Activate CE Process Milestones Action Plan'
        ];
        System.assert(tasks.size() > 0, 'Task with subject Activate CE Process Milestones Action Plan must be created');
    }

    @IsTest
    static void highConfidenceCE_taskHasNormalPriority() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'CE-Recommended', 'High');
        Test.stopTest();

        List<Task> tasks = [
            SELECT Priority FROM Task WHERE WhatId = :ia.Id
            AND Subject = 'Activate CE Process Milestones Action Plan'
        ];
        System.assert(tasks.size() > 0, 'Task must exist before asserting priority');
        System.assertEquals('Normal', tasks[0].Priority, 'CE milestones task must have Normal priority for High confidence');
    }

    @IsTest
    static void mediumHighConfidenceCE_takesHighConfidencePath() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'CE-Recommended', 'Medium-High');
        Test.stopTest();

        List<ApplicationTimeline> events = [
            SELECT Id FROM ApplicationTimeline
            WHERE nepa_related_process__c = :ia.Id
            AND nepa_event_type__c = 'CE Determination'
        ];
        System.assert(events.size() > 0, 'Medium-High confidence must follow the high-confidence path and create a CE Determination timeline event');
    }

    @IsTest
    static void mediumConfidenceCE_createsCoordinatorReviewTaskOnly() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'CE-Recommended', 'Medium');
        Test.stopTest();

        List<ApplicationTimeline> events = [
            SELECT Id FROM ApplicationTimeline
            WHERE nepa_related_process__c = :ia.Id
            AND nepa_event_type__c = 'CE Determination'
        ];
        System.assertEquals(0, events.size(), 'No CE Determination timeline event must be created for Medium confidence');

        List<Task> tasks = [
            SELECT Subject FROM Task WHERE WhatId = :ia.Id
            AND Subject = 'Review CE Screening — Manual Confirmation Required'
        ];
        System.assert(tasks.size() > 0, 'Coordinator review task must be created for Medium confidence CE');
    }

    @IsTest
    static void mediumConfidenceCE_taskIsHighPriority() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'CE-Recommended', 'Medium');
        Test.stopTest();

        List<Task> tasks = [
            SELECT Priority FROM Task WHERE WhatId = :ia.Id
            AND Subject = 'Review CE Screening — Manual Confirmation Required'
        ];
        System.assert(tasks.size() > 0, 'Task must exist before asserting priority');
        System.assertEquals('High', tasks[0].Priority, 'Manual confirmation task must have High priority for Medium confidence CE');
    }

    @IsTest
    static void eaRequired_createsScopingTask() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'EA-Required', 'Low');
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task WHERE WhatId = :ia.Id
            AND Subject = 'Initiate Full NEPA Review — Scope and Document Review Type'
        ];
        System.assert(tasks.size() > 0, 'Scoping task must be created when recommendation is EA-Required');
    }

    @IsTest
    static void eisRequired_createsScopingTask() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'EIS-Required', 'High');
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task WHERE WhatId = :ia.Id
            AND Subject = 'Initiate Full NEPA Review — Scope and Document Review Type'
        ];
        System.assert(tasks.size() > 0, 'Scoping task must be created when recommendation is EIS-Required');
    }

    @IsTest
    static void eaRequired_noTimelineEventCreated() {
        IndividualApplication ia = insertBaseIA();

        Test.startTest();
        setScreeningFields(ia, 'EA-Required', 'Medium');
        Test.stopTest();

        List<ApplicationTimeline> events = [
            SELECT Id FROM ApplicationTimeline
            WHERE nepa_related_process__c = :ia.Id
            AND nepa_event_type__c = 'CE Determination'
        ];
        System.assertEquals(0, events.size(), 'No CE Determination ApplicationTimeline must be created when recommendation is EA-Required');
    }
}
