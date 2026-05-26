/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 */
public with sharing class NepaCEIntakeController {

    /**
     * Creates a Program (project) and a linked IndividualApplication (process)
     * in a single savepoint transaction. Returns the new IndividualApplication Id.
     */
    @AuraEnabled
    public static Id createIntake(Map<String, Object> programData, Map<String, Object> processData) {
        Savepoint sp = Database.setSavepoint();
        try {
            Program prog = new Program();
            prog.Name = (String) programData.get('projectTitle');
            prog.nepa_project_description__c = (String) programData.get('projectDescription');
            prog.nepa_lead_agency__c = (Id) programData.get('leadAgencyId');
            prog.nepa_project_sector__c = (String) programData.get('projectSector');
            prog.nepa_project_type__c = (String) programData.get('projectType');
            prog.nepa_applicant_naics__c = (String) programData.get('naicsCode');
            if (programData.get('lat') != null) {
                prog.nepa_location_lat__c = Decimal.valueOf(String.valueOf(programData.get('lat')));
            }
            if (programData.get('lng') != null) {
                prog.nepa_location_lon__c = Decimal.valueOf(String.valueOf(programData.get('lng')));
            }
            prog.nepa_location_text__c = (String) programData.get('locationText');
            if (programData.get('startDate') != null) {
                prog.nepa_start_date__c = Date.valueOf((String) programData.get('startDate'));
            }
            insert prog;

            Id licenseTypeId = getLicenseTypeId();

            IndividualApplication ia = new IndividualApplication();
            ia.nepa_related_project__c = prog.Id;
            ia.LicenseTypeId = licenseTypeId;
            ia.Category = 'Permit';
            ia.StatusCode = 'In Progress';
            ia.nepa_action_type__c = (String) processData.get('actionType');
            if (processData.get('disturbanceAcres') != null) {
                ia.nepa_disturbance_acres__c = Decimal.valueOf(String.valueOf(processData.get('disturbanceAcres')));
            }
            ia.nepa_purpose_need__c = (String) processData.get('purposeNeed');
            ia.nepa_regulatory_citation__c = (String) processData.get('regulatoryCitation');
            ia.nepa_ec_multi_dod__c = (Boolean) processData.get('ecMultiDod');
            ia.nepa_ec_usace_czma__c = (Boolean) processData.get('ecUsaczma');
            insert ia;

            return ia.Id;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Intake failed: ' + e.getMessage());
        }
    }

    /**
     * Returns the current CE screening result for the given IndividualApplication.
     * All keys are always present; values may be null while the async RTF is still running.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getScreeningResult(Id processId) {
        IndividualApplication ia = [
            SELECT nepa_review_type__c, nepa_process_code__c,
                   nepa_screening_confidence__c, nepa_classification_basis__c
            FROM IndividualApplication
            WHERE Id = :processId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        Map<String, Object> result = new Map<String, Object>();
        result.put('reviewType', ia.nepa_review_type__c);
        result.put('ceCode', ia.nepa_process_code__c);
        result.put('confidence', ia.nepa_screening_confidence__c);
        result.put('basis', ia.nepa_classification_basis__c);
        return result;
    }

    private static Id getLicenseTypeId() {
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType();
        rat.Name = 'NEPA Environmental Review';
        rat.RegulatoryAuthCategory = 'Permit';
        insert rat;
        return rat.Id;
    }
}
