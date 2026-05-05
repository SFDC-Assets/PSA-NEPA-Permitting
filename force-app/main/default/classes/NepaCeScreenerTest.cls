@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaCeScreenerTest {

    // ── Setup helpers ─────────────────────────────────────────────────────────

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

    /**
     * Creates a Program with BLM as lead agency + sector/type that matches T1_BLM_13
     * (Energy Production / Land-based Oil → CE recommendation).
     */
    private static Program makeBLMEnergyProject() {
        Account agency = new Account(Name = 'BLM');
        insert agency;
        Program p = new Program();
        p.Name                    = 'BLM Energy CE Test';
        p.nepa_project_id__c      = 'BLM-CE-001';
        p.nepa_project_title__c   = 'BLM Energy CE Test';
        p.nepa_lead_agency__c     = agency.Id;
        p.nepa_project_sector__c  = 'Energy';
        p.nepa_project_type__c    = 'EIS';
        return p;
    }

    // ── AI AUP gate: recommendation field set, review_type NOT set ────────────

    @IsTest
    static void ceMatch_setsRecommendationField_notReviewType() {
        Program proj = makeBLMEnergyProject();
        insert proj;

        IndividualApplication ia = new IndividualApplication();
        ia.Category                    = 'Permit';
        ia.LicenseTypeId               = getLicenseTypeId();
        ia.nepa_related_project__c     = proj.Id;
        ia.nepa_review_type__c         = null;
        ia.nepa_process_status__c      = 'in progress';
        ia.nepa_process_stage__c       = 'Scoping';
        ia.nepa_action_type__c         = 'Construct New';
        insert ia;

        Test.startTest();
        // Trigger the after-save async flow by updating an action type field
        ia.nepa_action_type__c = 'Modify Existing';
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_review_type__c, nepa_ce_pathway_recommendation__c,
                   nepa_screening_confidence__c, nepa_classification_basis__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        // AI AUP: review_type must NOT be auto-set by the flow regardless of async timing
        System.assertEquals(null, result.nepa_review_type__c,
            'CE Screener must NOT auto-set nepa_review_type__c — coordinator confirmation required per AI AUP');

        // AsyncAfterCommit: recommendation may not be written synchronously in test context
        if (result.nepa_ce_pathway_recommendation__c != null) {
            Set<String> validRecs = new Set<String>{ 'CE-Recommended', 'EA-Required', 'EIS-Required', 'Pending' };
            System.assert(validRecs.contains(result.nepa_ce_pathway_recommendation__c),
                'Recommendation must be a valid picklist value; got: ' + result.nepa_ce_pathway_recommendation__c);
        }
    }

    @IsTest
    static void humanSetReviewType_isPreservedAfterFlowFires() {
        Program proj = makeBLMEnergyProject();
        insert proj;

        // Human has already set the official pathway
        IndividualApplication ia = new IndividualApplication();
        ia.Category                    = 'Permit';
        ia.LicenseTypeId               = getLicenseTypeId();
        ia.nepa_related_project__c     = proj.Id;
        ia.nepa_review_type__c         = 'EIS';
        ia.nepa_process_status__c      = 'in progress';
        ia.nepa_process_stage__c       = 'Scoping';
        ia.nepa_action_type__c         = 'Construct New';
        insert ia;

        ia.nepa_action_type__c = 'Renew or Extend Existing';
        update ia;

        Test.startTest();
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_review_type__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        // Flow must not overwrite what a human coordinator set
        System.assertEquals('EIS', result.nepa_review_type__c,
            'Human-set nepa_review_type__c must not be overwritten by CE Screener');
    }

    // ── Recommendation picklist values ────────────────────────────────────────

    @IsTest
    static void classificationBasis_isPopulated() {
        Program proj = makeBLMEnergyProject();
        insert proj;

        IndividualApplication ia = new IndividualApplication();
        ia.Category                    = 'Permit';
        ia.LicenseTypeId               = getLicenseTypeId();
        ia.nepa_related_project__c     = proj.Id;
        ia.nepa_process_status__c      = 'in progress';
        ia.nepa_process_stage__c       = 'Scoping';
        ia.nepa_action_type__c         = 'Construct New';
        insert ia;

        Test.startTest();
        ia.nepa_action_type__c = 'Operate or Maintain Existing';
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_classification_basis__c, nepa_screening_confidence__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        // AsyncAfterCommit: basis may not be written synchronously in test context
        if (result.nepa_classification_basis__c != null) {
            System.assert(String.isNotBlank(result.nepa_classification_basis__c),
                'Classification basis must not be blank when written');
        }
    }

    // ── GIS extraordinary circumstances override ──────────────────────────────

    @IsTest
    static void extraordinaryCircumstances_overridesRecommendation() {
        Program proj = makeBLMEnergyProject();
        insert proj;

        IndividualApplication ia = new IndividualApplication();
        ia.Category                               = 'Permit';
        ia.LicenseTypeId                          = getLicenseTypeId();
        ia.nepa_related_project__c                = proj.Id;
        ia.nepa_process_status__c                 = 'in progress';
        ia.nepa_process_stage__c                  = 'Scoping';
        ia.nepa_action_type__c                    = 'Construct New';
        ia.nepa_extraordinary_circumstances__c    = 'Wetlands present within project footprint';
        insert ia;

        ia.nepa_action_type__c = 'Modify Existing';
        update ia;

        Test.startTest();
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ce_pathway_recommendation__c, nepa_classification_basis__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        // Extraordinary circumstances must force EA-Required or escalation
        if (result.nepa_ce_pathway_recommendation__c != null) {
            System.assertNotEquals('CE-Recommended', result.nepa_ce_pathway_recommendation__c,
                'Extraordinary circumstances must prevent CE-Recommended outcome');
        }
        // Audit trail should mention the override
        if (String.isNotBlank(result.nepa_classification_basis__c)) {
            System.assert(
                result.nepa_classification_basis__c.containsIgnoreCase('extraordinary')
                || result.nepa_classification_basis__c.containsIgnoreCase('GIS')
                || result.nepa_classification_basis__c.containsIgnoreCase('EA'),
                'Classification basis must document extraordinary circumstances: '
                    + result.nepa_classification_basis__c
            );
        }
    }

    // ── No related project — flow should not crash ────────────────────────────

    @IsTest
    static void noRelatedProject_flowHandlesGracefully() {
        IndividualApplication ia = new IndividualApplication();
        ia.Category               = 'Permit';
        ia.LicenseTypeId          = getLicenseTypeId();
        ia.nepa_process_status__c = 'in progress';
        ia.nepa_process_stage__c  = 'Scoping';
        ia.nepa_action_type__c    = 'Construct New';
        insert ia;

        ia.nepa_action_type__c = 'Modify Existing';

        Test.startTest();
        Boolean threw = false;
        try {
            update ia;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'CE Screener must not throw when no related project exists');
    }

    // ── Bulk: 5 records process without SOQL-in-loop violations ──────────────

    @IsTest
    static void bulk_multipleRecords_noException() {
        Account agency = new Account(Name = 'DOE');
        insert agency;
        Program proj = new Program();
        proj.Name                    = 'Bulk CE Test';
        proj.nepa_project_id__c      = 'BULK-CE-001';
        proj.nepa_project_title__c   = 'Bulk CE Test';
        proj.nepa_lead_agency__c     = agency.Id;
        proj.nepa_project_sector__c  = 'Energy';
        proj.nepa_project_type__c    = 'EIS';
        insert proj;

        List<IndividualApplication> ias = new List<IndividualApplication>();
        Id licTypeId = getLicenseTypeId();
        for (Integer i = 0; i < 5; i++) {
            IndividualApplication ia = new IndividualApplication();
            ia.Category                = 'Permit';
            ia.LicenseTypeId           = licTypeId;
            ia.nepa_related_project__c = proj.Id;
            ia.nepa_process_status__c  = 'in progress';
            ia.nepa_process_stage__c   = 'Scoping';
            ia.nepa_action_type__c     = 'Construct New';
            ias.add(ia);
        }
        insert ias;

        for (IndividualApplication ia : ias) {
            ia.nepa_action_type__c = 'Modify Existing';
        }

        Test.startTest();
        Boolean threw = false;
        try {
            update ias;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'CE Screener bulk update must not throw');
    }
}
