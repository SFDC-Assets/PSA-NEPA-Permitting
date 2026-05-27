@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaPhase2ApplicabilitySetterTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('P2A-001', 'Phase 2 Applicability Test', 'BLM');
    }

    private static Id getProjId() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'P2A-001' LIMIT 1].Id;
    }

    private static IndividualApplication queryIa(Id iaId) {
        return [
            SELECT nepa_phase2_applicable__c, nepa_climate_assessment_required__c
            FROM IndividualApplication
            WHERE Id = :iaId
        ];
    }

    // ── EA → both flags true ──────────────────────────────────────────────────

    @IsTest
    static void ea_setsPhase2FlagsTrue() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.insertProcess(projId, 'EA', null, null);

        IndividualApplication result = queryIa(ia.Id);

        System.assertEquals(true, result.nepa_phase2_applicable__c,
            'EA review type must set nepa_phase2_applicable__c = true');
        System.assertEquals(true, result.nepa_climate_assessment_required__c,
            'EA review type must set nepa_climate_assessment_required__c = true');
    }

    // ── EIS → both flags true ─────────────────────────────────────────────────

    @IsTest
    static void eis_setsPhase2FlagsTrue() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.insertProcess(projId, 'EIS', null, null);

        IndividualApplication result = queryIa(ia.Id);

        System.assertEquals(true, result.nepa_phase2_applicable__c,
            'EIS review type must set nepa_phase2_applicable__c = true');
        System.assertEquals(true, result.nepa_climate_assessment_required__c,
            'EIS review type must set nepa_climate_assessment_required__c = true');
    }

    // ── CE → both flags false ─────────────────────────────────────────────────

    @IsTest
    static void ce_clearsBothPhase2Flags() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.insertProcess(projId, 'CE', null, null);

        IndividualApplication result = queryIa(ia.Id);

        System.assertEquals(false, result.nepa_phase2_applicable__c,
            'CE review type must set nepa_phase2_applicable__c = false');
        System.assertEquals(false, result.nepa_climate_assessment_required__c,
            'CE review type must set nepa_climate_assessment_required__c = false');
    }

    // ── EA → CE: flags cleared ────────────────────────────────────────────────

    @IsTest
    static void changeEAToCE_clearsBothFlags() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.insertProcess(projId, 'EA', null, null);

        ia.nepa_review_type__c = 'CE';
        update ia;

        IndividualApplication result = queryIa(ia.Id);

        System.assertEquals(false, result.nepa_phase2_applicable__c,
            'Changing review type from EA to CE must clear nepa_phase2_applicable__c');
        System.assertEquals(false, result.nepa_climate_assessment_required__c,
            'Changing review type from EA to CE must clear nepa_climate_assessment_required__c');
    }

    // ── CE → EIS: flags set ───────────────────────────────────────────────────

    @IsTest
    static void changeCEToEIS_setsBothFlags() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.insertProcess(projId, 'CE', null, null);

        ia.nepa_review_type__c = 'EIS';
        update ia;

        IndividualApplication result = queryIa(ia.Id);

        System.assertEquals(true, result.nepa_phase2_applicable__c,
            'Changing review type from CE to EIS must set nepa_phase2_applicable__c = true');
        System.assertEquals(true, result.nepa_climate_assessment_required__c,
            'Changing review type from CE to EIS must set nepa_climate_assessment_required__c = true');
    }
}