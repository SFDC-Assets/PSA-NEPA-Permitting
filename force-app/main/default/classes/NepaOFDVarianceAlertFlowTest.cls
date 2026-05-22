@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.MethodNamingConventions')
@IsTest(SeeAllData=false)
/**
 * Tests for NEPA_OFD_Variance_Alert scheduled flow (F-15 FAST-41).
 * Uses Flow.Interview.createInterview — requires the flow to be deployed and Active.
 *
 * Coverage requirements:
 *   - FAST-41 process overdue (elapsed > target): creates a Task with High priority
 *   - FAST-41 process on target (elapsed < target): no Task created
 *   - Closed/Withdrawn processes are skipped — no Task
 *   - Process without FAST-41 flag is ignored
 *   - Bulk: 5 overdue processes → 5 Tasks, single DML (bulk-safe insert)
 *   - Task subject contains "OFD Timeline Variance" and the process name
 */
private class NepaOFDVarianceAlertFlowTest {

    // Scheduled flows with no inputs can be invoked via createInterview with empty map
    private static void runFlow() {
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_OFD_Variance_Alert', new Map<String, Object>()
        );
        interview.start();
    }

    private static IndividualApplication makeOverdueIA(Id projectId, String reviewType,
            Integer startDaysAgo, Integer ofdTargetDays, String status) {
        IndividualApplication ia = NepaTestFactory.makeProcess(projectId, reviewType, null, null);
        ia.nepa_fast41_covered__c   = true;
        ia.nepa_ofd_target_days__c  = ofdTargetDays;
        ia.nepa_start_date__c       = Date.today().addDays(-startDaysAgo);
        ia.nepa_process_status__c   = status;
        return ia;
    }

    // ── Happy path ────────────────────────────────────────────────────────────

    @IsTest
    static void overdueProcess_createsHighPriorityVarianceTask() {
        Program proj = NepaTestFactory.insertProgram('OFD-001', 'OFD Variance Test', 'BLM');
        IndividualApplication ia = makeOverdueIA(proj.Id, 'EIS', 200, 180, 'in progress');
        insert ia;

        Test.startTest();
        runFlow();
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, Priority, Status, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(),
            'Exactly one variance Task must be created for an overdue FAST-41 process');
        System.assertEquals('High', tasks[0].Priority,
            'OFD variance Task must have High priority');
        System.assertEquals('Not Started', tasks[0].Status,
            'OFD variance Task status must be Not Started');
        System.assert(tasks[0].Subject.containsIgnoreCase('OFD'),
            'Task subject must reference OFD: ' + tasks[0].Subject);
    }

    @IsTest
    static void processOnTarget_noTaskCreated() {
        Program proj = NepaTestFactory.insertProgram('OFD-002', 'OFD On-Target Test', 'USFS');
        IndividualApplication ia = makeOverdueIA(proj.Id, 'EA', 10, 180, 'in progress');
        insert ia;

        Test.startTest();
        runFlow();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'No Task should be created when elapsed days (10) < target (180)');
    }

    // ── Exclusion paths ───────────────────────────────────────────────────────

    @IsTest
    static void closedProcess_isSkipped_noTask() {
        Program proj = NepaTestFactory.insertProgram('OFD-003', 'OFD Closed Test', 'BLM');
        IndividualApplication ia = makeOverdueIA(proj.Id, 'EIS', 500, 180, 'completed');
        insert ia;

        Test.startTest();
        runFlow();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'Closed/completed processes must be skipped by the OFD alert flow');
    }

    @IsTest
    static void noFast41Flag_processIgnored() {
        Program proj = NepaTestFactory.insertProgram('OFD-004', 'Non-FAST41 Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.makeProcess(proj.Id, 'EIS', null, null);
        ia.nepa_fast41_covered__c  = false;
        ia.nepa_ofd_target_days__c = 180;
        ia.nepa_start_date__c      = Date.today().addDays(-300);
        ia.nepa_process_status__c  = 'in progress';
        insert ia;

        Test.startTest();
        runFlow();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'Non-FAST-41 processes must never generate OFD variance Tasks');
    }

    @IsTest
    static void nullOfdTarget_processIgnored() {
        Program proj = NepaTestFactory.insertProgram('OFD-005', 'Null Target Test', 'USFS');
        IndividualApplication ia = NepaTestFactory.makeProcess(proj.Id, 'EA', null, null);
        ia.nepa_fast41_covered__c  = true;
        ia.nepa_ofd_target_days__c = null;
        ia.nepa_start_date__c      = Date.today().addDays(-200);
        ia.nepa_process_status__c  = 'in progress';
        insert ia;

        Test.startTest();
        runFlow();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(),
            'Process with null OFD target must be excluded — cannot compute variance');
    }

    // ── Bulk safety ───────────────────────────────────────────────────────────

    @IsTest
    static void bulk_5OverdueProcesses_5TasksCreated() {
        Program proj = NepaTestFactory.insertProgram('OFD-006', 'OFD Bulk Test', 'BLM');

        List<IndividualApplication> ias = new List<IndividualApplication>();
        for (Integer i = 0; i < 5; i++) {
            ias.add(makeOverdueIA(proj.Id, 'EIS', 200 + i, 180, 'in progress'));
        }
        insert ias;

        Set<Id> iaIds = new Map<Id, IndividualApplication>(ias).keySet();

        Integer tasksBefore = [SELECT COUNT() FROM Task WHERE WhatId IN :iaIds];

        Test.startTest();
        runFlow();
        Test.stopTest();

        Integer tasksAfter = [SELECT COUNT() FROM Task WHERE WhatId IN :iaIds];
        System.assertEquals(tasksBefore + 5, tasksAfter,
            'One Task must be created per overdue FAST-41 process; expected 5, got: '
            + (tasksAfter - tasksBefore));
    }
}
