/**
 * Agentforce action bridge for the NEPA Pre-Application Screener agent.
 * Invoked by the NEPA_PreApp_Screener.agent run_screening topic action
 * (target: apex://NepaPreAppScreeningController).
 *
 * Calls the NEPA_PreApp_Screening_IP Integration Procedure, which is guest-safe
 * (reads NEPA_Permit_Matrix__mdt CMT only) and returns pathway, permits, and timeline.
 *
 * Also exposes an @AuraEnabled method for direct LWC use in the osStepChartAgent
 * OmniScript override pattern (OmniscriptAssistantAgent repo).
 */
public with sharing class NepaPreAppScreeningController {

    private static final String IP_KEY = 'NEPA/PreApp_Screening_IP/English/1';

    /** Input DTO for the Agentforce @InvocableMethod. */
    public class ScreeningRequest {
        @InvocableVariable(label='NAICS Code' required=false)
        public String inp_NAICSCode;

        @InvocableVariable(label='Sector Key' required=true)
        public String inp_SectorKey;

        @InvocableVariable(label='Lead Agency Key' required=false)
        public String inp_LeadAgencyKey;

        @InvocableVariable(label='Project Description' required=false)
        public String inp_ProjectDescription;

        @InvocableVariable(label='Project State' required=false)
        public String inp_ProjectState;
    }

    /** Output DTO returned to the agent. */
    public class ScreeningResult {
        @InvocableVariable(label='Review Type')
        public String out_ReviewType;

        @InvocableVariable(label='CE Code')
        public String out_CECode;

        @InvocableVariable(label='Confidence')
        public String out_Confidence;

        @InvocableVariable(label='Classification Basis')
        public String out_ClassificationBasis;

        @InvocableVariable(label='Required Permits')
        public String out_RequiredPermits;

        @InvocableVariable(label='Adjacent Reviews')
        public String out_AdjacentReviews;

        @InvocableVariable(label='Typical Timeline Months')
        public Decimal out_TypicalTimelineMonths;

        @InvocableVariable(label='EIS Likelihood Pct')
        public Decimal out_EISLikelihoodPct;

        @InvocableVariable(label='Screening Complete')
        public Boolean out_ScreeningComplete;

        @InvocableVariable(label='Error Message')
        public String out_ErrorMessage;
    }

    /**
     * Agentforce action target: invoke NEPA_PreApp_Screening_IP for the given
     * project inputs and return structured screening results.
     */
    @InvocableMethod(
        label='Run NEPA Pre-Application Screening'
        description='Calls the NEPA_PreApp_Screening_IP Integration Procedure to return CE/EA/EIS pathway, required permits, and typical timeline for the given sector and NAICS code.'
        callout=false
    )
    public static List<ScreeningResult> runScreening(List<ScreeningRequest> requests) {
        List<ScreeningResult> results = new List<ScreeningResult>();
        for (ScreeningRequest req : requests) {
            results.add(invokeIP(req));
        }
        return results;
    }

    /**
     * AuraEnabled entry for the osStepChartAgent LWC override pattern.
     * Accepts the same inputs as the invocable method and returns one result.
     */
    @AuraEnabled(cacheable=false)
    public static ScreeningResult runScreeningFromLWC(
        String naicsCode,
        String sectorKey,
        String leadAgencyKey,
        String projectDescription,
        String projectState
    ) {
        ScreeningRequest req = new ScreeningRequest();
        req.inp_NAICSCode         = naicsCode;
        req.inp_SectorKey         = sectorKey;
        req.inp_LeadAgencyKey     = leadAgencyKey;
        req.inp_ProjectDescription = projectDescription;
        req.inp_ProjectState      = projectState;
        return invokeIP(req);
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static ScreeningResult invokeIP(ScreeningRequest req) {
        ScreeningResult res = new ScreeningResult();
        res.out_ScreeningComplete = false;

        if (String.isBlank(req.inp_SectorKey)) {
            res.out_ErrorMessage = 'inp_SectorKey is required';
            return res;
        }

        try {
            Map<String, Object> inputMap = new Map<String, Object>{
                'NAICSCode'          => String.isBlank(req.inp_NAICSCode) ? '' : req.inp_NAICSCode,
                'SectorKey'          => req.inp_SectorKey,
                'LeadAgencyKey'      => String.isBlank(req.inp_LeadAgencyKey) ? '' : req.inp_LeadAgencyKey,
                'ProjectDescription' => String.isBlank(req.inp_ProjectDescription) ? '' : req.inp_ProjectDescription,
                'ProjectState'       => String.isBlank(req.inp_ProjectState) ? '' : req.inp_ProjectState
            };
            Map<String, Object> outputMap = new Map<String, Object>();
            Map<String, Object> options   = new Map<String, Object>();

            omnistudio.IntegrationProcedureService svc =
                new omnistudio.IntegrationProcedureService();
            svc.invokeMethod(IP_KEY, inputMap, outputMap, options);

            res.out_ReviewType           = (String)  outputMap.get('ReviewType');
            res.out_CECode               = (String)  outputMap.get('CECode');
            res.out_Confidence           = (String)  outputMap.get('Confidence');
            res.out_ClassificationBasis  = (String)  outputMap.get('ClassificationBasis');
            res.out_RequiredPermits      = (String)  outputMap.get('RequiredPermits');
            res.out_AdjacentReviews      = (String)  outputMap.get('AdjacentReviews');
            res.out_TypicalTimelineMonths = outputMap.containsKey('TypicalTimelineMonths')
                ? Decimal.valueOf(String.valueOf(outputMap.get('TypicalTimelineMonths')))
                : 0;
            res.out_EISLikelihoodPct = outputMap.containsKey('EISLikelihoodPct')
                ? Decimal.valueOf(String.valueOf(outputMap.get('EISLikelihoodPct')))
                : 0;
            res.out_ScreeningComplete = true;

        } catch (Exception ex) {
            res.out_ErrorMessage = ex.getMessage();
        }
        return res;
    }
}