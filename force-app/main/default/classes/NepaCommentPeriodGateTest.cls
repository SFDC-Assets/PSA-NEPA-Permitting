@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaCommentPeriodGateTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('CPG-001', 'Comment Period Gate Test', 'BLM');
    }

    private static Program getProgram() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'CPG-001' LIMIT 1];
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static PublicComplaint makeComment(Id processId) {
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                = 'Test Commenter';
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = processId;
        pc.nepa_comment_body__c    = 'This project will have significant environmental impacts on local waterways and surrounding habitat.';
        return pc;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void openPeriod_allowsInsert() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        PublicComplaint pc = makeComment(ia.Id);

        Test.startTest();
        insert pc;
        Test.stopTest();

        System.assertNotEquals(null, pc.Id, 'Comment must be saved when the comment period is open');
    }

    @IsTest
    static void closedPeriod_blocksInsertWithError() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertClosedProcess(proj.Id);

        PublicComplaint pc = makeComment(ia.Id);

        Boolean threw = false;
        String errorMsg = '';

        Test.startTest();
        try {
            insert pc;
        } catch (DmlException e) {
            threw = true;
            errorMsg = e.getMessage();
        }
        Test.stopTest();

        System.assert(threw, 'DmlException must be thrown when the comment period has closed');
        String msgLower = errorMsg.toLowerCase();
        System.assert(
            msgLower.contains('comment period') || msgLower.contains('closed') || msgLower.contains('nepa'),
            'Error message must reference the closed comment period; actual: ' + errorMsg
        );
    }

    @IsTest
    static void noRelatedProcess_allowsInsert() {
        PublicComplaint pc = new PublicComplaint();
        pc.LastName     = 'Unlinked Commenter';
        pc.IncidentDate = Date.today();
        pc.nepa_comment_body__c = 'General comment not tied to any specific NEPA review process.';

        Test.startTest();
        insert pc;
        Test.stopTest();

        System.assertNotEquals(null, pc.Id, 'Comment with no related process must be allowed to insert (fail-open)');
    }

    @IsTest
    static void noEndDateOnProcess_allowsInsert() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);

        PublicComplaint pc = makeComment(ia.Id);

        Test.startTest();
        insert pc;
        Test.stopTest();

        System.assertNotEquals(null, pc.Id, 'Comment must be allowed when the related process has no comment period end date (fail-open)');
    }

    @IsTest
    static void bulk_250Comments_openPeriod_allInserted() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        List<PublicComplaint> comments = new List<PublicComplaint>();
        for (Integer i = 0; i < 250; i++) {
            PublicComplaint pc = new PublicComplaint();
            pc.LastName                = 'Bulk Commenter ' + i;
            pc.IncidentDate            = Date.today();
            pc.nepa_related_process__c = ia.Id;
            pc.nepa_comment_body__c    = 'Bulk test comment ' + i + ': The proposed action requires further analysis of cumulative impacts on the watershed.';
            comments.add(pc);
        }

        Test.startTest();
        insert comments;
        Test.stopTest();

        Integer saved = [SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__c = :ia.Id];
        System.assertEquals(250, saved, 'All 250 comments must be saved when the comment period is open');
    }

    @IsTest
    static void closedPeriod_errorMessage_referencesPeriod() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertClosedProcess(proj.Id);

        PublicComplaint pc = makeComment(ia.Id);

        String errorMsg = '';

        Test.startTest();
        try {
            insert pc;
        } catch (DmlException e) {
            errorMsg = e.getMessage();
        }
        Test.stopTest();

        System.assert(String.isNotBlank(errorMsg), 'DmlException message must be non-blank for closed period insert attempt');
        String msgLower = errorMsg.toLowerCase();
        System.assert(
            msgLower.contains('comment period') || msgLower.contains('closed') || msgLower.contains('nepa'),
            'Error message must contain comment period, closed, or NEPA to be meaningful; actual: ' + errorMsg
        );
    }
}
