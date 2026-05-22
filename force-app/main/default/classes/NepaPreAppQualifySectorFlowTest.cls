@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.MethodNamingConventions')
@IsTest(SeeAllData=false)
/**
 * Tests for NEPA_PreApp_Qualify_Sector autolaunched flow.
 * Uses Flow.Interview.createInterview — requires the flow to be deployed and Active.
 *
 * Coverage requirements (F-03 Pre-Application AI Screening):
 *   - Valid sector + NAICS returns ValidationPassed=true, SectorKey non-blank, LeadAgencyKey non-blank
 *   - Blank sector and NAICS returns ValidationPassed=false with guidance message
 *   - Unrecognized sector (no CMT row) returns ValidationPassed=false
 *   - NAICSCode is normalized and passed through to out_NAICSCode
 */
private class NepaPreAppQualifySectorFlowTest {

    private static Map<String, Object> buildInputs(String naics, String sector, String description, String state) {
        return new Map<String, Object>{
            'inp_NAICSCode'          => naics,
            'inp_Sector'             => sector,
            'inp_ProjectDescription' => description,
            'inp_ProjectState'       => state
        };
    }

    // ── Happy paths ───────────────────────────────────────────────────────────

    @IsTest
    static void validEnergySector_returnsSectorKeyAndAgency() {
        Map<String, Object> inputs = buildInputs('211120', 'Energy Production and Management',
            'Oil and gas exploration on federal land', 'WY');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_PreApp_Qualify_Sector', inputs);
        interview.start();
        Test.stopTest();

        Boolean passed      = (Boolean) interview.getVariableValue('out_ValidationPassed');
        String  sectorKey   = (String)  interview.getVariableValue('out_SectorKey');
        String  agencyKey   = (String)  interview.getVariableValue('out_LeadAgencyKey');
        String  naicsOut    = (String)  interview.getVariableValue('out_NAICSCode');

        System.assertEquals(true, passed,
            'out_ValidationPassed must be true for a recognized sector with a Permit Matrix row');
        System.assert(String.isNotBlank(sectorKey),
            'out_SectorKey must be non-blank for Energy sector');
        System.assert(String.isNotBlank(agencyKey),
            'out_LeadAgencyKey must be non-blank — used by NepaPreAppScreeningController');
        System.assertEquals('211120', naicsOut,
            'out_NAICSCode must pass through the input NAICS code');
    }

    @IsTest
    static void validWaterSector_returnsSectorKeyAndAgency() {
        Map<String, Object> inputs = buildInputs('221310', 'Water',
            'Water treatment facility expansion', 'CO');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_PreApp_Qualify_Sector', inputs);
        interview.start();
        Test.stopTest();

        Boolean passed    = (Boolean) interview.getVariableValue('out_ValidationPassed');
        String  sectorKey = (String)  interview.getVariableValue('out_SectorKey');

        System.assertEquals(true, passed,
            'out_ValidationPassed must be true for Water sector with a Permit Matrix row');
        System.assert(String.isNotBlank(sectorKey),
            'out_SectorKey must be non-blank for Water sector');
    }

    @IsTest
    static void validMiningSector_returnsSectorKeyAndAgency() {
        Map<String, Object> inputs = buildInputs('212210', 'Mining',
            'Open pit copper mine expansion on BLM land', 'NV');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_PreApp_Qualify_Sector', inputs);
        interview.start();
        Test.stopTest();

        Boolean passed = (Boolean) interview.getVariableValue('out_ValidationPassed');
        System.assertEquals(true, passed,
            'out_ValidationPassed must be true for Mining sector');
    }

    // ── Validation failure paths ──────────────────────────────────────────────

    @IsTest
    static void blankSectorAndNAICS_returnsValidationFailureWithMessage() {
        Map<String, Object> inputs = buildInputs('', '', 'Some project description', 'CA');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_PreApp_Qualify_Sector', inputs);
        interview.start();
        Test.stopTest();

        Boolean passed  = (Boolean) interview.getVariableValue('out_ValidationPassed');
        String  message = (String)  interview.getVariableValue('out_ValidationMessage');

        System.assertEquals(false, passed,
            'out_ValidationPassed must be false when both sector and NAICS are blank');
        System.assert(String.isNotBlank(message),
            'out_ValidationMessage must provide guidance when no sector is given');
    }

    @IsTest
    static void unrecognizedSector_noPermitMatrixRow_returnsValidationFailure() {
        // This sector exists in no NEPA_Permit_Matrix__mdt row
        Map<String, Object> inputs = buildInputs('999999', 'Fictional Unicorn Industry',
            'Building a unicorn stable on federal land', 'CA');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_PreApp_Qualify_Sector', inputs);
        interview.start();
        Test.stopTest();

        Boolean passed  = (Boolean) interview.getVariableValue('out_ValidationPassed');
        String  message = (String)  interview.getVariableValue('out_ValidationMessage');

        System.assertEquals(false, passed,
            'out_ValidationPassed must be false when no Permit Matrix row matches the sector');
        System.assert(String.isNotBlank(message),
            'out_ValidationMessage must explain the no-match result');
    }

    @IsTest
    static void blankNAICS_withValidSector_stillPasses() {
        // NAICS is optional — sector alone is sufficient for screening
        Map<String, Object> inputs = buildInputs('', 'Agriculture and Natural',
            'Livestock grazing on federal rangeland', 'MT');

        Test.startTest();
        Flow.Interview interview = Flow.Interview.createInterview('NEPA_PreApp_Qualify_Sector', inputs);
        interview.start();
        Test.stopTest();

        Boolean passed = (Boolean) interview.getVariableValue('out_ValidationPassed');
        System.assertEquals(true, passed,
            'Sector alone is sufficient — NAICS is optional for qualification');
    }
}
