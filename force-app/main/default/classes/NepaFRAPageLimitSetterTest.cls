@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaFRAPageLimitSetterTest {

    @IsTest
    static void docTypeEA_setsPageLimit75() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test EA Doc';
        cv.PathOnClient = 'TestEA.pdf';
        cv.VersionData = Blob.valueOf('test content');
        cv.nepa_document_type__c = 'EA';
        insert cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(75, cv.nepa_fra_page_limit__c, 'EA doc type should set page limit to 75');
    }

    @IsTest
    static void docTypeDraftEIS_setsPageLimit150() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Draft EIS Doc';
        cv.PathOnClient = 'TestDraftEIS.pdf';
        cv.VersionData = Blob.valueOf('test content');
        cv.nepa_document_type__c = 'Draft EIS';
        insert cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(150, cv.nepa_fra_page_limit__c, 'Draft EIS doc type should set page limit to 150');
    }

    @IsTest
    static void docTypeFinalEIS_setsPageLimit300() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Final EIS Doc';
        cv.PathOnClient = 'TestFinalEIS.pdf';
        cv.VersionData = Blob.valueOf('test content');
        cv.nepa_document_type__c = 'Final EIS';
        insert cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(300, cv.nepa_fra_page_limit__c, 'Final EIS doc type should set page limit to 300');
    }

    @IsTest
    static void docTypeAppendix_setsAppendixFlagAndZeroLimit() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Appendix Doc';
        cv.PathOnClient = 'TestAppendix.pdf';
        cv.VersionData = Blob.valueOf('test content');
        cv.nepa_document_type__c = 'Appendix';
        insert cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assert(cv.nepa_is_appendix__c, 'Appendix doc type should set nepa_is_appendix__c to true');
        System.assertEquals(0, cv.nepa_fra_page_limit__c, 'Appendix doc type should set page limit to 0');
    }

    @IsTest
    static void docTypeOther_setsZeroLimit() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test CE Doc';
        cv.PathOnClient = 'TestCE.pdf';
        cv.VersionData = Blob.valueOf('test content');
        cv.nepa_document_type__c = 'CE';
        insert cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(0, cv.nepa_fra_page_limit__c, 'Non-FRA doc type should set page limit to 0');
    }

    @IsTest
    static void docTypeChangedFromEAToFinalEIS_updatesLimit() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test EA to Final EIS Doc';
        cv.PathOnClient = 'TestEAtoFinalEIS.pdf';
        cv.VersionData = Blob.valueOf('test content');
        cv.nepa_document_type__c = 'EA';
        insert cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(75, cv.nepa_fra_page_limit__c, 'EA doc type should initially set page limit to 75');

        cv.nepa_document_type__c = 'Final EIS';
        update cv;

        cv = [SELECT Id, nepa_fra_page_limit__c, nepa_is_appendix__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(300, cv.nepa_fra_page_limit__c, 'Changing doc type to Final EIS should update page limit to 300');
    }

    @IsTest
    static void bulkPath_50CVsWithMixedDocTypes_allStamped() {
        List<ContentVersion> cvs = new List<ContentVersion>();

        for (Integer i = 0; i < 25; i++) {
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Bulk EA Doc ' + i;
            cv.PathOnClient = 'BulkEA' + i + '.pdf';
            cv.VersionData = Blob.valueOf('test content ea ' + i);
            cv.nepa_document_type__c = 'EA';
            cvs.add(cv);
        }

        for (Integer i = 0; i < 25; i++) {
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Bulk Final EIS Doc ' + i;
            cv.PathOnClient = 'BulkFinalEIS' + i + '.pdf';
            cv.VersionData = Blob.valueOf('test content final eis ' + i);
            cv.nepa_document_type__c = 'Final EIS';
            cvs.add(cv);
        }

        insert cvs;

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>(
            [SELECT Id, nepa_fra_page_limit__c, nepa_document_type__c FROM ContentVersion WHERE Id IN :cvs]
        );

        Integer ea75Count = 0;
        Integer finalEIS300Count = 0;

        for (ContentVersion cv : cvMap.values()) {
            if (cv.nepa_document_type__c == 'EA') {
                System.assertEquals(75, cv.nepa_fra_page_limit__c, 'Bulk EA doc should have page limit 75');
                ea75Count++;
            } else if (cv.nepa_document_type__c == 'Final EIS') {
                System.assertEquals(300, cv.nepa_fra_page_limit__c, 'Bulk Final EIS doc should have page limit 300');
                finalEIS300Count++;
            }
        }

        System.assertEquals(25, ea75Count, 'Should have 25 EA docs with limit 75');
        System.assertEquals(25, finalEIS300Count, 'Should have 25 Final EIS docs with limit 300');
    }
}
