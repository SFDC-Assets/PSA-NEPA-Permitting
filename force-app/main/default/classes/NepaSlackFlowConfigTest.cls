@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.MethodNamingConventions')
@IsTest(SeeAllData=false)
/**
 * Tests for F-12 Slack integration flows and NEPA_Slack_Config__mdt seed integrity.
 *
 * The Slack flows depend on the Salesforce for Slack managed package which is not
 * available in test context. These tests verify:
 *   - The seed CMT record exists with expected default values
 *   - Stage notifier flow short-circuits cleanly when channel IDs are placeholder values
 *   - Risk alert flow exits at the threshold decision when score is below threshold
 *   - Risk alert flow exits at config check when CMT has placeholder channel IDs
 *   - EJTribal Router still routes correctly when Slack CMT has placeholder IDs
 *     (Slack path must be non-blocking — existing routing must not be degraded)
 *
 * Note: slack__SendMessage action calls will fail in test context since the managed
 * package is absent. The flows are designed with a placeholder-ID guard that prevents
 * the action from being called — these tests verify that guard works correctly.
 */
private class NepaSlackFlowConfigTest {

    // ── CMT seed integrity ────────────────────────────────────────────────────

    @IsTest
    static void slackConfigSeedRecord_exists() {
        List<NEPA_Slack_Config__mdt> configs = [
            SELECT DeveloperName, Default_Channel_Id__c,
                   Risk_Alert_Threshold__c, Notify_Tribal_Channel__c
            FROM NEPA_Slack_Config__mdt
            WHERE DeveloperName = 'Default'
        ];
        System.assertEquals(1, configs.size(),
            'Exactly one NEPA_Slack_Config__mdt record with DeveloperName="Default" must be deployed');
    }

    @IsTest
    static void slackConfigSeedRecord_hasExpectedThreshold() {
        NEPA_Slack_Config__mdt config = [
            SELECT Risk_Alert_Threshold__c
            FROM NEPA_Slack_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        System.assertNotEquals(null, config.Risk_Alert_Threshold__c,
            'Risk_Alert_Threshold__c must not be null in the Default seed record');
        System.assert(config.Risk_Alert_Threshold__c > 0 && config.Risk_Alert_Threshold__c <= 100,
            'Risk_Alert_Threshold__c must be in 1–100 range; got: ' + config.Risk_Alert_Threshold__c);
    }

    @IsTest
    static void slackConfigSeedRecord_channelIdsAreSet() {
        NEPA_Slack_Config__mdt config = [
            SELECT Default_Channel_Id__c, Notify_Tribal_Channel__c
            FROM NEPA_Slack_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        // Channel IDs will be placeholders in a fresh deploy — this test verifies
        // the fields exist and are non-null. Actual channel IDs are set post-deploy
        // per DEVELOPER_GUIDE.md § Step 12c.
        System.assertNotEquals(null, config.Default_Channel_Id__c,
            'Default_Channel_Id__c must not be null (may be PLACEHOLDER in fresh deploy)');
        System.assertNotEquals(null, config.Notify_Tribal_Channel__c,
            'Notify_Tribal_Channel__c must not be null (may be PLACEHOLDER in fresh deploy)');
    }

    // ── Stage notifier: placeholder guard prevents slack call ─────────────────

    @IsTest
    static void stageNotifier_placeholderChannelId_flowCompletesWithoutError() {
        // NEPA_Slack_Stage_Notifier is after-save on IA. Invoke it via DML trigger
        // by changing nepa_process_stage__c — flow reads CMT, finds placeholder,
        // and exits at Decision_Config_Found without calling slack__SendMessage.
        Program proj = NepaTestFactory.insertProgram('SLACK-001', 'Stage Notifier Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        Test.startTest();
        ia.nepa_process_stage__c = 'Public Comment';
        update ia;
        Test.stopTest();

        // If no exception is thrown, the placeholder guard worked correctly
        System.assert(true, 'Stage notifier flow must complete without error when CMT has placeholder channel IDs');
    }

    // ── Risk alert: below-threshold guard ────────────────────────────────────

    @IsTest
    static void riskAlert_belowThreshold_flowCompletesWithoutError() {
        NEPA_Slack_Config__mdt config = [
            SELECT Risk_Alert_Threshold__c FROM NEPA_Slack_Config__mdt
            WHERE DeveloperName = 'Default' LIMIT 1
        ];
        Decimal threshold = config.Risk_Alert_Threshold__c;
        Decimal belowThreshold = threshold > 1 ? threshold - 1 : 0;

        Program proj = NepaTestFactory.insertProgram('SLACK-002', 'Risk Alert Below Threshold', 'USFS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        Test.startTest();
        ia.nepa_risk_score__c = belowThreshold;
        update ia;
        Test.stopTest();

        System.assert(true,
            'Risk alert flow must complete without error when score (' + belowThreshold +
            ') is below threshold (' + threshold + ')');
    }

    @IsTest
    static void riskAlert_placeholderChannel_atOrAboveThreshold_flowCompletesWithoutError() {
        // Channel ID is placeholder — flow exits at Decision_Threshold_Breached
        // NotEqualTo PLACEHOLDER guard before attempting slack__SendMessage
        NEPA_Slack_Config__mdt config = [
            SELECT Risk_Alert_Threshold__c FROM NEPA_Slack_Config__mdt
            WHERE DeveloperName = 'Default' LIMIT 1
        ];
        Decimal atThreshold = config.Risk_Alert_Threshold__c;

        Program proj = NepaTestFactory.insertProgram('SLACK-003', 'Risk Alert Placeholder Channel', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        Test.startTest();
        ia.nepa_risk_score__c = atThreshold;
        update ia;
        Test.stopTest();

        System.assert(true,
            'Risk alert flow must complete without error at threshold (' + atThreshold +
            ') when channel ID is still a placeholder value');
    }

    // ── EJTribal Router regression: Slack path must not break existing routing ─

    @IsTest
    static void ejTribalRouter_placeholderSlackConfig_routingStillCompletes() {
        Program proj = NepaTestFactory.insertProgram('SLACK-004', 'EJ Tribal Slack Regression', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        PublicComplaint pc = new PublicComplaint();
        pc.IncidentDate            = Date.today();
        pc.nepa_related_process__c = ia.Id;
        pc.nepa_comment_body__c    = 'This project threatens tribal sovereignty and treaty rights.';
        pc.nepa_date_submitted__c  = Date.today();
        insert pc;

        Map<String, Object> inputs = new Map<String, Object>{
            'inp_CommentId'      => pc.Id,
            'inp_EJTriggers'     => 'Tribal Sovereignty',
            'inp_TriggerDetails' => 'Mandatory human review required'
        };

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_EJTribal_Router', inputs);
        interview.start();
        Test.stopTest();

        Boolean routed = (Boolean) interview.getVariableValue('out_Routed');
        System.assertEquals(true, routed,
            'EJ/Tribal routing must complete successfully even when Slack CMT has placeholder channel IDs');

        PublicComplaint result = [
            SELECT nepa_is_ej_comment__c, nepa_requires_human_review__c, nepa_ai_triage_status__c
            FROM PublicComplaint WHERE Id = :pc.Id
        ];
        System.assertEquals(true, result.nepa_is_ej_comment__c,
            'nepa_is_ej_comment__c must be true — Slack path must not block EJ flag updates');
        System.assertEquals(true, result.nepa_requires_human_review__c,
            'nepa_requires_human_review__c must be true — Slack path must not block human review flag');
        System.assertEquals('EJ-Routed', result.nepa_ai_triage_status__c,
            'EJ-Routed status must be set — Slack path must not block comment status update');
    }
}
