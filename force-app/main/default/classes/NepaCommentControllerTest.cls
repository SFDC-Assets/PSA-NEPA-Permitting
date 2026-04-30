@IsTest
@SuppressWarnings('PMD.MethodNamingConventions, PMD.ApexUnitTestClassShouldHaveRunAs')
private class NepaCommentControllerTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('CMT-TEST-001', 'Comment Test Project', 'BLM');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        Program proj2 = NepaTestFactory.insertProgram('CMT-TEST-002', 'Closed Period Project', 'EPA');
        NepaTestFactory.insertClosedProcess(proj2.Id);
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private static NepaCommentController.CommentInput makeInput(String processId) {
        NepaCommentController.CommentInput i = new NepaCommentController.CommentInput();
        i.processId        = processId;
        i.commenterName    = 'Jane Public';
        i.organization     = 'Sierra Club';
        i.email            = 'jane@example.com';
        i.category         = 'Wildlife';
        i.commentBody      = 'This project will harm migratory birds.';
        i.notifyMe         = true;
        i.contentVersionId = null;
        return i;
    }

    // ── submitComment — happy path ────────────────────────────────────────────

    @IsTest
    static void submitComment_openPeriod_createsRecord() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        Test.startTest();
        String commentId = NepaCommentController.submitComment(makeInput(ia.Id));
        Test.stopTest();

        System.assertNotEquals(null, commentId, 'Should return the new comment Id');

        PublicComplaint created = [
            SELECT Id, Name, nepa_comment_body__c, nepa_organization__c,
                   nepa_category__c, nepa_public_source__c, Method_of_Submission__c,
                   nepa_public_access__c, nepa_email__c, nepa_date_submitted__c
            FROM PublicComplaint
            WHERE Id = :commentId
        ];

        System.assertEquals('Jane Public',                               created.Name);
        System.assertEquals('This project will harm migratory birds.',   created.nepa_comment_body__c);
        System.assertEquals('Sierra Club',                               created.nepa_organization__c);
        System.assertEquals('Wildlife',                                  created.nepa_category__c);
        System.assertEquals(true,                                        created.nepa_public_source__c);
        System.assertEquals('Online',                                    created.Method_of_Submission__c);
        System.assertEquals('Public',                                    created.nepa_public_access__c);
        System.assertEquals('jane@example.com',                          created.nepa_email__c);
        System.assertEquals(Date.today(),                                created.nepa_date_submitted__c);
    }

    @IsTest
    static void submitComment_notifyMeFalse_emailNotStored() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.notifyMe = false;

        Test.startTest();
        String commentId = NepaCommentController.submitComment(input);
        Test.stopTest();

        PublicComplaint created = [SELECT nepa_email__c FROM PublicComplaint WHERE Id = :commentId];
        System.assertEquals(null, created.nepa_email__c, 'Email should not be stored when notifyMe is false');
    }

    @IsTest
    static void submitComment_withAttachmentRef_storesDocLocationRef() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.contentVersionId = 'fakeContentVersionId';

        Test.startTest();
        String commentId = NepaCommentController.submitComment(input);
        Test.stopTest();

        PublicComplaint created = [SELECT nepa_document_location_ref__c FROM PublicComplaint WHERE Id = :commentId];
        System.assertEquals('fakeContentVersionId', created.nepa_document_location_ref__c);
    }

    @IsTest
    static void submitComment_htmlInBody_isSanitized() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.commentBody = '<script>alert("xss")</script>Real comment text.';

        Test.startTest();
        String commentId = NepaCommentController.submitComment(input);
        Test.stopTest();

        PublicComplaint created = [SELECT nepa_comment_body__c FROM PublicComplaint WHERE Id = :commentId];
        System.assert(!created.nepa_comment_body__c.contains('<script>'), 'HTML tags should be stripped');
        System.assert(created.nepa_comment_body__c.contains('Real comment text.'), 'Plain text should be preserved');
    }

    // ── submitComment — validation failures ───────────────────────────────────

    @IsTest
    static void submitComment_nullInput_throwsException() {
        Test.startTest();
        try {
            NepaCommentController.submitComment(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void submitComment_blankProcessId_throwsException() {
        NepaCommentController.CommentInput input = makeInput('');

        Test.startTest();
        try {
            NepaCommentController.submitComment(input);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('processId'));
        }
        Test.stopTest();
    }

    @IsTest
    static void submitComment_blankCommenterName_throwsException() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.commenterName = '';

        Test.startTest();
        try {
            NepaCommentController.submitComment(input);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('name'));
        }
        Test.stopTest();
    }

    @IsTest
    static void submitComment_blankBody_throwsException() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.commentBody = '   ';

        Test.startTest();
        try {
            NepaCommentController.submitComment(input);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('body') || e.getMessage().contains('Comment'));
        }
        Test.stopTest();
    }

    @IsTest
    static void submitComment_bodyExceedsMaxLength_throwsException() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.commentBody = 'x'.repeat(32001);

        Test.startTest();
        try {
            NepaCommentController.submitComment(input);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('32,000'));
        }
        Test.stopTest();
    }

    // ── submitComment — closed/missing period ─────────────────────────────────

    @IsTest
    static void submitComment_closedPeriod_throwsException() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c < :DateTime.now()
            LIMIT 1
        ];

        Test.startTest();
        try {
            NepaCommentController.submitComment(makeInput(ia.Id));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not currently open'));
        }
        Test.stopTest();
    }

    @IsTest
    @SuppressWarnings('PMD.AvoidHardcodingId')
    static void submitComment_processNotFound_throwsException() {
        // Syntactically valid 18-char Id that does not exist in the test org
        Id fakeId = '001000000000001AAA';

        Test.startTest();
        try {
            NepaCommentController.submitComment(makeInput(fakeId));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('not found') || e.getMessage().contains('not currently open'),
                'Should surface a meaningful error'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void submitComment_noCommentPeriodDatesSet_throwsException() {
        // Process with null comment period dates — isOpen check should fail
        Program proj3 = NepaTestFactory.insertProgram('CMT-TEST-003', 'No Period Project', 'NPS');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj3.Id, 'EA', null, null);

        Test.startTest();
        try {
            NepaCommentController.submitComment(makeInput(ia.Id));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not currently open'));
        }
        Test.stopTest();
    }

    // ── bulk safety ───────────────────────────────────────────────────────────

    @IsTest
    static void submitComment_bulkSafe() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        Test.startTest();
        for (Integer i = 0; i < 10; i++) {
            NepaCommentController.CommentInput input = makeInput(ia.Id);
            input.commenterName = 'Commenter ' + i;
            NepaCommentController.submitComment(input);
        }
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM PublicComplaint WHERE IndividualApplicationId = :ia.Id];
        System.assertEquals(10, count, 'All 10 comments should have been created');
    }
}
