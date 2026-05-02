/** Tests validation rules on IndividualApplication: description length, FONSI/ROD on CE, waiver legal sufficiency, tiering age check. */
@IsTest
@SuppressWarnings('PMD.MethodNamingConventions, PMD.ApexUnitTestClassShouldHaveRunAs')
private class NepaValidationRuleTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('VR-TEST-001', 'Validation Rule Test Project', 'BLM');
        NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
    }

    private static IndividualApplication getProcess() {
        return [
            SELECT Id, nepa_review_type__c, nepa_description__c,
                   nepa_decision_document_type__c, nepa_waiver_invoked__c,
                   nepa_waiver_statute_cite__c, nepa_tiering_to_prior_eis__c,
                   nepa_prior_nepa_date__c, nepa_supplementation_review_complete__c
            FROM IndividualApplication
            LIMIT 1
        ];
    }

    // ── VR_Description_Minimum_Length ─────────────────────────────────────────

    @IsTest
    static void descriptionMinLength_199chars_blocks() {
        IndividualApplication ia = getProcess();
        ia.nepa_description__c = 'x'.repeat(199);
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void descriptionMinLength_200chars_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_description__c = 'x'.repeat(200);
        update ia;
        IndividualApplication result = [SELECT nepa_description__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals(200, result.nepa_description__c.length());
    }

    @IsTest
    static void descriptionMinLength_blank_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_description__c = null;
        update ia;
        IndividualApplication result = [SELECT nepa_description__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals(null, result.nepa_description__c);
    }

    // ── VR_FONSI_ROD_On_CE ───────────────────────────────────────────────────

    @IsTest
    static void fonsiRodOnCe_ceWithFonsi_blocks() {
        IndividualApplication ia = getProcess();
        ia.nepa_review_type__c = 'CE';
        ia.nepa_decision_document_type__c = 'FONSI';
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void fonsiRodOnCe_ceWithRod_blocks() {
        IndividualApplication ia = getProcess();
        ia.nepa_review_type__c = 'CE';
        ia.nepa_decision_document_type__c = 'ROD';
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void fonsiRodOnCe_ceWithNoa_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_review_type__c = 'CE';
        ia.nepa_decision_document_type__c = 'NOA';
        update ia;
        IndividualApplication result = [SELECT nepa_decision_document_type__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('NOA', result.nepa_decision_document_type__c);
    }

    @IsTest
    static void fonsiRodOnCe_eisWithFonsi_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_review_type__c = 'EIS';
        ia.nepa_decision_document_type__c = 'FONSI';
        update ia;
        IndividualApplication result = [SELECT nepa_decision_document_type__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('FONSI', result.nepa_decision_document_type__c);
    }

    // ── VR_003_NEPA_Waiver_Legal_Sufficiency ─────────────────────────────────

    @IsTest
    static void waiverLegalSufficiency_invokedBlankStatute_blocks() {
        IndividualApplication ia = getProcess();
        ia.nepa_waiver_invoked__c = true;
        ia.nepa_waiver_statute_cite__c = null;
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void waiverLegalSufficiency_invokedWithStatute_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_waiver_invoked__c = true;
        ia.nepa_waiver_statute_cite__c = '42 U.S.C. 4332';
        update ia;
        IndividualApplication result = [SELECT nepa_waiver_statute_cite__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('42 U.S.C. 4332', result.nepa_waiver_statute_cite__c);
    }

    @IsTest
    static void waiverLegalSufficiency_notInvokedBlankStatute_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_waiver_invoked__c = false;
        ia.nepa_waiver_statute_cite__c = null;
        update ia;
        IndividualApplication result = [SELECT nepa_waiver_invoked__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals(false, result.nepa_waiver_invoked__c);
    }

    // ── VR_006_Tiering_Age_Check ─────────────────────────────────────────────

    @IsTest
    static void tieringAgeCheck_staleDateNoSupplementation_blocks() {
        IndividualApplication ia = getProcess();
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = false;
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void tieringAgeCheck_staleDateWithSupplementation_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = true;
        update ia;
        IndividualApplication result = [SELECT nepa_supplementation_review_complete__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals(true, result.nepa_supplementation_review_complete__c);
    }

    @IsTest
    static void tieringAgeCheck_recentDateNoSupplementation_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-100);
        ia.nepa_supplementation_review_complete__c = false;
        update ia;
        IndividualApplication result = [SELECT nepa_prior_nepa_date__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals(Date.today().addDays(-100), result.nepa_prior_nepa_date__c);
    }

    @IsTest
    static void tieringAgeCheck_noTieringStaleDateNoSupplementation_saves() {
        IndividualApplication ia = getProcess();
        ia.nepa_tiering_to_prior_eis__c = false;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = false;
        update ia;
        IndividualApplication result = [SELECT nepa_tiering_to_prior_eis__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals(false, result.nepa_tiering_to_prior_eis__c);
    }
}
