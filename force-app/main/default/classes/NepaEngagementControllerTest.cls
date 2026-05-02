@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage')
@IsTest
@SuppressWarnings('PMD.MethodNamingConventions, PMD.ApexUnitTestClassShouldHaveRunAs')
private class NepaEngagementControllerTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('ENG-TEST-001', 'Engagement Project', 'FWS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        NepaTestFactory.insertPublicEngagement(ia.Id);
        NepaTestFactory.insertPrivateEngagement(ia.Id); // non-public — should be excluded
    }

    // ── getPublicEngagements ──────────────────────────────────────────────────

    @IsTest
    static void getPublicEngagements_returnsOnlyPublicEngagements() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

        Test.startTest();
        List<NepaEngagementController.EngagementRecord> results =
            NepaEngagementController.getPublicEngagements(ia.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only 1 public engagement should be returned');
        NepaEngagementController.EngagementRecord r = results[0];
        System.assertNotEquals(null, r.id);
        System.assertEquals('Public Hearing', r.title);
        System.assertEquals('Public Hearing', r.engagementType);
        System.assertEquals('In-Person',      r.locationFormat);
        System.assertNotEquals(null, r.startDatetime);
        System.assertNotEquals(null, r.endDatetime);
    }

    @IsTest
    static void getPublicEngagements_noEngagements_returnsEmpty() {
        Program proj2 = NepaTestFactory.insertProgram('ENG-TEST-002', 'Empty Engagement Project', 'NPS');
        IndividualApplication ia2 = NepaTestFactory.insertOpenProcess(proj2.Id, 'EA');

        Test.startTest();
        List<NepaEngagementController.EngagementRecord> results =
            NepaEngagementController.getPublicEngagements(ia2.Id);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void getPublicEngagements_blankProcessId_throwsException() {
        Test.startTest();
        try {
            NepaEngagementController.getPublicEngagements('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void getPublicEngagements_nullProcessId_throwsException() {
        Test.startTest();
        try {
            NepaEngagementController.getPublicEngagements(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    // ── bulk safety ───────────────────────────────────────────────────────────

    @IsTest
    static void getPublicEngagements_bulkSafe() {
        Program proj = NepaTestFactory.insertProgram('ENG-BULK-001', 'Bulk Engagement Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        List<nepa_engagement__c> engagements = new List<nepa_engagement__c>();
        for (Integer i = 0; i < 210; i++) {
            nepa_engagement__c e = new nepa_engagement__c();
            e.nepa_process__c         = ia.Id;
            e.nepa_engagement_type__c = 'Public Meeting';
            e.nepa_location_format__c = 'Virtual';
            e.nepa_start_datetime__c  = DateTime.now().addDays(i);
            e.nepa_public_access__c   = true;
            engagements.add(e);
        }
        insert engagements;

        Test.startTest();
        List<NepaEngagementController.EngagementRecord> results =
            NepaEngagementController.getPublicEngagements(ia.Id);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Should be capped at LIMIT 200');
    }
}
