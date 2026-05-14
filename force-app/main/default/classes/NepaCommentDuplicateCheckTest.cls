@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
/**
 * Tests for NEPA_Comment_Duplicate_Check invocable flow.
 * Uses Flow.Interview.createInterview() — requires the flow to be deployed and Active.
 *
 * Coverage requirements (MFR 8):
 *   - No-process guard (missing process ID → out_IsDuplicate = false)
 *   - No prior comments path (empty result set → not duplicate)
 *   - Duplicate detected (first 80 chars match → sets nepa_is_duplicate__c, nepa_duplicate_of__c)
 *   - Short body (< 20 chars) is never flagged as duplicate even if text matches
 *   - Distinct body (no overlap) → not duplicate
 *   - Bulk: 200-comment collection does not cause governor limit errors
 */
private class NepaCommentDuplicateCheckTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static PublicComplaint makeComment(Id processId, String body) {
        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = processId;
        pc.nepa_comment_body__c    = body;
        pc.nepa_date_submitted__c  = Date.today();
        return pc;
    }

    private static Map<String, Object> flowInputs(Id commentId, String body, Id processId) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('inp_CommentId',        commentId);
        m.put('inp_CommentBody',      body);
        m.put('inp_RelatedProcessId', processId);
        return m;
    }

    private static final String LONG_BODY =
        'The proposed pipeline route would cross the Yellowstone River at a point where annual spring '
        + 'floods have historically deposited significant sediment loads affecting downstream habitat. '
        + 'Federal and tribal monitoring data confirm elevated turbidity levels during runoff events.';

    // ── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void noProcess_returns_notDuplicate() {
        Program proj = NepaTestFactory.insertProgram('DUP-001', 'Dup Check Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        PublicComplaint pc = makeComment(ia.Id, LONG_BODY);
        insert pc;

        Map<String, Object> inputs = flowInputs(pc.Id, LONG_BODY, null);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_Comment_Duplicate_Check', inputs);
        interview.start();
        Test.stopTest();

        Boolean isDuplicate = (Boolean) interview.getVariableValue('out_IsDuplicate');
        System.assertEquals(false, isDuplicate, 'Missing process ID must return not-duplicate');
    }

    @IsTest
    static void noPriorComments_returns_notDuplicate() {
        Program proj = NepaTestFactory.insertProgram('DUP-002', 'Dup No Prior Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        PublicComplaint pc = makeComment(ia.Id, LONG_BODY);
        insert pc;

        Map<String, Object> inputs = flowInputs(pc.Id, LONG_BODY, ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_Comment_Duplicate_Check', inputs);
        interview.start();
        Test.stopTest();

        Boolean isDuplicate = (Boolean) interview.getVariableValue('out_IsDuplicate');
        System.assertEquals(false, isDuplicate, 'No prior comments should return not-duplicate');
    }

    @IsTest
    static void matchingBody_detects_duplicate() {
        Program proj = NepaTestFactory.insertProgram('DUP-003', 'Dup Detect Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        // Insert the "original" comment first
        PublicComplaint original = makeComment(ia.Id, LONG_BODY);
        insert original;

        // Insert the duplicate to test
        PublicComplaint duplicate = makeComment(ia.Id, LONG_BODY);
        insert duplicate;

        Map<String, Object> inputs = flowInputs(duplicate.Id, LONG_BODY, ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_Comment_Duplicate_Check', inputs);
        interview.start();
        Test.stopTest();

        Boolean isDuplicate = (Boolean) interview.getVariableValue('out_IsDuplicate');
        String originalId   = (String) interview.getVariableValue('out_OriginalCommentId');

        System.assertEquals(true, isDuplicate, 'Matching comment body should be flagged as duplicate');
        System.assertEquals(String.valueOf(original.Id), originalId,
            'out_OriginalCommentId must reference the original comment');

        PublicComplaint updated = [
            SELECT nepa_is_duplicate__c, nepa_duplicate_of__c
            FROM PublicComplaint WHERE Id = :duplicate.Id
        ];
        System.assertEquals(true, updated.nepa_is_duplicate__c,
            'nepa_is_duplicate__c must be set to true on the duplicate record');
        System.assertEquals(original.Id, updated.nepa_duplicate_of__c,
            'nepa_duplicate_of__c must point to the original comment');
    }

    @IsTest
    static void shortBody_never_flagged_as_duplicate() {
        Program proj = NepaTestFactory.insertProgram('DUP-004', 'Dup Short Body Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        String shortBody = 'I object.';
        PublicComplaint original = makeComment(ia.Id, shortBody);
        insert original;

        PublicComplaint candidate = makeComment(ia.Id, shortBody);
        insert candidate;

        Map<String, Object> inputs = flowInputs(candidate.Id, shortBody, ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_Comment_Duplicate_Check', inputs);
        interview.start();
        Test.stopTest();

        Boolean isDuplicate = (Boolean) interview.getVariableValue('out_IsDuplicate');
        System.assertEquals(false, isDuplicate, 'Body < 20 chars must not be flagged as duplicate');
    }

    @IsTest
    static void distinctBody_not_flagged_as_duplicate() {
        Program proj = NepaTestFactory.insertProgram('DUP-005', 'Dup Distinct Body Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        PublicComplaint original = makeComment(ia.Id, LONG_BODY);
        insert original;

        String differentBody =
            'I support this project and believe the environmental review was thorough. '
            + 'The agency has addressed all substantive concerns raised during scoping.';
        PublicComplaint candidate = makeComment(ia.Id, differentBody);
        insert candidate;

        Map<String, Object> inputs = flowInputs(candidate.Id, differentBody, ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_Comment_Duplicate_Check', inputs);
        interview.start();
        Test.stopTest();

        Boolean isDuplicate = (Boolean) interview.getVariableValue('out_IsDuplicate');
        System.assertEquals(false, isDuplicate, 'Distinct body should not be flagged as duplicate');
    }

    @IsTest
    static void bulk_200comments_noGovernorError() {
        Program proj = NepaTestFactory.insertProgram('DUP-006', 'Dup Bulk Test', 'USFS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        // Insert 200 prior comments with distinct bodies to avoid false-positive duplicate detection
        List<PublicComplaint> priors = new List<PublicComplaint>();
        for (Integer i = 0; i < 200; i++) {
            priors.add(makeComment(ia.Id, 'Unique prior comment number ' + i + ' with enough text to pass the 20-character length guard for duplicate detection.'));
        }
        insert priors;

        PublicComplaint candidate = makeComment(ia.Id, LONG_BODY);
        insert candidate;

        Map<String, Object> inputs = flowInputs(candidate.Id, LONG_BODY, ia.Id);

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_Comment_Duplicate_Check', inputs);
        interview.start();
        Test.stopTest();

        // No exception thrown = bulk test passes; LONG_BODY is distinct from all priors
        Boolean isDuplicate = (Boolean) interview.getVariableValue('out_IsDuplicate');
        System.assertEquals(false, isDuplicate, 'Bulk 200-comment run should complete without error');
    }
}
