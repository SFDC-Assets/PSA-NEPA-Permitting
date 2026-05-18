@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
/** Tests validation rules on IndividualApplication, PublicComplaint, and ContentVersion. */
@IsTest
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
                   nepa_prior_nepa_date__c, nepa_supplementation_review_complete__c,
                   nepa_phase2_applicable__c, nepa_climate_assessment_required__c,
                   nepa_climate_assessment_complete__c, nepa_process_stage__c
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
        ia.nepa_review_type__c = 'EIS';
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

    // ── NEPA_Comment_Period_Closed ────────────────────────────────────────────

    @IsTest
    static void commentPeriodClosed_newCommentAfterDeadline_blocks() {
        Program proj = NepaTestFactory.insertProgram('VR-CPC-001', 'CPC Test Project', 'BLM');
        DateTime pastDeadline = DateTime.now().addDays(-1);
        IndividualApplication proc = NepaTestFactory.insertProcessWithDateTimes(
            proj.Id, 'EA', DateTime.now().addDays(-30), pastDeadline
        );
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                = 'Late Commenter';
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = proc.Id;
        pc.nepa_comment_body__c    = 'Comment after deadline.';
        try {
            insert pc;
            System.assert(false, 'Expected DmlException for comment after closed period');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('comment period'), 'Error should mention comment period: ' + e.getMessage());
        }
    }

    @IsTest
    static void commentPeriodClosed_newCommentBeforeDeadline_saves() {
        Program proj = NepaTestFactory.insertProgram('VR-CPC-002', 'CPC Open Project', 'BLM');
        IndividualApplication proc = NepaTestFactory.insertProcessWithDateTimes(
            proj.Id, 'EA', DateTime.now().addDays(-5), DateTime.now().addDays(10)
        );
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                = 'On Time Commenter';
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = proc.Id;
        pc.nepa_comment_body__c    = 'Comment before deadline.';
        insert pc;
        PublicComplaint saved = [SELECT Id FROM PublicComplaint WHERE Id = :pc.Id];
        System.assertNotEquals(null, saved.Id, 'Comment within open period should save');
    }

    @IsTest
    static void commentPeriodClosed_updateAfterDeadline_saves() {
        // ISNEW() guard: updating an existing comment is allowed even after the deadline
        Program proj = NepaTestFactory.insertProgram('VR-CPC-003', 'CPC Update Project', 'BLM');
        IndividualApplication proc = NepaTestFactory.insertProcessWithDateTimes(
            proj.Id, 'EA', DateTime.now().addDays(-10), DateTime.now().addDays(5)
        );
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                = 'Updater';
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = proc.Id;
        pc.nepa_comment_body__c    = 'Original comment.';
        insert pc;

        // Now close the period
        proc.nepa_public_comment_period_end_date__c = DateTime.now().addDays(-1);
        update proc;

        // Update the existing comment — ISNEW() guard means this should succeed
        PublicComplaint pcUpdate = new PublicComplaint(Id = pc.Id);
        pcUpdate.nepa_comment_body__c = 'Updated comment text.';
        update pcUpdate;
        PublicComplaint saved = [SELECT nepa_comment_body__c FROM PublicComplaint WHERE Id = :pc.Id];
        System.assertEquals('Updated comment text.', saved.nepa_comment_body__c);
    }

    @IsTest
    static void commentPeriodClosed_noEndDate_failOpen_saves() {
        // Null end date → fail-open: insert must be allowed
        Program proj = NepaTestFactory.insertProgram('VR-CPC-004', 'CPC No Date Project', 'BLM');
        IndividualApplication proc = NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                = 'No Deadline Commenter';
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = proc.Id;
        pc.nepa_comment_body__c    = 'Comment with no end date set.';
        insert pc;
        PublicComplaint saved = [SELECT Id FROM PublicComplaint WHERE Id = :pc.Id];
        System.assertNotEquals(null, saved.Id, 'Null end date should fail-open and allow insert');
    }

    // ── NEPA_AIDocumentRequiresSMEReview ──────────────────────────────────────

    @IsTest
    static void aiDocReview_aiApprovedMissingReviewer_blocks() {
        IndividualApplication proc = getProcess();
        try {
            NepaTestFactory.insertContentVersionWithStatus(
                proc.Id, 'NOI', 'AI-Generated', 'Approved', null, null
            );
            System.assert(false, 'Expected DmlException for AI Approved doc missing reviewer');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('reviewer') || e.getMessage().contains('Reviewer'),
                'Error should mention reviewer: ' + e.getMessage());
        }
    }

    @IsTest
    static void aiDocReview_aiApprovedMissingDate_blocks() {
        // Reviewer set but no reviewed date → VR must still block
        IndividualApplication proc = getProcess();
        try {
            NepaTestFactory.insertContentVersionWithStatus(
                proc.Id, 'NOI', 'AI-Generated', 'Approved', UserInfo.getUserId(), null
            );
            System.assert(false, 'Expected DmlException for AI Approved doc missing review date');
        } catch (DmlException e) {
            System.assert(e.getMessage() != null && e.getMessage().length() > 0,
                'Should surface VR error: ' + e.getMessage());
        }
    }

    @IsTest
    static void aiDocReview_aiApprovedWithBothFields_saves() {
        IndividualApplication proc = getProcess();
        ContentVersion cv = NepaTestFactory.insertContentVersionWithStatus(
            proc.Id, 'NOI', 'AI-Generated', 'Approved', UserInfo.getUserId(), Date.today()
        );
        ContentVersion saved = [SELECT nepa_status__c, nepa_reviewer__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Approved', saved.nepa_status__c);
        System.assertNotEquals(null, saved.nepa_reviewer__c, 'Reviewer must be set when both fields provided');
    }

    @IsTest
    static void aiDocReview_nonAiApprovedMissingReviewer_saves() {
        // Human-authored doc: VR must not fire even when reviewer is blank
        IndividualApplication proc = getProcess();
        ContentVersion cv = NepaTestFactory.insertContentVersionWithStatus(
            proc.Id, 'NOI', 'Human-Authored', 'Approved', null, null
        );
        ContentVersion saved = [SELECT nepa_status__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Approved', saved.nepa_status__c, 'Non-AI doc with Approved status should save without reviewer');
    }

    // ── NEPA_Phase2_Climate_Gate bypass paths ─────────────────────────────────

    @IsTest
    static void phase2Gate_notApplicable_decisionStageAllowed() {
        IndividualApplication ia = getProcess();
        ia.nepa_phase2_applicable__c          = false;
        ia.nepa_climate_assessment_required__c = true;
        ia.nepa_climate_assessment_complete__c = false;
        ia.nepa_process_stage__c               = 'Decision';
        update ia;
        IndividualApplication saved = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision', saved.nepa_process_stage__c);
    }

    @IsTest
    static void phase2Gate_notRequired_decisionStageAllowed() {
        IndividualApplication ia = getProcess();
        ia.nepa_phase2_applicable__c          = true;
        ia.nepa_climate_assessment_required__c = false;
        ia.nepa_climate_assessment_complete__c = false;
        ia.nepa_process_stage__c               = 'Decision';
        update ia;
        IndividualApplication saved = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision', saved.nepa_process_stage__c);
    }

    @IsTest
    static void phase2Gate_assessmentComplete_decisionStageAllowed() {
        IndividualApplication ia = getProcess();
        ia.nepa_phase2_applicable__c          = true;
        ia.nepa_climate_assessment_required__c = true;
        ia.nepa_climate_assessment_complete__c = true;
        ia.nepa_process_stage__c               = 'Decision';
        update ia;
        IndividualApplication saved = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Decision', saved.nepa_process_stage__c);
    }

    @IsTest
    static void phase2Gate_nonDecisionStage_incompleteAllowed() {
        // applicable + required + incomplete is fine at non-Decision stages
        IndividualApplication ia = getProcess();
        ia.nepa_phase2_applicable__c          = true;
        ia.nepa_climate_assessment_required__c = true;
        ia.nepa_climate_assessment_complete__c = false;
        ia.nepa_process_stage__c               = 'Scoping';
        update ia;
        IndividualApplication saved = [SELECT nepa_process_stage__c FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertEquals('Scoping', saved.nepa_process_stage__c);
    }

    // ── NEPA_Phase2_Applicability_Setter flow auto-triggers ───────────────────

    @IsTest
    static void phase2Setter_eisReviewType_autoSetsFlags() {
        // Before-save flow NEPA_Phase2_Applicability_Setter should set applicable=true
        // and required=true when review type changes to EIS
        IndividualApplication ia = getProcess();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        IndividualApplication saved = [
            SELECT nepa_phase2_applicable__c, nepa_climate_assessment_required__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, saved.nepa_phase2_applicable__c,
            'EIS review type should auto-set Phase 2 applicable flag');
        System.assertEquals(true, saved.nepa_climate_assessment_required__c,
            'EIS review type should auto-set climate assessment required flag');
    }

    @IsTest
    static void phase2Setter_eaReviewType_autoSetsFlags() {
        IndividualApplication ia = getProcess();
        ia.nepa_review_type__c = 'EA';
        update ia;
        IndividualApplication saved = [
            SELECT nepa_phase2_applicable__c, nepa_climate_assessment_required__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, saved.nepa_phase2_applicable__c,
            'EA review type should auto-set Phase 2 applicable flag');
    }

    @IsTest
    static void phase2Setter_ceReviewType_clearsFlags() {
        // If previously set to EIS and then changed to CE, flags should clear
        IndividualApplication ia = getProcess();
        ia.nepa_phase2_applicable__c          = true;
        ia.nepa_climate_assessment_required__c = true;
        ia.nepa_review_type__c                 = 'CE';
        update ia;
        IndividualApplication saved = [
            SELECT nepa_phase2_applicable__c, nepa_climate_assessment_required__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(false, saved.nepa_phase2_applicable__c,
            'CE review type should clear Phase 2 applicable flag');
        System.assertEquals(false, saved.nepa_climate_assessment_required__c,
            'CE review type should clear climate assessment required flag');
    }
}
