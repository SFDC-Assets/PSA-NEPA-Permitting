@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaSlaDueDateSetterTest {

    @TestSetup
    static void setup() {
        NepaTestFactory.insertProgram('SLA-001', 'SLA Due Date Setter Test', 'BLM');
    }

    private static Id getProjId() {
        return [SELECT Id FROM Program WHERE nepa_project_id__c = 'SLA-001' LIMIT 1].Id;
    }

    // ── Test 1: review type + start date together → due date computed ─────────

    @IsTest
    static void reviewTypeAndStartDate_computesDueDate() {
        List<NEPA_SLA_Config__mdt> configs = [
            SELECT Review_Type__c, Total_Days__c
            FROM NEPA_SLA_Config__mdt
            WHERE Active__c = true
            LIMIT 1
        ];
        if (configs.isEmpty()) { return; }

        String reviewType = configs[0].Review_Type__c;
        Integer totalDays = configs[0].Total_Days__c.intValue();
        Date startDate    = Date.today();

        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.makeProcess(projId, null, null, null);
        insert ia;

        ia.nepa_review_type__c = reviewType;
        ia.nepa_start_date__c  = startDate;
        update ia;

        IndividualApplication result = [
            SELECT nepa_sla_due_date__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        System.assertNotEquals(null, result.nepa_sla_due_date__c,
            'NEPA_SLA_Due_Date_Setter flow must populate nepa_sla_due_date__c when both review type and start date are set');
        System.assertEquals(startDate.addDays(totalDays), result.nepa_sla_due_date__c,
            'SLA due date must equal start date + ' + totalDays + ' days for review type ' + reviewType
            + '; got: ' + result.nepa_sla_due_date__c);
    }

    // ── Test 2: changing review type + start date resets warning/overdue flags ─

    @IsTest
    static void dueDateChange_resetsSlaWarningAndOverdueFlags() {
        List<NEPA_SLA_Config__mdt> configs = [
            SELECT Review_Type__c, Total_Days__c
            FROM NEPA_SLA_Config__mdt
            WHERE Active__c = true
            LIMIT 1
        ];
        if (configs.isEmpty()) { return; }

        String reviewType = configs[0].Review_Type__c;
        Date startDate    = Date.today();

        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.makeProcess(projId, null, null, null);
        ia.nepa_sla_warning_sent__c = true;
        ia.nepa_sla_overdue__c      = true;
        insert ia;

        ia.nepa_review_type__c = reviewType;
        ia.nepa_start_date__c  = startDate;
        update ia;

        IndividualApplication result = [
            SELECT nepa_sla_warning_sent__c, nepa_sla_overdue__c, nepa_sla_due_date__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        System.assertNotEquals(null, result.nepa_sla_due_date__c,
            'NEPA_SLA_Due_Date_Setter flow must populate nepa_sla_due_date__c when both review type and start date are set');
        System.assertEquals(false, result.nepa_sla_warning_sent__c,
            'nepa_sla_warning_sent__c must be reset to false when due date is (re)computed');
        System.assertEquals(false, result.nepa_sla_overdue__c,
            'nepa_sla_overdue__c must be reset to false when due date is (re)computed');
    }

    // ── Test 3: review type set, no start date → due date stays null ──────────

    @IsTest
    static void noStartDate_doesNotSetDueDate() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.makeProcess(projId, null, null, null);
        insert ia;

        ia.nepa_review_type__c = 'EIS';
        update ia;

        IndividualApplication result = [
            SELECT nepa_sla_due_date__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        System.assertEquals(null, result.nepa_sla_due_date__c,
            'nepa_sla_due_date__c must remain null when nepa_start_date__c is not set');
    }

    // ── Test 4: start date set, no review type → due date stays null ─────────

    @IsTest
    static void noReviewType_doesNotSetDueDate() {
        Id projId = getProjId();
        IndividualApplication ia = NepaTestFactory.makeProcess(projId, null, null, null);
        insert ia;

        ia.nepa_start_date__c = Date.today();
        update ia;

        IndividualApplication result = [
            SELECT nepa_sla_due_date__c
            FROM IndividualApplication
            WHERE Id = :ia.Id
        ];

        System.assertEquals(null, result.nepa_sla_due_date__c,
            'nepa_sla_due_date__c must remain null when nepa_review_type__c is not set');
    }
}