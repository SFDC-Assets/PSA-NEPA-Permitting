@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaStageGateTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('SGT-001', 'Stage Gate Test Project', 'BLM');
    }

    private static Program getProgram() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'SGT-001' LIMIT 1];
    }

    // ── VR-001: Supplementation Gate ─────────────────────────────────────────

    @IsTest
    static void stageGate_vr001_allConditionsMet_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        // Set all blocking conditions and the stage change in one update so VR_006 fires inside the try/catch
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = false;
        ia.nepa_process_stage__c = 'Draft EIS Preparation';
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void stageGate_vr001_supplementationConfirmed_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = true;
        update ia;

        ia.nepa_process_stage__c = 'Draft EIS Preparation';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Draft EIS Preparation', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr001_recentPriorDate_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-100);
        ia.nepa_supplementation_review_complete__c = false;
        update ia;

        ia.nepa_process_stage__c = 'Draft EIS Preparation';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Draft EIS Preparation', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr001_notTiering_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_tiering_to_prior_eis__c = false;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = false;
        update ia;

        ia.nepa_process_stage__c = 'Draft EIS Preparation';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Draft EIS Preparation', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr001_notEIS_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_tiering_to_prior_eis__c = true;
        ia.nepa_prior_nepa_date__c = Date.today().addDays(-2000);
        ia.nepa_supplementation_review_complete__c = false;
        update ia;

        ia.nepa_process_stage__c = 'Draft EA Preparation';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Draft EA Preparation', result.nepa_process_stage__c);
    }

    // ── VR-004: ESA Consultation Gate ────────────────────────────────────────

    @IsTest
    static void stageGate_vr004_openConsultationEA_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_esa_consultation_status__c = 'May Affect - Initiated';
        update ia;

        ia.nepa_process_stage__c = 'Decision Issued';
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void stageGate_vr004_openConsultationEIS_blocksSave() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_esa_consultation_status__c = 'Reinitiated';
        update ia;

        ia.nepa_process_stage__c = 'Decision Issued';
        try {
            update ia;
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0, 'Should surface error: ' + e.getMessage());
        }
    }

    @IsTest
    static void stageGate_vr004_concurrenceReceived_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_esa_consultation_status__c = 'Concurrence Received';
        update ia;

        ia.nepa_process_stage__c = 'Decision Issued';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision Issued', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr004_biologicalOpinionIssued_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_esa_consultation_status__c = 'Biological Opinion Issued';
        update ia;

        ia.nepa_process_stage__c = 'Decision Issued';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision Issued', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr004_notRequired_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_esa_consultation_status__c = 'Not Required';
        update ia;

        ia.nepa_process_stage__c = 'Decision Issued';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision Issued', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr004_cePathway_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'CE', null, null);
        ia.nepa_esa_consultation_status__c = 'May Affect - Initiated';
        update ia;

        ia.nepa_process_stage__c = 'Decision Issued';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision Issued', result.nepa_process_stage__c);
    }

    @IsTest
    static void stageGate_vr004_nonDecisionStage_saves() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
        ia.nepa_esa_consultation_status__c = 'May Affect - Initiated';
        update ia;

        ia.nepa_process_stage__c = 'Final EIS Preparation';
        update ia;

        IndividualApplication result = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Final EIS Preparation', result.nepa_process_stage__c);
    }

    // ── Baseline: positive flow behavior ─────────────────────────────────────

    @IsTest
    static void stageGate_baseline_stageChange_stampsTransitionTimestamp() {
        Program proj = getProgram();
        IndividualApplication ia = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);

        ia.nepa_process_stage__c = 'Draft EA Preparation';
        update ia;

        IndividualApplication result = [SELECT nepa_last_stage_transition__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertNotEquals(null, result.nepa_last_stage_transition__c, 'Stage transition timestamp should be stamped');
    }

    @IsTest
    static void stageGate_baseline_reviewTypeFirstSet_stampsTargetDate() {
        Program proj = getProgram();
        IndividualApplication ia = new IndividualApplication();
        ia.Category = 'Permit';
        ia.nepa_related_project__c = proj.Id;
        ia.nepa_process_status__c = 'in progress';
        ia.nepa_process_stage__c = 'Scoping';
        insert ia;

        ia.nepa_review_type__c = 'EIS';
        update ia;

        IndividualApplication result = [SELECT nepa_target_completion_date__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertNotEquals(null, result.nepa_target_completion_date__c, 'Target completion date should be stamped');
        Integer daysDiff = Date.today().daysBetween(result.nepa_target_completion_date__c);
        System.assert(daysDiff >= 729 && daysDiff <= 731, 'Target date should be approximately today + 730 days, got ' + daysDiff);
    }
}
