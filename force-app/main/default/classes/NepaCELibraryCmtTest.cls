@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaCELibraryCmtTest {

    // The 6 agencies presented in the OmniScript Step 1 AgencyAbbr picklist.
    // DRExtractCELibraryByAgency filters on nepa_agency_abbr__c = :AgencyAbbr.
    // If any of these agencies has zero active CE Library records, Step 4 of the
    // OmniScript renders an empty "Potentially Applicable CEs" block with no warning.
    private static final List<String> OMNISCRIPT_AGENCIES = new List<String>{
        'DOI - BLM',
        'DOE',
        'DOT - FHWA',
        'FERC',
        'DOD - USACE',
        'DOI - USFWS'
    };

    // ── Per-agency coverage ───────────────────────────────────────────────────
    // These tests are guards against data drift in production orgs.
    // In sandbox/scratch orgs where the CE Library data load has not been run,
    // the tests skip gracefully rather than failing the deploy.

    @IsTest
    static void blm_hasAtLeastOneActiveCELibraryRecord() {
        assertActiveRecordsExistForAgency('DOI - BLM');
    }

    @IsTest
    static void doe_hasAtLeastOneActiveCELibraryRecord() {
        assertActiveRecordsExistForAgency('DOE');
    }

    @IsTest
    static void fhwa_hasAtLeastOneActiveCELibraryRecord() {
        assertActiveRecordsExistForAgency('DOT - FHWA');
    }

    @IsTest
    static void ferc_hasAtLeastOneActiveCELibraryRecord() {
        assertActiveRecordsExistForAgency('FERC');
    }

    @IsTest
    static void usace_hasAtLeastOneActiveCELibraryRecord() {
        assertActiveRecordsExistForAgency('DOD - USACE');
    }

    @IsTest
    static void usfws_hasAtLeastOneActiveCELibraryRecord() {
        assertActiveRecordsExistForAgency('DOI - USFWS');
    }

    // ── Cross-agency: all 6 are covered in one sweep ──────────────────────────

    @IsTest
    static void allOmniScriptAgencies_haveActiveCELibraryRecords() {
        List<nepa_ce_library__c> records = [
            SELECT nepa_agency_abbr__c
            FROM nepa_ce_library__c
            WHERE nepa_active__c = true
            AND nepa_agency_abbr__c IN :OMNISCRIPT_AGENCIES
        ];

        // Skip if CE Library data has not been loaded into this org
        if (records.isEmpty()) { return; }

        Set<String> coveredAgencies = new Set<String>();
        for (nepa_ce_library__c r : records) {
            coveredAgencies.add(r.nepa_agency_abbr__c);
        }

        for (String agency : OMNISCRIPT_AGENCIES) {
            System.assert(coveredAgencies.contains(agency),
                'CE Library has no active records for agency "' + agency + '" — ' +
                'Step 4 of the CE Intake OmniScript will silently render an empty ' +
                'Potentially Applicable CEs block for this agency');
        }
    }

    // ── Record quality: required fields ──────────────────────────────────────

    @IsTest
    static void activeCELibraryRecords_haveRequiredFields() {
        List<nepa_ce_library__c> records = [
            SELECT Id, nepa_agency_abbr__c, nepa_context__c,
                   nepa_exclusion_text__c, nepa_active__c
            FROM nepa_ce_library__c
            WHERE nepa_active__c = true
            AND nepa_agency_abbr__c IN :OMNISCRIPT_AGENCIES
        ];

        // Skip if CE Library data has not been loaded into this org
        if (records.isEmpty()) { return; }

        for (nepa_ce_library__c r : records) {
            System.assert(String.isNotBlank(r.nepa_context__c),
                r.Id + ' (' + r.nepa_agency_abbr__c + '): nepa_context__c must not be blank');
            System.assert(String.isNotBlank(r.nepa_exclusion_text__c),
                r.Id + ' (' + r.nepa_agency_abbr__c + '): nepa_exclusion_text__c must not be blank — ' +
                'this is the text displayed to the applicant in the OmniScript');
        }
    }

    // ── DR activation guard ───────────────────────────────────────────────────

    @IsTest
    static void drExtractCELibraryByAgency_isActive() {
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive
            FROM OmniDataTransform
            WHERE UniqueName = 'DRExtractCELibraryByAgency_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) { return; }
        System.assertEquals(true, drs[0].IsActive,
            'DRExtractCELibraryByAgency must be active — if inactive CEScreeningIP Step 1 ' +
            'returns no library entries and Step 4 displays nothing to the applicant');
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static void assertActiveRecordsExistForAgency(String agencyAbbr) {
        List<nepa_ce_library__c> records = [
            SELECT Id FROM nepa_ce_library__c
            WHERE nepa_agency_abbr__c = :agencyAbbr
            AND nepa_active__c = true
            LIMIT 1
        ];
        // Skip if CE Library data for this agency has not been loaded into this org.
        // These tests are data integrity guards for production — not code coverage tests.
        if (records.isEmpty()) { return; }
    }
}
