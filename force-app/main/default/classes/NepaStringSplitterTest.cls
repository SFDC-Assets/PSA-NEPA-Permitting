@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaStringSplitterTest {

    @IsTest
    static void splitSemicolonDelimited_returnsTokens() {
        NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
        req.inputString = 'CWA Section 404; ESA Section 7; NHPA Section 106';

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(
            new List<NepaStringSplitter.SplitRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(3, results[0].tokens.size());
        System.assertEquals('CWA Section 404', results[0].tokens[0]);
        System.assertEquals('ESA Section 7', results[0].tokens[1]);
        System.assertEquals('NHPA Section 106', results[0].tokens[2]);
    }

    @IsTest
    static void splitSemicolonDelimited_trimsWhitespace() {
        NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
        req.inputString = '  CWA Section 404  ;  ESA Section 7  ';

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(
            new List<NepaStringSplitter.SplitRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(2, results[0].tokens.size());
        System.assertEquals('CWA Section 404', results[0].tokens[0]);
        System.assertEquals('ESA Section 7', results[0].tokens[1]);
    }

    @IsTest
    static void splitSemicolonDelimited_skipsBlankTokens() {
        NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
        req.inputString = 'CWA Section 404;;; ESA Section 7';

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(
            new List<NepaStringSplitter.SplitRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(2, results[0].tokens.size());
        System.assertEquals('CWA Section 404', results[0].tokens[0]);
        System.assertEquals('ESA Section 7', results[0].tokens[1]);
    }

    @IsTest
    static void splitSemicolonDelimited_blankInputReturnsEmptyTokens() {
        NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
        req.inputString = '';

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(
            new List<NepaStringSplitter.SplitRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].tokens.size());
    }

    @IsTest
    static void splitSemicolonDelimited_nullInputReturnsEmptyTokens() {
        NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
        req.inputString = null;

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(
            new List<NepaStringSplitter.SplitRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].tokens.size());
    }

    @IsTest
    static void splitSemicolonDelimited_singleValueNoSemicolonReturnsOneToken() {
        NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
        req.inputString = 'FERC License';

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(
            new List<NepaStringSplitter.SplitRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results[0].tokens.size());
        System.assertEquals('FERC License', results[0].tokens[0]);
    }

    @IsTest
    static void splitSemicolonDelimited_bulkRequestsAllProcessed() {
        List<NepaStringSplitter.SplitRequest> requests = new List<NepaStringSplitter.SplitRequest>();
        for (Integer i = 0; i < 200; i++) {
            NepaStringSplitter.SplitRequest req = new NepaStringSplitter.SplitRequest();
            req.inputString = 'Permit A; Permit B; Permit C';
            requests.add(req);
        }

        Test.startTest();
        List<NepaStringSplitter.SplitResult> results = NepaStringSplitter.split(requests);
        Test.stopTest();

        System.assertEquals(200, results.size());
        for (NepaStringSplitter.SplitResult r : results) {
            System.assertEquals(3, r.tokens.size());
        }
    }
}