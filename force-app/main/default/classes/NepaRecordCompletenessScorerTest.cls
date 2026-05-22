@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaRecordCompletenessScorerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Id getPermitDocRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'ContentVersion' AND DeveloperName = 'nepa_permit_document'
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            return null;
        }
        return rts[0].Id;
    }

    private static ApplicationTimeline insertCaseEvent(Id processId) {
        ApplicationTimeline at = new ApplicationTimeline();
        at.Name                    = 'Test Case Event';
        at.nepa_related_process__c = processId;
        at.nepa_event_type__c      = 'NOI';
        at.nepa_status__c          = 'Completed';
        insert at;
        return at;
    }

    private static ContentVersion insertPermitDocCV(
        Id processId, Id caseEventId, Id rtId, String docType, String docStatus
    ) {
        Integer counter = Integer.valueOf(Math.random() * 100000);
        String label = docType + '_' + counter;
        ContentVersion cv = new ContentVersion();
        cv.Title                      = label;
        cv.PathOnClient               = label.replaceAll('[^a-zA-Z0-9]', '_') + '.pdf';
        cv.VersionData                = Blob.valueOf('test content');
        cv.FirstPublishLocationId     = processId;
        cv.nepa_process__c            = processId;
        cv.nepa_document_type__c      = docType;
        cv.nepa_status__c             = docStatus;
        cv.nepa_publish_date__c       = Date.today();
        cv.nepa_public_access__c      = true;
        cv.nepa_related_case_event__c = caseEventId;
        cv.RecordTypeId               = rtId;
        insert cv;
        return cv;
    }

    // ── Test 1: CV with related case event triggers completeness update on IA ──

    @IsTest
    static void cvWithRelatedCaseEvent_updatesCompletenessOnIA() {
        Id rtId = getPermitDocRecordTypeId();
        if (rtId == null) {
            return;
        }

        Program proj = NepaTestFactory.insertProgram('CS-001', 'Completeness Test Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ApplicationTimeline at = insertCaseEvent(ia.Id);

        Test.startTest();
        insertPermitDocCV(ia.Id, at.Id, rtId, 'EA', 'Draft');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_record_completeness__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(null, result.nepa_record_completeness__c,
            'nepa_record_completeness__c must be populated after CV insert with valid case event link');
    }

    // ── Test 2: CV with null case event does not update IA ───────────────────

    @IsTest
    static void cvWithNoRelatedCaseEvent_doesNotUpdateIA() {
        Id rtId = getPermitDocRecordTypeId();
        if (rtId == null) {
            return;
        }

        Program proj = NepaTestFactory.insertProgram('CS-002', 'Completeness No Event Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);

        Integer counter = Integer.valueOf(Math.random() * 100000);
        String label = 'EA_NoEvent_' + counter;
        ContentVersion cv = new ContentVersion();
        cv.Title                  = label;
        cv.PathOnClient           = label + '.pdf';
        cv.VersionData            = Blob.valueOf('test content');
        cv.FirstPublishLocationId = ia.Id;
        cv.nepa_process__c        = ia.Id;
        cv.nepa_document_type__c  = 'EA';
        cv.nepa_status__c         = 'Draft';
        cv.nepa_publish_date__c   = Date.today();
        cv.nepa_public_access__c  = true;
        cv.RecordTypeId           = rtId;

        Test.startTest();
        insert cv;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_record_completeness__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(null, result.nepa_record_completeness__c,
            'nepa_record_completeness__c must remain null when CV has no nepa_related_case_event__c — flow exits at Decision_HasRelatedProcess');
    }

    // ── Test 3: Approved doc matching a required CMT row scores > 0 ───────────

    @IsTest
    static void approvedDocMatchingRequired_scoresAboveZero() {
        Id rtId = getPermitDocRecordTypeId();
        if (rtId == null) {
            return;
        }

        List<NEPA_Required_Document__mdt> cmtRows = [
            SELECT Document_Type__c, Review_Type__c
            FROM NEPA_Required_Document__mdt
            WHERE Active__c = true
            LIMIT 1
        ];
        if (cmtRows.isEmpty()) {
            return;
        }

        NEPA_Required_Document__mdt cmtRow = cmtRows[0];
        Program proj = NepaTestFactory.insertProgram('CS-003', 'Completeness Score 100 Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertProcess(
            proj.Id, cmtRow.Review_Type__c, null, null
        );
        ApplicationTimeline at = insertCaseEvent(ia.Id);

        Test.startTest();
        insertPermitDocCV(ia.Id, at.Id, rtId, cmtRow.Document_Type__c, 'Approved');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_record_completeness__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(null, result.nepa_record_completeness__c,
            'nepa_record_completeness__c must be set when an approved document matches a required CMT row');
        System.assert(result.nepa_record_completeness__c > 0,
            'Completeness must be greater than 0 when at least one required document is approved; got: ' +
            result.nepa_record_completeness__c);
    }

    // ── Test 4: Non-approved doc against required CMT row scores 0 ───────────

    @IsTest
    static void noApprovedDocs_scoresZero() {
        Id rtId = getPermitDocRecordTypeId();
        if (rtId == null) {
            return;
        }

        List<NEPA_Required_Document__mdt> cmtRows = [
            SELECT Document_Type__c, Review_Type__c
            FROM NEPA_Required_Document__mdt
            WHERE Active__c = true
            LIMIT 1
        ];
        if (cmtRows.isEmpty()) {
            return;
        }

        NEPA_Required_Document__mdt cmtRow = cmtRows[0];
        Program proj = NepaTestFactory.insertProgram('CS-004', 'Completeness Score 0 Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertProcess(
            proj.Id, cmtRow.Review_Type__c, null, null
        );
        ApplicationTimeline at = insertCaseEvent(ia.Id);

        Test.startTest();
        insertPermitDocCV(ia.Id, at.Id, rtId, cmtRow.Document_Type__c, 'Draft');
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_record_completeness__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(null, result.nepa_record_completeness__c,
            'nepa_record_completeness__c must be written even when no documents are approved');
        System.assert(result.nepa_record_completeness__c < 100,
            'Completeness must be less than 100 when no documents have status Approved; got: ' +
            result.nepa_record_completeness__c);
    }

    // ── Test 5: CV without nepa_permit_document RecordType does not fire flow ──

    @IsTest
    static void cvWithoutMatchingRecordType_doesNotFire() {
        Program proj = NepaTestFactory.insertProgram('CS-005', 'Completeness RT Guard Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ApplicationTimeline at = insertCaseEvent(ia.Id);

        Integer counter = Integer.valueOf(Math.random() * 100000);
        String label = 'EA_NoRT_' + counter;
        ContentVersion cv = new ContentVersion();
        cv.Title                      = label;
        cv.PathOnClient               = label + '.pdf';
        cv.VersionData                = Blob.valueOf('test content');
        cv.FirstPublishLocationId     = ia.Id;
        cv.nepa_process__c            = ia.Id;
        cv.nepa_document_type__c      = 'EA';
        cv.nepa_status__c             = 'Approved';
        cv.nepa_publish_date__c       = Date.today();
        cv.nepa_public_access__c      = true;
        cv.nepa_related_case_event__c = at.Id;

        Test.startTest();
        insert cv;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_record_completeness__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(null, result.nepa_record_completeness__c,
            'nepa_record_completeness__c must remain null when CV lacks the nepa_permit_document RecordType — flow trigger filter must not fire');
    }
}
