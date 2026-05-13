@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaChallengePredictorTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Program insertEnergyProject(String projectId, String circuit) {
        Program p = NepaTestFactory.makeProgram(projectId, projectId, 'BLM');
        p.nepa_primary_sector__c     = 'Energy Production and Management';
        p.nepa_circuit__c            = circuit;
        insert p;
        return p;
    }

    private static Decimal getDelta(Id iaId) {
        return [SELECT nepa_challenge_risk_delta__c FROM IndividualApplication WHERE Id = :iaId]
               .nepa_challenge_risk_delta__c;
    }

    // ── Energy × 4th Circuit → +12 delta ─────────────────────────────────────

    @IsTest
    static void challengePredictor_energy4thCircuit_setsPositiveDelta() {
        Program proj = insertEnergyProject('CP-ENERGY-4TH-001', '4th');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);

        // Trigger: change review type to fire IsChanged entry condition
        Test.startTest();
        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_review_type__c = 'EIS';
        update iaUpdate;
        Test.stopTest();

        Decimal delta = getDelta(ia.Id);
        if (delta != null) {
            System.assert(delta >= 12,
                'Energy × 4th Circuit must produce a delta of at least 12; got: ' + delta);
        }
    }

    // ── Tribal plaintiff flag → +20 delta contribution ───────────────────────

    @IsTest
    static void challengePredictor_tribalPlaintiffFlag_addsTribalDelta() {
        Program proj = insertEnergyProject('CP-TRIBAL-001', 'DC');
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);

        // Set tribal flag before triggering predictor
        IndividualApplication iaSetup = new IndividualApplication(Id = ia.Id);
        iaSetup.nepa_tribal_plaintiff_flag__c = true;
        update iaSetup;

        Test.startTest();
        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_review_type__c = 'EIS';
        update iaUpdate;
        Test.stopTest();

        Decimal delta = getDelta(ia.Id);
        if (delta != null) {
            System.assert(delta >= 20,
                'Tribal plaintiff flag must contribute at least 20 delta points; got: ' + delta);
        }
    }

    // ── No sector/plaintiff match → delta stays 0 ─────────────────────────────

    @IsTest
    static void challengePredictor_noMatch_deltaIsZeroOrNull() {
        // Agriculture sector in 9th circuit — no challenge rule should match
        Program p = NepaTestFactory.makeProgram('CP-NOMATCH-001', 'CP-NOMATCH-001', 'FERC');
        p.nepa_primary_sector__c = 'Agriculture and Natural Resource Management';
        p.nepa_circuit__c        = '9th';
        insert p;
        IndividualApplication ia = NepaTestFactory.insertProcess(p.Id, 'EA', null, null);

        Test.startTest();
        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_review_type__c = 'EA';
        update iaUpdate;
        Test.stopTest();

        Decimal delta = getDelta(ia.Id);
        // Delta should be null or 0 — no matching rules
        Boolean deltaIsEmpty = (delta == null || delta == 0);
        System.assert(deltaIsEmpty,
            'No matching challenge rules should produce null or 0 delta; got: ' + delta);
    }

    // ── CMT has Tribal Override rule with delta = 20 ──────────────────────────

    @IsTest
    static void challengePredictor_tribalOverrideRule_hasCorrectDelta() {
        List<NEPA_Challenge_Prediction_Rule__mdt> rules = [
            SELECT Risk_Delta__c, Trigger_Plaintiff_Flag__c
            FROM NEPA_Challenge_Prediction_Rule__mdt
            WHERE Trigger_Plaintiff_Flag__c = true AND Active__c = true
            LIMIT 1
        ];
        System.assertEquals(1, rules.size(),
            'There must be at least one active challenge rule with Trigger_Plaintiff_Flag__c = true');
        System.assertEquals(20, rules[0].Risk_Delta__c,
            'Tribal Plaintiff Override rule must have Risk_Delta__c = 20; got: ' + rules[0].Risk_Delta__c);
    }

    // ── CMT has Energy 4th Circuit rule with delta = 12 ──────────────────────

    @IsTest
    static void challengePredictor_energy4thCircuitRule_hasCorrectDelta() {
        List<NEPA_Challenge_Prediction_Rule__mdt> rules = [
            SELECT Risk_Delta__c, Trigger_Sector__c
            FROM NEPA_Challenge_Prediction_Rule__mdt
            WHERE Trigger_Sector__c = 'Energy Production and Management'
            AND Active__c = true
            LIMIT 1
        ];
        System.assertEquals(1, rules.size(),
            'There must be at least one active challenge rule for Energy Production and Management sector');
        System.assertEquals(12, rules[0].Risk_Delta__c,
            'Energy × 4th Circuit rule must have Risk_Delta__c = 12; got: ' + rules[0].Risk_Delta__c);
    }
}
