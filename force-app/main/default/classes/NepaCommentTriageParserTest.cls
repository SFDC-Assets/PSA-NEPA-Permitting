@IsTest
@SuppressWarnings('PMD.MethodNamingConventions')
private class NepaCommentTriageParserTest {

    private static final String VALID_JSON = '{"sentiment":"Opposed","is_substantive":true,"confidence_score":85,"cluster_hint":"water quality concern","triage_rationale":"Substantive: raises specific water quality claim citing upstream contamination data."}';
    private static final String VALID_JSON_WRAPPED = '```json\n' + VALID_JSON + '\n```';

    // ── Happy path ────────────────────────────────────────────────────────────

    @IsTest
    static void validJson_parsesAllFields() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = VALID_JSON;

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(true, res.parseSuccess, 'Parse should succeed for valid JSON');
        System.assertEquals('Opposed', res.sentiment);
        System.assertEquals(true, res.isSubstantive);
        System.assertEquals(85, res.confidenceScore);
        System.assertEquals('water quality concern', res.clusterHint);
        System.assert(res.triageRationale.contains('Substantive:'));
        System.assertEquals('', res.parseError);
    }

    @IsTest
    static void supportiveSentiment_parsesCorrectly() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '{"sentiment":"Supportive","is_substantive":false,"confidence_score":92,"cluster_hint":"","triage_rationale":"Non-substantive: expresses support without specific factual claims."}';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(true, res.parseSuccess);
        System.assertEquals('Supportive', res.sentiment);
        System.assertEquals(false, res.isSubstantive);
        System.assertEquals(92, res.confidenceScore);
    }

    // ── Code fence stripping ──────────────────────────────────────────────────

    @IsTest
    static void jsonWithCodeFences_stripsAndParses() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = VALID_JSON_WRAPPED;

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(true, res.parseSuccess, 'Should parse JSON wrapped in markdown code fences');
        System.assertEquals('Opposed', res.sentiment);
    }

    @IsTest
    static void jsonWithPlainCodeFences_stripsAndParses() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '```\n' + VALID_JSON + '\n```';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].parseSuccess, 'Should handle plain ``` code fences');
    }

    // ── Partial / missing fields ──────────────────────────────────────────────

    @IsTest
    static void missingOptionalFields_defaultsApplied() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '{"sentiment":"Neutral","is_substantive":false,"confidence_score":70}';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(true, res.parseSuccess);
        System.assertEquals('Neutral', res.sentiment);
        System.assertEquals('', res.clusterHint, 'Missing cluster_hint should default to empty string');
        System.assertEquals('', res.triageRationale, 'Missing triage_rationale should default to empty string');
    }

    // ── Sentiment validation ──────────────────────────────────────────────────

    @IsTest
    static void unknownSentiment_defaultsToNeutral() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '{"sentiment":"Ambivalent","is_substantive":true,"confidence_score":55,"cluster_hint":"","triage_rationale":"Some rationale."}';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(true, res.parseSuccess);
        System.assertEquals('Neutral', res.sentiment, 'Unknown sentiment should be coerced to Neutral');
    }

    @IsTest
    static void allValidSentiments_acceptedAsIs() {
        List<String> validSentiments = new List<String>{ 'Supportive', 'Neutral', 'Opposed', 'Mixed' };
        List<NepaCommentTriageParser.Request> requests = new List<NepaCommentTriageParser.Request>();
        for (String s : validSentiments) {
            NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
            req.triageJson = '{"sentiment":"' + s + '","is_substantive":false,"confidence_score":75,"cluster_hint":"","triage_rationale":"test"}';
            requests.add(req);
        }

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(requests);
        Test.stopTest();

        for (Integer i = 0; i < validSentiments.size(); i++) {
            System.assertEquals(validSentiments[i], results[i].sentiment,
                'Valid sentiment ' + validSentiments[i] + ' should not be altered');
        }
    }

    // ── Error cases ───────────────────────────────────────────────────────────

    @IsTest
    static void blankInput_returnsParseError() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(false, res.parseSuccess, 'Blank input should fail to parse');
        System.assert(String.isNotBlank(res.parseError), 'Parse error message should be populated');
    }

    @IsTest
    static void nullInput_returnsParseError() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = null;

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].parseSuccess, 'Null input should fail to parse');
    }

    @IsTest
    static void malformedJson_returnsParseError() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '{"sentiment":"Opposed","is_substantive":true MALFORMED';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        NepaCommentTriageParser.Result res = results[0];
        System.assertEquals(false, res.parseSuccess, 'Malformed JSON should fail to parse');
        System.assert(res.parseError.contains('JSON parse error'), 'Error message should indicate JSON parse failure');
        System.assertEquals('Neutral', res.sentiment, 'Sentiment default should hold after parse failure');
    }

    @IsTest
    static void notAnObject_returnsParseError() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '"just a string"';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].parseSuccess, 'Non-object JSON should fail to parse');
    }

    // ── Bulk ─────────────────────────────────────────────────────────────────

    @IsTest
    static void bulk_multipleRequests_allProcessed() {
        List<NepaCommentTriageParser.Request> requests = new List<NepaCommentTriageParser.Request>();
        for (Integer i = 0; i < 5; i++) {
            NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
            req.triageJson = '{"sentiment":"Mixed","is_substantive":true,"confidence_score":' + (60 + i) + ',"cluster_hint":"","triage_rationale":"rationale ' + i + '"}';
            requests.add(req);
        }

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(requests);
        Test.stopTest();

        System.assertEquals(5, results.size());
        for (Integer i = 0; i < 5; i++) {
            System.assertEquals(true, results[i].parseSuccess, 'Request ' + i + ' should parse successfully');
            System.assertEquals('Mixed', results[i].sentiment);
            System.assertEquals(60 + i, results[i].confidenceScore);
        }
    }
}
