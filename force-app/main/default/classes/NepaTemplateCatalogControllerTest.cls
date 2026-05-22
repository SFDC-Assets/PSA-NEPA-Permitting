@IsTest
private class NepaTemplateCatalogControllerTest {

    @TestSetup
    static void setup() {
        // IndividualApplication for installTemplate tests
        IndividualApplication ia = new IndividualApplication();
        ia.Name = 'Test NEPA Process';
        insert ia;
    }

    @IsTest
    static void getCatalog_noFilters_returnsAll() {
        Test.startTest();
        List<NEPA_Template_Catalog__mdt> results = NepaTemplateCatalogController.getCatalog(null, null);
        Test.stopTest();

        // CMT records are org-level; assert no exception and type correctness
        System.assertNotEquals(null, results, 'Expected non-null result list');
    }

    @IsTest
    static void getCatalog_filtersByReviewType_returnsMatchingRecords() {
        Test.startTest();
        List<NEPA_Template_Catalog__mdt> ceResults  = NepaTemplateCatalogController.getCatalog('CE', null);
        List<NEPA_Template_Catalog__mdt> eisResults = NepaTemplateCatalogController.getCatalog('EIS', null);
        List<NEPA_Template_Catalog__mdt> allResults = NepaTemplateCatalogController.getCatalog('All', null);
        Test.stopTest();

        System.assertNotEquals(null, ceResults,  'CE filter returned null');
        System.assertNotEquals(null, eisResults, 'EIS filter returned null');
        System.assertNotEquals(null, allResults, 'All filter returned null');

        // Verify all returned records match the requested review type
        for (NEPA_Template_Catalog__mdt rec : ceResults) {
            System.assert(
                rec.Review_Type__c == 'CE' || rec.Review_Type__c == 'All',
                'CE filter returned a non-CE record: ' + rec.Review_Type__c
            );
        }
    }

    @IsTest
    static void getCatalog_filtersBySector_returnsMatchingRecords() {
        Test.startTest();
        List<NEPA_Template_Catalog__mdt> results = NepaTemplateCatalogController.getCatalog(null, 'Energy');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Sector filter returned null');
        for (NEPA_Template_Catalog__mdt rec : results) {
            System.assert(
                rec.Sector__c != null && rec.Sector__c.containsIgnoreCase('Energy'),
                'Sector filter returned record without Energy in sector: ' + rec.Sector__c
            );
        }
    }

    @IsTest
    static void getCatalog_filtersByReviewTypeAndSector_returnsNarrowResults() {
        Test.startTest();
        List<NEPA_Template_Catalog__mdt> results = NepaTemplateCatalogController.getCatalog('EA', 'Transportation');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Combined filter returned null');
        for (NEPA_Template_Catalog__mdt rec : results) {
            System.assert(
                rec.Review_Type__c == 'EA' || rec.Review_Type__c == 'All',
                'Combined filter returned wrong review type: ' + rec.Review_Type__c
            );
        }
    }

    @IsTest
    static void installTemplate_blankAptName_throwsAuraHandledException() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

        Test.startTest();
        try {
            NepaTemplateCatalogController.installTemplate(ia.Id, '');
            System.assert(false, 'Expected AuraHandledException for blank APT name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Expected required message, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void installTemplate_nullRecordId_throwsAuraHandledException() {
        Test.startTest();
        try {
            NepaTemplateCatalogController.installTemplate(null, 'NEPA_CE_Process_Milestones');
            System.assert(false, 'Expected AuraHandledException for null recordId');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Record ID'), 'Expected Record ID message, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void installTemplate_inactiveOrMissingTemplate_throwsAuraHandledException() {
        IndividualApplication ia = [SELECT Id FROM IndividualApplication LIMIT 1];

        Test.startTest();
        try {
            NepaTemplateCatalogController.installTemplate(ia.Id, 'NEPA_NONEXISTENT_TEMPLATE_XYZ');
            System.assert(false, 'Expected AuraHandledException for missing template');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('not found') || e.getMessage().containsIgnoreCase('inactive'),
                'Expected not-found/inactive message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
}
