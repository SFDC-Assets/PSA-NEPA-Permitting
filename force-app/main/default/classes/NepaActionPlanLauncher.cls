public with sharing class NepaActionPlanLauncher {

    public class LaunchRequest {
        @InvocableVariable(label='Record Id' description='WorkOrder.Id to attach the Action Plan to' required=true)
        public String recordId;

        @InvocableVariable(label='APT Developer Name' description='ActionPlanTemplate.UniqueName to launch' required=true)
        public String aptDeveloperName;
    }

    public class LaunchResult {
        @InvocableVariable(label='Action Plan Id' description='Id of the created ActionPlan record, if successful')
        public String actionPlanId;

        @InvocableVariable(label='Error Message' description='Non-null when launch failed; checked by calling flow')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Launch Action Plan Template'
        description='Launches a named Action Plan Template against a WorkOrder record. Called by NEPA_WO_Milestone_Setter.'
        callout=false
    )
    public static List<LaunchResult> launch(List<LaunchRequest> requests) {
        List<LaunchResult> results = new List<LaunchResult>();
        for (LaunchRequest req : requests) {
            LaunchResult res = new LaunchResult();
            try {
                res.actionPlanId = launchTemplate(req.recordId, req.aptDeveloperName);
            } catch (Exception ex) {
                res.errorMessage = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    private static String launchTemplate(String recordId, String aptDeveloperName) {
        // Find the template by UniqueName
        List<ActionPlanTemplate> templates = [
            SELECT Id, Name
            FROM ActionPlanTemplate
            WHERE UniqueName = :aptDeveloperName
            WITH USER_MODE
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            throw new AuraHandledException('ActionPlanTemplate not found: ' + aptDeveloperName);
        }

        // Find the active published version
        List<ActionPlanTemplateVersion> versions = [
            SELECT Id
            FROM ActionPlanTemplateVersion
            WHERE ActionPlanTemplateId = :templates[0].Id
                AND Status = 'Active'
            WITH USER_MODE
            ORDER BY Version DESC
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw new AuraHandledException(
                'No active ActionPlanTemplateVersion found for: ' + aptDeveloperName
            );
        }

        ActionPlan ap = new ActionPlan();
        ap.Name                         = templates[0].Name;
        ap.ActionPlanTemplateVersionId  = versions[0].Id;
        ap.TargetId                     = recordId;
        ap.StartDate                    = Date.today();
        insert as user ap;

        return ap.Id;
    }
}
