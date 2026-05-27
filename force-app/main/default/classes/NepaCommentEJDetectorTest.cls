@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
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

    // ── Adversarial: diacritic/accent bypass (regression for normalizeDiacritics fix) ──

    @IsTest
    static void diacriticBypass_nativeAmericanAndBurialGround_triggersEscalation() {
        // Regression: adversarial submission substitutes Unicode accented characters to
        // defeat lowercase String.contains() matching without normalization.
        // "nàtive américan buríal ground" → after normalizeDiacritics() → "native american burial ground"
        // Before fix: requiresHumanReview = false (bypass succeeded).
        // After fix:  requiresHumanReview = true  (caught by normalization).
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'I strongly support this project! It will bring great jobs. '
            + 'Also, the pipeline crosses a nàtive àméricàn buríal ground, but I don\'t care.';
        req.commentId = 'ADVERSARIAL-001';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        NepaCommentEJDetector.Result res = results[0];
        System.assertEquals(true, res.requiresHumanReview,
            'Diacritic-obfuscated "native american" and "burial ground" must trigger mandatory EJ escalation');
        System.assert(
            res.detectedTriggers.contains('Tribal Sovereignty') || res.detectedTriggers.contains('Sacred Sites'),
            'Tribal Sovereignty or Sacred Sites must be detected after diacritic normalization: ' + res.detectedTriggers
        );
    }

    @IsTest
    static void diacriticBypass_tribalSovereigntyAndNavajo_triggersEscalation() {
        // "trïbàl" = trïbàl → "tribal", "Nàvàjo" = Nàvàjo → "navajo"
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'The trïbàl sôveréignty of the Nàvàjo Nation must be respected.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].requiresHumanReview,
            'Accented "tribal" and "Navajo" must trigger escalation after diacritic normalization');
        System.assert(results[0].detectedTriggers.contains('Tribal Sovereignty'));
    }

    @IsTest
    static void diacriticBypass_environmentalJustice_triggersEscalation() {
        // "énvironméntàl justïce" → "environmental justice"
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = 'This is an énvironméntàl justïce community '
            + 'bearing disproportionate impacts.';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].requiresHumanReview,
            'Accented "environmental justice" must be caught after diacritic normalization');
        System.assert(results[0].detectedTriggers.contains('Environmental Justice'));
    }

    @IsTest
    static void nonLatinScript_doesNotFalsePositive_andDoesNotCrash() {
        // Non-Latin characters (CJK, Arabic) should not match EJ keywords and must not
        // throw an exception in normalizeDiacritics(). The method only replaces specific
        // Latin-range code points; all other characters pass through unchanged.
        NepaCommentEJDetector.Request req = new NepaCommentEJDetector.Request();
        req.commentBody = '测试 مرحبا plain latin text with no triggers';

        Test.startTest();
        List<NepaCommentEJDetector.Result> results = NepaCommentEJDetector.detect(
            new List<NepaCommentEJDetector.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].requiresHumanReview,
            'Non-Latin script should not produce false positives');
    }

    @IsTest
    static void normalizeDiacritics_allCoveredCharacters_roundtrip() {
        // Unit test for the normalization helper itself — confirms each character class
        // produces the correct ASCII base letter after normalization.
        System.assertEquals('a', NepaCommentEJDetector.normalizeDiacritics('à'), 'à → a');
        System.assertEquals('e', NepaCommentEJDetector.normalizeDiacritics('é'), 'é → e');
        System.assertEquals('i', NepaCommentEJDetector.normalizeDiacritics('í'), 'í → i');
        System.assertEquals('i', NepaCommentEJDetector.normalizeDiacritics('ï'), 'ï → i');
        System.assertEquals('o', NepaCommentEJDetector.normalizeDiacritics('ô'), 'ô → o');
        System.assertEquals('u', NepaCommentEJDetector.normalizeDiacritics('ú'), 'ú → u');
        System.assertEquals('n', NepaCommentEJDetector.normalizeDiacritics('ñ'), 'ñ → n');
        System.assertEquals('c', NepaCommentEJDetector.normalizeDiacritics('ç'), 'ç → c');
        // Uppercase variants normalize to lowercase base letters
        System.assertEquals('a', NepaCommentEJDetector.normalizeDiacritics('À'), 'À → a');
        System.assertEquals('e', NepaCommentEJDetector.normalizeDiacritics('É'), 'É → e');
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