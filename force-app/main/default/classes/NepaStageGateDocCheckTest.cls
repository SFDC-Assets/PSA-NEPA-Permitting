@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaStageGateDocCheckTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('SGDC-001', 'Stage Gate Doc Check Test', 'BLM');
    }

    private static Program getProgram() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'SGDC-001' LIMIT 1];
    }

    private static void insertApprovedDoc(Id processId, String docType) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'ContentVersion' AND DeveloperName = 'nepa_permit_document'
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            return;
        }
        Integer counter = Integer.valueOf(Math.random() * 100000);
        String label = docType.replaceAll('[^a-zA-Z0-9]', '_') + '_' + counter;
        ContentVersion cv = new ContentVersion();
        cv.Title                  = label;
        cv.PathOnClient           = label + '.pdf';
        cv.VersionData            = Blob.valueOf('test content');
        cv.FirstPublishLocationId = processId;
        cv.nepa_process__c        = processId;
        cv.nepa_document_type__c  = docType;
        cv.nepa_status__c         = 'Approved';
        cv.nepa_publish_date__c   = Date.today();
        cv.nepa_public_access__c  = true;
        cv.RecordTypeId           = rts[0].Id;
        insert cv;
    }

    private static Boolean tryCompleteEvent(Id processId, String eventType) {
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                    = 'Test Event ' + eventType;
        evt.nepa_event_type__c      = eventType;
        evt.nepa_status__c          = 'Completed';
        evt.nepa_tier__c            = '1';
        evt.nepa_source__c          = 'Test';
        evt.nepa_start_date__c      = Date.today().addDays(-5);
        evt.nepa_public_access__c   = true;
        evt.nepa_related_process__c = processId;
        try {
            insert evt;
            return true;
        } catch (DmlException e) {
            return false;
        }
    }

    // ── Survey gate: Draft EA Published ──────────────────────────────────────

    @IsTest
    static void surveyGate_draftEAPublished_surveysIncomplete_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_surveys_complete__c = false;
        update ia;

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'Draft EA Published');
        Test.stopTest();

        System.assertEquals(false, saved,
            'Draft EA Published with surveys incomplete must block the save');
    }

    @IsTest
    static void surveyGate_draftEAPublished_surveysComplete_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_surveys_complete__c = true;
        update ia;
        insertApprovedDoc(ia.Id, 'Environmental Assessment');

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'Draft EA Published');
        Test.stopTest();

        System.assertEquals(true, saved,
            'Draft EA Published with surveys complete must allow the save');
    }

    @IsTest
    static void surveyGate_draftEISPublished_surveysIncomplete_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_surveys_complete__c = false;
        update ia;

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'Draft EIS Published');
        Test.stopTest();

        System.assertEquals(false, saved,
            'Draft EIS Published with surveys incomplete must block the save');
    }

    @IsTest
    static void surveyGate_draftEISPublished_surveysComplete_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_surveys_complete__c = true;
        update ia;
        insertApprovedDoc(ia.Id, 'Draft EIS');

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'Draft EIS Published');
        Test.stopTest();

        System.assertEquals(true, saved,
            'Draft EIS Published with surveys complete must allow the save');
    }

    // ── Permit gate: ROD ──────────────────────────────────────────────────────

    @IsTest
    static void permitGate_rod_uninitatedCriticalPermit_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_surveys_complete__c = true;
        update ia;
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', true, null);

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'ROD Issued');
        Test.stopTest();

        System.assertEquals(false, saved,
            'ROD Issued with an uninitiated critical-path permit must block the save');
    }

    @IsTest
    static void permitGate_rod_allPermitsInitiated_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_surveys_complete__c = true;
        update ia;
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, null);
        insertApprovedDoc(ia.Id, 'ROD');

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'ROD Issued');
        Test.stopTest();

        System.assertEquals(true, saved,
            'ROD Issued with all critical permits initiated must allow the save');
    }

    // ── Permit gate: FONSI ────────────────────────────────────────────────────

    @IsTest
    static void permitGate_fonsi_uninitatedCriticalPermit_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_surveys_complete__c = true;
        update ia;
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', true, null);

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'FONSI Issued');
        Test.stopTest();

        System.assertEquals(false, saved,
            'FONSI Issued with an uninitiated critical-path permit must block the save');
    }

    @IsTest
    static void permitGate_fonsi_nonCriticalPermit_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_surveys_complete__c = true;
        update ia;
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', false, null);
        insertApprovedDoc(ia.Id, 'FONSI');
        insertApprovedDoc(ia.Id, 'Comment Response');

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'FONSI Issued');
        Test.stopTest();

        System.assertEquals(true, saved,
            'FONSI Issued with only non-critical Not Started permits must allow the save');
    }

    // ── No gate rules path ────────────────────────────────────────────────────

    @IsTest
    static void noGateRules_noiEvent_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);

        Test.startTest();
        Boolean saved = tryCompleteEvent(ia.Id, 'NOI');
        Test.stopTest();

        System.assertEquals(true, saved,
            'NOI event with no gate rules configured must allow the save');
    }

    // ── Error message content ─────────────────────────────────────────────────

    @IsTest
    static void surveyGate_errorMessage_referencesSurveys() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_surveys_complete__c = false;
        update ia;

        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                    = 'Test Survey Error';
        evt.nepa_event_type__c      = 'Draft EA Published';
        evt.nepa_status__c          = 'Completed';
        evt.nepa_tier__c            = '1';
        evt.nepa_source__c          = 'Test';
        evt.nepa_start_date__c      = Date.today().addDays(-5);
        evt.nepa_public_access__c   = true;
        evt.nepa_related_process__c = ia.Id;

        String errorMsg = '';
        Test.startTest();
        try {
            insert evt;
        } catch (DmlException e) {
            errorMsg = e.getMessage();
        }
        Test.stopTest();

        System.assert(
            errorMsg.contains('survey') || errorMsg.contains('Survey') || errorMsg.contains('field survey'),
            'Error message must reference field surveys; got: ' + errorMsg
        );
    }
}