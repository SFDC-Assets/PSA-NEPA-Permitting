@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaIndustryCodePickerControllerTest {

    @IsTest
    static void getAllOptions_returnsNonNullResult() {
        Test.startTest();
        NepaIndustryCodePickerController.PickerOptions result = NepaIndustryCodePickerController.getAllOptions();
        Test.stopTest();

        System.assertNotEquals(null, result, 'PickerOptions should not be null');
        System.assertNotEquals(null, result.sectorOptions, 'sectorOptions should not be null');
        System.assertNotEquals(null, result.subSectorOptions, 'subSectorOptions should not be null');
        System.assertNotEquals(null, result.industryGroupOptions, 'industryGroupOptions should not be null');
        System.assertNotEquals(null, result.industryOptions, 'industryOptions should not be null');
        System.assertNotEquals(null, result.nationalIndustryOptions, 'nationalIndustryOptions should not be null');
    }

    @IsTest
    static void getAllOptions_sectorList_sizeMatchesCMTData() {
        List<NEPA_NAICS_Code__mdt> cmtSectors = [
            SELECT Id FROM NEPA_NAICS_Code__mdt WHERE Level__c = 'Sector'
        ];

        Test.startTest();
        NepaIndustryCodePickerController.PickerOptions result = NepaIndustryCodePickerController.getAllOptions();
        Test.stopTest();

        System.assertEquals(cmtSectors.size(), result.sectorOptions.size(),
            'sectorOptions size should match CMT records with Level__c = Sector');
    }

    @IsTest
    static void getAllOptions_eachOptionHasValueAndLabel() {
        Test.startTest();
        NepaIndustryCodePickerController.PickerOptions result = NepaIndustryCodePickerController.getAllOptions();
        Test.stopTest();

        List<List<NepaIndustryCodePickerController.PickerOption>> allLists =
            new List<List<NepaIndustryCodePickerController.PickerOption>>{
                result.sectorOptions,
                result.subSectorOptions,
                result.industryGroupOptions,
                result.industryOptions,
                result.nationalIndustryOptions
            };

        for (List<NepaIndustryCodePickerController.PickerOption> opts : allLists) {
            if (opts.isEmpty()) {
                continue;
            }
            for (NepaIndustryCodePickerController.PickerOption opt : opts) {
                System.assert(String.isNotBlank(opt.value), 'Each option value should not be blank');
                System.assert(String.isNotBlank(opt.label), 'Each option label should not be blank');
            }
        }
    }

    @IsTest
    static void getAllOptions_noExceptionThrown() {
        Exception caughtEx = null;

        Test.startTest();
        try {
            NepaIndustryCodePickerController.PickerOptions result = NepaIndustryCodePickerController.getAllOptions();
        } catch (Exception ex) {
            caughtEx = ex;
        }
        Test.stopTest();

        System.assertEquals(null, caughtEx, 'getAllOptions should not throw an exception');
    }

    @IsTest
    static void getAllOptions_optionsOrderedByCode() {
        Test.startTest();
        NepaIndustryCodePickerController.PickerOptions result = NepaIndustryCodePickerController.getAllOptions();
        Test.stopTest();

        List<NepaIndustryCodePickerController.PickerOption> orderedList = null;
        for (List<NepaIndustryCodePickerController.PickerOption> opts : new List<List<NepaIndustryCodePickerController.PickerOption>>{
            result.sectorOptions,
            result.subSectorOptions,
            result.industryGroupOptions,
            result.industryOptions,
            result.nationalIndustryOptions
        }) {
            if (opts.size() >= 2) {
                orderedList = opts;
                break;
            }
        }

        if (orderedList == null) {
            return;
        }

        System.assert(
            orderedList[0].value <= orderedList[1].value,
            'Options should be ordered ascending by Code__c; first=' + orderedList[0].value + ' second=' + orderedList[1].value
        );
    }
}