/**
 * Invocable Apex called by NEPA_WO_Milestone_Setter to launch an Action Plan
 * Template against a newly created auto-generated Work Order.
 *
 * Flow passes: recordId (WorkOrder.Id), aptDeveloperName (ActionPlanTemplate.uniqueName).
 * Uses ConnectApi.ActionPlan.createActionPlan if available; falls back to DML
 * insertion of ActionPlan + ActionPlanItem for orgs without full FSL Action Plan
 * entitlement.
 *
 * Declared with @InvocableMethod so Flow can call it as an Apex Action element.
 */
public with sharing class NepaActionPlanLauncher {

    public class LaunchRequest {
        @InvocableVariable(label='Record Id' description='WorkOrder.Id to attach the Action Plan to' required=true)
        public String recordId;

        @InvocableVariable(label='APT Developer Name' description='ActionPlanTemplate.uniqueName to launch' required=true)
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
        List<ActionPlanTemplate> templates = [
            SELECT Id, Name, TargetEntityType
            FROM ActionPlanTemplate
            WHERE UniqueName = :aptDeveloperName
                AND IsActive = true
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            throw new AuraHandledException(
                'ActionPlanTemplate not found or inactive: ' + aptDeveloperName
            );
        }

        ActionPlanTemplate apt = templates[0];

        List<ActionPlanTemplateItem> items = [
            SELECT Id, DisplayOrder, IsRequired, Name, ItemEntityType,
                   ActionPlanTemplateId
            FROM ActionPlanTemplateItem
            WHERE ActionPlanTemplateId = :apt.Id
            ORDER BY DisplayOrder ASC
        ];

        ActionPlan ap = new ActionPlan();
        ap.Name                  = apt.Name;
        ap.ActionPlanTemplateId  = apt.Id;
        ap.TargetId              = recordId;
        ap.StartDate             = Date.today();
        insert ap;

        if (!items.isEmpty()) {
            List<ActionPlanItem> apItems = new List<ActionPlanItem>();
            for (ActionPlanTemplateItem ti : items) {
                ActionPlanItem api = new ActionPlanItem();
                api.ActionPlanId            = ap.Id;
                api.ActionPlanTemplateItemId = ti.Id;
                api.IsRequired              = ti.IsRequired;
                api.DisplayOrder            = ti.DisplayOrder;
                api.ItemEntityType          = ti.ItemEntityType;
                apItems.add(api);
            }
            insert apItems;
        }

        return ap.Id;
    }
}
