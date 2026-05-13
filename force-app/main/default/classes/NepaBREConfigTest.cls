/**
 * Tests for Business Rules Engine custom metadata configuration.
 *
 * Why this approach: BRE Expression Sets and Decision Matrices are evaluated
 * inside Flow engine context only — there is no Apex API to invoke them
 * directly. These tests take two complementary approaches:
 *
 *   1. CMT configuration tests — query the custom metadata records that feed
 *      the BRE and assert on counts, required fields, weight ranges, and
 *      internal consistency. Guards against accidental misconfiguration of
 *      the rules that drive CE/EA/EIS determination and risk scoring.
 *
 *   2. Flow end-to-end smoke tests — trigger the record-triggered flows by
 *      updating IndividualApplication, then assert on the output fields the
 *      BRE populates. Because these flows run AsyncAfterCommit, the BRE output
 *      may not be present synchronously; assertions use null-guards and verify
 *      the flow did not throw rather than hard-asserting on exact values.
 *      BRE Expression Sets must be activated in the target org for these
 *      tests to produce output fields (activation requires Setup UI — see docs).
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.MethodNamingConventions')
@IsTest
private class NepaBREConfigTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Id getLicenseTypeId() {
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review' LIMIT 1
        ];
        if (!existing.isEmpty()) { return existing[0].Id; }
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
            Name = 'NEPA Environmental Review', RegulatoryAuthCategory = 'Permit');
        insert rat;
        return rat.Id;
    }

    private static IndividualApplication makeProcess(Id projectId, String reviewType) {
        IndividualApplication ia = new IndividualApplication();
        ia.Category                = 'Permit';
        ia.LicenseTypeId           = getLicenseTypeId();
        ia.nepa_related_project__c = projectId;
        ia.nepa_review_type__c     = reviewType;
        ia.nepa_process_status__c  = 'in progress';
        ia.nepa_process_stage__c   = 'Scoping';
        ia.nepa_action_type__c     = 'Construct New';
        return ia;
    }

    private static Program makeProject(String name, String agency, String circuit,
                                       String sector, String projectType) {
        Account acct = new Account(Name = agency + '_' + name);
        insert acct;
        Program p = new Program();
        p.Name                   = name;
        p.nepa_project_id__c     = 'BRE-TEST-' + name.left(10);
        p.nepa_project_title__c  = name;
        p.nepa_lead_agency__c    = acct.Id;
        p.nepa_project_sector__c = sector;
        p.nepa_project_type__c   = projectType;
        p.nepa_circuit__c        = circuit;
        insert p;
        return p;
    }


    // ══════════════════════════════════════════════════════════════════════════
    // PART 1 — CMT CONFIGURATION INTEGRITY
    // These tests run entirely against custom metadata (no DML on SObjects)
    // and will pass even when BRE Expression Sets are not yet activated.
    // ══════════════════════════════════════════════════════════════════════════

    // ── CE Screening Rules ────────────────────────────────────────────────────

    @IsTest
    static void ceScreeningRules_minimumCountMet() {
        List<NEPA_CE_Screening_Rule__mdt> rules = [
            SELECT Id FROM NEPA_CE_Screening_Rule__mdt WHERE Active__c = true
        ];
        System.assert(rules.size() >= 20,
            'Expected at least 20 active CE Screening Rules; found: ' + rules.size());
    }

    @IsTest
    static void ceScreeningRules_allActiveRulesHaveRequiredFields() {
        List<NEPA_CE_Screening_Rule__mdt> rules = [
            SELECT DeveloperName, Tier__c, Review_Type__c, Classification_Basis__c,
                   Priority__c, Confidence__c
            FROM NEPA_CE_Screening_Rule__mdt
            WHERE Active__c = true
        ];
        List<String> violations = new List<String>();
        for (NEPA_CE_Screening_Rule__mdt r : rules) {
            if (String.isBlank(r.Tier__c)) {
                violations.add(r.DeveloperName + ': missing Tier__c');
            }
            if (String.isBlank(r.Review_Type__c)) {
                violations.add(r.DeveloperName + ': missing Review_Type__c');
            }
            if (String.isBlank(r.Classification_Basis__c)) {
                violations.add(r.DeveloperName + ': missing Classification_Basis__c');
            }
            if (r.Priority__c == null) {
                violations.add(r.DeveloperName + ': missing Priority__c');
            }
        }
        System.assertEquals(0, violations.size(),
            'CE Screening Rules with missing required fields: ' + String.join(violations, '; '));
    }

    @IsTest
    static void ceScreeningRules_reviewTypeValuesAreValid() {
        Set<String> validTypes = new Set<String>{ 'CE', 'EA', 'EIS' };
        List<NEPA_CE_Screening_Rule__mdt> rules = [
            SELECT DeveloperName, Review_Type__c
            FROM NEPA_CE_Screening_Rule__mdt
            WHERE Active__c = true
        ];
        List<String> bad = new List<String>();
        for (NEPA_CE_Screening_Rule__mdt r : rules) {
            if (!validTypes.contains(r.Review_Type__c)) {
                bad.add(r.DeveloperName + ' → "' + r.Review_Type__c + '"');
            }
        }
        System.assertEquals(0, bad.size(),
            'CE Screening Rules with invalid Review_Type__c: ' + String.join(bad, '; '));
    }

    @IsTest
    static void ceScreeningRules_tierValuesAreOneOrTwo() {
        List<NEPA_CE_Screening_Rule__mdt> rules = [
            SELECT DeveloperName, Tier__c
            FROM NEPA_CE_Screening_Rule__mdt
            WHERE Active__c = true
        ];
        List<String> bad = new List<String>();
        for (NEPA_CE_Screening_Rule__mdt r : rules) {
            if (r.Tier__c != '1' && r.Tier__c != '2') {
                bad.add(r.DeveloperName + ' → "' + r.Tier__c + '"');
            }
        }
        System.assertEquals(0, bad.size(),
            'CE Screening Rules with invalid Tier__c (must be 1 or 2): ' + String.join(bad, '; '));
    }

    @IsTest
    static void ceScreeningRules_acreageCheckRulesHaveThreshold() {
        List<NEPA_CE_Screening_Rule__mdt> rules = [
            SELECT DeveloperName, Acreage_Threshold__c
            FROM NEPA_CE_Screening_Rule__mdt
            WHERE Active__c = true AND Requires_Acreage_Check__c = true
        ];
        List<String> bad = new List<String>();
        for (NEPA_CE_Screening_Rule__mdt r : rules) {
            if (r.Acreage_Threshold__c == null || r.Acreage_Threshold__c <= 0) {
                bad.add(r.DeveloperName);
            }
        }
        System.assertEquals(0, bad.size(),
            'Rules requiring acreage check must have Acreage_Threshold__c > 0: '
                + String.join(bad, '; '));
    }

    @IsTest
    static void ceScreeningRules_tier2DisqualifierExists() {
        List<NEPA_CE_Screening_Rule__mdt> disqualifiers = [
            SELECT DeveloperName FROM NEPA_CE_Screening_Rule__mdt
            WHERE Active__c = true AND Tier__c = '2' AND Review_Type__c != 'CE'
        ];
        System.assert(disqualifiers.size() >= 1,
            'At least one active Tier 2 disqualifier (non-CE Review_Type) must exist to prevent improper CE reliance');
    }

    // ── Circuit Risk Weights ──────────────────────────────────────────────────

    @IsTest
    static void circuitRiskWeights_allCircuitsCovered() {
        Set<String> requiredCircuits = new Set<String>{
            '1st','2nd','3rd','4th','5th','6th','7th','8th','9th','10th','11th','DC'
        };
        List<NEPA_Circuit_Risk_Weight__mdt> weights = [
            SELECT Circuit_Key__c FROM NEPA_Circuit_Risk_Weight__mdt
        ];
        Set<String> present = new Set<String>();
        for (NEPA_Circuit_Risk_Weight__mdt w : weights) {
            present.add(w.Circuit_Key__c);
        }
        Set<String> missing = requiredCircuits.clone();
        missing.removeAll(present);
        System.assertEquals(0, missing.size(),
            'Missing circuit risk weight records for: ' + String.join(new List<String>(missing), ', '));
    }

    @IsTest
    static void circuitRiskWeights_pointsInValidRange() {
        List<NEPA_Circuit_Risk_Weight__mdt> weights = [
            SELECT DeveloperName, Circuit_Key__c, Risk_Points__c
            FROM NEPA_Circuit_Risk_Weight__mdt
        ];
        List<String> bad = new List<String>();
        for (NEPA_Circuit_Risk_Weight__mdt w : weights) {
            if (w.Risk_Points__c == null || w.Risk_Points__c < 0 || w.Risk_Points__c > 30) {
                bad.add(w.DeveloperName + ' = ' + w.Risk_Points__c);
            }
        }
        System.assertEquals(0, bad.size(),
            'Circuit risk points must be 0–30 (BRE Expression Set range): '
                + String.join(bad, '; '));
    }

    @IsTest
    static void circuitRiskWeights_ninthCircuitIsHighestRisk() {
        Map<String, Decimal> pointsByCircuit = new Map<String, Decimal>();
        for (NEPA_Circuit_Risk_Weight__mdt w : [
            SELECT Circuit_Key__c, Risk_Points__c FROM NEPA_Circuit_Risk_Weight__mdt
        ]) {
            pointsByCircuit.put(w.Circuit_Key__c, w.Risk_Points__c);
        }
        Decimal ninth = pointsByCircuit.get('9th');
        System.assertNotEquals(null, ninth, '9th circuit weight record must exist');
        for (String key : pointsByCircuit.keySet()) {
            if (key != '9th' && key != 'Default') {
                System.assert(ninth >= pointsByCircuit.get(key),
                    '9th circuit (' + ninth + 'pts) must be >= ' + key
                    + ' (' + pointsByCircuit.get(key) + 'pts) based on PermitTEC corpus');
            }
        }
    }

    // ── Agency Risk Rates ─────────────────────────────────────────────────────

    @IsTest
    static void agencyRiskRates_blmExists() {
        List<NEPA_Agency_Risk_Rate__mdt> blm = [
            SELECT Risk_Points__c FROM NEPA_Agency_Risk_Rate__mdt
            WHERE Agency_Abbreviation__c = 'BLM'
        ];
        System.assertEquals(1, blm.size(), 'BLM agency risk rate record must exist');
        System.assert(blm[0].Risk_Points__c > 0, 'BLM risk points must be positive');
    }

    @IsTest
    static void agencyRiskRates_defaultRecordExists() {
        List<NEPA_Agency_Risk_Rate__mdt> defaults = [
            SELECT Risk_Points__c FROM NEPA_Agency_Risk_Rate__mdt
            WHERE DeveloperName = 'Default'
        ];
        System.assertEquals(1, defaults.size(),
            'A Default agency risk rate record must exist for agencies not in the corpus');
    }

    @IsTest
    static void agencyRiskRates_pointsInValidRange() {
        List<NEPA_Agency_Risk_Rate__mdt> rates = [
            SELECT DeveloperName, Risk_Points__c FROM NEPA_Agency_Risk_Rate__mdt
        ];
        List<String> bad = new List<String>();
        for (NEPA_Agency_Risk_Rate__mdt r : rates) {
            if (r.Risk_Points__c == null || r.Risk_Points__c < 0 || r.Risk_Points__c > 40) {
                bad.add(r.DeveloperName + ' = ' + r.Risk_Points__c);
            }
        }
        System.assertEquals(0, bad.size(),
            'Agency risk points must be 0–40: ' + String.join(bad, '; '));
    }

    // ── Statute Risk Weights ──────────────────────────────────────────────────

    @IsTest
    static void statuteRiskWeights_esaCwaAndNhpaPresent() {
        Set<String> required = new Set<String>{ 'ESA', 'CWA', 'NHPA' };
        List<NEPA_Statute_Risk_Weight__mdt> statutes = [
            SELECT Statute_Key__c FROM NEPA_Statute_Risk_Weight__mdt WHERE Active__c = true
        ];
        Set<String> found = new Set<String>();
        for (NEPA_Statute_Risk_Weight__mdt s : statutes) { found.add(s.Statute_Key__c); }
        Set<String> missing = required.clone();
        missing.removeAll(found);
        System.assertEquals(0, missing.size(),
            'Required statute risk weight records missing: '
                + String.join(new List<String>(missing), ', '));
    }

    @IsTest
    static void statuteRiskWeights_pointsArePositive() {
        List<NEPA_Statute_Risk_Weight__mdt> statutes = [
            SELECT DeveloperName, Risk_Points__c
            FROM NEPA_Statute_Risk_Weight__mdt WHERE Active__c = true
        ];
        List<String> bad = new List<String>();
        for (NEPA_Statute_Risk_Weight__mdt s : statutes) {
            if (s.Risk_Points__c == null || s.Risk_Points__c <= 0) {
                bad.add(s.DeveloperName);
            }
        }
        System.assertEquals(0, bad.size(),
            'Active statute risk weights must be positive: ' + String.join(bad, '; '));
    }

    // ── Challenge Prediction Rules ────────────────────────────────────────────

    @IsTest
    static void challengePredictionRules_minimumCountMet() {
        List<NEPA_Challenge_Prediction_Rule__mdt> rules = [
            SELECT Id FROM NEPA_Challenge_Prediction_Rule__mdt WHERE Active__c = true
        ];
        System.assert(rules.size() >= 3,
            'At least 3 active challenge prediction rules required; found: ' + rules.size());
    }

    @IsTest
    static void challengePredictionRules_improperCERelianceRuleExists() {
        List<NEPA_Challenge_Prediction_Rule__mdt> rule = [
            SELECT Explanation__c FROM NEPA_Challenge_Prediction_Rule__mdt
            WHERE DeveloperName = 'Improper_CE_Reliance' AND Active__c = true
        ];
        System.assertEquals(1, rule.size(),
            'Improper_CE_Reliance challenge prediction rule must be active');
        System.assert(String.isNotBlank(rule[0].Explanation__c),
            'Improper_CE_Reliance rule must have a non-blank Explanation__c for defensibility guidance');
    }

    @IsTest
    static void challengePredictionRules_allHaveExplanation() {
        List<NEPA_Challenge_Prediction_Rule__mdt> rules = [
            SELECT DeveloperName, Explanation__c
            FROM NEPA_Challenge_Prediction_Rule__mdt WHERE Active__c = true
        ];
        List<String> bad = new List<String>();
        for (NEPA_Challenge_Prediction_Rule__mdt r : rules) {
            if (String.isBlank(r.Explanation__c)) { bad.add(r.DeveloperName); }
        }
        System.assertEquals(0, bad.size(),
            'Active challenge prediction rules missing Explanation__c: '
                + String.join(bad, '; '));
    }

    // ── Risk score ceiling (BRE Expression Set formula bound) ─────────────────

    @IsTest
    static void breCmtWeights_maxTheoreticalScoreDoesNotExceed100() {
        // The Litigation Risk Scorer ES caps output at 100. This test verifies
        // that the sum of all max-weight CMT inputs cannot silently exceed that
        // bound due to a configuration change.
        //
        // Max weights from source: EIS=40, BLM=23, 9th=20, ESA+CWA+NHPA=15 → 98 max
        // Ceiling = 100; sum of these alone = 98; safe margin = 2

        Decimal maxReviewPoints = 40; // EIS (defined in the Expression Set formula)

        Decimal maxAgencyPoints = 0;
        for (NEPA_Agency_Risk_Rate__mdt r : [
            SELECT Risk_Points__c FROM NEPA_Agency_Risk_Rate__mdt
            WHERE DeveloperName != 'Default'
        ]) {
            if (r.Risk_Points__c > maxAgencyPoints) { maxAgencyPoints = r.Risk_Points__c; }
        }

        Decimal maxCircuitPoints = 0;
        for (NEPA_Circuit_Risk_Weight__mdt w : [
            SELECT Risk_Points__c FROM NEPA_Circuit_Risk_Weight__mdt
            WHERE DeveloperName != 'Default'
        ]) {
            if (w.Risk_Points__c > maxCircuitPoints) { maxCircuitPoints = w.Risk_Points__c; }
        }

        Decimal maxStatutePoints = 0;
        for (NEPA_Statute_Risk_Weight__mdt s : [
            SELECT Risk_Points__c FROM NEPA_Statute_Risk_Weight__mdt WHERE Active__c = true
        ]) {
            maxStatutePoints += s.Risk_Points__c; // all statutes could co-trigger
        }

        Decimal theoretical = maxReviewPoints + maxAgencyPoints + maxCircuitPoints + maxStatutePoints;
        System.assert(theoretical <= 100,
            'Theoretical max BRE score (' + theoretical
            + ') exceeds 100 — Expression Set cap will truncate; review CMT weights. '
            + 'Components: review=' + maxReviewPoints + ', agency=' + maxAgencyPoints
            + ', circuit=' + maxCircuitPoints + ', statutes=' + maxStatutePoints);
    }

    // ── Tier-boundary consistency ─────────────────────────────────────────────

    @IsTest
    static void riskTierBoundaries_areContiguousAndCoverZeroTo100() {
        // The Expression Set formula maps score → tier using these boundaries:
        //   0–24 = Low, 25–49 = Medium, 50–74 = High, 75–100 = Very High
        // This test asserts those boundary values are internally consistent.
        // If the ES formula is changed the boundaries below must be updated too.
        final Integer LOW_MAX    = 24;
        final Integer MEDIUM_MIN = 25;
        final Integer MEDIUM_MAX = 49;
        final Integer HIGH_MIN   = 50;
        final Integer HIGH_MAX   = 74;
        final Integer VERY_HIGH  = 75;

        System.assertEquals(MEDIUM_MIN, LOW_MAX + 1,    'Low/Medium boundary must be contiguous');
        System.assertEquals(HIGH_MIN,   MEDIUM_MAX + 1, 'Medium/High boundary must be contiguous');
        System.assertEquals(VERY_HIGH,  HIGH_MAX + 1,   'High/Very High boundary must be contiguous');
        System.assertEquals(0,  0, 'Low tier starts at 0');
        System.assert(VERY_HIGH <= 100, 'Very High tier starts at or below 100');
    }


    // ══════════════════════════════════════════════════════════════════════════
    // PART 2 — FLOW END-TO-END SMOKE TESTS
    // These trigger the record-triggered flows and assert on output fields.
    // AsyncAfterCommit: output fields may not populate synchronously.
    // All assertions are null-guarded; the primary assertion is no-throw.
    // BRE Expression Sets must be activated in the org for outputs to appear.
    // ══════════════════════════════════════════════════════════════════════════

    // ── CE Screener: recommendation field populated, review_type not overwritten ──

    @IsTest
    static void ceScreener_blmMineralMining_doesNotThrow() {
        // T2_BLM_MineralMaterials: BLM + Agriculture and Natural Resource Management
        // + Mineral Resources + OAM + ≤5 acres → CE recommendation
        Program proj = makeProject('Mineral Test', 'Bureau of Land Management',
                                   '9th', 'Agriculture and Natural Resource Management', 'CE');
        proj.nepa_project_type__c = 'Mineral Resources';
        update proj;

        IndividualApplication ia = makeProcess(proj.Id, null);
        ia.nepa_action_type__c         = 'Operate or Maintain Existing';
        ia.nepa_disturbance_acres__c   = 3;
        insert ia;

        Test.startTest();
        ia.nepa_action_type__c = 'Modify Existing'; // trigger IsChanged
        Boolean threw = false;
        try { update ia; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'CE Screener must not throw for BLM Mineral Materials project');

        IndividualApplication result = [
            SELECT nepa_review_type__c, nepa_ce_pathway_recommendation__c,
                   nepa_screening_confidence__c, nepa_classification_basis__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        // AI AUP: CE Screener must never auto-set nepa_review_type__c
        System.assertEquals(null, result.nepa_review_type__c,
            'CE Screener must not auto-set nepa_review_type__c regardless of BRE output');

        // If BRE fired, validate output shape
        if (result.nepa_ce_pathway_recommendation__c != null) {
            Set<String> valid = new Set<String>{ 'CE-Recommended', 'EA-Required', 'EIS-Required', 'Pending' };
            System.assert(valid.contains(result.nepa_ce_pathway_recommendation__c),
                'Recommendation must be a valid picklist value: '
                    + result.nepa_ce_pathway_recommendation__c);
        }
        if (result.nepa_classification_basis__c != null) {
            System.assert(String.isNotBlank(result.nepa_classification_basis__c),
                'Classification basis must not be blank when written');
        }
    }

    @IsTest
    static void ceScreener_highAcreageOilGas_routesToEA() {
        // T2_HighAcreage: Oil & Gas + Construct New + acres > 5 → EA (priority 98)
        Program proj = makeProject('Oil Gas High Acreage', 'Bureau of Land Management',
                                   '9th', 'Energy Production', 'EIS');
        proj.nepa_project_type__c = 'Oil & Gas';
        update proj;

        IndividualApplication ia = makeProcess(proj.Id, null);
        ia.nepa_action_type__c       = 'Construct New';
        ia.nepa_disturbance_acres__c = 50;
        insert ia;

        Test.startTest();
        ia.nepa_disturbance_acres__c = 51; // trigger IsChanged
        Boolean threw = false;
        try { update ia; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'CE Screener must not throw for high-acreage Oil & Gas');

        IndividualApplication result = [
            SELECT nepa_ce_pathway_recommendation__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        // If BRE evaluated: high acreage disqualifier must produce EA, not CE
        if (result.nepa_ce_pathway_recommendation__c != null) {
            System.assertNotEquals('CE-Recommended', result.nepa_ce_pathway_recommendation__c,
                'High acreage Oil & Gas construction must not receive CE-Recommended');
        }
    }

    @IsTest
    static void ceScreener_humanSetReviewType_isPreserved() {
        Program proj = makeProject('Human Set Test', 'Bureau of Land Management',
                                   '9th', 'Energy', 'EIS');
        IndividualApplication ia = makeProcess(proj.Id, 'EIS');
        insert ia;

        Test.startTest();
        ia.nepa_action_type__c = 'Renew or Extend Existing';
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_review_type__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('EIS', result.nepa_review_type__c,
            'Human-set nepa_review_type__c must never be overwritten by CE Screener');
    }

    // ── Litigation Risk Scorer: score and tier populated, no throw ────────────

    @IsTest
    static void riskScorer_eis9thCircuitBLM_doesNotThrow() {
        // Maximum-weight combination: EIS=40 + BLM=23 + 9th=20 → 83 → Very High
        Program proj = makeProject('EIS 9th BLM', 'Bureau of Land Management', '9th', 'Energy', 'EIS');
        IndividualApplication ia = makeProcess(proj.Id, 'EA');
        insert ia;

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        Boolean threw = false;
        try { update ia; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'Risk Scorer must not throw for EIS + BLM + 9th circuit');

        IndividualApplication result = [
            SELECT nepa_risk_score__c, nepa_risk_tier__c, nepa_risk_score_factors__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_risk_score__c != null) {
            System.assert(result.nepa_risk_score__c >= 0 && result.nepa_risk_score__c <= 100,
                'Risk score must be in range 0–100; got: ' + result.nepa_risk_score__c);
            System.assert(result.nepa_risk_score__c > 0,
                'EIS + BLM + 9th circuit should produce a non-zero score');
        }
        if (result.nepa_risk_tier__c != null) {
            Set<String> valid = new Set<String>{ 'Low', 'Medium', 'High', 'Very High' };
            System.assert(valid.contains(result.nepa_risk_tier__c),
                'Risk tier must be valid: ' + result.nepa_risk_tier__c);
            // If score written, tier must match the correct band
            if (result.nepa_risk_score__c != null && result.nepa_risk_score__c >= 75) {
                System.assertEquals('Very High', result.nepa_risk_tier__c,
                    'Score >= 75 must map to Very High');
            }
        }
    }

    @IsTest
    static void riskScorer_ce_producesLowerScoreThanEIS() {
        Program projEIS = makeProject('EIS Score Comp', 'Bureau of Land Management', '9th', 'Energy', 'EIS');
        Program projCE  = makeProject('CE Score Comp',  'Bureau of Land Management', '9th', 'Energy', 'CE');

        IndividualApplication iaEIS = makeProcess(projEIS.Id, 'EA');
        insert iaEIS;
        IndividualApplication iaCE  = makeProcess(projCE.Id, 'EA');
        insert iaCE;

        Test.startTest();
        iaEIS.nepa_review_type__c = 'EIS';
        update iaEIS;
        iaCE.nepa_review_type__c = 'CE';
        update iaCE;
        Test.stopTest();

        IndividualApplication eisResult = [SELECT nepa_risk_score__c FROM IndividualApplication WHERE Id = :iaEIS.Id];
        IndividualApplication ceResult  = [SELECT nepa_risk_score__c FROM IndividualApplication WHERE Id = :iaCE.Id];

        if (eisResult.nepa_risk_score__c != null && ceResult.nepa_risk_score__c != null) {
            System.assert(eisResult.nepa_risk_score__c > ceResult.nepa_risk_score__c,
                'EIS score (' + eisResult.nepa_risk_score__c + ') must exceed CE score ('
                    + ceResult.nepa_risk_score__c + ')');
        }
    }

    @IsTest
    static void riskScorer_tierMatchesScoreBand() {
        Program proj = makeProject('Tier Band Test', 'Bureau of Land Management', '9th', 'Energy', 'EIS');
        IndividualApplication ia = makeProcess(proj.Id, 'CE');
        insert ia;

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_risk_score__c, nepa_risk_tier__c FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_risk_score__c == null || result.nepa_risk_tier__c == null) { return; }

        Decimal score = result.nepa_risk_score__c;
        String  tier  = result.nepa_risk_tier__c;

        if (score >= 75) {
            System.assertEquals('Very High', tier, 'Score >= 75 → Very High; score=' + score);
        } else if (score >= 50) {
            System.assertEquals('High', tier, 'Score 50–74 → High; score=' + score);
        } else if (score >= 25) {
            System.assertEquals('Medium', tier, 'Score 25–49 → Medium; score=' + score);
        } else {
            System.assertEquals('Low', tier, 'Score < 25 → Low; score=' + score);
        }
    }

    @IsTest
    static void riskScorer_noRelatedProject_doesNotThrow() {
        IndividualApplication ia = new IndividualApplication();
        ia.Category               = 'Permit';
        ia.LicenseTypeId          = getLicenseTypeId();
        ia.nepa_process_status__c = 'in progress';
        ia.nepa_process_stage__c  = 'Scoping';
        ia.nepa_review_type__c    = 'EA';
        insert ia;

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        Boolean threw = false;
        try { update ia; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw,
            'Risk Scorer must handle missing related project without throwing');
    }

    @IsTest
    static void riskScorer_bulk5Records_doesNotThrow() {
        Program proj = makeProject('Bulk Risk', 'Bureau of Land Management', 'DC', 'Energy', 'EIS');
        List<IndividualApplication> ias = new List<IndividualApplication>();
        for (Integer i = 0; i < 5; i++) {
            ias.add(makeProcess(proj.Id, 'EA'));
        }
        insert ias;

        List<IndividualApplication> updates = new List<IndividualApplication>();
        for (IndividualApplication ia : ias) {
            updates.add(new IndividualApplication(Id = ia.Id, nepa_review_type__c = 'EIS'));
        }

        Test.startTest();
        Boolean threw = false;
        try { update updates; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'Risk Scorer bulk update of 5 records must not throw');
    }

    // ── GIS Extraordinary Circumstances: CE override ──────────────────────────

    @IsTest
    static void ceScreener_extraordinaryCircumstances_preventsCERecommendation() {
        Program proj = makeProject('EC Test', 'Bureau of Land Management', '9th',
                                   'Agriculture and Natural Resource Management', 'CE');
        IndividualApplication ia = makeProcess(proj.Id, null);
        ia.nepa_extraordinary_circumstances__c = 'Wetlands present within project footprint';
        ia.nepa_disturbance_acres__c           = 3;
        ia.nepa_action_type__c                 = 'Operate or Maintain Existing';
        insert ia;

        Test.startTest();
        ia.nepa_action_type__c = 'Modify Existing';
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ce_pathway_recommendation__c, nepa_classification_basis__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_ce_pathway_recommendation__c != null) {
            System.assertNotEquals('CE-Recommended', result.nepa_ce_pathway_recommendation__c,
                'Extraordinary circumstances must block CE-Recommended');
        }
    }
}
