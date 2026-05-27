@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaPermitSLAMonitorTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('NEPA-SLA-001', 'SLA Monitor Test', 'BLM');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
    }

    // ── Overdue permit → Task created ─────────────────────────────────────────

    @IsTest
    static void overduePermit_taskCreated() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(-1));

        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, Priority, Status, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(), 'One overdue Task must be created for the overdue permit');
        Task t = tasks[0];
        System.assert(t.Subject.startsWith('Permit SLA Overdue: '), 'Task Subject must start with "Permit SLA Overdue: "');
        System.assertEquals('High', t.Priority, 'Task Priority must be High');
        System.assertEquals('Not Started', t.Status, 'Task Status must be Not Started');
        System.assertEquals(ia.Id, t.WhatId, 'Task WhatId must be the parent IA');
    }

    // ── Non-overdue permit → no Task ──────────────────────────────────────────

    @IsTest
    static void futureSlaDueDate_noTaskCreated() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(30));

        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(), 'No Task must be created when SLA due date is in the future');
    }

    // ── Issued/Denied/Withdrawn permits → excluded ────────────────────────────

    @IsTest
    static void resolvedPermits_noTaskCreated() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Issued',    true, Date.today().addDays(-5));
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Denied',    true, Date.today().addDays(-5));
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Withdrawn', true, Date.today().addDays(-5));

        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(), 'Issued/Denied/Withdrawn permits must not generate Tasks');
    }

    // ── Non-critical permit → excluded ────────────────────────────────────────

    @IsTest
    static void nonCriticalOverduePermit_noTaskCreated() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', false, Date.today().addDays(-1));

        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(), 'Non-critical-path permits must not generate Tasks');
    }

    // ── No overdue permits → no Tasks (clean exit) ────────────────────────────

    @IsTest
    static void noOverduePermits_noTasksCreated() {
        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task];
        System.assertEquals(0, tasks.size(), 'No Tasks must be created when there are no overdue permits');
    }

    // ── Multiple overdue permits → one Task each ──────────────────────────────

    @IsTest
    static void multipleOverduePermits_oneTaskEach() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(-1));
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', true, Date.today().addDays(-3));
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Under Review', true, Date.today().addDays(-7));

        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(3, tasks.size(), 'One Task must be created per overdue permit');
        for (Task t : tasks) {
            System.assert(t.Subject.startsWith('Permit SLA Overdue: '),
                'Every Task Subject must start with "Permit SLA Overdue: "');
        }
    }

    // ── Mixed: overdue + non-overdue → only overdue gets a Task ──────────────

    @IsTest
    static void mixedPermits_onlyOverdueGetsTask() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(-1));  // overdue
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(30)); // not overdue
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Issued',      true, Date.today().addDays(-1)); // resolved

        Test.startTest();
        Flow.Interview flow = Flow.Interview.createInterview('NEPA_Permit_SLA_Monitor', new Map<String, Object>());
        flow.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(), 'Exactly one Task must be created: only the overdue+active critical permit');
    }
}