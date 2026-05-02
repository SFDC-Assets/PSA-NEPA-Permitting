@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage')
@IsTest
@SuppressWarnings('PMD.MethodNamingConventions, PMD.ApexUnitTestClassShouldHaveRunAs')
private class NepaProjectControllerTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('NEPA-TEST-001', 'Wind Farm EIS', 'BLM');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');

        Program proj2 = NepaTestFactory.insertProgram('NEPA-TEST-002', 'Solar Project EA', 'DOE');
        NepaTestFactory.insertClosedProcess(proj2.Id);

        // Project with no child IA — tests isCommentPeriodOpen = false path
        NepaTestFactory.insertProgram('NEPA-TEST-003', 'Pipeline CE', 'FERC');
    }

    // ── getProjectList ────────────────────────────────────────────────────────

    @IsTest
    static void getProjectList_returnsResults() {
        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, null, 1, 20);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.projects, 'Projects list should not be null');
        System.assertEquals(3, result.totalCount, 'Should return 3 total projects');
        System.assertEquals(1, result.pageNumber, 'Page number should be 1');
        System.assertEquals(20, result.pageSize, 'Page size should be 20');
    }

    @IsTest
    static void getProjectList_pagination_defaultsApplied() {
        Test.startTest();
        // Null page params should default to page 1, size 20
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, result.pageNumber);
        System.assertEquals(20, result.pageSize);
    }

    @IsTest
    static void getProjectList_pageSizeCappedAtMax() {
        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, null, 1, 999);
        Test.stopTest();

        System.assertEquals(20, result.pageSize, 'Page size over 100 should default to 20');
    }

    @IsTest
    static void getProjectList_validSortField() {
        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, 'nepa_lead_agency__c', 1, 10);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(3, result.totalCount);
    }

    @IsTest
    static void getProjectList_invalidSortFieldDefaultsGracefully() {
        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, 'INVALID_FIELD; DROP TABLE', 1, 10);
        Test.stopTest();

        // Should not throw — falls back to nepa_project_title__c
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void getProjectList_projectWithOpenPeriod_flaggedCorrectly() {
        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, null, 1, 20);
        Test.stopTest();

        Boolean foundOpen  = false;
        Boolean foundClosed = false;

        for (NepaProjectController.ProjectResult r : result.projects) {
            if (r.projectTitle == 'Wind Farm EIS' && r.isCommentPeriodOpen == true) {
                foundOpen = true;
            }
            if (r.projectTitle == 'Solar Project EA' && r.isCommentPeriodOpen == false) {
                foundClosed = true;
            }
        }

        System.assert(foundOpen,   'Wind Farm EIS should have open comment period');
        System.assert(foundClosed, 'Solar Project EA should have closed comment period');
    }

    @IsTest
    static void getProjectList_projectWithNoProcess_isCommentPeriodOpenFalse() {
        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, null, 1, 20);
        Test.stopTest();

        for (NepaProjectController.ProjectResult r : result.projects) {
            if (r.projectTitle == 'Pipeline CE') {
                System.assertEquals(false, r.isCommentPeriodOpen,
                    'Project with no process should have isCommentPeriodOpen = false');
            }
        }
    }

    // ── getProjectDetail ──────────────────────────────────────────────────────

    @IsTest
    static void getProjectDetail_returnsDetail() {
        Test.startTest();
        NepaProjectController.ProjectDetail detail =
            NepaProjectController.getProjectDetail('NEPA-TEST-001');
        Test.stopTest();

        System.assertEquals('NEPA-TEST-001', detail.federalUniqueId);
        System.assertEquals('Wind Farm EIS',  detail.projectTitle);
        System.assertEquals('BLM',            detail.leadAgencyName);
        System.assertNotEquals(null,           detail.processId, 'processId should be populated');
        System.assertEquals(true,             detail.isCommentPeriodOpen);
    }

    @IsTest
    static void getProjectDetail_projectWithNoProcess_isCommentPeriodOpenFalse() {
        Test.startTest();
        NepaProjectController.ProjectDetail detail =
            NepaProjectController.getProjectDetail('NEPA-TEST-003');
        Test.stopTest();

        System.assertEquals(false, detail.isCommentPeriodOpen);
        System.assertEquals(null,  detail.processId);
    }

    @IsTest
    static void getProjectDetail_blankId_throwsException() {
        Test.startTest();
        try {
            NepaProjectController.getProjectDetail('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Exception message should mention required');
        }
        Test.stopTest();
    }

    @IsTest
    static void getProjectDetail_notFound_throwsException() {
        Test.startTest();
        try {
            NepaProjectController.getProjectDetail('DOES-NOT-EXIST');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Exception message should mention not found');
        }
        Test.stopTest();
    }

    // ── getOpenCommentPeriods ─────────────────────────────────────────────────

    @IsTest
    static void getOpenCommentPeriods_returnsOnlyOpenPeriods() {
        Test.startTest();
        List<NepaProjectController.OpenCommentPeriod> periods =
            NepaProjectController.getOpenCommentPeriods();
        Test.stopTest();

        System.assertEquals(1, periods.size(), 'Only 1 open comment period should be returned');
        System.assertEquals('EIS', periods[0].reviewType);
        System.assert(periods[0].daysRemaining >= 0, 'Days remaining should be non-negative');
    }

    @IsTest
    static void getOpenCommentPeriods_noOpenPeriods_returnsEmpty() {
        // Move the open process's end date to yesterday
        IndividualApplication openIA = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_public_comment_period_end_date__c >= :DateTime.now()
            LIMIT 1
        ];
        openIA.nepa_public_comment_period_end_date__c = (DateTime)Date.today().addDays(-1);
        update openIA;

        Test.startTest();
        List<NepaProjectController.OpenCommentPeriod> periods =
            NepaProjectController.getOpenCommentPeriods();
        Test.stopTest();

        System.assertEquals(0, periods.size(), 'No open comment periods should be returned');
    }

    // ── bulk safety (251+ records) ────────────────────────────────────────────

    @IsTest
    static void getProjectList_bulkSafe() {
        List<Program> programs = new List<Program>();
        for (Integer i = 0; i < 251; i++) {
            programs.add(NepaTestFactory.makeProgram('BULK-' + i, 'Bulk Project ' + i, 'BLM'));
        }
        insert programs;

        Test.startTest();
        NepaProjectController.ProjectListResult result =
            NepaProjectController.getProjectList(null, null, null, 1, 100);
        Test.stopTest();

        System.assertEquals(100, result.projects.size(), 'Should return 100 results per page');
        System.assert(result.totalCount > 250, 'Total count should exceed 250');
    }
}
