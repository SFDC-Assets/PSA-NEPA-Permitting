@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaPermitMatrixCmtTest {

    // OmniScript Step 2 nepa_project_sector__c picklist values.
    // PreAppScreeningIP GetPermitMatrixRow queries NEPA_Permit_Matrix__mdt by Sector__c.
    // If a sector has no row, the IP returns nulls for RequiredPermits,
    // TypicalTimelineMonths, and EISLikelihoodPct with no error or warning.
    // Sector__c values as stored in NEPA_Permit_Matrix__mdt records.
    // These must match the exact CMT field values, not the UI picklist display labels.
    private static final List<String> OMNISCRIPT_SECTORS = new List<String>{
        'Energy Production and Management',
        'Agriculture and Natural Resource Management',
        'Transportation and Infrastructure',
        'Materials and Manufacturing',
        'Water and Waste Management'
    };

    // ── Per-sector row existence ──────────────────────────────────────────────

    @IsTest
    static void energy_hasAtLeastOneActivePermitMatrixRow() {
        assertActiveRowExistsForSector('Energy Production and Management');
    }

    @IsTest
    static void agriculture_hasAtLeastOneActivePermitMatrixRow() {
        assertActiveRowExistsForSector('Agriculture and Natural Resource Management');
    }

    @IsTest
    static void infrastructure_hasAtLeastOneActivePermitMatrixRow() {
        assertActiveRowExistsForSector('Transportation and Infrastructure');
    }

    @IsTest
    static void mining_hasAtLeastOneActivePermitMatrixRow() {
        assertActiveRowExistsForSector('Materials and Manufacturing');
    }

    @IsTest
    static void water_hasAtLeastOneActivePermitMatrixRow() {
        assertActiveRowExistsForSector('Water and Waste Management');
    }

    // ── Cross-sector sweep ────────────────────────────────────────────────────

    @IsTest
    static void allOmniScriptSectors_haveActivePermitMatrixRows() {
        List<NEPA_Permit_Matrix__mdt> rows = [
            SELECT Sector__c
            FROM NEPA_Permit_Matrix__mdt
            WHERE Active__c = true
            AND Sector__c IN :OMNISCRIPT_SECTORS
        ];

        Set<String> coveredSectors = new Set<String>();
        for (NEPA_Permit_Matrix__mdt r : rows) {
            coveredSectors.add(r.Sector__c);
        }

        for (String sector : OMNISCRIPT_SECTORS) {
            System.assert(coveredSectors.contains(sector),
                'Permit Matrix has no active rows for sector "' + sector + '" — ' +
                'PreAppScreeningIP will return null for RequiredPermits, ' +
                'TypicalTimelineMonths, and EISLikelihoodPct for this sector');
        }
    }

    // ── Row quality: numeric fields must be positive ─────────────────────────

    @IsTest
    static void activePermitMatrixRows_havePositiveTimeline() {
        List<NEPA_Permit_Matrix__mdt> rows = [
            SELECT DeveloperName, Sector__c, Typical_Timeline_Months__c
            FROM NEPA_Permit_Matrix__mdt
            WHERE Active__c = true
            AND Sector__c IN :OMNISCRIPT_SECTORS
        ];

        System.assert(!rows.isEmpty(),
            'At least one active Permit Matrix row must exist for OmniScript sectors');

        for (NEPA_Permit_Matrix__mdt r : rows) {
            System.assertNotEquals(null, r.Typical_Timeline_Months__c,
                r.DeveloperName + ': Typical_Timeline_Months__c must not be null');
            System.assert(r.Typical_Timeline_Months__c > 0,
                r.DeveloperName + ': Typical_Timeline_Months__c must be > 0; got: '
                    + r.Typical_Timeline_Months__c);
        }
    }

    @IsTest
    static void activePermitMatrixRows_haveEISLikelihoodInRange() {
        List<NEPA_Permit_Matrix__mdt> rows = [
            SELECT DeveloperName, Sector__c, EIS_Likelihood_Pct__c
            FROM NEPA_Permit_Matrix__mdt
            WHERE Active__c = true
            AND Sector__c IN :OMNISCRIPT_SECTORS
        ];

        for (NEPA_Permit_Matrix__mdt r : rows) {
            System.assertNotEquals(null, r.EIS_Likelihood_Pct__c,
                r.DeveloperName + ': EIS_Likelihood_Pct__c must not be null');
            System.assert(r.EIS_Likelihood_Pct__c >= 0 && r.EIS_Likelihood_Pct__c <= 100,
                r.DeveloperName + ': EIS_Likelihood_Pct__c must be 0–100; got: '
                    + r.EIS_Likelihood_Pct__c);
        }
    }

    @IsTest
    static void activePermitMatrixRows_haveRequiredPermitsText() {
        List<NEPA_Permit_Matrix__mdt> rows = [
            SELECT DeveloperName, Sector__c, Required_Permits__c
            FROM NEPA_Permit_Matrix__mdt
            WHERE Active__c = true
            AND Sector__c IN :OMNISCRIPT_SECTORS
        ];

        for (NEPA_Permit_Matrix__mdt r : rows) {
            System.assert(String.isNotBlank(r.Required_Permits__c),
                r.DeveloperName + ': Required_Permits__c must not be blank — ' +
                'this is returned to the Agentforce Pre-App Screener as RequiredPermits');
        }
    }

    // ── Lead_Agency_Key integrity ─────────────────────────────────────────────

    @IsTest
    static void activePermitMatrixRows_haveLeadAgencyKey() {
        List<NEPA_Permit_Matrix__mdt> rows = [
            SELECT DeveloperName, Lead_Agency_Key__c
            FROM NEPA_Permit_Matrix__mdt
            WHERE Active__c = true
            AND Sector__c IN :OMNISCRIPT_SECTORS
        ];

        for (NEPA_Permit_Matrix__mdt r : rows) {
            System.assert(String.isNotBlank(r.Lead_Agency_Key__c),
                r.DeveloperName + ': Lead_Agency_Key__c must not be blank — ' +
                'used by PreAppScreeningIP BuildScreeningResponse as LeadAgency output');
        }
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static void assertActiveRowExistsForSector(String sector) {
        List<NEPA_Permit_Matrix__mdt> rows = [
            SELECT Id FROM NEPA_Permit_Matrix__mdt
            WHERE Active__c = true AND Sector__c = :sector
            LIMIT 1
        ];
        System.assert(!rows.isEmpty(),
            'Permit Matrix must have at least one active row for sector "' + sector + '"');
    }
}
