@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaStageGateOrchestratorTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('SGO-001', 'Stage Gate Orchestrator Test', 'BLM');
    }

    private static Program getProgram() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'SGO-001' LIMIT 1];
    }

    private static IndividualApplication makeIAAtStage(Id projId, String stage, String reviewType) {
        IndividualApplication ia = NepaTestFactory.makeProcess(projId, reviewType, null, null);
        ia.nepa_process_stage__c = stage;
        insert ia;
        return ia;
    }

    private static void completeTimelineEvent(Id iaId, String eventType) {
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                    = 'Test Event ' + eventType;
        evt.nepa_event_type__c      = eventType;
        evt.nepa_status__c          = 'Completed';
        evt.nepa_tier__c            = '1';
        evt.nepa_source__c          = 'Test';
        evt.nepa_start_date__c      = Date.today().addDays(-10);
        evt.nepa_public_access__c   = true;
        evt.nepa_related_process__c = iaId;
        insert evt;
    }

    // ── Stage sequence tests ──────────────────────────────────────────────────

    @IsTest
    static void intake_completedEvent_advancesToScoping() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Intake', 'EIS');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Intake Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Scoping', result.nepa_process_stage__c,
            'Intake completed event must advance stage to Scoping');
    }

    @IsTest
    static void scoping_completedEvent_advancesToAnalysis() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Scoping', 'EIS');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Scoping Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Analysis', result.nepa_process_stage__c,
            'Scoping completed event must advance stage to Analysis');
    }

    @IsTest
    static void analysis_completedEvent_advancesToReview() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Analysis', 'EIS');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Analysis Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Review', result.nepa_process_stage__c,
            'Analysis completed event must advance stage to Review');
    }

    @IsTest
    static void review_completedEvent_advancesToDecision() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Review', 'EIS');
        // Satisfy climate gate so flow can advance to Decision
        ia.nepa_climate_assessment_complete__c = true;
        update ia;

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Review Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Decision', result.nepa_process_stage__c,
            'Review completed event must advance stage to Decision');
    }

    @IsTest
    static void decision_completedEvent_advancesToClosed() {
        Program proj = getProgram();
        // Insert at non-Decision stage first
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Review', 'EIS');
        // Complete climate assessment, then advance stage to Decision
        ia.nepa_climate_assessment_complete__c = true;
        ia.nepa_process_stage__c = 'Decision';
        update ia;

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Decision Issued');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Closed', result.nepa_process_stage__c,
            'Decision completed event must advance stage to Closed');
    }

    @IsTest
    static void screening_completedEvent_advancesToCEDetermination() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Screening', 'CE');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Screening Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('CE Determination', result.nepa_process_stage__c,
            'Screening completed event must advance CE pathway stage to CE Determination');
    }

    @IsTest
    static void ceDetermination_completedEvent_advancesToDecision() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'CE Determination', 'CE');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'CE Determination Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('Decision', result.nepa_process_stage__c,
            'CE Determination completed event must advance stage to Decision');
    }

    // ── Metadata stamp tests ──────────────────────────────────────────────────

    @IsTest
    static void completedEvent_stampsLastStageTransition() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Scoping', 'EIS');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Scoping Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_last_stage_transition__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(null, result.nepa_last_stage_transition__c,
            'nepa_last_stage_transition__c must be stamped after a stage gate transition');
    }

    @IsTest
    static void completedEvent_setsIdempotencyFlag() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Scoping', 'EIS');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Scoping Complete');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_stage_gate_processed__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, result.nepa_stage_gate_processed__c,
            'nepa_stage_gate_processed__c must be set to true after stage gate runs');
    }

    // ── Task creation test ────────────────────────────────────────────────────

    @IsTest
    static void completedEvent_createsNextStageTask() {
        Program proj = getProgram();
        IndividualApplication ia = makeIAAtStage(proj.Id, 'Scoping', 'EIS');

        Test.startTest();
        completeTimelineEvent(ia.Id, 'Scoping Complete');
        Test.stopTest();

        IndividualApplication iaAfter = [SELECT nepa_process_stage__c, nepa_stage_gate_processed__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assert(iaAfter.nepa_process_stage__c == 'Analysis', 'Stage should be Analysis but was: ' + iaAfter.nepa_process_stage__c + ' processed=' + iaAfter.nepa_stage_gate_processed__c);

        // Verify basic Task creation works in this test context
        Task directTask = new Task();
        directTask.Subject = 'Direct Test Task';
        directTask.WhatId = ia.Id;
        directTask.Status = 'Not Started';
        directTask.Priority = 'Normal';
        insert directTask;
        List<Task> directTasks = [SELECT Subject FROM Task WHERE WhatId = :ia.Id AND Subject = 'Direct Test Task'];
        System.assert(directTasks.size() == 1, 'Direct Task insert works: ' + directTasks.size());

        List<Task> allTasks = [SELECT Subject, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.debug('All tasks on IA: ' + allTasks.size());
        for (Task t : allTasks) System.debug('Task subject: [' + t.Subject + ']');

        List<Task> tasks = [
            SELECT Subject, WhatId
            FROM Task
            WHERE WhatId = :ia.Id
            AND Subject = 'Begin Analysis stage'
        ];
        System.assertEquals(1, tasks.size(),
            'Exactly one "Begin Analysis stage" task must be created after Scoping completes; allTasks=' + allTasks.size() + ' subjects=' + allTasks);
        System.assertEquals(ia.Id, tasks[0].WhatId,
            'Task WhatId must reference the parent IndividualApplication');
    }
}
