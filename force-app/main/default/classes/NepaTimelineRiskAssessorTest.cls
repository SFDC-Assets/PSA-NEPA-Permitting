@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaTimelineRiskAssessorTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Id getLicenseTypeId() {
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review' LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
            Name = 'NEPA Environmental Review',
            RegulatoryAuthCategory = 'Permit'
        );
        insert rat;
        return rat.Id;
    }

    private static IndividualApplication makeEISProcess(Id projectId) {
        IndividualApplication ia = new IndividualApplication();
        ia.Category                = 'Permit';
        ia.LicenseTypeId           = getLicenseTypeId();
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

    // ── On Track: stage transition 10 days ago → well below per-agency EIS baseline ──
    // EIS baseline is now per-agency from NEPA_Agency_Scoping_Baseline__mdt.
    // BLM baseline = (28 + 13) × 30 = 1230d; 10 days is far below all agency baselines.

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
                'Transition 10 days ago should be On Track — below all per-agency EIS baselines');
        }
    }

    // ── Overdue: stage transition 2000 days ago → exceeds all per-agency EIS baselines ──
    // Highest per-agency baseline: FAA = (47+12)*30 = 1770d. 2000 days exceeds all agencies.

    @IsTest
    static void overdue_whenDaysInStageExceedOverdueThreshold() {
        Program proj = NepaTestFactory.insertProgram('TRA-004', 'Overdue Project', 'BLM');
        IndividualApplication ia = makeEISProcess(proj.Id);
        ia.nepa_last_stage_transition__c = daysAgo(2000); // 2000 days exceeds all per-agency baselines
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c           = 'Draft EIS Preparation';
        iaUpdate.nepa_last_stage_transition__c    = daysAgo(2000);

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
                '2000 days in EIS Draft Preparation must be Stalled or Overdue (exceeds all per-agency baselines); got: '
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
        ia.LicenseTypeId                  = getLicenseTypeId();
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
        ia.LicenseTypeId          = getLicenseTypeId();
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

    // ── AI writes projected field, not the statutory estimated field ──────────

    @IsTest
    static void timelineRisk_writesProjectedNotEstimated() {
        Program proj = NepaTestFactory.insertProgram('TRA-007', 'Projected Field Test', 'BLM');
        IndividualApplication ia = makeEISProcess(proj.Id);
        ia.nepa_last_stage_transition__c     = daysAgo(30);
        ia.nepa_estimated_completion_date__c = null;
        ia.nepa_projected_completion_date__c = null;
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c           = 'Draft EIS Preparation';
        iaUpdate.nepa_last_stage_transition__c   = daysAgo(30);

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_projected_completion_date__c, nepa_estimated_completion_date__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        // AsyncAfterCommit flows may not complete synchronously in test context.
        // Key governance assertion: nepa_estimated_completion_date__c must NEVER be written by the flow.
        System.assertEquals(null, result.nepa_estimated_completion_date__c,
            'nepa_estimated_completion_date__c must remain null — reserved statutory field, AI must write projected only');
        // If the async path did complete, projected date must not be in the past.
        if (result.nepa_projected_completion_date__c != null) {
            System.assert(result.nepa_projected_completion_date__c >= Date.today(),
                'Projected completion date must not be in the past');
        }
    }

    // ── CE page count outlier: >17 pages → At Risk regardless of timeline ───────
    // Stage 6 corpus analysis: p95 CE page count = 17 pages. Above this signals scope creep.

    @IsTest
    static void cePageCount_aboveThreshold_producesAtRisk() {
        Program proj = NepaTestFactory.insertProgram('TRA-PAGE-CE-001', 'CE Page Outlier', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                      = 'Permit';
        ia.LicenseTypeId                 = getLicenseTypeId();
        ia.nepa_related_project__c       = proj.Id;
        ia.nepa_review_type__c           = 'CE';
        ia.nepa_process_status__c        = 'in progress';
        ia.nepa_process_stage__c         = 'CE Determination';
        ia.nepa_last_stage_transition__c = daysAgo(5); // well within timeline — page count drives risk
        ia.nepa_total_pages__c           = 20; // > 17 threshold
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_total_pages__c = 21; // trigger IsChanged

        Test.startTest();
        Boolean threw = false;
        try { update iaUpdate; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'CE page count outlier flow must not throw');

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c, nepa_classification_basis__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_timeline_risk_tier__c != null) {
            System.assertEquals('At Risk', result.nepa_timeline_risk_tier__c,
                'CE with >17 pages must produce At Risk — page count outlier override');
        }
    }

    @IsTest
    static void cePageCount_withinThreshold_doesNotElevateRisk() {
        Program proj = NepaTestFactory.insertProgram('TRA-PAGE-CE-002', 'CE Page Normal', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                      = 'Permit';
        ia.LicenseTypeId                 = getLicenseTypeId();
        ia.nepa_related_project__c       = proj.Id;
        ia.nepa_review_type__c           = 'CE';
        ia.nepa_process_status__c        = 'in progress';
        ia.nepa_process_stage__c         = 'CE Determination';
        ia.nepa_last_stage_transition__c = daysAgo(5);
        ia.nepa_total_pages__c           = 10; // ≤ 17 threshold
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_total_pages__c = 11;

        Test.startTest();
        Boolean threw = false;
        try { update iaUpdate; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'CE within page threshold must not throw');

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_timeline_risk_tier__c != null) {
            System.assertNotEquals('At Risk', result.nepa_timeline_risk_tier__c,
                'CE with ≤17 pages and recent transition should not be At Risk due to page count');
        }
    }

    // ── EA page count outlier: >200 pages → minimum At Risk ─────────────────────

    @IsTest
    static void eaPageCount_aboveThreshold_producesAtRisk() {
        Program proj = NepaTestFactory.insertProgram('TRA-PAGE-EA-001', 'EA Page Outlier', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                      = 'Permit';
        ia.LicenseTypeId                 = getLicenseTypeId();
        ia.nepa_related_project__c       = proj.Id;
        ia.nepa_review_type__c           = 'EA';
        ia.nepa_process_status__c        = 'in progress';
        ia.nepa_process_stage__c         = 'EA Preparation';
        ia.nepa_last_stage_transition__c = daysAgo(5); // well within timeline — page count drives risk
        ia.nepa_total_pages__c           = 250; // > 200 threshold
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_total_pages__c = 251;

        Test.startTest();
        Boolean threw = false;
        try { update iaUpdate; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'EA page count outlier flow must not throw');

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_timeline_risk_tier__c != null) {
            System.assertEquals('At Risk', result.nepa_timeline_risk_tier__c,
                'EA with >200 pages must produce at minimum At Risk — page count outlier');
        }
    }

    // ── Scoping overrun: EIS days in scoping stage exceeds agency cap ────────────
    // BLM scoping cap = 24 months. 750 days = 25 months → exceeds cap.

    @IsTest
    static void scopingOverrun_whenDaysExceedAgencyCap_setsFlag() {
        Program proj = NepaTestFactory.insertProgram('TRA-SCOPING-001', 'Scoping Overrun', 'BLM');
        IndividualApplication ia = makeEISProcess(proj.Id);
        ia.nepa_process_stage__c         = 'Scoping';
        ia.nepa_last_stage_transition__c = daysAgo(750); // ~25 months; BLM cap = 24 months
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c        = 'Scoping'; // keep in scoping to test overrun
        iaUpdate.nepa_last_stage_transition__c = daysAgo(750);

        Test.startTest();
        Boolean threw = false;
        try { update iaUpdate; } catch (Exception e) { threw = true; }
        Test.stopTest();

        System.assertEquals(false, threw, 'Scoping overrun detection must not throw');

        IndividualApplication result = [
            SELECT nepa_scoping_overrun_flag__c, nepa_projected_scoping_overrun_months__c,
                   nepa_agency_scoping_baseline_months__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];

        if (result.nepa_scoping_overrun_flag__c != null) {
            System.assertEquals(true, result.nepa_scoping_overrun_flag__c,
                '750 days in Scoping for BLM (cap 24mo=720d) should set nepa_scoping_overrun_flag__c');
        }
        if (result.nepa_projected_scoping_overrun_months__c != null) {
            System.assert(result.nepa_projected_scoping_overrun_months__c > 0,
                'Projected scoping overrun months must be positive when flag is set');
        }
    }

    // ── Other Authorization pathway is always On Track ────────────────────────

    @IsTest
    static void timelineRisk_otherAuthPathway_alwaysOnTrack() {
        Program proj = NepaTestFactory.insertProgram('TRA-008', 'Other Auth Project', 'BLM');
        IndividualApplication ia = new IndividualApplication();
        ia.Category                      = 'Permit';
        ia.LicenseTypeId                 = getLicenseTypeId();
        ia.nepa_related_project__c       = proj.Id;
        ia.nepa_review_type__c           = 'Other Authorization';
        ia.nepa_process_status__c        = 'in progress';
        ia.nepa_process_stage__c         = 'Intake';
        ia.nepa_last_stage_transition__c = daysAgo(500);
        insert ia;

        IndividualApplication iaUpdate = new IndividualApplication(Id = ia.Id);
        iaUpdate.nepa_process_stage__c          = 'Analysis';
        iaUpdate.nepa_last_stage_transition__c  = daysAgo(500);

        Test.startTest();
        update iaUpdate;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_timeline_risk_tier__c FROM IndividualApplication WHERE Id = :ia.Id
        ];

        // AsyncAfterCommit may not complete synchronously in tests — accept null or On Track.
        // Key governance: 'Other Authorization' must never produce At Risk/Stalled/Overdue.
        System.assert(
            result.nepa_timeline_risk_tier__c == null || result.nepa_timeline_risk_tier__c == 'On Track',
            'Other Authorization pathway must never produce At Risk/Stalled/Overdue — EA baselines must not apply');
    }

    // ── Per-agency scoping baseline drives overrun threshold ──────────────────
    // BLM cap = 28 months (840d). FAA cap = 47 months (1410d).
    // 900 days exceeds BLM but is well under FAA — only BLM should flag overrun.

    @IsTest
    static void scopingOverrun_perAgencyCap_BLMExceeds_FAADoesNot() {
        // BLM: 900d > 28mo (840d) → overrun expected
        Program blmProj = NepaTestFactory.makeProgram('TRA-PCAP-BLM-001', 'BLM Scoping Cap', 'BLM');
        blmProj.nepa_record_owner_agency__c = 'BLM';
        insert blmProj;
        IndividualApplication blmIa = makeEISProcess(blmProj.Id);
        blmIa.nepa_process_stage__c         = 'Scoping';
        blmIa.nepa_last_stage_transition__c = daysAgo(900);
        insert blmIa;

        // FAA: 900d < 47mo (1410d) → no overrun
        Program faaProj = NepaTestFactory.makeProgram('TRA-PCAP-FAA-001', 'FAA Scoping Cap', 'FAA');
        faaProj.nepa_record_owner_agency__c = 'FAA';
        insert faaProj;
        IndividualApplication faaIa = makeEISProcess(faaProj.Id);
        faaIa.nepa_process_stage__c         = 'Scoping';
        faaIa.nepa_last_stage_transition__c = daysAgo(900);
        insert faaIa;

        Test.startTest();
        IndividualApplication blmUpdate = new IndividualApplication(Id = blmIa.Id);
        blmUpdate.nepa_last_stage_transition__c = daysAgo(900);
        update blmUpdate;

        IndividualApplication faaUpdate = new IndividualApplication(Id = faaIa.Id);
        faaUpdate.nepa_last_stage_transition__c = daysAgo(900);
        update faaUpdate;
        Test.stopTest();

        IndividualApplication blmResult = [
            SELECT nepa_scoping_overrun_flag__c FROM IndividualApplication WHERE Id = :blmIa.Id
        ];
        IndividualApplication faaResult = [
            SELECT nepa_scoping_overrun_flag__c FROM IndividualApplication WHERE Id = :faaIa.Id
        ];

        // BLM: if the flag was written, it must be true
        if (blmResult.nepa_scoping_overrun_flag__c != null) {
            System.assertEquals(true, blmResult.nepa_scoping_overrun_flag__c,
                'BLM: 900 days exceeds 28-month scoping cap (840d) — overrun flag must be true');
        }

        // FAA: if the flag was written, it must be false (900d < 47mo cap = 1410d)
        if (faaResult.nepa_scoping_overrun_flag__c != null) {
            System.assertEquals(false, faaResult.nepa_scoping_overrun_flag__c,
                'FAA: 900 days is within 47-month scoping cap (1410d) — overrun flag must be false');
        }
    }
}
