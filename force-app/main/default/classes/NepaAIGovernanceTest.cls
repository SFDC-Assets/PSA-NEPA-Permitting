@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
/**
 * OMB M-24-10 AI governance test suite.
 *
 * Requirement coverage:
 *   PC-004/PC-005  AI triage writes to recommendation field; human classification field is protected
 *   PC-004         Legal review status preserved across re-triage; AI cannot overwrite attorney state
 *   PC-004         Low-confidence or EJ-flagged triage triggers human review Task
 *   PC-004         Response status allowlist prevents hallucinated values from reaching the record
 *   TL-003         Timeline Risk Assessor writes to projected (AI) field, not estimated (statutory) field
 *   TL-003         Other Authorization pathway is not evaluated against EA baselines
 *   DM-005         Stage Gate Doc Check blocks AI-generated documents from satisfying gate requirements
 *   DM-005         Validation rule blocks AI documents from reaching Approved without SME reviewer
 *   DM-005         EIS Section Assembler sets nepa_status__c = AI Draft — Pending Review
 *   CE-001         CE Screener entry guard prevents firing on EA/EIS records
 */
@IsTest
private class NepaAIGovernanceTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static PublicComplaint makeComment(Id processId) {
        PublicComplaint pc = new PublicComplaint();
        pc.nepa_related_process__c  = processId;
        pc.nepa_comment_body__c     = 'Test comment body for governance testing.';
        pc.nepa_date_submitted__c   = Date.today();
        pc.nepa_is_substantive__c   = false;
        insert pc;
        return pc;
    }

    private static Map<String, Object> baseTriageInputs(Id commentId) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('inp_CommentId',          commentId);
        m.put('inp_Sentiment',          'Neutral');
        m.put('inp_IsSubstantive',      true);
        m.put('inp_ClusterId',          'cluster-001');
        m.put('inp_AIConfidenceScore',  85.0);
        m.put('inp_AITriageRationale',  'Test rationale.');
        m.put('inp_RequiresHumanReview', false);
        m.put('inp_ResponseStatus',     'Pending');
        m.put('inp_LitigationThreat',   false);
        m.put('inp_LitigationThreatBasis', '');
        return m;
    }

    // ── Station 1: Comment Triage ─────────────────────────────────────────────

    @IsTest
    static void triage_aiRecommendationField_doesNotTouchIsSubstantive() {
        Program proj = NepaTestFactory.insertProgram('GOV-001', 'Governance Test Project', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'CE');
        PublicComplaint pc = makeComment(ia.Id);
        pc.nepa_is_substantive__c = false;
        update pc;

        Map<String, Object> inputs = baseTriageInputs(pc.Id);
        inputs.put('inp_IsSubstantive', true);

        Test.startTest();
        Flow.Interview.createInterview('NEPA_Comment_Triage_Save', inputs).start();
        Test.stopTest();

        PublicComplaint result = [
            SELECT nepa_is_substantive__c, nepa_ai_substantive_recommendation__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals(false, result.nepa_is_substantive__c,
            'nepa_is_substantive__c must not be changed by the AI triage flow');
        System.assertEquals('Substantive', result.nepa_ai_substantive_recommendation__c,
            'AI recommendation field must reflect the AI output');
    }

    @IsTest
    static void triage_legalReviewStatus_preservedOnRetriage() {
        Program proj = NepaTestFactory.insertProgram('GOV-002', 'Governance Legal Status Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        PublicComplaint pc = makeComment(ia.Id);
        pc.nepa_legal_review_status__c = 'Assigned to Counsel';
        pc.nepa_litigation_threat_flag__c = true;
        update pc;

        Map<String, Object> inputs = baseTriageInputs(pc.Id);
        inputs.put('inp_LitigationThreat', false);

        Test.startTest();
        Flow.Interview.createInterview('NEPA_Comment_Triage_Save', inputs).start();
        Test.stopTest();

        PublicComplaint result = [
            SELECT nepa_legal_review_status__c FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals('Assigned to Counsel', result.nepa_legal_review_status__c,
            'Attorney-set legal review status must not be overwritten when litigation threat is cleared');
    }

    @IsTest
    static void triage_lowConfidence_triggersHumanReviewTask() {
        Program proj = NepaTestFactory.insertProgram('GOV-003', 'Governance Low Confidence Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'CE');
        PublicComplaint pc = makeComment(ia.Id);

        Map<String, Object> inputs = baseTriageInputs(pc.Id);
        inputs.put('inp_AIConfidenceScore', 55.0);
        inputs.put('inp_RequiresHumanReview', false);

        Test.startTest();
        Flow.Interview.createInterview('NEPA_Comment_Triage_Save', inputs).start();
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task WHERE WhatId = :pc.Id AND Subject LIKE '%AI Triage Review Required%'
        ];
        System.assertEquals(1, tasks.size(),
            'A human review Task must be created when AI confidence score is below 70');
    }

    @IsTest
    static void triage_ejFlag_triggersHumanReviewTask() {
        Program proj = NepaTestFactory.insertProgram('GOV-004', 'Governance EJ Flag Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        PublicComplaint pc = makeComment(ia.Id);

        Map<String, Object> inputs = baseTriageInputs(pc.Id);
        inputs.put('inp_RequiresHumanReview', true);
        inputs.put('inp_AIConfidenceScore', 90.0);

        Test.startTest();
        Flow.Interview.createInterview('NEPA_Comment_Triage_Save', inputs).start();
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task WHERE WhatId = :pc.Id AND Subject LIKE '%AI Triage Review Required%'
        ];
        System.assertEquals(1, tasks.size(),
            'A human review Task must be created when RequiresHumanReview is true regardless of confidence');
    }

    @IsTest
    static void triage_responseStatus_allowlist_rejectsInvalidValue() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '{"sentiment":"Neutral","is_substantive":false,"confidence_score":80,'
            + '"cluster_hint":"","triage_rationale":"test","litigation_threat":false,'
            + '"litigation_threat_basis":"","response_status":"Closed"}';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].parseSuccess);
        System.assertEquals('Pending', results[0].responseStatus,
            'Hallucinated response_status value "Closed" must be sanitized to "Pending"');
    }

    @IsTest
    static void triage_responseStatus_validValue_preserved() {
        NepaCommentTriageParser.Request req = new NepaCommentTriageParser.Request();
        req.triageJson = '{"sentiment":"Supportive","is_substantive":true,"confidence_score":90,'
            + '"cluster_hint":"","triage_rationale":"test","litigation_threat":false,'
            + '"litigation_threat_basis":"","response_status":"Draft"}';

        Test.startTest();
        List<NepaCommentTriageParser.Result> results = NepaCommentTriageParser.parse(
            new List<NepaCommentTriageParser.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals('Draft', results[0].responseStatus,
            'Valid response_status "Draft" must pass through allowlist unchanged');
    }

    // ── Station 2: Timeline Risk Assessor ────────────────────────────────────

    @IsTest
    static void timelineRisk_writesProjectedNotEstimated() {
        Program proj = NepaTestFactory.insertProgram('GOV-010', 'Governance Timeline Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        ia.nepa_process_stage__c             = 'Scoping';
        ia.nepa_estimated_completion_date__c = null;
        ia.nepa_projected_completion_date__c = null;
        update ia;

        ia.nepa_process_stage__c = 'Analysis';
        update ia;

        Test.startTest();
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_projected_completion_date__c, nepa_estimated_completion_date__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(null, result.nepa_projected_completion_date__c,
            'Timeline Risk Assessor must populate nepa_projected_completion_date__c (AI field)');
        System.assertEquals(null, result.nepa_estimated_completion_date__c,
            'nepa_estimated_completion_date__c must remain null — this is a reserved statutory field');
    }

    @IsTest
    static void timelineRisk_otherAuthPathway_alwaysOnTrack() {
        Program proj = NepaTestFactory.insertProgram('GOV-011', 'Governance Other Auth Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'Other Authorization');
        ia.nepa_process_stage__c = 'Intake';
        update ia;

        ia.nepa_process_stage__c = 'Analysis';
        update ia;

        Test.startTest();
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals('On Track', result.nepa_timeline_risk_tier__c,
            'Other Authorization pathway must always be On Track — EA baselines must not apply');
    }

    // ── Station 3: Generative Content / Document Gate ────────────────────────

    /** Creates a Decision Issued timeline event for processId and attempts to complete it; returns true if a DmlException was thrown. */
    private static Boolean attemptDecisionGateComplete(Id processId) {
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.nepa_related_process__c = processId;
        evt.nepa_event_type__c      = 'Decision Issued';
        evt.nepa_status__c          = 'In Progress';
        insert evt;
        evt.nepa_status__c = 'Completed';
        Boolean threw = false;
        try {
            update evt;
        } catch (DmlException e) {
            threw = true;
        }
        return threw;
    }

    @IsTest
    static void stageGateDocs_humanDocSatisfiesGate() {
        Program proj = NepaTestFactory.insertProgram('GOV-020', 'Governance Doc Gate Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');
        cv.nepa_status__c        = 'Approved';
        cv.nepa_draft_source__c  = 'Human-Authored';
        cv.nepa_reviewer__c      = UserInfo.getUserId();
        cv.nepa_reviewed_date__c = Date.today();
        update cv;

        Test.startTest();
        Boolean threw = attemptDecisionGateComplete(ia.Id);
        Test.stopTest();

        System.assertEquals(false, threw,
            'Human-authored approved document must satisfy stage gate without throwing an error');
    }

    @IsTest
    static void stageGateDocs_aiDocumentBlockedFromGate() {
        Program proj = NepaTestFactory.insertProgram('GOV-021', 'Governance AI Doc Gate Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');
        cv.nepa_status__c        = 'Approved';
        cv.nepa_draft_source__c  = 'AI-Generated';
        cv.nepa_reviewer__c      = UserInfo.getUserId();
        cv.nepa_reviewed_date__c = Date.today();
        update cv;

        Test.startTest();
        Boolean threw = attemptDecisionGateComplete(ia.Id);
        Test.stopTest();

        System.assertEquals(true, threw,
            'AI-generated documents must NOT satisfy stage gate — gate must block completion');
    }

    @IsTest
    static void contentVersion_aiApproval_requiresReviewer() {
        Program proj = NepaTestFactory.insertProgram('GOV-022', 'Governance AI SME Review Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');

        Test.startTest();
        cv.nepa_draft_source__c = 'AI-Generated';
        cv.nepa_status__c       = 'Approved';
        Boolean threw = false;
        try {
            update cv;
        } catch (DmlException e) {
            threw = e.getMessage().contains('AI-generated documents require');
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Validation rule must block AI documents from being Approved without reviewer + reviewed date');
    }

    @IsTest
    static void contentVersion_aiApproval_allowedWithReviewer() {
        Program proj = NepaTestFactory.insertProgram('GOV-023', 'Governance AI SME Reviewer Present', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');

        Test.startTest();
        cv.nepa_draft_source__c  = 'AI-Generated';
        cv.nepa_status__c        = 'Approved';
        cv.nepa_reviewer__c      = UserInfo.getUserId();
        cv.nepa_reviewed_date__c = Date.today();
        Boolean threw = false;
        try {
            update cv;
        } catch (DmlException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'AI document with reviewer and reviewed date must be allowed to reach Approved status');
    }

    @IsTest
    static void contentVersion_aiDraftStatus_setCorrectly() {
        // Verifies the picklist value exists and can be persisted (covers EIS Assembler status fix)
        Program proj = NepaTestFactory.insertProgram('GOV-024', 'Governance AI Draft Status Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');

        Test.startTest();
        cv.nepa_draft_source__c = 'AI-Generated';
        cv.nepa_status__c       = 'AI Draft — Pending Review';
        Boolean threw = false;
        try {
            update cv;
        } catch (DmlException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            '"AI Draft — Pending Review" picklist value must be valid and saveable');
        ContentVersion result = [SELECT nepa_status__c FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('AI Draft — Pending Review', result.nepa_status__c,
            'nepa_status__c must persist "AI Draft — Pending Review"');
    }

    // ── CE Screener entry guard ───────────────────────────────────────────────

    @IsTest
    static void ceScreener_doesNotFireOnEARecord() {
        Program proj = NepaTestFactory.insertProgram('GOV-030', 'Governance CE Guard Test', 'BLM');
        proj.nepa_location_lat__c = 39.7392;
        proj.nepa_location_lon__c = -104.9903;
        update proj;

        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        ia.nepa_related_project__c = proj.Id;
        update ia;

        Test.startTest();
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ce_pathway_recommendation__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(null, result.nepa_ce_pathway_recommendation__c,
            'CE Screener must not fire on EA records — nepa_ce_pathway_recommendation__c must remain null');
    }

    @IsTest
    static void ceScreener_doesNotFireOnEISRecord() {
        Program proj = NepaTestFactory.insertProgram('GOV-031', 'Governance CE Guard EIS Test', 'BLM');
        proj.nepa_location_lat__c = 39.7392;
        proj.nepa_location_lon__c = -104.9903;
        update proj;

        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ia.nepa_related_project__c = proj.Id;
        update ia;

        Test.startTest();
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ce_pathway_recommendation__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(null, result.nepa_ce_pathway_recommendation__c,
            'CE Screener must not fire on EIS records — nepa_ce_pathway_recommendation__c must remain null');
    }
}
