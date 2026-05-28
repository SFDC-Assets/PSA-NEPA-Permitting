@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaPermitIssuedScheduleCreatorTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram(
            'PISC-TEST-001', 'Permit Issued Schedule Creator Test', 'BLM'
        );
        IndividualApplication ia = NepaTestFactory.makeProcess(proj.Id, 'EA', null, null);
        insert ia;
    }

    private static IndividualApplication getIA() {
        return [
            SELECT Id
            FROM IndividualApplication
            WHERE nepa_related_project__r.nepa_project_id__c = 'PISC-TEST-001'
            LIMIT 1
        ];
    }

    @IsTest
    static void permitStatusChangedToIssued_createsVisits() {
        List<NEPA_Inspection_Schedule__mdt> schedules = [
            SELECT Id FROM NEPA_Inspection_Schedule__mdt WHERE Active__c = true LIMIT 1
        ];
        if (schedules.isEmpty()) {
            return;
        }

        IndividualApplication ia = getIA();
        nepa_required_permit__c permit = NepaTestFactory.insertRequiredPermit(
            ia.Id, 'Not Started', true, Date.today().addDays(90)
        );

        Test.startTest();
        permit.nepa_permit_status__c = 'Issued';
        update permit;
        Test.stopTest();

        List<Visit> visits = [
            SELECT Id, nepa_discipline__c, nepa_auto_generated__c,
                   nepa_state_risk_context__c, nepa_trigger_layer__c
            FROM Visit WHERE nepa_process__c = :ia.Id
        ];
        System.assertNotEquals(0, visits.size(),
            'Visits must be created when permit status changes to Issued');
        Visit v = visits[0];
        System.assertEquals(true, v.nepa_auto_generated__c,
            'Visit must be flagged as auto-generated');
        System.assertNotEquals(null, v.nepa_discipline__c,
            'Visit must have nepa_discipline__c populated from Inspection_Type__c');
        System.assertEquals(null, v.nepa_trigger_layer__c,
            'Visit must not have nepa_trigger_layer__c set — that field is for GIS-triggered visits only');
    }

    @IsTest
    static void permitAlreadyIssued_onInsert_createsVisits() {
        List<NEPA_Inspection_Schedule__mdt> schedules = [
            SELECT Id FROM NEPA_Inspection_Schedule__mdt WHERE Active__c = true LIMIT 1
        ];
        if (schedules.isEmpty()) {
            return;
        }

        IndividualApplication ia = getIA();
        nepa_required_permit__c permit = NepaTestFactory.makeRequiredPermit(
            ia.Id, 'Issued', true, Date.today().addDays(90)
        );

        Test.startTest();
        insert permit;
        Test.stopTest();

        List<Visit> visits = [
            SELECT Id FROM Visit WHERE nepa_process__c = :ia.Id
        ];
        System.assertNotEquals(0, visits.size(),
            'Visits must be created when a permit is inserted with status Issued');
    }

    @IsTest
    static void permitStatusNotIssued_doesNotCreateVisits() {
        IndividualApplication ia = getIA();
        nepa_required_permit__c permit = NepaTestFactory.insertRequiredPermit(
            ia.Id, 'Not Started', false, null
        );

        Test.startTest();
        permit.nepa_permit_status__c = 'Under Review';
        update permit;
        Test.stopTest();

        List<Visit> visits = [
            SELECT Id FROM Visit WHERE nepa_process__c = :ia.Id
        ];
        System.assertEquals(0, visits.size(),
            'No Visits must be created when permit status is not Issued');
    }

    @IsTest
    static void permitWithNoMatchingSchedule_createsNoVisits() {
        IndividualApplication ia = getIA();
        nepa_required_permit__c permit = NepaTestFactory.makeRequiredPermit(
            ia.Id, 'Issued', false, Date.today().addDays(90)
        );
        permit.nepa_permit_type__c = 'Unknown Permit Type XYZ';

        Test.startTest();
        insert permit;
        Test.stopTest();

        List<Visit> visits = [
            SELECT Id FROM Visit WHERE nepa_process__c = :ia.Id
        ];
        System.assertEquals(0, visits.size(),
            'No Visits must be created when no NEPA_Inspection_Schedule__mdt matches the permit type');
    }

    @IsTest
    static void permitIssued_visitFieldsPopulatedCorrectly() {
        List<NEPA_Inspection_Schedule__mdt> schedules = [
            SELECT Id FROM NEPA_Inspection_Schedule__mdt WHERE Active__c = true LIMIT 1
        ];
        if (schedules.isEmpty()) {
            return;
        }

        IndividualApplication ia = getIA();
        nepa_required_permit__c permit = NepaTestFactory.insertRequiredPermit(
            ia.Id, 'Not Started', true, Date.today().addDays(90)
        );

        Test.startTest();
        permit.nepa_permit_status__c = 'Issued';
        update permit;
        Test.stopTest();

        List<Visit> visits = [
            SELECT Id, nepa_discipline__c, nepa_auto_generated__c, nepa_hard_gate__c,
                   nepa_state_risk_context__c, nepa_trigger_layer__c,
                   nepa_process__c
            FROM Visit WHERE nepa_process__c = :ia.Id
        ];
        System.assertNotEquals(0, visits.size(), 'Expected Visit records after permit issued');

        for (Visit v : visits) {
            System.assertEquals(true, v.nepa_auto_generated__c,
                'nepa_auto_generated__c must be true on flow-created visits');
            System.assertEquals(false, v.nepa_hard_gate__c,
                'nepa_hard_gate__c must be false on permit-issued visits');
            System.assertNotEquals(null, v.nepa_discipline__c,
                'nepa_discipline__c must be populated from NEPA_Inspection_Schedule__mdt.Inspection_Type__c');
            System.assertEquals(null, v.nepa_trigger_layer__c,
                'nepa_trigger_layer__c must be null — this field is for GIS-triggered visits only, not permit-issued visits');
            System.assertEquals(ia.Id, v.nepa_process__c,
                'Visit must be linked to the parent IndividualApplication');
        }
    }

    @IsTest
    static void bulkPath_multiplePermits_createsVisits() {
        List<NEPA_Inspection_Schedule__mdt> schedules = [
            SELECT Id FROM NEPA_Inspection_Schedule__mdt WHERE Active__c = true LIMIT 1
        ];
        if (schedules.isEmpty()) {
            return;
        }

        Program proj = NepaTestFactory.insertProgram(
            'PISC-BULK-001', 'Permit Issued Bulk Test', 'BLM'
        );

        List<IndividualApplication> ias = new List<IndividualApplication>();
        for (Integer i = 0; i < 5; i++) {
            ias.add(NepaTestFactory.makeProcess(proj.Id, 'EA', null, null));
        }
        insert ias;

        List<nepa_required_permit__c> permits = new List<nepa_required_permit__c>();
        for (IndividualApplication ia : ias) {
            permits.add(NepaTestFactory.makeRequiredPermit(
                ia.Id, 'Not Started', true, Date.today().addDays(90)
            ));
        }
        insert permits;

        List<nepa_required_permit__c> updates = new List<nepa_required_permit__c>();
        for (nepa_required_permit__c p : permits) {
            updates.add(new nepa_required_permit__c(
                Id = p.Id,
                nepa_permit_status__c = 'Issued'
            ));
        }

        Test.startTest();
        update updates;
        Test.stopTest();

        Set<Id> iaIds = new Set<Id>();
        for (IndividualApplication ia : ias) {
            iaIds.add(ia.Id);
        }

        List<Visit> visits = [
            SELECT Id FROM Visit WHERE nepa_process__c IN :iaIds
        ];
        System.assertNotEquals(0, visits.size(),
            'Visits must be created across multiple permits updated to Issued in bulk');
    }
}