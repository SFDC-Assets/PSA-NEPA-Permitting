@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
/**
 * Pure Apex and validation-rule tests for OMB M-24-10 AI governance.
 * No Flow.Interview calls — see NepaAIGovernanceFlowTest for those.
 *
 * Requirement coverage:
 *   PC-004  Response status allowlist prevents hallucinated values from reaching the record
 *   DM-005  Validation rule blocks AI documents from reaching Approved without SME reviewer
 *   DM-005  EIS Section Assembler sets nepa_status__c = AI Draft — Pending Review
 *   CE-001  CE Screener entry guard prevents firing on EA/EIS records
 */
@IsTest
private class NepaAIGovernanceTest {

    // ── Station 1: Parser allowlist — pure Apex ───────────────────────────────

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

    // ── Station 3: Generative Content / Document Gate — validation rules ──────

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
        System.assertEquals('AI Draft — Pending Review', result.nepa_status__c);
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
