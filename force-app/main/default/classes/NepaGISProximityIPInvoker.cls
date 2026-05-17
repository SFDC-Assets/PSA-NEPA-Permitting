/**
 * Invocable bridge: calls the NEPA_GISProximityIP OmniStudio Integration Procedure from Flow.
 * Required because Flow <subflows> resolves only Flow records; OmniIntegrationProcedures
 * are OmniProcess records and cannot be referenced via <subflows>.
 */
public with sharing class NepaGISProximityIPInvoker {

    /** Input variables for the invocable method. */
    public class InvokerRequest {
        @InvocableVariable(label='Project Id' required=true)
        public String projectId;
    }

    /** Output variables from the invocable method. */
    public class InvokerResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    /**
     * Invokes the GIS Proximity Integration Procedure for each project request.
     * @param requests List of InvokerRequest with projectId
     * @return List of InvokerResult with success flag and errorMessage per request
     */
    @InvocableMethod(
        label='Invoke GIS Proximity Integration Procedure'
        description='Calls NEPA_GISProximityIP OmniStudio IP asynchronously with the given projectId.'
        callout=true
    )
    public static List<InvokerResult> invoke(List<InvokerRequest> requests) {
        List<InvokerResult> results = new List<InvokerResult>();
        for (InvokerRequest req : requests) {
            InvokerResult res = new InvokerResult();
            try {
                Map<String, Object> inputMap = new Map<String, Object>{
                    'projectId' => req.projectId
                };
                Map<String, Object> outputMap = new Map<String, Object>();
                Map<String, Object> options  = new Map<String, Object>();
                omnistudio.IntegrationProcedureService svc =
                    new omnistudio.IntegrationProcedureService();
                Object ipResult = svc.invokeMethod(
                    'runIntegrationService',
                    inputMap,
                    outputMap,
                    options
                );
                res.success      = ipResult != null;
                res.errorMessage = null;
            } catch (Exception ex) {
                res.success      = false;
                res.errorMessage = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}
