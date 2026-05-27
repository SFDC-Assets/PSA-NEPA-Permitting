@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaTimelineControllerTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('TL-TEST-001', 'Timeline Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        // Two public events, one non-public
        NepaTestFactory.insertPublicTimelineEvent(ia.Id);
        NepaTestFactory.insertPublicTimelineEvent(ia.Id);
        NepaTestFactory.insertPrivateTimelineEvent(ia.Id);
    }

    // ── getProcessTimeline ────────────────────────────────────────────────────

    @IsTest
    static void getProcessTimeline_returnsOnlyPublicEvents() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

        Test.startTest();
        List<NepaTimelineController.TimelineEvent> events =
            NepaTimelineController.getProcessTimeline(ia.Id);
        Test.stopTest();

        System.assertEquals(2, events.size(), 'Only 2 public events should be returned');

        for (NepaTimelineController.TimelineEvent e : events) {
            System.assertEquals('NOI',       e.eventType);
            System.assertEquals('1',         e.stage);
            System.assertEquals('Completed', e.status);
            System.assertEquals('Test',      e.source);
            System.assertNotEquals(null, e.startDate, 'startDate should be populated');
            System.assertNotEquals(null, e.endDate,   'endDate should be populated');
        }
    }

    @IsTest
    static void getProcessTimeline_noEvents_returnsEmpty() {
        Program proj2 = NepaTestFactory.insertProgram('TL-TEST-002', 'No Events Project', 'EPA');
        IndividualApplication ia2 = NepaTestFactory.insertOpenProcess(proj2.Id, 'EA');

        Test.startTest();
        List<NepaTimelineController.TimelineEvent> events =
            NepaTimelineController.getProcessTimeline(ia2.Id);
        Test.stopTest();

        System.assertEquals(0, events.size());
    }

    @IsTest
    static void getProcessTimeline_blankProcessId_throwsException() {
        Test.startTest();
        Boolean threw = false;
        try {
            NepaTimelineController.getProcessTimeline('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for blank processId');
    }

    @IsTest
    static void getProcessTimeline_nullProcessId_throwsException() {
        Test.startTest();
        Boolean threw = false;
        try {
            NepaTimelineController.getProcessTimeline(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for null processId');
    }

    @IsTest
    static void getProcessTimeline_eventWithNullDates_doesNotThrow() {
        Program proj = NepaTestFactory.insertProgram('TL-TEST-003', 'Null Dates Project', 'NPS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        // Insert an event with null start/end dates
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                    = 'Null Dates Event';
        evt.nepa_event_type__c      = 'Scoping Open';
        evt.nepa_status__c          = 'Pending';
        evt.nepa_public_access__c   = true;
        evt.nepa_related_process__c = ia.Id;
        // nepa_start_date__c and nepa_end_date__c intentionally omitted
        insert evt;

        Test.startTest();
        List<NepaTimelineController.TimelineEvent> events =
            NepaTimelineController.getProcessTimeline(ia.Id);
        Test.stopTest();

        System.assertEquals(1, events.size());
        System.assertEquals(null, events[0].startDate, 'Null start date should serialize as null');
        System.assertEquals(null, events[0].endDate,   'Null end date should serialize as null');
    }

    // ── bulk safety ───────────────────────────────────────────────────────────

    @IsTest
    static void getProcessTimeline_bulkSafe() {
        Program proj = NepaTestFactory.insertProgram('TL-BULK-001', 'Bulk Timeline Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        List<ApplicationTimeline> evts = new List<ApplicationTimeline>();
        for (Integer i = 0; i < 210; i++) {
            ApplicationTimeline e = new ApplicationTimeline();
            e.Name                    = 'Bulk Event ' + i;
            e.nepa_event_type__c      = 'NOI';
            e.nepa_status__c          = 'Completed';
            e.nepa_public_access__c   = true;
            e.nepa_start_date__c      = Date.today().addDays(-i);
            e.nepa_related_process__c = ia.Id;
            evts.add(e);
        }
        insert evts;

        Test.startTest();
        List<NepaTimelineController.TimelineEvent> events =
            NepaTimelineController.getProcessTimeline(ia.Id);
        Test.stopTest();

        System.assertEquals(200, events.size(), 'Should be capped at LIMIT 200');
    }
}