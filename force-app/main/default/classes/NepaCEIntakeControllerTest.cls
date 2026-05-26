/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 */
@IsTest
private class NepaCEIntakeControllerTest {

    @TestSetup
    static void setup() {
        Account agency = new Account(Name = 'Test Lead Agency');
        insert agency;
    }

    @IsTest
    static void testCreateIntakeNewProgram() {
        Account agency = [SELECT Id FROM Account LIMIT 1];
        Map<String, Object> programData = new Map<String, Object>{
            'projectTitle'       => 'Test Solar Project',
            'projectDescription' => 'A test description',
            'leadAgencyId'       => agency.Id,
            'projectSector'      => 'Energy',
            'projectType'        => 'Solar',
            'naicsCode'          => '221114',
            'lat'                => '39.7456',
            'lng'                => '-104.9889',
            'locationText'       => 'Denver, CO',
            'startDate'          => '2026-06-01'
        };
        Map<String, Object> processData = new Map<String, Object>{
            'actionType'         => 'CE',
            'disturbanceAcres'   => '5.5',
            'purposeNeed'        => 'Provide renewable energy',
            'regulatoryCitation' => '40 CFR 1508.4',
            'ecMultiDod'         => false,
            'ecUsaczma'          => false
        };

        Test.startTest();
        Id iaId = NepaCEIntakeController.createIntake(programData, processData);
        Test.stopTest();

        System.assertNotEquals(null, iaId, 'Should return a new IA Id');

        IndividualApplication ia = [
            SELECT Id, nepa_related_project__c, Category, StatusCode,
                   nepa_action_type__c, nepa_disturbance_acres__c
            FROM IndividualApplication
            WHERE Id = :iaId
        ];
        System.assertEquals('Permit', ia.Category);
        System.assertEquals('In Progress', ia.StatusCode);
        System.assertEquals('CE', ia.nepa_action_type__c);
        System.assertNotEquals(null, ia.nepa_related_project__c, 'IA must be linked to Program');
        System.assertEquals(5.5, ia.nepa_disturbance_acres__c);

        Program prog = [
            SELECT Name, nepa_location_lat__c, nepa_location_lon__c, nepa_applicant_naics__c
            FROM Program
            WHERE Id = :ia.nepa_related_project__c
        ];
        System.assertEquals('Test Solar Project', prog.Name);
        System.assertEquals(39.7456, prog.nepa_location_lat__c);
        System.assertEquals(-104.9889, prog.nepa_location_lon__c);
        System.assertEquals('221114', prog.nepa_applicant_naics__c);
    }

    @IsTest
    static void testCreateIntakeLicenseTypeCreated() {
        Map<String, Object> programData = new Map<String, Object>{
            'projectTitle' => 'License Type Create Test'
        };
        Map<String, Object> processData = new Map<String, Object>{
            'ecMultiDod' => false,
            'ecUsaczma'  => false
        };

        Integer countBefore = [SELECT COUNT() FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review'];
        System.assertEquals(0, countBefore, 'No pre-existing license type expected');

        Test.startTest();
        NepaCEIntakeController.createIntake(programData, processData);
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review'];
        System.assertEquals(1, countAfter, 'Should create exactly one RegulatoryAuthorizationType');
    }

    @IsTest
    static void testCreateIntakeExistingLicenseType() {
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType();
        rat.Name = 'NEPA Environmental Review';
        rat.RegulatoryAuthCategory = 'Permit';
        insert rat;

        Map<String, Object> programData = new Map<String, Object>{
            'projectTitle' => 'Existing License Type Test'
        };
        Map<String, Object> processData = new Map<String, Object>{
            'ecMultiDod' => false,
            'ecUsaczma'  => false
        };

        Test.startTest();
        NepaCEIntakeController.createIntake(programData, processData);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM RegulatoryAuthorizationType WHERE Name = 'NEPA Environmental Review'];
        System.assertEquals(1, count, 'Should reuse existing RegulatoryAuthorizationType — no duplicate');
    }

    @IsTest
    static void testGetScreeningResultPending() {
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType();
        rat.Name = 'NEPA Environmental Review';
        rat.RegulatoryAuthCategory = 'Permit';
        insert rat;

        Program prog = new Program(Name = 'Screening Pending Test');
        insert prog;

        IndividualApplication ia = new IndividualApplication();
        ia.nepa_related_project__c = prog.Id;
        ia.LicenseTypeId = rat.Id;
        ia.Category = 'Permit';
        ia.StatusCode = 'In Progress';
        insert ia;

        Test.startTest();
        Map<String, Object> result = NepaCEIntakeController.getScreeningResult(ia.Id);
        Test.stopTest();

        System.assert(result.containsKey('reviewType'), 'Result must contain reviewType key');
        System.assert(result.containsKey('ceCode'), 'Result must contain ceCode key');
        System.assert(result.containsKey('confidence'), 'Result must contain confidence key');
        System.assert(result.containsKey('basis'), 'Result must contain basis key');
        System.assertEquals(null, result.get('reviewType'), 'Pending result should have null reviewType');
    }

    @IsTest
    static void testGetScreeningResultFilled() {
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType();
        rat.Name = 'NEPA Environmental Review';
        rat.RegulatoryAuthCategory = 'Permit';
        insert rat;

        Program prog = new Program(Name = 'Screening Filled Test');
        insert prog;

        IndividualApplication ia = new IndividualApplication();
        ia.nepa_related_project__c = prog.Id;
        ia.LicenseTypeId = rat.Id;
        ia.Category = 'Permit';
        ia.StatusCode = 'In Progress';
        ia.nepa_review_type__c = 'CE';
        ia.nepa_process_code__c = 'CE-001';
        ia.nepa_screening_confidence__c = 0.92;
        insert ia;

        Test.startTest();
        Map<String, Object> result = NepaCEIntakeController.getScreeningResult(ia.Id);
        Test.stopTest();

        System.assertEquals('CE', result.get('reviewType'));
        System.assertEquals('CE-001', result.get('ceCode'));
        System.assertEquals(0.92, result.get('confidence'));
    }
}
