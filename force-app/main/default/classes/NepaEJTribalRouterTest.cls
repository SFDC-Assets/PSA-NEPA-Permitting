@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
/**
 * Tests for NEPA_EJTribal_Router invocable flow.
 * Uses Flow.Interview.createInterview() — requires the flow to be deployed and Active.
 *
 * Coverage requirements (MFR 8 / EO 12898 / OMB M-24-10):
 *   - EJ routing: creates Task assigned to EJ queue (or fallback triage queue)
 *   - Task due date is 14 calendar days from today
 *   - Task priority is High; status is Not Started
 *   - Comment record gets nepa_is_ej_comment__c = true
 *   - Comment record gets nepa_requires_human_review__c = true
 *   - Comment record gets nepa_ai_triage_status__c = EJ-Routed
 *   - out_Routed = true; out_QueueName is non-blank
 *   - Missing CommentId: flow still sets flags (guard handled by router internals)
 */
private class NepaEJTribalRouterTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static PublicComplaint makeComment(Id processId, String body) {
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = processId;
        pc.nepa_comment_body__c    = body;
        pc.ReceivedDate            = Date.today();
        insert pc;
        return pc;
    }

    private static Map<String, Object> ejInputs(Id commentId, String triggers, String details) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('inp_CommentId',      commentId);
        m.put('inp_EJTriggers',     triggers);
        m.put('inp_TriggerDetails', details);
        return m;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void ejComment_creates_responseTask() {
        Program proj = NepaTestFactory.insertProgram('EJ-001', 'EJ Router Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        PublicComplaint pc = makeComment(ia.Id,
            'This project threatens tribal sovereignty and our treaty rights on ancestral lands.');

        Map<String, Object> inputs = ejInputs(
            pc.Id,
            'Tribal Sovereignty',
            'Mandatory human review required: Tribal Sovereignty. Comment contains language triggering EJ/tribal sovereignty escalation protocols.'
        );

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_EJTribal_Router', inputs);
        interview.start();
        Test.stopTest();

        Boolean routed    = (Boolean) interview.getVariableValue('out_Routed');
        String queueName  = (String)  interview.getVariableValue('out_QueueName');

        System.assertEquals(true, routed, 'out_Routed must be true when EJ router creates a task');
        System.assertNotEquals(null, queueName, 'out_QueueName must be set when a queue is found');
        System.assert(String.isNotBlank(queueName), 'out_QueueName must be non-blank');

        List<Task> tasks = [SELECT Subject, Priority, Status, ActivityDate FROM Task WHERE WhatId = :pc.Id];
        System.assertEquals(1, tasks.size(), 'Exactly one Task must be created for EJ/tribal comment');
        System.assertEquals('High', tasks[0].Priority, 'EJ response task must have High priority');
        System.assertEquals('Not Started', tasks[0].Status, 'Task status must be Not Started');

        Date expectedDue = Date.today().addDays(14);
        System.assertEquals(expectedDue, tasks[0].ActivityDate,
            'EJ task due date must be TODAY() + 14 days');
    }

    @IsTest
    static void ejComment_sets_ejFlag_and_humanReview() {
        Program proj = NepaTestFactory.insertProgram('EJ-002', 'EJ Flags Test', 'USFS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        PublicComplaint pc = makeComment(ia.Id,
            'The cumulative impact on this low-income fence line community is disproportionate and unjust.');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_EJTribal_Router',
            ejInputs(pc.Id, 'Environmental Justice, Low-Income Impact', 'See comment body')
        );
        interview.start();
        Test.stopTest();

        PublicComplaint result = [
            SELECT nepa_is_ej_comment__c, nepa_requires_human_review__c,
                   nepa_ai_triage_status__c, nepa_ai_triage_rationale__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];

        System.assertEquals(true, result.nepa_is_ej_comment__c,
            'nepa_is_ej_comment__c must be true after EJ routing');
        System.assertEquals(true, result.nepa_requires_human_review__c,
            'nepa_requires_human_review__c must be true for all EJ/tribal comments');
        System.assertEquals('EJ-Routed', result.nepa_ai_triage_status__c,
            'nepa_ai_triage_status__c must be EJ-Routed');
        System.assert(String.isNotBlank(result.nepa_ai_triage_rationale__c),
            'Rationale must be populated by the EJ router');
    }

    @IsTest
    static void ejComment_withBlankTriggers_stillCreatesTask() {
        Program proj = NepaTestFactory.insertProgram('EJ-003', 'EJ Blank Triggers Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'CE');
        PublicComplaint pc = makeComment(ia.Id, 'Sacred ground will be disturbed by this project.');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_EJTribal_Router',
            ejInputs(pc.Id, '', '')
        );
        interview.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :pc.Id];
        System.assertEquals(1, tasks.size(), 'Task must be created even when trigger detail strings are blank');

        PublicComplaint result = [
            SELECT nepa_requires_human_review__c FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals(true, result.nepa_requires_human_review__c);
    }

    @IsTest
    static void taskDescription_contains_triggerInfo() {
        Program proj = NepaTestFactory.insertProgram('EJ-004', 'EJ Task Description Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        PublicComplaint pc = makeComment(ia.Id, 'This impacts native american communities near the site.');

        String triggers = 'Tribal Sovereignty';
        String details  = 'Keyword "native american" found in comment body';

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_EJTribal_Router',
            ejInputs(pc.Id, triggers, details)
        );
        interview.start();
        Test.stopTest();

        List<Task> tasks = [SELECT Description FROM Task WHERE WhatId = :pc.Id];
        System.assertEquals(1, tasks.size());
        System.assert(tasks[0].Description.contains('EJ/Tribal'),
            'Task description must reference EJ/Tribal escalation');
        System.assert(tasks[0].Description.contains(triggers),
            'Task description must include the detected trigger categories');
    }

    @IsTest
    static void bulk_5comments_allRouted() {
        Program proj = NepaTestFactory.insertProgram('EJ-005', 'EJ Bulk Test', 'USFS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        List<PublicComplaint> comments = new List<PublicComplaint>();
        for (Integer i = 0; i < 5; i++) {
            comments.add(makeComment(ia.Id, 'Tribal sovereignty and sacred sites are affected by action ' + i));
        }

        List<Task> tasksBefore = [SELECT Id FROM Task];
        Integer taskCountBefore = tasksBefore.size();

        Test.startTest();
        for (PublicComplaint pc : comments) {
            Flow.Interview interview = Flow.Interview.createInterview(
                'NEPA_EJTribal_Router',
                ejInputs(pc.Id, 'Tribal Sovereignty', 'See comment body')
            );
            interview.start();
        }
        Test.stopTest();

        List<Task> tasksAfter = [SELECT Id FROM Task];
        System.assertEquals(taskCountBefore + 5, tasksAfter.size(),
            'Each of the 5 EJ comments must generate exactly one response Task');
    }
}