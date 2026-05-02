@IsTest
@SuppressWarnings('PMD.MethodNamingConventions')
private class NepaCommentEJDetectorTest {

    // ── Positive: each trigger category independently ───────────────────────

    @IsTest
    static void tribalSovereignty_keyword_triggers_escalation() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'This project would violate our treaty rights as a federally recognized tribe.';
        req.commentId = 'PC001';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview, 'Tribal sovereignty keyword should trigger escalation');
        System.assert(res.detectedTriggers.contains('Tribal Sovereignty'), 'Tribal Sovereignty should be in detected triggers');
        System.assert(res.triggerDetails.contains('Mandatory human review'), 'Trigger details should state mandatory human review');
    }

    @IsTest
    static void sacredSites_keyword_triggers_escalation() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'The proposed route passes through a burial ground that is sacred to our community.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview);
        System.assert(res.detectedTriggers.contains('Sacred Sites'));
    }

    @IsTest
    static void environmentalJustice_keyword_triggers_escalation() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'This is an environmental justice community that already bears cumulative impacts from nearby facilities.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview);
        System.assert(res.detectedTriggers.contains('Environmental Justice'));
    }

    @IsTest
    static void lowIncomeImpact_keyword_triggers_escalation() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'The majority of residents in this area live in public housing and rely on affordable housing programs.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview);
        System.assert(res.detectedTriggers.contains('Low-Income Impact'));
    }

    @IsTest
    static void civilRights_keyword_triggers_escalation() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'This project has a disparate impact on communities of color in violation of Title VI.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview);
        System.assert(res.detectedTriggers.contains('Civil Rights'));
    }

    // ── Negative: clean comment passes through ───────────────────────────────

    @IsTest
    static void cleanComment_noTriggers_passesThrough() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'I support the project because it will bring jobs to the region and use clean energy.';
        req.commentId = 'PC002';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(false, res.requiresHumanReview, 'Clean comment should not trigger escalation');
        System.assertEquals('', res.detectedTriggers, 'No triggers should be detected');
        System.assert(res.triggerDetails.contains('No EJ'), 'Trigger details should confirm no triggers detected');
    }

    // ── Case insensitivity ────────────────────────────────────────────────────

    @IsTest
    static void keywords_areMatchedCaseInsensitively() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'The NAVAJO NATION has TREATY RIGHTS that must be respected.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].requiresHumanReview, 'Keywords should match regardless of case');
    }

    // ── Multiple categories in one comment ───────────────────────────────────

    @IsTest
    static void multipleCategories_allDetected() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'This environmental justice community includes tribal sovereignty concerns and civil rights issues.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview);
        System.assert(res.detectedTriggers.contains('Environmental Justice'));
        System.assert(res.detectedTriggers.contains('Tribal Sovereignty'));
        System.assert(res.detectedTriggers.contains('Civil Rights'));
    }

    // ── Blank/null input ─────────────────────────────────────────────────────

    @IsTest
    static void blankComment_noTriggers() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = '';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].requiresHumanReview, 'Blank comment should not trigger escalation');
    }

    @IsTest
    static void nullComment_noTriggers() {
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = null;

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].requiresHumanReview, 'Null comment should not trigger escalation');
    }

    // ── Bulk: 5 requests processed correctly ─────────────────────────────────

    @IsTest
    static void bulk_mixedComments_processedCorrectly() {
        List<NepaCommentEJDetector.Request> requests = new List<NepaCommentEJDetector.Request>();
        for (Integer i = 0; i < 3; i++) {
            NepaCommentEJDetector.Request clean = new NepaCommentEJDetector.Request();
            clean.commentBody = 'General comment about noise levels from construction ' + i;
            requests.add(clean);
        }
        NepaCommentEJDetector.Request ejReq = new NepaCommentEJDetector.Request();
        ejReq.commentBody = 'This is an environmental justice community.';
        requests.add(ejReq);

        NepaCommentEJDetector.Request tribalReq = new NepaCommentEJDetector.Request();
        tribalReq.commentBody = 'Indigenous rights must be protected.';
        requests.add(tribalReq);

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(requests);
        Test.stopTest();

        System.assertEquals(5, results.size());
        System.assertEquals(false, results[0].requiresHumanReview);
        System.assertEquals(false, results[1].requiresHumanReview);
        System.assertEquals(false, results[2].requiresHumanReview);
        System.assertEquals(true, results[3].requiresHumanReview);
        System.assertEquals(true, results[4].requiresHumanReview);
    }
}
