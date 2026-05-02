@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage')
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

    // ── Bug regression: nepa_related_process__c populated on insert ──────────

    @IsTest
    static void submitComment_setsNepaRelatedProcess_forGateEnforcement() {
        // Regression for Bug 3: nepa_related_process__c must be set on insert so the
        // NEPA_Comment_Period_Gate before-save flow and NEPA_Comment_Period_Closed validation
        // rule can enforce the deadline. This org's PSS installation does not expose
        // IndividualApplicationId on PublicComplaint; nepa_related_process__c is the sole gate field.
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        Test.startTest();
        String commentId = NepaCommentController.submitComment(makeInput(ia.Id));
        Test.stopTest();

        PublicComplaint created = [
            SELECT nepa_related_process__c
            FROM PublicComplaint
            WHERE Id = :commentId
        ];
        System.assertEquals(ia.Id, created.nepa_related_process__c,
            'nepa_related_process__c must be set so before-save flow and validation rule can enforce the deadline');
    }

    // ── Bug regression: exact-minute deadline (DateTime precision) ────────────

    @IsTest
    static void submitComment_deadlinePassedTodayEarlier_throwsException() {
        // Regression for Bug 2: original code compared Date.today() >= periodEnd.date(),
        // which allowed submissions on the deadline calendar day even after the exact
        // cutoff time. The fix uses DateTime.now() with strict > comparison matching
        // the before-save flow's $Flow.CurrentDateTime semantics.
        //
        // We set the period end to 1 second in the past — same calendar day as now(),
        // but the exact-minute deadline has passed.
        Program proj = NepaTestFactory.insertProgram('CMT-DT-001', 'DateTime Precision Test', 'EPA');
        DateTime justExpired = DateTime.now().addSeconds(-1);
        IndividualApplication ia = NepaTestFactory.insertProcessWithDateTimes(
            proj.Id, 'EIS', DateTime.now().addDays(-30), justExpired
        );

        Test.startTest();
        try {
            NepaCommentController.submitComment(makeInput(ia.Id));
            System.assert(false, 'Should have thrown — deadline passed 1 second ago');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not currently open'),
                'Expected "not currently open" but got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void submitComment_deadlineInOneSecond_succeeds() {
        // Complement to the above: period closes 60 seconds from now — submission must succeed.
        Program proj = NepaTestFactory.insertProgram('CMT-DT-002', 'Nearly Closed Test', 'NPS');
        IndividualApplication ia = NepaTestFactory.insertProcessWithDateTimes(
            proj.Id, 'EIS', DateTime.now().addDays(-5), DateTime.now().addSeconds(60)
        );

        Test.startTest();
        String commentId = NepaCommentController.submitComment(makeInput(ia.Id));
        Test.stopTest();

        System.assertNotEquals(null, commentId, 'Should succeed when period closes 60 seconds from now');
    }

    // ── Bot payload: oversized body rejected before DML ───────────────────────

    @IsTest
    static void submitComment_200kbBotPayload_rejectedBeforeDml() {
        // Phase 1 test 1.2: a 200KB malicious body (all HTML junk + 50-char substantive
        // content buried within) must be rejected by the 32,000-char controller guard
        // before it ever reaches the database or the Agentforce triage pipeline.
        // LongTextArea max is 32,768 chars; controller enforces 32,000 to leave headroom.
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        // 200 * 1024 = 204,800 characters — well above the 32,000 threshold
        String botPayload = '<div>'.repeat(40000) + 'The pipeline affects salmon habitat.' + '</div>'.repeat(256);

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.commentBody = botPayload;

        Test.startTest();
        try {
            NepaCommentController.submitComment(input);
            System.assert(false, 'Should have thrown for oversized body');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('32,000'),
                'Should surface the 32,000-char limit message: ' + e.getMessage());
        }
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__c = :ia.Id];
        System.assertEquals(0, count, 'No record should be persisted for the oversized payload');
    }

    @IsTest
    static void submitComment_htmlStrippedThenSentimentPreserved() {
        // After HTML stripping, the substantive text content must survive intact
        // (guard against over-aggressive sanitization that strips legitimate text).
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];

        NepaCommentController.CommentInput input = makeInput(ia.Id);
        input.commentBody = '<div><span style="color:red">The pipeline crosses a sensitive wetland '
            + 'under 33 U.S.C. 1344 jurisdiction.</span></div>';

        Test.startTest();
        String commentId = NepaCommentController.submitComment(input);
        Test.stopTest();

        PublicComplaint created = [SELECT nepa_comment_body__c FROM PublicComplaint WHERE Id = :commentId];
        System.assert(!created.nepa_comment_body__c.contains('<div>'), 'HTML tags must be stripped');
        System.assert(!created.nepa_comment_body__c.contains('<span'), 'HTML tags must be stripped');
        System.assert(created.nepa_comment_body__c.contains('wetland'),
            'Substantive content must survive sanitization');
        System.assert(created.nepa_comment_body__c.contains('1344'),
            'Statutory citation must survive sanitization');
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

        Integer count = [SELECT COUNT() FROM PublicComplaint WHERE nepa_related_process__c = :ia.Id];
        System.assertEquals(10, count, 'All 10 comments should have been created');
    }
}
