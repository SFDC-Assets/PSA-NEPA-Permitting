@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaDocumentControllerTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('DOC-TEST-001', 'EIS Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        // Two public docs, one non-public
        NepaTestFactory.insertPublicContentVersion(ia.Id,  'Draft EIS');
        NepaTestFactory.insertPublicContentVersion(ia.Id,  'NOI');
        NepaTestFactory.insertPrivateContentVersion(ia.Id, 'Draft EIS');
    }

    // ── getPublicDocuments ────────────────────────────────────────────────────

    @IsTest
    static void getPublicDocuments_returnsOnlyPublicDocs() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

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
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, 'NOI', 1, 20);
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'Only 1 NOI doc should match filter');
        System.assertEquals('NOI', result.documents[0].documentType);
    }

    @IsTest
    static void getPublicDocuments_noLinkedDocs_returnsEmpty() {
        Program proj2 = NepaTestFactory.insertProgram('DOC-TEST-002', 'Empty Project', 'EPA');
        IndividualApplication ia2 = NepaTestFactory.insertOpenProcess(proj2.Id, 'EA');

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia2.Id, null, 1, 20);
        Test.stopTest();

        System.assertEquals(0, result.totalCount);
        System.assertEquals(0, result.documents.size());
    }

    @IsTest
    static void getPublicDocuments_blankProcessId_throwsException() {
        Test.startTest();
        try {
            NepaDocumentController.getPublicDocuments('', null, 1, 20);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void getPublicDocuments_paginationDefaults() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ── getContentDownloadUrl ─────────────────────────────────────────────────

    @IsTest
    static void getContentDownloadUrl_publicDoc_returnsUrl() {
        ContentVersion cv = [
            SELECT Id FROM ContentVersion
            WHERE nepa_public_access__c = true AND IsLatest = true
            LIMIT 1
        ];

        Test.startTest();
        String url = NepaDocumentController.getContentDownloadUrl(cv.Id);
        Test.stopTest();

        System.assert(url.contains(cv.Id), 'URL should contain the ContentVersion Id');
        System.assert(url.startsWith('/sfc/'), 'URL should start with /sfc/');
    }

    @IsTest
    static void getContentDownloadUrl_nonPublicDoc_throwsException() {
        ContentVersion cv = [
            SELECT Id FROM ContentVersion
            WHERE nepa_public_access__c = false AND IsLatest = true
            LIMIT 1
        ];

        Test.startTest();
        try {
            NepaDocumentController.getContentDownloadUrl(cv.Id);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found') || e.getMessage().contains('accessible'));
        }
        Test.stopTest();
    }

    @IsTest
    static void getContentDownloadUrl_blankId_throwsException() {
        Test.startTest();
        try {
            NepaDocumentController.getContentDownloadUrl('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    // ── bulk safety ───────────────────────────────────────────────────────────

    @IsTest
    static void getPublicDocuments_bulkSafe() {
        Program proj = NepaTestFactory.insertProgram('DOC-BULK-001', 'Bulk Doc Project', 'NPS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        List<ContentVersion> cvs = new List<ContentVersion>();
        for (Integer i = 0; i < 25; i++) {
            ContentVersion cv = new ContentVersion();
            cv.Title                 = 'Bulk Doc ' + i;
            cv.PathOnClient          = 'bulk_doc_' + i + '.pdf';
            cv.VersionData           = Blob.valueOf('content ' + i);
            cv.nepa_public_access__c = true;
            cv.nepa_document_type__c = 'Draft EIS';
            cv.nepa_status__c        = 'Draft';
            cv.nepa_publish_date__c  = Date.today();
            cvs.add(cv);
        }
        insert cvs;

        List<ContentVersion> inserted = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Title LIKE 'Bulk Doc %'];
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : inserted) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId    = ia.Id;
            cdl.ShareType         = 'V';
            cdl.Visibility        = 'AllUsers';
            links.add(cdl);
        }
        insert links;

        Test.startTest();
        NepaDocumentController.DocumentListResult result =
            NepaDocumentController.getPublicDocuments(ia.Id, null, 1, 20);
        Test.stopTest();

        System.assert(result.totalCount >= 25, 'Should find at least 25 docs');
        System.assertEquals(20, result.documents.size(), 'Page size should cap at 20');
    }
}
