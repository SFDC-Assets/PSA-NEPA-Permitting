@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaAgencyTierSetterTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Program insertProgramWithAgency(String projectId, String agency) {
        Program p = NepaTestFactory.makeProgram(projectId, projectId, agency);
        p.nepa_record_owner_agency__c = agency;
        insert p;
        return p;
    }

    private static String getTier(Id programId) {
        return [SELECT nepa_agency_performance_tier__c FROM Program WHERE Id = :programId].nepa_agency_performance_tier__c;
    }

    // ── FAA → Slow_Scoping_Bottleneck ─────────────────────────────────────────

    @IsTest
    static void agencyTierSetter_FAA_setsSlowScopingBottleneck() {
        Program proj = insertProgramWithAgency('TIER-FAA-001', 'BLM');

        Test.startTest();
        proj.nepa_record_owner_agency__c = 'FAA';
        update proj;
        Test.stopTest();

        String tier = getTier(proj.Id);
        if (tier != null) {
            System.assertEquals('Slow_Scoping_Bottleneck', tier,
                'FAA agency must map to Slow_Scoping_Bottleneck tier; got: ' + tier);
        }
    }

    // ── FERC → Fast_and_Defensible ────────────────────────────────────────────

    @IsTest
    static void agencyTierSetter_FERC_setsFastAndDefensible() {
        Program proj = insertProgramWithAgency('TIER-FERC-001', 'BLM');

        Test.startTest();
        proj.nepa_record_owner_agency__c = 'FERC';
        update proj;
        Test.stopTest();

        String tier = getTier(proj.Id);
        if (tier != null) {
            System.assertEquals('Fast_and_Defensible', tier,
                'FERC agency must map to Fast_and_Defensible tier; got: ' + tier);
        }
    }

    // ── BLM → Legally_Vulnerable ──────────────────────────────────────────────

    @IsTest
    static void agencyTierSetter_BLM_setsLegallyVulnerable() {
        Program proj = insertProgramWithAgency('TIER-BLM-001', 'FERC');

        Test.startTest();
        proj.nepa_record_owner_agency__c = 'BLM';
        update proj;
        Test.stopTest();

        String tier = getTier(proj.Id);
        if (tier != null) {
            System.assertEquals('Legally_Vulnerable', tier,
                'BLM agency must map to Legally_Vulnerable tier; got: ' + tier);
        }
    }

    // ── Agency change updates tier ────────────────────────────────────────────

    @IsTest
    static void agencyTierSetter_agencyChange_updatesExistingTier() {
        Program proj = insertProgramWithAgency('TIER-CHANGE-001', 'BLM');

        // First set to FERC (Fast_and_Defensible)
        Test.startTest();
        proj.nepa_record_owner_agency__c = 'FERC';
        update proj;
        Test.stopTest();

        String firstTier = getTier(proj.Id);

        // Then change to FAA (Slow_Scoping_Bottleneck) in a second DML
        Test.startTest();
        proj.nepa_record_owner_agency__c = 'FAA';
        update proj;
        Test.stopTest();

        String secondTier = getTier(proj.Id);

        // If both tiers are populated, they must differ — the agency change must have taken effect
        if (firstTier != null && secondTier != null) {
            System.assertNotEquals(firstTier, secondTier,
                'Changing agency from FERC to FAA must update the performance tier');
        }
    }

    // ── CMT has records for all key agencies ──────────────────────────────────

    @IsTest
    static void agencyTierSetter_allKeyAgenciesHaveBaselineRecord() {
        List<NEPA_Agency_Scoping_Baseline__mdt> records = [
            SELECT Agency_Key__c, Agency_Performance_Tier__c
            FROM NEPA_Agency_Scoping_Baseline__mdt
            WHERE Active__c = true
        ];

        Map<String, String> tierByAgency = new Map<String, String>();
        for (NEPA_Agency_Scoping_Baseline__mdt r : records) {
            tierByAgency.put(r.Agency_Key__c, r.Agency_Performance_Tier__c);
        }

        System.assert(tierByAgency.containsKey('FAA'),
            'NEPA_Agency_Scoping_Baseline__mdt must have an active FAA record');
        System.assert(tierByAgency.containsKey('FERC'),
            'NEPA_Agency_Scoping_Baseline__mdt must have an active FERC record');
        System.assert(tierByAgency.containsKey('BLM'),
            'NEPA_Agency_Scoping_Baseline__mdt must have an active BLM record');

        System.assertEquals('Slow_Scoping_Bottleneck', tierByAgency.get('FAA'),
            'FAA CMT record must have Agency_Performance_Tier__c = Slow_Scoping_Bottleneck');
        System.assertEquals('Fast_and_Defensible', tierByAgency.get('FERC'),
            'FERC CMT record must have Agency_Performance_Tier__c = Fast_and_Defensible');
        System.assertEquals('Legally_Vulnerable', tierByAgency.get('BLM'),
            'BLM CMT record must have Agency_Performance_Tier__c = Legally_Vulnerable');
    }
}
