@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaGISProximityIPInvokerTest {

    @IsTest
    static void invokeWithValidProjectIdReturnsResult() {
        NepaGISProximityIPInvoker.InvokerRequest req = new NepaGISProximityIPInvoker.InvokerRequest();
        req.projectId = 'a0B000000000001AAA';

        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one result');
        System.assertNotEquals(null, results[0], 'Result object must not be null');
        // If the IP service was unavailable, the invoker must have caught the exception
        // and returned success=false with an errorMessage — not silently passed.
        if (!results[0].success) {
            System.assertNotEquals(null, results[0].errorMessage,
                'Failed result must carry an errorMessage; silent failure is not acceptable');
        }
    }

    @IsTest
    static void invokeWithEmptyListReturnsEmptyResults() {
        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>()
            );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should produce empty output');
    }

    @IsTest
    static void invokeExceptionPathSetsErrorMessage() {
        NepaGISProximityIPInvoker.InvokerRequest req = new NepaGISProximityIPInvoker.InvokerRequest();
        req.projectId = null;

        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Must return one result for one request');
        System.assertNotEquals(null, results[0], 'Result must not be null');
        if (!results[0].success) {
            System.assertNotEquals(null, results[0].errorMessage,
                'Null projectId fault path must populate errorMessage');
        }
    }
}
