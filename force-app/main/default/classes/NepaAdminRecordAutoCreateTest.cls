@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaAdminRecordAutoCreateTest {

    // ── Shared setup ───────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Program prog = NepaTestFactory.insertProgram('AAC-SETUP-001', 'Admin Record AutoCreate Test', 'BLM');
        NepaTestFactory.insertProcess(prog.Id, 'EIS', null, null);
    }

    private static IndividualApplication getProcess() {
        return [
            SELECT Id FROM IndividualApplication
            WHERE nepa_review_type__c = 'EIS'
            LIMIT 1
        ];
    }

    private static ApplicationTimeline makePreExistingEvent(Id processId) {
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                    = 'Pre-existing NOI Event';
        evt.nepa_related_process__c = processId;
        evt.nepa_event_type__c      = 'NOI';
        evt.nepa_status__c          = 'Completed';
        evt.nepa_tier__c            = '1';
        evt.nepa_source__c          = 'Test';
        evt.nepa_start_date__c      = Date.today().addDays(-10);
        evt.nepa_public_access__c   = false;
        insert evt;
        return evt;
    }

    // ── Helper: count Document Upload AT events for a process ─────────────────

    private static Integer countDocUploadEvents(Id processId) {
        return [
            SELECT COUNT()
            FROM ApplicationTimeline
            WHERE nepa_related_process__c = :processId
            AND nepa_event_type__c = 'Document Upload'
            AND nepa_source__c = 'System'
            AND nepa_tier__c = 'Administrative Record'
        ];
    }

    // ── Test 1: CV with doc type + pre-existing case event fires but exits early ─
    // Trigger filter: nepa_document_type__c IS NOT null AND nepa_related_case_event__c IS NOT null
    // Decision_HasRelatedCaseEvent: exits via Already_Linked because nepa_related_case_event__c IS NOT null
    // Expected: flow fires but creates NO new Document Upload AT event.

    @IsTest
    static void cvWithDocTypeAndExistingCaseEvent_noNewDocUploadEventCreated() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline preExisting = makePreExistingEvent(ia.Id);

        Integer beforeCount = countDocUploadEvents(ia.Id);

        ContentVersion cv = new ContentVersion();
        cv.Title                       = 'EA Document AAC-T1';
        cv.PathOnClient                = 'EA_Document_AAC_T1.pdf';
        cv.VersionData                 = Blob.valueOf('test content');
        cv.FirstPublishLocationId      = ia.Id;
        cv.nepa_document_type__c       = 'EA';
        cv.nepa_status__c              = 'Draft';
        cv.nepa_publish_date__c        = Date.today();
        cv.nepa_process__c             = ia.Id;
        cv.nepa_related_case_event__c  = preExisting.Id;

        Test.startTest();
        insert cv;
        Test.stopTest();

        Integer afterCount = countDocUploadEvents(ia.Id);
        System.assertEquals(
            beforeCount, afterCount,
            'Flow must exit via Already_Linked guard — no new Document Upload event expected when nepa_related_case_event__c is already set'
        );
    }

    // ── Test 2: CV with doc type but NULL case event — flow does not fire ───────
    // Trigger requires nepa_related_case_event__c IS NOT null; a null value skips the flow entirely.
    // Expected: no Document Upload AT event created.

    @IsTest
    static void cvWithDocTypeAndNullCaseEvent_flowDoesNotFire() {
        IndividualApplication ia = getProcess();

        Integer beforeCount = countDocUploadEvents(ia.Id);

        Test.startTest();
        NepaTestFactory.insertPublicContentVersion(ia.Id, 'EA');
        Test.stopTest();

        Integer afterCount = countDocUploadEvents(ia.Id);
        System.assertEquals(
            beforeCount, afterCount,
            'Flow must not fire when nepa_related_case_event__c is null (trigger filter not satisfied)'
        );
    }

    // ── Test 3: CV with no doc type — flow does not fire ─────────────────────
    // Trigger requires nepa_document_type__c IS NOT null; blank doc type skips the flow.
    // Expected: no Document Upload AT event created.

    @IsTest
    static void cvWithNoDocType_flowDoesNotFire() {
        IndividualApplication ia = getProcess();

        Integer beforeCount = countDocUploadEvents(ia.Id);

        ContentVersion cv = new ContentVersion();
        cv.Title                  = 'Untyped Doc AAC-T3';
        cv.PathOnClient           = 'Untyped_Doc_AAC_T3.pdf';
        cv.VersionData            = Blob.valueOf('test content');
        cv.FirstPublishLocationId = ia.Id;
        cv.nepa_status__c         = 'Draft';
        cv.nepa_publish_date__c   = Date.today();
        cv.nepa_process__c        = ia.Id;

        Test.startTest();
        insert cv;
        Test.stopTest();

        Integer afterCount = countDocUploadEvents(ia.Id);
        System.assertEquals(
            beforeCount, afterCount,
            'Flow must not fire when nepa_document_type__c is null (trigger filter not satisfied)'
        );
    }

    // ── Test 4: Idempotency — inserting the same already-linked CV twice does not create duplicate events ─
    // Both inserts arrive with nepa_related_case_event__c already set, so both exit via Already_Linked.
    // Expected: Document Upload AT event count unchanged after both inserts.

    @IsTest
    static void cvAlreadyLinked_noDuplicateEventOnSecondInsert() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline preExisting = makePreExistingEvent(ia.Id);

        Integer beforeCount = countDocUploadEvents(ia.Id);

        Test.startTest();
        ContentVersion cv1 = new ContentVersion();
        cv1.Title                       = 'NOI Document AAC-T4-A';
        cv1.PathOnClient                = 'NOI_Document_AAC_T4_A.pdf';
        cv1.VersionData                 = Blob.valueOf('test content');
        cv1.FirstPublishLocationId      = ia.Id;
        cv1.nepa_document_type__c       = 'NOI';
        cv1.nepa_status__c              = 'Draft';
        cv1.nepa_publish_date__c        = Date.today();
        cv1.nepa_process__c             = ia.Id;
        cv1.nepa_related_case_event__c  = preExisting.Id;
        insert cv1;

        ContentVersion cv2 = new ContentVersion();
        cv2.Title                       = 'NOI Document AAC-T4-B';
        cv2.PathOnClient                = 'NOI_Document_AAC_T4_B.pdf';
        cv2.VersionData                 = Blob.valueOf('test content');
        cv2.FirstPublishLocationId      = ia.Id;
        cv2.nepa_document_type__c       = 'NOI';
        cv2.nepa_status__c              = 'Draft';
        cv2.nepa_publish_date__c        = Date.today();
        cv2.nepa_process__c             = ia.Id;
        cv2.nepa_related_case_event__c  = preExisting.Id;
        insert cv2;
        Test.stopTest();

        Integer afterCount = countDocUploadEvents(ia.Id);
        System.assertEquals(
            beforeCount, afterCount,
            'Already-linked guard must prevent any Document Upload event creation for both inserts'
        );
    }

    // ── Test 5: Bulk — 5 CVs with case event set, no duplicate AT events ──────
    // All 5 trigger the flow; all 5 exit via Already_Linked. Count must stay at zero new events.

    @IsTest
    static void bulk_fiveCvsAlreadyLinked_noDocUploadEventsCreated() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline preExisting = makePreExistingEvent(ia.Id);

        Integer beforeCount = countDocUploadEvents(ia.Id);

        List<ContentVersion> cvs = new List<ContentVersion>();
        for (Integer i = 0; i < 5; i++) {
            ContentVersion cv = new ContentVersion();
            cv.Title                       = 'Bulk Doc AAC-T5-' + i;
            cv.PathOnClient                = 'Bulk_Doc_AAC_T5_' + i + '.pdf';
            cv.VersionData                 = Blob.valueOf('test content');
            cv.FirstPublishLocationId      = ia.Id;
            cv.nepa_document_type__c       = 'EA';
            cv.nepa_status__c              = 'Draft';
            cv.nepa_publish_date__c        = Date.today();
            cv.nepa_process__c             = ia.Id;
            cv.nepa_related_case_event__c  = preExisting.Id;
            cvs.add(cv);
        }

        Test.startTest();
        Boolean threw = false;
        try {
            insert cvs;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'Bulk insert of 5 already-linked CVs must not throw');

        Integer afterCount = countDocUploadEvents(ia.Id);
        System.assertEquals(
            beforeCount, afterCount,
            'No Document Upload AT events should be created when all 5 CVs already have nepa_related_case_event__c set'
        );
    }

    // ── Test 6: No exception is thrown for any valid trigger path ─────────────
    // Smoke test: inserting a CV that meets all trigger criteria must not throw.

    @IsTest
    static void cvWithDocTypeAndCaseEvent_doesNotThrow() {
        IndividualApplication ia = getProcess();
        ApplicationTimeline preExisting = makePreExistingEvent(ia.Id);

        Test.startTest();
        Boolean threw = false;
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title                       = 'Smoke Doc AAC-T6';
            cv.PathOnClient                = 'Smoke_Doc_AAC_T6.pdf';
            cv.VersionData                 = Blob.valueOf('test content');
            cv.FirstPublishLocationId      = ia.Id;
            cv.nepa_document_type__c       = 'Final EIS';
            cv.nepa_status__c              = 'Draft';
            cv.nepa_publish_date__c        = Date.today();
            cv.nepa_process__c             = ia.Id;
            cv.nepa_related_case_event__c  = preExisting.Id;
            insert cv;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'NEPA_AdminRecord_AutoCreate must not throw for a CV with nepa_document_type__c and nepa_related_case_event__c both set');
    }
}