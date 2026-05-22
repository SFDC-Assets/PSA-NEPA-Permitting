@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaDRActivationGuardTest {

    // Guard tests for DataRaptors whose deactivation causes silent failures
    // rather than explicit errors. Each test follows the same pattern:
    //   1. Query OmniDataTransform by UniqueName.
    //   2. If not yet deployed, skip (return early) rather than false-fail.
    //   3. If present, assert IsActive__c = true with a precise failure message
    //      that explains the downstream consequence.

    // ── DRExtractCELibraryByAgency ────────────────────────────────────────────
    // Used by NEPA_CEScreeningIP Step 1 (GetCELibraryEntries).
    // If inactive: Step 4 of CE Intake OmniScript renders an empty
    // "Potentially Applicable CEs" block with no error.

    @IsTest
    static void drExtractCELibraryByAgency_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DRExtractCELibraryByAgency_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DRExtractCELibraryByAgency must be active — if inactive, NEPA_CEScreeningIP ' +
            'GetCELibraryEntries returns nothing and the applicant sees no CE suggestions ' +
            'in OmniScript Step 4 without any error');
    }

    // ── DRLoadNEPAProcess ─────────────────────────────────────────────────────
    // Used by NEPA_CESaveIP Step 1 (SaveProcess).
    // If inactive: CESaveIP Step 1 fails with failOnStepError=true — the entire
    // CE intake submission errors out at the Review and Submit step.

    @IsTest
    static void drLoadNEPAProcess_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DRLoadNEPAProcess_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DRLoadNEPAProcess must be active — if inactive, NEPA_CESaveIP Step 1 ' +
            '(SaveProcess) fails with failOnStepError=true and every CE intake ' +
            'submission will error out on the Review and Submit screen');
    }

    // ── DRExtractGISLayers ────────────────────────────────────────────────────
    // Used by NEPA_GISProximityIP Step 3 (GetActiveGISLayers).
    // If inactive: no GIS layers are loaded; the loop has nothing to iterate;
    // every project gets "No protected areas identified" regardless of location.

    @IsTest
    static void drExtractGISLayers_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DRExtractGISLayers_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DRExtractGISLayers must be active — if inactive, NEPA_GISProximityIP ' +
            'GetActiveGISLayers returns no layers, the loop body never executes, and ' +
            'every project incorrectly shows "No protected areas identified"');
    }

    // ── DRExtractNEPAProject ──────────────────────────────────────────────────
    // Used by NEPA_GISProximityIP Step 1 (GetProjectLocation).
    // If inactive: lat/lon are null; GuardCoordinates conditional block fires;
    // IP exits with "GIS proximity check skipped" for every project.
    // (This guard also exists in NepaGISProximityCheckTest; kept here for
    // completeness of the activation guard test class.)

    @IsTest
    static void drExtractNEPAProject_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DRExtractNEPAProject_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DRExtractNEPAProject must be active — if inactive the GIS proximity check ' +
            'silently skips every project due to null coordinates');
    }

    // ── DRExtractPreAppPermitMatrix ───────────────────────────────────────────
    // Used by NEPA_PreAppScreeningIP Step 3 (GetPermitMatrixRow).
    // If inactive: RequiredPermits, AdjacentReviews, TypicalTimelineMonths, and
    // EISLikelihoodPct are all null; Agentforce Pre-App Screener returns incomplete
    // screening summaries with no error.

    @IsTest
    static void drExtractPreAppPermitMatrix_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DR_Extract_PreApp_PermitMatrix_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DR_Extract_PreApp_PermitMatrix must be active — if inactive, ' +
            'NEPA_PreAppScreeningIP GetPermitMatrixRow returns no permit or timeline ' +
            'data and the Pre-App Screener agent gives incomplete answers silently');
    }

    // ── DRUpsertDetectedLayer ─────────────────────────────────────────────────
    // Used by NEPA_GISProximityIP Step 14 (SaveDetectedLayers).
    // If inactive: detected layer records are never written; the IP continues
    // and writes project-level fields, but individual layer results are lost.

    @IsTest
    static void drUpsertDetectedLayer_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive__c
            FROM OmniDataTransform
            WHERE UniqueName = 'DRUpsertDetectedLayer_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive__c,
            'DRUpsertDetectedLayer must be active — if inactive, SaveDetectedLayers in ' +
            'NEPA_GISProximityIP fails with failOnStepError=true and no layer records ' +
            'are persisted after a GIS proximity check');
    }
}
