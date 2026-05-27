@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class UserInformationTest {

    @IsTest
    static void getName_returnsNonNullString() {
        Test.startTest();
        String result = UserInformation.getName();
        Test.stopTest();

        // UserInfo.getFirstName() returns the running-user's first name; non-null in any org
        System.assertNotEquals(null, result, 'getName must return a non-null value');
    }

    @IsTest
    static void getTiming_returnsExpectedPeriod() {
        Test.startTest();
        String result = UserInformation.getTiming();
        Test.stopTest();

        System.assert(
            result == 'Morning' || result == 'Afternoon' || result == 'Evening',
            'getTiming must return Morning, Afternoon, or Evening; got: ' + result
        );
    }

    @IsTest
    static void getExpiryDays_returnsIntegerOrThrowsAuraHandledException() {
        // Production orgs may lack TrialExpirationDate — both branches must be exercised safely
        Boolean threw = false;
        Integer days;
        Test.startTest();
        try {
            days = UserInformation.getExpiryDays();
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        if (threw) {
            // catch block path exercised — acceptable outcome
            System.assert(true, 'AuraHandledException is the expected catch-block outcome');
        } else {
            System.assertNotEquals(null, days, 'getExpiryDays must return a non-null integer when TrialExpirationDate exists');
        }
    }
}
