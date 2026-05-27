@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class SectionBlockControllerTest {

    // ── getSectionsByType guard throws ────────────────────────────────────────

    @IsTest
    static void getSectionsByType_nullSectionType_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType(null, 'Home');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null sectionType must throw AuraHandledException');
    }

    @IsTest
    static void getSectionsByType_nullPageType_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType('Feature', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null pageType must throw AuraHandledException');
    }

    @IsTest
    static void getSectionsByType_noMatchingPage_throwsAuraHandledException() {
        // No Page__c records exist in test context — MISSING_PAGE branch fires
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsByType('Feature', 'NONEXISTENT_PAGE_TYPE_XYZ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Missing Page__c must throw AuraHandledException');
    }

    // ── getSectionsByPageId guard throws ─────────────────────────────────────

    @IsTest
    static void getSectionsByPageId_nullSectionType_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsByPageId(null, 'fakePageId');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null sectionType must throw AuraHandledException');
    }

    @IsTest
    static void getSectionsByPageId_nullPageId_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsByPageId('Feature', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null pageId must throw AuraHandledException');
    }

    @IsTest
    static void getSectionsByPageId_validArgs_returnsEmptyListWithoutException() {
        // No Section__c records in test context — returns empty list without throwing
        Boolean threw = false;
        List<Section__c> result;
        Test.startTest();
        try {
            result = SectionBlockController.getSectionsByPageId('Feature', 'fakePageId000000001');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(false, threw, 'Valid args with no matching sections must not throw');
        System.assertNotEquals(null, result, 'Result must not be null');
    }

    // ── getSectionWithBlockBySectionId guard throw ────────────────────────────

    @IsTest
    static void getSectionWithBlockBySectionId_nullSectionId_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionWithBlockBySectionId(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null sectionId must throw AuraHandledException');
    }

    // ── getDynamicLinks empty list returns empty ──────────────────────────────

    @IsTest
    static void getDynamicLinks_emptyList_returnsEmpty() {
        Test.startTest();
        List<DynamicLink__c> result = SectionBlockController.getDynamicLinks(new List<String>());
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result must not be null');
        System.assertEquals(0, result.size(), 'Empty input must return empty list');
    }

    // ── getSectionsWithBlocksByType guard throws ──────────────────────────────

    @IsTest
    static void getSectionsWithBlocksByType_nullArgs_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByType(null, 'Home');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null sectionType must throw AuraHandledException');
    }

    // ── getSectionsWithBlocksByPageId guard throws ────────────────────────────

    @IsTest
    static void getSectionsWithBlocksByPageId_nullPageId_throwsAuraHandledException() {
        Boolean threw = false;
        Test.startTest();
        try {
            SectionBlockController.getSectionsWithBlocksByPageId('Feature', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Null pageId must throw AuraHandledException');
    }
}
