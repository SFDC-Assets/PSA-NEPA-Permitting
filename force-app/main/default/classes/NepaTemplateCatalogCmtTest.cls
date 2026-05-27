@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
/**
 * CMT seed-data integrity tests for NEPA_Template_Catalog__mdt (F-11 Agency Template Exchange).
 * Mirrors the pattern from NepaPermitMatrixCmtTest.
 *
 * These tests verify that the 46 seed records deployed with the sprint are well-formed
 * and correctly reference the ActionPlanTemplates they catalog.
 * If any test fails, the catalog LWC will display incomplete or broken entries.
 */
private class NepaTemplateCatalogCmtTest {

    private static final Set<String> VALID_REVIEW_TYPES = new Set<String>{
        'CE', 'EA', 'EIS', 'Visit', 'All'
    };

    private static final Set<String> EXPECTED_APT_NAMES = new Set<String>{
        'NEPA_CE_Agriculture_PublicLands', 'NEPA_CE_Energy_Hydro_Transmission',
        'NEPA_CE_Energy_Nuclear_Waste', 'NEPA_CE_Energy_Offshore',
        'NEPA_CE_Energy_OilGas_Land_Coal', 'NEPA_CE_Energy_Pipeline_LNG',
        'NEPA_CE_Energy_Renewables_Solar_Geo', 'NEPA_CE_Materials_Mining',
        'NEPA_CE_Military_Urban_Regulatory', 'NEPA_CE_Process_Milestones',
        'NEPA_CE_Transportation_Land', 'NEPA_CE_Transportation_Water',
        'NEPA_CE_Water_Resources',
        'NEPA_EA_Agriculture_PublicLands', 'NEPA_EA_Energy_Hydro_Transmission',
        'NEPA_EA_Energy_Nuclear_Waste', 'NEPA_EA_Energy_Offshore',
        'NEPA_EA_Energy_OilGas_Land_Coal', 'NEPA_EA_Energy_Pipeline_LNG',
        'NEPA_EA_Energy_Renewables_Solar_Geo', 'NEPA_EA_Materials_Mining',
        'NEPA_EA_Military_Urban_Regulatory', 'NEPA_EA_Process_Milestones',
        'NEPA_EA_Transportation_Land', 'NEPA_EA_Transportation_Water',
        'NEPA_EA_Water_Resources',
        'NEPA_EIS_Agriculture_PublicLands', 'NEPA_EIS_Energy_Hydro_Transmission',
        'NEPA_EIS_Energy_Nuclear_Waste', 'NEPA_EIS_Energy_Offshore',
        'NEPA_EIS_Energy_OilGas_Land_Coal', 'NEPA_EIS_Energy_Pipeline_LNG',
        'NEPA_EIS_Energy_Renewables_Solar_Geo', 'NEPA_EIS_Materials_Mining',
        'NEPA_EIS_Military_Urban_Regulatory', 'NEPA_EIS_Process_Milestones',
        'NEPA_EIS_Transportation_Land', 'NEPA_EIS_Transportation_Water',
        'NEPA_EIS_Water_Resources',
        'NEPA_Visit_Aquatic_Milestones_BLM', 'NEPA_Visit_BigGame_Milestones_BLM',
        'NEPA_Visit_Botanical_Milestones_BLM', 'NEPA_Visit_Geology_Milestones_BLM',
        'NEPA_Visit_Hydrology_Milestones_BLM', 'NEPA_Visit_MigratoryBird_Milestones_BLM',
        'NEPA_Visit_SageGrouse_Milestones_BLM'
    };

    // ── Count ─────────────────────────────────────────────────────────────────

    @IsTest
    static void catalogSeedCount_is46() {
        Integer count = [SELECT COUNT() FROM NEPA_Template_Catalog__mdt WHERE Is_Active__c = true];
        System.assertEquals(46, count,
            'Exactly 46 active NEPA_Template_Catalog__mdt records must be deployed. ' +
            'If this fails, re-deploy: sf project deploy start --metadata "CustomMetadata:NEPA_Template_Catalog.*"');
    }

    // ── Required field presence ───────────────────────────────────────────────

    @IsTest
    static void allRecords_haveAPTUniqueName() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT DeveloperName, APT_Unique_Name__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];
        System.assert(!records.isEmpty(), 'No active catalog records found');
        for (NEPA_Template_Catalog__mdt r : records) {
            System.assert(String.isNotBlank(r.APT_Unique_Name__c),
                r.DeveloperName + ': APT_Unique_Name__c must not be blank — ' +
                'NepaTemplateCatalogController.installTemplate() uses this to look up the ActionPlanTemplate');
        }
    }

    @IsTest
    static void allRecords_haveReviewType() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT DeveloperName, Review_Type__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];
        for (NEPA_Template_Catalog__mdt r : records) {
            System.assert(String.isNotBlank(r.Review_Type__c),
                r.DeveloperName + ': Review_Type__c must not be blank — used for catalog filtering');
        }
    }

    @IsTest
    static void allRecords_haveSector() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT DeveloperName, Sector__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];
        for (NEPA_Template_Catalog__mdt r : records) {
            System.assert(String.isNotBlank(r.Sector__c),
                r.DeveloperName + ': Sector__c must not be blank — used for catalog filtering');
        }
    }

    @IsTest
    static void allRecords_haveTemplateName() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT DeveloperName, Template_Name__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];
        for (NEPA_Template_Catalog__mdt r : records) {
            System.assert(String.isNotBlank(r.Template_Name__c),
                r.DeveloperName + ': Template_Name__c must not be blank — displayed in catalog card UI');
        }
    }

    // ── Review type value integrity ───────────────────────────────────────────

    @IsTest
    static void allRecords_reviewTypeIsValidValue() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT DeveloperName, Review_Type__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];
        for (NEPA_Template_Catalog__mdt r : records) {
            System.assert(VALID_REVIEW_TYPES.contains(r.Review_Type__c),
                r.DeveloperName + ': Review_Type__c "' + r.Review_Type__c +
                '" is not a valid value. Must be one of: CE, EA, EIS, Visit, All. ' +
                'getCatalog() filter will not return this record correctly.');
        }
    }

    // ── APT name format ───────────────────────────────────────────────────────

    @IsTest
    static void allRecords_aptUniqueNameStartsWithNEPA() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT DeveloperName, APT_Unique_Name__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];
        for (NEPA_Template_Catalog__mdt r : records) {
            System.assert(r.APT_Unique_Name__c.startsWith('NEPA_'),
                r.DeveloperName + ': APT_Unique_Name__c must start with "NEPA_"; got: '
                + r.APT_Unique_Name__c);
        }
    }

    // ── Complete APT coverage ─────────────────────────────────────────────────

    @IsTest
    static void catalogCoversAll46KnownAPTs() {
        List<NEPA_Template_Catalog__mdt> records = [
            SELECT APT_Unique_Name__c
            FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true
        ];

        Set<String> deployedNames = new Set<String>();
        for (NEPA_Template_Catalog__mdt r : records) {
            deployedNames.add(r.APT_Unique_Name__c);
        }

        List<String> missing = new List<String>();
        for (String expected : EXPECTED_APT_NAMES) {
            if (!deployedNames.contains(expected)) {
                missing.add(expected);
            }
        }

        System.assertEquals(0, missing.size(),
            'The following expected APTs are missing from the catalog CMT: ' +
            String.join(missing, ', '));
    }

    // ── Filter correctness: getCatalog groupings ──────────────────────────────

    @IsTest
    static void ceSectorRecords_exist() {
        assertCountByReviewType('CE', 13);
    }

    @IsTest
    static void eaSectorRecords_exist() {
        assertCountByReviewType('EA', 13);
    }

    @IsTest
    static void eisSectorRecords_exist() {
        assertCountByReviewType('EIS', 13);
    }

    @IsTest
    static void visitFieldSurveyRecords_exist() {
        assertCountByReviewType('Visit', 7);
    }

    private static void assertCountByReviewType(String reviewType, Integer expected) {
        Integer count = [
            SELECT COUNT() FROM NEPA_Template_Catalog__mdt
            WHERE Is_Active__c = true AND Review_Type__c = :reviewType
        ];
        System.assertEquals(expected, count,
            'Expected ' + expected + ' active catalog records for Review_Type__c="' + reviewType +
            '"; got ' + count + '. nepaTemplateCatalog LWC filter will return wrong results.');
    }
}