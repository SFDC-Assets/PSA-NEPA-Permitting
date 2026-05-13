@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaRfpRequirementsTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('RFP-TEST-001', 'RFP Requirements Test Project', 'BLM');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
    }

    /**
     * DI-001: All 9 CEQ entity objects accept their required fields and persist.
     * Entities 1-9: Program, IndividualApplication, ContentVersion, PublicComplaint,
     * nepa_engagement__c, ApplicationTimeline, nepa_gis_data_element__c,
     * nepa_process_team_member__c, RegulatoryCode.
     */
    @IsTest
    static void coreEntitiesExist() {
        Program proj = NepaTestFactory.insertProgram('DI001-PROJ-001', 'DI-001 Test Project', 'CEQ');
        System.assertNotEquals(null, proj.Id);

        IndividualApplication proc = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        System.assertNotEquals(null, proc.Id);

        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(proc.Id, 'Environmental Assessment');
        System.assertNotEquals(null, cv.Id);

        PublicComplaint pc = new PublicComplaint();
        pc.Subject                 = 'DI-001 Test Comment';
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = proc.Id;
        pc.nepa_comment_body__c    = 'Test.';
        pc.nepa_date_submitted__c  = Date.today();
        pc.nepa_is_substantive__c  = false;
        insert pc;
        System.assertNotEquals(null, pc.Id);

        nepa_engagement__c eng = NepaTestFactory.insertPublicEngagement(proc.Id);
        System.assertNotEquals(null, eng.Id);

        ApplicationTimeline tl = NepaTestFactory.insertPublicTimelineEvent(proc.Id);
        System.assertNotEquals(null, tl.Id);

        nepa_gis_data_element__c gis = NepaTestFactory.insertGisDataElement(null, 'Project Boundary');
        System.assertNotEquals(null, gis.Id);

        nepa_process_team_member__c tm = NepaTestFactory.insertTeamMember(proc.Id, null, 'Lead NEPA Coordinator');
        System.assertNotEquals(null, tm.Id);

        RegulatoryCode rc = NepaTestFactory.insertRegulatoryCode('40 CFR 1501.4', 'CE Determination');
        System.assertNotEquals(null, rc.Id);
    }

    /**
     * PC-004 / TR-007 / OMB M-24-10: AI audit trail fields are writable on all
     * AI-scored objects — confidence score, rationale, timestamp, human override
     * on PublicComplaint; AI-generated flag on ContentVersion; litigation
     * confidence on IndividualApplication.
     */
    @IsTest
    static void aiAuditFieldsPresent() {
        IndividualApplication proc = [SELECT Id FROM IndividualApplication LIMIT 1];

        PublicComplaint pc = new PublicComplaint();
        pc.Subject                        = 'AI Audit Field Test';
        pc.IncidentDate                   = Date.today();
        pc.nepa_related_process__c        = proc.Id;
        pc.nepa_comment_body__c           = 'The project will harm wetlands adjacent to the creek.';
        pc.nepa_date_submitted__c         = Date.today();
        pc.nepa_is_substantive__c         = false;
        pc.nepa_ai_confidence_score__c    = 0.87;
        pc.nepa_ai_triage_rationale__c    = 'Comment raises substantive wetland impact issue.';
        pc.nepa_ai_triage_timestamp__c    = DateTime.now();
        pc.nepa_requires_human_review__c  = true;
        pc.nepa_human_override__c         = false;
        insert pc;

        PublicComplaint pcResult = [
            SELECT nepa_ai_confidence_score__c, nepa_ai_triage_rationale__c,
                   nepa_ai_triage_timestamp__c, nepa_requires_human_review__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals(0.87, pcResult.nepa_ai_confidence_score__c);
        System.assertNotEquals(null, pcResult.nepa_ai_triage_timestamp__c);
        System.assertEquals(true, pcResult.nepa_requires_human_review__c);

        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(proc.Id, 'Environmental Assessment');
        cv.nepa_ai_generated__c = true;
        update cv;
        System.assertEquals(true, [SELECT nepa_ai_generated__c FROM ContentVersion WHERE Id = :cv.Id].nepa_ai_generated__c);

        IndividualApplication ia = new IndividualApplication(
            Id                              = proc.Id,
            nepa_litigation_ai_confidence__c = 75.0
        );
        update ia;
        System.assertEquals(75.0,
            [SELECT nepa_litigation_ai_confidence__c FROM IndividualApplication WHERE Id = :proc.Id].nepa_litigation_ai_confidence__c);
    }
}
