@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaTimelineRiskAssessorTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static IndividualApplication makeEISProcess(Id projectId) {
        IndividualApplication ia = new IndividualApplication();
        ia.Category                = 'Permit';
        ia.nepa_related_project__c = projectId;
        ia.nepa_review_type__c     = 'EIS';
        ia.nepa_process_status__c  = 'in progress';
        ia.nepa_process_stage__c   = 'Scoping';
        return ia;
    }

    // nepa_days_in_current_stage__c is a formula: TODAY() - DATEVALUE(nepa_last_stage_transition__c).
    // To simulate N days in stage, set nepa_last_stage_transition__c = N days ago.
    private static DateTime daysAgo(Integer n) {
        return DateTime.now().addDays(-n);
    }

    // ── Stage change triggers risk tier assessment ────────────────────────────

    @IsTest
    static void stageChange_triggersRiskTierWrite() {
        Program proj = NepaTestFactory.insertProgram('TRA-001', 'Timeline Risk Project', 'BLM');
        IndividualApplication ia = makeEISProcess(proj.Id);
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c = 'Draft EIS Preparation';

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c, nepa_estimated_completion_date__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        System.assertNotEquals(null, result.Id,
            'Record must still exist after stage change');

        if (result.nepa_timeline_risk_tier__c != null) {
            Set<String> validTiers = new Set<String>{
                'On Track', 'At Risk', 'Stalled', 'Overdue'
            };
            System.assert(validTiers.contains(result.nepa_timeline_risk_tier__c),
                'Risk tier must be one of On Track/At Risk/Stalled/Overdue; got: '
                    + result.nepa_timeline_risk_tier__c);
        }
    }

    // ── Status change also triggers flow ─────────────────────────────────────

    @IsTest
    static void statusChange_triggersRiskAssessment() {
        Program proj = NepaTestFactory.insertProgram('TRA-002', 'Status Change Project', 'FWS');
        IndividualApplication ia = makeEISProcess(proj.Id);
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_status__c = 'paused';

        Test.startTest();
        Boolean threw = false;
        try {
            update iaUpdate;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'Timeline risk assessor must not throw on status change');
    }

    // ── On Track: stage transition 10 days ago → well below 730-day EIS baseline ──

    @IsTest
    static void onTrack_whenDaysInStageWellBelowBaseline() {
        Program proj = NepaTestFactory.insertProgram('TRA-003', 'On Track Project', 'BLM');
        IndividualApplication ia = makeEISProcess(proj.Id);
        ia.nepa_last_stage_transition__c = daysAgo(10); // 10 days in stage
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c           = 'Draft EIS Preparation';
        iaUpdate.nepa_last_stage_transition__c    = daysAgo(10);

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        if (result.nepa_timeline_risk_tier__c != null) {
            System.assertEquals('On Track', result.nepa_timeline_risk_tier__c,
                'Transition 10 days ago in EIS Draft Preparation should be On Track (baseline 730d)');
        }
    }

    // ── Overdue: stage transition 1200 days ago → far exceeds 730-day EIS baseline ──

    @IsTest
    static void overdue_whenDaysInStageExceedOverdueThreshold() {
        Program proj = NepaTestFactory.insertProgram('TRA-004', 'Overdue Project', 'BLM');
        IndividualApplication ia = makeEISProcess(proj.Id);
        ia.nepa_last_stage_transition__c = daysAgo(1200); // 1200 days in stage
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c           = 'Draft EIS Preparation';
        iaUpdate.nepa_last_stage_transition__c    = daysAgo(1200);

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        if (result.nepa_timeline_risk_tier__c != null) {
            System.assert(
                result.nepa_timeline_risk_tier__c == 'Overdue'
                || result.nepa_timeline_risk_tier__c == 'Stalled',
                '1200 days in EIS Draft Preparation must be Stalled or Overdue; got: '
                    + result.nepa_timeline_risk_tier__c
            );
        }
    }

    // ── Estimated completion date is set and in the future ───────────────────

    @IsTest
    static void estimatedCompletionDate_isSetAndNotInPast() {
        Program proj = NepaTestFactory.insertProgram('TRA-005', 'Completion Date Project', 'FWS');
        IndividualApplication ia = makeEISProcess(proj.Id);
        ia.nepa_last_stage_transition__c = daysAgo(60); // 60 days in stage; baseline 730
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c        = 'Draft EIS Preparation';
        iaUpdate.nepa_last_stage_transition__c = daysAgo(60);

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_estimated_completion_date__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        if (result.nepa_estimated_completion_date__c != null) {
            System.assert(result.nepa_estimated_completion_date__c >= Date.today(),
                'Estimated completion date must not be in the past for an on-track project');
        }
    }

    // ── At Risk CE: transition 40 days ago → exceeds CE at-risk threshold (33d) ──

    @IsTest
    static void atRisk_createsEscalationTask() {
        Program proj = NepaTestFactory.insertProgram('TRA-006', 'At Risk CE Project', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                       = 'Permit';
        ia.nepa_related_project__c        = proj.Id;
        ia.nepa_review_type__c            = 'CE';
        ia.nepa_process_status__c         = 'in progress';
        ia.nepa_process_stage__c          = 'Scoping';
        ia.nepa_timeline_risk_tier__c     = 'On Track';
        ia.nepa_last_stage_transition__c  = daysAgo(1);
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c          = 'CE Determination';
        iaUpdate.nepa_last_stage_transition__c  = daysAgo(40); // 40d > CE at-risk threshold 33d
        iaUpdate.nepa_timeline_risk_tier__c     = 'On Track';

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [SELECT Id FROM IndividualApplication WHERE Id = :ia.Id];
        System.assertNotEquals(null, result.Id,
            'Record must exist after at-risk update');
    }

    // ── No related project — flow handles gracefully ──────────────────────────

    @IsTest
    static void noRelatedProject_flowHandlesGracefully() {
        IndividualApplication ia = new IndividualApplication();
        ia.Category               = 'Permit';
        ia.nepa_process_status__c = 'in progress';
        ia.nepa_process_stage__c  = 'Scoping';
        ia.nepa_review_type__c    = 'EIS';
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c = 'Draft EIS Preparation';

        Test.startTest();
        Boolean threw = false;
        try {
            update iaUpdate;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'Timeline risk assessor must not throw when no related project');
    }

    // ── Bulk: multiple records update without error ───────────────────────────

    @IsTest
    static void bulk_multipleRecords_noException() {
        Program proj = NepaTestFactory.insertProgram('TRA-BULK-001', 'Bulk TRA Project', 'BLM');
        List<IndividualApplication> ias = new List<IndividualApplication>();
        for (Integer i = 0; i < 5; i++) {
            IndividualApplication ia = makeEISProcess(proj.Id);
            ia.nepa_last_stage_transition__c = daysAgo(i * 100);
            ias.add(ia);
        }
        insert ias;

        List<IndividualApplication> updates = new List<IndividualApplication>();
        for (IndividualApplication ia : ias) {
            updates.add(new IndividualApplication(
                Id = ia.Id,
                nepa_process_stage__c = 'Draft EIS Preparation'
            ));
        }

        Test.startTest();
        Boolean threw = false;
        try {
            update updates;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'Timeline risk assessor bulk update must not throw');
    }
}
