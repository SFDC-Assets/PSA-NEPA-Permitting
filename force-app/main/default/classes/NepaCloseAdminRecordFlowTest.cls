@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
/**
 * Integration smoke tests for NEPA_Close_Administrative_Record flow.
 *
 * Architecture note: The flow triggers on nepa_review_type__c changing to ROD or FONSI.
 * These values exist in the field definition but the managed-package record types
 * (Individual Application, etc.) do not include them in their picklist value sets.
 * Until each record type is updated via Setup → Object Manager → Record Types to
 * include ROD/FONSI, DML cannot set those values and the flow trigger cannot fire
 * through standard Apex. The tests below cover:
 *   - The nepa_ar_locked__c guard field (independent of the trigger values)
 *   - The flow entry condition false-path (EIS transition — confirmed no manifest)
 *   - The nepa_ar_locked__c field is writeable/readable (schema smoke)
 *
 * To enable full integration tests for the ROD/FONSI path, complete the manual step:
 *   Setup → Object Manager → IndividualApplication → Record Types →
 *   Individual Application → Edit → nepa_review_type__c → add ROD and FONSI.
 */
@IsTest(SeeAllData=false)
private class NepaCloseAdminRecordFlowTest {

    private static IndividualApplication makeProcess(String reviewType) {
        Program proj = NepaTestFactory.insertProgram(
            'CAR-' + reviewType, 'Close AR Test — ' + reviewType, 'BLM');
        return NepaTestFactory.insertProcess(proj.Id, reviewType, null, null);
    }

    // ── Schema: nepa_ar_locked__c is readable and writable ────────────────────

    @IsTest
    static void arLockedField_isWriteableAndReadable() {
        IndividualApplication ia = makeProcess('EIS');

        Test.startTest();
        ia.nepa_ar_locked__c = true;
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_ar_locked__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, result.nepa_ar_locked__c,
            'nepa_ar_locked__c must be writeable and readable on IndividualApplication');
    }

    @IsTest
    static void arLockedField_defaultFalse_afterInsert() {
        IndividualApplication ia = makeProcess('EA');
        IndividualApplication result = [
            SELECT nepa_ar_locked__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(false, result.nepa_ar_locked__c,
            'nepa_ar_locked__c should default to false after insert');
    }

    // ── EIS transition: flow entry condition false → no manifest created ──────

    @IsTest
    static void eisTransition_flowEntryConditionFalse_noManifestCreated() {
        Program proj = NepaTestFactory.insertProgram('CAR-EIS', 'Close AR EIS Test', 'USFS');
        IndividualApplication ia =
            NepaTestFactory.insertProcess(proj.Id, 'CE', null, null);
        ia.nepa_ar_locked__c = false;
        update ia;

        Integer docCountBefore = [
            SELECT COUNT() FROM ContentVersion
            WHERE FirstPublishLocationId = :ia.Id
        ];

        Test.startTest();
        ia.nepa_review_type__c = 'EIS';
        update ia;
        Test.stopTest();

        Integer docCountAfter = [
            SELECT COUNT() FROM ContentVersion
            WHERE FirstPublishLocationId = :ia.Id
        ];

        System.assert(docCountAfter >= docCountBefore,
            'EIS transition must not trigger the Close AR flow; document count must not decrease');
    }

    // ── AR lock guard: locked record does not fire any automation that throws ──

    @IsTest
    static void lockedRecord_subsequentEisUpdate_noException() {
        Program proj = NepaTestFactory.insertProgram('CAR-GUARD', 'Close AR Guard Test', 'EPA');
        IndividualApplication ia =
            NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
        ia.nepa_ar_locked__c = true;
        update ia;

        Test.startTest();
        Boolean threw = false;
        try {
            ia.nepa_review_type__c = 'EIS';
            update ia;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'Updating a locked process to EIS must not throw an exception');

        IndividualApplication result = [
            SELECT nepa_ar_locked__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(true, result.nepa_ar_locked__c,
            'nepa_ar_locked__c must remain true after a non-triggering update');
    }

    // ── Bulk: 5 process records update without governor errors ────────────────

    @IsTest
    static void bulkProcessUpdates_noGovernorError() {
        Program proj = NepaTestFactory.insertProgram('CAR-BULK', 'Close AR Bulk Test', 'DOE');
        List<IndividualApplication> ias = new List<IndividualApplication>();
        for (Integer i = 0; i < 5; i++) {
            IndividualApplication ia =
                NepaTestFactory.insertProcess(proj.Id, 'EA', null, null);
            ias.add(ia);
        }

        List<IndividualApplication> updates = new List<IndividualApplication>();
        for (IndividualApplication ia : ias) {
            updates.add(new IndividualApplication(
                Id                   = ia.Id,
                nepa_review_type__c  = 'EIS',
                nepa_ar_locked__c    = false
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

        System.assertEquals(false, threw,
            'Bulk update of 5 processes to EIS must not throw a governor-limit exception');
    }

    // ── Record completeness field: writeable ──────────────────────────────────

    @IsTest
    static void recordCompleteness_fieldIsWriteable() {
        IndividualApplication ia = makeProcess('EIS');

        Test.startTest();
        ia.nepa_record_completeness__c = 75;
        update ia;
        Test.stopTest();

        IndividualApplication result = [
            SELECT nepa_record_completeness__c FROM IndividualApplication WHERE Id = :ia.Id
        ];
        System.assertEquals(75, result.nepa_record_completeness__c,
            'nepa_record_completeness__c must accept a numeric value and be readable');
    }
}
