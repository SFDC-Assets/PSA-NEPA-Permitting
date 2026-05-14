@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
/**
 * Tests for NEPA_Comment_ResponseTask_Creator invocable flow.
 * Uses Flow.Interview.createInterview() — requires the flow to be deployed and Active.
 *
 * Coverage requirements (MFR 8):
 *   - Substantive comment → Task created with 30-day due date; out_Created = true
 *   - Substantive comment with explicit inp_ResponseDue → Task uses that date
 *   - Non-substantive comment → no Task created; out_Created = false
 *   - Null CommentId → no Task created; out_Created = false
 *   - Task properties: High priority, Not Started, WhatId = comment, OwnerId = NEPA_Coordinator queue
 *   - After Task creation → nepa_response_status__c = Pending on the PublicComplaint
 */
private class NepaCommentResponseTaskTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static PublicComplaint makeComment(Id processId) {
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = processId;
        pc.nepa_comment_body__c    = 'This agency must conduct additional analysis of cumulative impacts on the watershed before proceeding.';
        pc.nepa_date_submitted__c  = Date.today();
        insert pc;
        return pc;
    }

    private static Map<String, Object> taskInputs(Id commentId, Boolean isSubstantive, Date responseDue) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('inp_CommentId',    commentId == null ? null : String.valueOf(commentId));
        m.put('inp_IsSubstantive', isSubstantive);
        if (responseDue != null) {
            m.put('inp_ResponseDue', responseDue);
        }
        return m;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void substantiveComment_creates_task() {
        Program proj = NepaTestFactory.insertProgram('RT-001', 'Response Task Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        PublicComplaint pc = makeComment(ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_Comment_ResponseTask_Creator',
            taskInputs(pc.Id, true, null)
        );
        interview.start();
        Test.stopTest();

        Boolean created = (Boolean) interview.getVariableValue('out_Created');
        String taskId   = (String)  interview.getVariableValue('out_TaskId');

        System.assertEquals(true, created, 'out_Created must be true for substantive comment');
        System.assertNotEquals(null, taskId, 'out_TaskId must be set when Task is created');

        List<Task> tasks = [SELECT Priority, Status, ActivityDate, WhatId FROM Task WHERE Id = :taskId];
        System.assertEquals(1, tasks.size());
        System.assertEquals('High', tasks[0].Priority, 'Response task must be High priority');
        System.assertEquals('Not Started', tasks[0].Status);
        System.assertEquals(pc.Id, tasks[0].WhatId, 'WhatId must be the PublicComplaint');

        Date expectedDue = Date.today().addDays(30);
        System.assertEquals(expectedDue, tasks[0].ActivityDate,
            'Default due date must be TODAY() + 30 days');
    }

    @IsTest
    static void substantiveComment_withExplicitDueDate_uses_providedDate() {
        Program proj = NepaTestFactory.insertProgram('RT-002', 'Response Due Date Test', 'USFS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        PublicComplaint pc = makeComment(ia.Id);

        Date customDue = Date.today().addDays(45);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_Comment_ResponseTask_Creator',
            taskInputs(pc.Id, true, customDue)
        );
        interview.start();
        Test.stopTest();

        Boolean created = (Boolean) interview.getVariableValue('out_Created');
        System.assertEquals(true, created);

        List<Task> tasks = [SELECT ActivityDate FROM Task WHERE WhatId = :pc.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals(customDue, tasks[0].ActivityDate,
            'When inp_ResponseDue is provided it must override the 30-day default');
    }

    @IsTest
    static void nonSubstantiveComment_no_task_created() {
        Program proj = NepaTestFactory.insertProgram('RT-003', 'Non-Substantive Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'CE');
        PublicComplaint pc = makeComment(ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_Comment_ResponseTask_Creator',
            taskInputs(pc.Id, false, null)
        );
        interview.start();
        Test.stopTest();

        Boolean created = (Boolean) interview.getVariableValue('out_Created');
        System.assertEquals(false, created, 'Non-substantive comment must not trigger Task creation');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :pc.Id];
        System.assertEquals(0, tasks.size(), 'No Task should exist for a non-substantive comment');
    }

    @IsTest
    static void nullCommentId_no_task_created() {
        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_Comment_ResponseTask_Creator',
            taskInputs(null, true, null)
        );
        interview.start();
        Test.stopTest();

        Boolean created = (Boolean) interview.getVariableValue('out_Created');
        System.assertEquals(false, created, 'Null comment ID must prevent Task creation');
    }

    @IsTest
    static void substantiveComment_sets_responsePending() {
        Program proj = NepaTestFactory.insertProgram('RT-004', 'Response Status Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        PublicComplaint pc = makeComment(ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview(
            'NEPA_Comment_ResponseTask_Creator',
            taskInputs(pc.Id, true, null)
        );
        interview.start();
        Test.stopTest();

        PublicComplaint result = [
            SELECT nepa_response_status__c FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals('Pending', result.nepa_response_status__c,
            'nepa_response_status__c must be set to Pending after task creation');
    }

    @IsTest
    static void bulk_substantiveComments_allGetTasks() {
        Program proj = NepaTestFactory.insertProgram('RT-005', 'Response Bulk Test', 'FHWA');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        List<PublicComplaint> comments = new List<PublicComplaint>();
        for (Integer i = 0; i < 10; i++) {
            comments.add(makeComment(ia.Id));
        }

        Integer tasksBefore = [SELECT COUNT() FROM Task];

        Test.startTest();
        for (PublicComplaint pc : comments) {
            Flow.Interview interview = Flow.Interview.createInterview(
                'NEPA_Comment_ResponseTask_Creator',
                taskInputs(pc.Id, true, null)
            );
            interview.start();
        }
        Test.stopTest();

        Integer tasksAfter = [SELECT COUNT() FROM Task];
        System.assertEquals(tasksBefore + 10, tasksAfter,
            'Each substantive comment must generate exactly one response Task');
    }
}
