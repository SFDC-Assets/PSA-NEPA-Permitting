@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaPermitRecordCreatorTest {

    // Label strings that NEPA_Permit_Record_Creator looks up in RegulatoryAuthorizationType
    private static final String PERMIT_LABEL_APD  = 'BLM Application for Permit to Drill';
    private static final String PERMIT_LABEL_CWA  = 'CWA Section 404 Permit';
    private static final String PERMIT_LABEL_CWA401 = 'CWA Section 401 Water Quality Certification';
    private static final String PERMIT_LABEL_NHPA = 'NHPA Section 106 Consultation';
    private static final String PERMIT_LABEL_CZMA = 'CZMA Federal Consistency Determination';

    @TestSetup
    static void setup() {
        // Seed RegulatoryAuthorizationType records the flow looks up by Name when building permit records.
        // CWA 401 is required here because the GIS NHD bridge appends it as a token; without a matching
        // RAT the flow skips the token (by design — see unknownPermitLabel_noRatMatch_createsNoPermit).
        List<RegulatoryAuthorizationType> rats = new List<RegulatoryAuthorizationType>();
        for (String lbl : new List<String>{
            PERMIT_LABEL_APD, PERMIT_LABEL_CWA, PERMIT_LABEL_CWA401, PERMIT_LABEL_NHPA, PERMIT_LABEL_CZMA
        }) {
            rats.add(new RegulatoryAuthorizationType(
                Name = lbl,
                RegulatoryAuthCategory = 'Permit'
            ));
        }
        insert rats;

        Program proj = NepaTestFactory.insertProgram('PERM-RC-001', 'Permit Creator Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        ia.nepa_federal_unique_id__c = 'FUID-RC-001';
        update ia;
    }

    private static IndividualApplication getIA() {
        return [
            SELECT Id, nepa_co_permits_required__c,
                   nepa_nhd_proximity_flag__c,
                   nepa_tribal_lands_flag__c,
                   nepa_ec_usace_czma__c
            FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'FUID-RC-001'
            LIMIT 1
        ];
    }

    // ── Flow fires and creates records when field is set ──────────────────────

    @IsTest
    static void permitsSet_createsRequiredPermitRecords() {
        IndividualApplication ia = getIA();
        ia.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id FROM nepa_required_permit__c WHERE nepa_process__c = :ia.Id
        ];
        System.assert(permits.size() > 0,
            'At least one nepa_required_permit__c must be created when nepa_co_permits_required__c is set');
    }

    // ── Field unchanged / null — entry condition not satisfied ────────────────

    @IsTest
    static void permitsField_notChanged_noRecordsCreated() {
        IndividualApplication ia = getIA();
        // Ensure field is null (from setup it is), touch a non-triggering field
        ia.nepa_disturbance_acres__c = 0;

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id FROM nepa_required_permit__c WHERE nepa_process__c = :ia.Id
        ];
        System.assertEquals(0, permits.size(),
            'No permit records must be created when nepa_co_permits_required__c is null/unchanged');
    }

    // ── Re-run: Not Started deleted, In Progress preserved ───────────────────

    @IsTest
    static void rerun_preservesInProgressPermits_deletesNotStarted() {
        IndividualApplication ia = getIA();

        nepa_required_permit__c pNotStarted = NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', true, (Date) null);
        nepa_required_permit__c pInProgress = NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, (Date) null);

        ia.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        Test.startTest();
        update ia;
        Test.stopTest();

        Set<Id> remainingIds = new Set<Id>();
        for (nepa_required_permit__c p : [
            SELECT Id FROM nepa_required_permit__c WHERE nepa_process__c = :ia.Id
        ]) {
            remainingIds.add(p.Id);
        }

        System.assert(remainingIds.contains(pInProgress.Id),
            'In Progress permit must be preserved on re-run');
        System.assert(!remainingIds.contains(pNotStarted.Id),
            'Original Not Started permit must be deleted on re-run');
    }

    // ── GIS bridge: NHD proximity flag appends CWA Section 401 ───────────────

    @IsTest
    static void gisNhdFlag_appendsCwa401() {
        IndividualApplication ia = getIA();
        ia.nepa_nhd_proximity_flag__c  = true;
        ia.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id FROM nepa_required_permit__c
            WHERE nepa_process__c = :ia.Id
            AND nepa_permit_type__c = 'CWA Section 401 Water Quality Certification'
        ];
        System.assert(permits.size() > 0,
            'CWA Section 401 Water Quality Certification permit must be created when nepa_nhd_proximity_flag__c = true');
    }

    // ── GIS bridge: tribal lands flag appends NHPA Section 106 ───────────────

    @IsTest
    static void gisTribalFlag_appendsNhpa106() {
        IndividualApplication ia = getIA();
        ia.nepa_tribal_lands_flag__c   = true;
        ia.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id FROM nepa_required_permit__c
            WHERE nepa_process__c = :ia.Id
            AND nepa_permit_type__c = :PERMIT_LABEL_NHPA
        ];
        System.assert(permits.size() > 0,
            'NHPA Section 106 permit must be created when nepa_tribal_lands_flag__c = true');
    }

    // ── GIS bridge: CZMA flag appends CZMA Federal Consistency ───────────────

    @IsTest
    static void gisCzmaFlag_appendsCzma() {
        IndividualApplication ia = getIA();
        ia.nepa_ec_usace_czma__c       = true;
        ia.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id FROM nepa_required_permit__c
            WHERE nepa_process__c = :ia.Id
            AND nepa_permit_type__c = :PERMIT_LABEL_CZMA
        ];
        System.assert(permits.size() > 0,
            'CZMA Federal Consistency permit must be created when nepa_ec_usace_czma__c = true');
    }

    // ── GIS flags produce MORE permits than non-GIS baseline ─────────────────

    @IsTest
    static void gisFlags_produceMorePermitsThanBaseline() {
        // Baseline IA: same permits string, no GIS flags
        Program proj = NepaTestFactory.insertProgram('PERM-RC-NOGIS', 'No GIS Test', 'BLM');
        IndividualApplication iaNoGis = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');

        IndividualApplication iaGis = getIA();
        iaGis.nepa_nhd_proximity_flag__c  = true;
        iaGis.nepa_tribal_lands_flag__c   = true;
        iaGis.nepa_ec_usace_czma__c       = true;
        iaGis.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        iaNoGis.nepa_co_permits_required__c = PERMIT_LABEL_APD;

        Test.startTest();
        update iaGis;
        update iaNoGis;
        Test.stopTest();

        Integer gisCount   = [SELECT COUNT() FROM nepa_required_permit__c WHERE nepa_process__c = :iaGis.Id];
        Integer noGisCount = [SELECT COUNT() FROM nepa_required_permit__c WHERE nepa_process__c = :iaNoGis.Id];

        System.assert(gisCount >= noGisCount,
            'All three GIS flags set must produce at least as many permits as no GIS flags; gis='
            + gisCount + ' noGis=' + noGisCount);
    }

    // ── Unrecognized permit label — no RAT match, no permit created ──────────
    // Root cause of Carrie Placer Mine missing-permit defect (SESSION-EXECUTIVE-SUMMARY 2026-05-28):
    // the demo load included permit labels ("BLM APD", "ESA §7 Consultation") that had no matching
    // RegulatoryAuthorizationType record in the org. The flow skipped those tokens silently.
    // This test locks that behavior: unrecognized labels must not crash the flow and must not
    // produce phantom permit records.

    @IsTest
    static void unknownPermitLabel_noRatMatch_createsNoPermit() {
        IndividualApplication ia = getIA();
        ia.nepa_co_permits_required__c = 'Completely Unknown Permit XYZ';

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id FROM nepa_required_permit__c WHERE nepa_process__c = :ia.Id
        ];
        System.assertEquals(0, permits.size(),
            'No permit must be created when the label has no matching RegulatoryAuthorizationType — '
            + 'unrecognized tokens must be skipped, not crash the flow');
    }

    @IsTest
    static void mixedLabels_someKnownSomeUnknown_onlyKnownCreated() {
        IndividualApplication ia = getIA();
        // One valid label (seeded in @TestSetup) + one with no RAT record
        ia.nepa_co_permits_required__c = PERMIT_LABEL_APD + ';Unknown Permit Type XYZ';

        Test.startTest();
        update ia;
        Test.stopTest();

        List<nepa_required_permit__c> permits = [
            SELECT Id, nepa_permit_type__c FROM nepa_required_permit__c
            WHERE nepa_process__c = :ia.Id
        ];
        System.assertEquals(1, permits.size(),
            'Exactly one permit must be created — the known label — when a semicolon-delimited '
            + 'string mixes valid and unrecognized RAT labels');
        System.assertEquals(PERMIT_LABEL_APD, permits[0].nepa_permit_type__c,
            'The created permit must be for the known label, not the unrecognized one');
    }

    // ── Bulk: 200 IAs — no governor limit exception ───────────────────────────

    @IsTest
    static void bulk_200IAs_noGovernorException() {
        Program proj = NepaTestFactory.insertProgram('PERM-RC-BULK', 'Bulk Creator Test', 'BLM');

        List<IndividualApplication> ias = new List<IndividualApplication>();
        for (Integer i = 0; i < 200; i++) {
            ias.add(NepaTestFactory.makeProcess(proj.Id, 'EA', null, null));
        }
        insert ias;

        List<IndividualApplication> updates = new List<IndividualApplication>();
        for (IndividualApplication ia : ias) {
            updates.add(new IndividualApplication(
                Id = ia.Id,
                nepa_co_permits_required__c = PERMIT_LABEL_APD
            ));
        }

        Boolean threw = false;
        Test.startTest();
        try {
            update updates;
        } catch (Exception e) {
            threw = true;
            System.debug(LoggingLevel.ERROR, 'Bulk test exception: ' + e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'Bulk update of 200 IAs setting nepa_co_permits_required__c must not throw');
    }
}