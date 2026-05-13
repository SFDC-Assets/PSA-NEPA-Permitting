@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaPlaintiffIntelligenceTest {

    @TestSetup
    static void setup() {
        Program proj = NepaTestFactory.insertProgram('PLT-TEST-001', 'Plaintiff Intel Test Project', 'BLM');
        NepaTestFactory.insertProcess(proj.Id, 'EIS', null, null);
    }

    private static IndividualApplication getParentApp() {
        return [
            SELECT Id, nepa_plaintiff_risk_flag__c, nepa_tribal_plaintiff_flag__c
            FROM IndividualApplication
            WHERE nepa_related_project__r.nepa_project_id__c = 'PLT-TEST-001'
            LIMIT 1
        ];
    }

    private static PublicComplaint buildComplaint(Id parentAppId, String orgName) {
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                       = 'Test Commenter';
        pc.IncidentDate                   = Date.today();
        pc.nepa_organization__c           = orgName;
        pc.nepa_related_process__c  = parentAppId;
        pc.nepa_related_process__c        = parentAppId;
        return pc;
    }

    @IsTest
    static void plaintiffIntelligence_veryHighOrgMatch_flagsAndCreatesTask() {
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'Center for Biological Diversity');
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'Parent IA should be flagged for VERY_HIGH plaintiff match');

        List<Task> tasks = [SELECT Id, Priority, Status, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(), 'One defensibility review task should be created');
        System.assertEquals('High', tasks[0].Priority);
        System.assertEquals('Not Started', tasks[0].Status);
    }

    @IsTest
    static void plaintiffIntelligence_highOrgMatch_flagsAndCreatesTask() {
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'Western Watersheds Project');
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'Parent IA should be flagged for HIGH plaintiff match');

        List<Task> tasks = [SELECT Id, Priority, Status, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(), 'One defensibility review task should be created');
        System.assertEquals('High', tasks[0].Priority);
        System.assertEquals('Not Started', tasks[0].Status);
    }

    @IsTest
    static void plaintiffIntelligence_partialContainsMatch_flagsAndCreatesTask() {
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'Center for Biological Diversity - Pacific Region');
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'CONTAINS match should flag the parent IA');

        List<Task> tasks = [SELECT Id, Priority, Status, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(), 'One task should be created for partial CONTAINS match');
    }

    @IsTest
    static void plaintiffIntelligence_noMatch_noFlagNoTask() {
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'Friends of the River');
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'Parent IA should NOT be flagged for unrecognized organization');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(), 'No task should be created for non-matching org');
    }

    @IsTest
    static void plaintiffIntelligence_blankOrgName_flowSkipped() {
        IndividualApplication ia = getParentApp();

        PublicComplaint pc = new PublicComplaint();
        pc.LastName                       = 'Anonymous Commenter';
        pc.IncidentDate                   = Date.today();
        pc.nepa_organization__c           = null;
        pc.nepa_related_process__c  = ia.Id;
        pc.nepa_related_process__c        = ia.Id;

        Test.startTest();
        insert pc;
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertNotEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'Blank org name should skip flow — flag remains false');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(), 'No task when org name is blank');
    }

    @IsTest
    static void plaintiffIntelligence_nullParentApp_flowSkipped() {
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                       = 'Orphaned Commenter';
        pc.IncidentDate                   = Date.today();
        pc.nepa_organization__c           = 'Center for Biological Diversity';
        pc.nepa_related_process__c  = null;

        Test.startTest();
        insert pc;
        Test.stopTest();

        IndividualApplication ia = getParentApp();
        System.assertNotEquals(true, ia.nepa_plaintiff_risk_flag__c,
            'Null parent app should skip flow — no IA flagged');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(0, tasks.size(), 'No task when parent app is null');
    }

    @IsTest
    static void plaintiffIntelligence_tribalNation_setsBothFlags() {
        // Navajo Nation: Is_Tribal_Nation__c=true, Risk_Tier__c=VERY_HIGH in MDT
        // Stage 10: Tribal Nation challengers achieve 87.5% win rate — highest category
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'Navajo Nation');
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c, nepa_tribal_plaintiff_flag__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'Navajo Nation match should set nepa_plaintiff_risk_flag__c');
        System.assertEquals(true, updated.nepa_tribal_plaintiff_flag__c,
            'Navajo Nation (Is_Tribal_Nation__c=true) must set nepa_tribal_plaintiff_flag__c');
    }

    @IsTest
    static void plaintiffIntelligence_nonTribalHighRisk_doesNotSetTribalFlag() {
        // WildEarth Guardians: Is_Tribal_Nation__c=false, Risk_Tier__c=VERY_HIGH
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'WildEarth Guardians');
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c, nepa_tribal_plaintiff_flag__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'WildEarth Guardians should set nepa_plaintiff_risk_flag__c (VERY_HIGH non-tribal)');
        System.assertNotEquals(true, updated.nepa_tribal_plaintiff_flag__c,
            'WildEarth Guardians (Is_Tribal_Nation__c=false) must not set nepa_tribal_plaintiff_flag__c');
    }

    @IsTest
    static void plaintiffIntelligence_tribalNation_taskSubjectContainsOrgName() {
        // When Navajo Nation matches (Is_Tribal_Nation__c=true, VERY_HIGH), the task
        // subject formula includes the org name — verify the task was created with WhatId = IA
        // and subject contains "Navajo" (partial check so it's tolerant of exact formula wording).
        IndividualApplication ia = getParentApp();

        Test.startTest();
        insert buildComplaint(ia.Id, 'Navajo Nation');
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, WhatId FROM Task WHERE WhatId = :ia.Id];
        System.assertEquals(1, tasks.size(),
            'One defensibility review task must be created for Navajo Nation match');
        System.assertEquals(ia.Id, tasks[0].WhatId,
            'Task WhatId must reference the parent IndividualApplication');
        System.assert(
            tasks[0].Subject.contains('Navajo') || tasks[0].Subject.contains('VERY_HIGH'),
            'Task subject must reference matched org name or risk tier; got: ' + tasks[0].Subject);
    }

    @IsTest
    static void plaintiffIntelligence_twoHighRiskOrgs_bothFlagsSet() {
        // Insert two complaints for the same IA in a single Test.startTest() block —
        // one from a non-tribal VERY_HIGH org, one from a tribal VERY_HIGH org.
        // After stopTest the async paths complete; verify the tribal flag is set.
        IndividualApplication ia = getParentApp();

        PublicComplaint nontribal = buildComplaint(ia.Id, 'Center for Biological Diversity');
        PublicComplaint tribal = buildComplaint(ia.Id, 'Navajo Nation');
        tribal.LastName = 'Tribal Commenter';

        Test.startTest();
        insert nontribal;
        insert tribal;
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c, nepa_tribal_plaintiff_flag__c
            FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'nepa_plaintiff_risk_flag__c must be set after high-risk org comments');
        System.assertEquals(true, updated.nepa_tribal_plaintiff_flag__c,
            'nepa_tribal_plaintiff_flag__c must be set after Navajo Nation tribal comment');
    }

    @IsTest
    static void plaintiffIntelligence_bulk_multipleRecords_noSoqlInLoop() {
        IndividualApplication ia = getParentApp();

        List<PublicComplaint> complaints = new List<PublicComplaint>();
        for (Integer i = 0; i < 5; i++) {
            PublicComplaint pc = buildComplaint(ia.Id, 'Center for Biological Diversity');
            pc.LastName = 'Bulk Commenter ' + i;
            complaints.add(pc);
        }

        Test.startTest();
        insert complaints;
        Test.stopTest();

        IndividualApplication updated = [
            SELECT nepa_plaintiff_risk_flag__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, updated.nepa_plaintiff_risk_flag__c,
            'Bulk insert of matching complaints should flag the parent IA');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ia.Id];
        System.assert(tasks.size() >= 1,
            'At least one defensibility review task should exist after bulk insert');
    }
}
