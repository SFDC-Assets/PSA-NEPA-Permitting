@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaDocumentControllerTest {

    // Each test creates its own IA + CVs to avoid ContentDocument lock contention
    // when the defensibility flow fires on concurrent parallel test transactions.
    private static IndividualApplication makeIsolatedProcess(String key) {
        Program proj = NepaTestFactory.insertProgram(key, 'Doc Test ' + key, 'BLM');
        return NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
    }

    // ── getPublicDocuments ────────────────────────────────────────────────────

    @IsTest
    static void getPublicDocuments_returnsOnlyPublicDocs() {
        IndividualApplication ia = makeIsolatedProcess('DOC-PUB-001');
        NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');
        NepaTestFactory.insertPublicContentVersion(ia.Id, 'NOI');
        NepaTestFactory.insertPrivateContentVersion(ia.Id, 'Draft EIS');

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, null, 1, 20);
        Test.stopTest();

        System.assertEquals(2, result.totalCount, 'Only 2 public docs should be returned');
        System.assertEquals(2, result.documents.size());
        for (NepaDocumentController.DocumentRecord dr : result.documents) {
            System.assertNotEquals(null, dr.contentVersionId);
            System.assertNotEquals(null, dr.documentTitle);
        }
    }

    @IsTest
    static void getPublicDocuments_withDocTypeFilter() {
        IndividualApplication ia = makeIsolatedProcess('DOC-FILT-001');
        NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');
        NepaTestFactory.insertPublicContentVersion(ia.Id, 'NOI');

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, 'NOI', 1, 20);
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'Only 1 NOI doc should match filter');
        System.assertEquals('NOI', result.documents[0].documentType);
    }

    @IsTest
    static void getPublicDocuments_noLinkedDocs_returnsEmpty() {
        IndividualApplication ia = makeIsolatedProcess('DOC-EMPTY-001');

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, null, 1, 20);
        Test.stopTest();

        System.assertEquals(0, result.totalCount);
        System.assertEquals(0, result.documents.size());
    }

    @IsTest
    static void getPublicDocuments_blankProcessId_throwsException() {
        Test.startTest();
        Boolean threw = false;
        try {
            NepaDocumentController.getPublicDocuments('', null, 1, 20);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for blank processId');
    }

    @IsTest
    static void getPublicDocuments_paginationDefaults() {
        IndividualApplication ia = makeIsolatedProcess('DOC-PAGE-001');
        NepaTestFactory.insertPublicContentVersion(ia.Id, 'NOI');

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ── getContentDownloadUrl ─────────────────────────────────────────────────

    @IsTest
    static void getContentDownloadUrl_publicDoc_returnsUrl() {
        IndividualApplication ia = makeIsolatedProcess('DOC-URL-001');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'NOI');
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        String url = NepaDocumentController.getContentDownloadUrl(cv.Id);
        Test.stopTest();

        System.assert(url.contains(cv.Id), 'URL should contain the ContentVersion Id');
        System.assert(url.startsWith('/sfc/'), 'URL should start with /sfc/');
    }

    @IsTest
    static void getContentDownloadUrl_nonPublicDoc_throwsException() {
        IndividualApplication ia = makeIsolatedProcess('DOC-NONPUB-001');
        ContentVersion cv = NepaTestFactory.insertPrivateContentVersion(ia.Id, 'Draft EIS');
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        Boolean threw = false;
        try {
            NepaDocumentController.getContentDownloadUrl(cv.Id);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for non-public document');
    }

    @IsTest
    static void getContentDownloadUrl_blankId_throwsException() {
        Test.startTest();
        Boolean threw = false;
        try {
            NepaDocumentController.getContentDownloadUrl('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for blank contentVersionId');
    }

    // ── bulk safety ───────────────────────────────────────────────────────────

    @IsTest
    static void getPublicDocuments_bulkSafe() {
        IndividualApplication ia = makeIsolatedProcess('DOC-BULK-001');

        List<ContentVersion> cvs = new List<ContentVersion>();
        for (Integer i = 0; i < 25; i++) {
            ContentVersion cv = new ContentVersion();
            cv.Title                    = 'Bulk Doc ' + i + ' ' + String.valueOf(ia.Id).right(4);
            cv.PathOnClient             = 'bulk_doc_' + i + '.pdf';
            cv.VersionData              = Blob.valueOf('content ' + i);
            cv.FirstPublishLocationId   = ia.Id;
            cv.nepa_public_access__c    = true;
            cv.nepa_document_type__c    = 'Draft EIS';
            cv.nepa_status__c           = 'Draft';
            cv.nepa_publish_date__c     = Date.today();
            cvs.add(cv);
        }
        insert cvs;

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, null, 1, 20);
        Test.stopTest();

        System.assert(result.totalCount >= 25, 'Should find at least 25 docs');
        System.assertEquals(20, result.documents.size(), 'Page size should cap at 20');
    }
}
