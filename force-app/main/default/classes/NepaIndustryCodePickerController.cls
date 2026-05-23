/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 */
public with sharing class NepaIndustryCodePickerController {

    public class PickerOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String parentValue;

        public PickerOption(String value, String label, String parentValue) {
            this.value = value;
            this.label = label;
            this.parentValue = parentValue;
        }
    }

    public class PickerOptions {
        @AuraEnabled public List<PickerOption> sectorOptions;
        @AuraEnabled public List<PickerOption> subSectorOptions;
        @AuraEnabled public List<PickerOption> industryGroupOptions;
        @AuraEnabled public List<PickerOption> industryOptions;
        @AuraEnabled public List<PickerOption> nationalIndustryOptions;
    }

    @AuraEnabled(cacheable=true)
    public static PickerOptions getAllOptions() {
        PickerOptions result = new PickerOptions();
        result.sectorOptions           = queryLevel('Sector');
        result.subSectorOptions        = queryLevel('SubSector');
        result.industryGroupOptions    = queryLevel('IndustryGroup');
        result.industryOptions         = queryLevel('Industry');
        result.nationalIndustryOptions = queryLevel('NationalIndustry');
        return result;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<PickerOption> queryLevel(String level) {
        List<PickerOption> options = new List<PickerOption>();
        for (NEPA_NAICS_Code__mdt rec : [
            SELECT Code__c, Title__c, Parent_Code__c
            FROM NEPA_NAICS_Code__mdt
            WHERE Level__c = :level
            ORDER BY Code__c ASC
        ]) {
            String lbl = String.isNotBlank(rec.Title__c) ? rec.Title__c : rec.Code__c;
            options.add(new PickerOption(rec.Code__c, lbl, rec.Parent_Code__c));
        }
        return options;
    }

}
