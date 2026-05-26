/**
 * After-insert trigger handler for Visit. For each auto-generated NEPA Visit,
 * looks up the NEPA_Layer_Discipline__mdt record matching nepa_discipline__c
 * and launches the configured Action Plan Template against the Visit.
 *
 * APT launch is trigger-based rather than flow-invocable to avoid the
 * platform restriction on dot-field access in Flow loops.
 */
public with sharing class NepaVisitActionPlanLauncher {

    public static void createActionPlans(List<Visit> visits) {
        // Filter to auto-generated NEPA visits that have a discipline set
        List<Visit> nepaVisits = new List<Visit>();
        Set<String> disciplines = new Set<String>();
        for (Visit v : visits) {
            if (v.nepa_auto_generated__c == true && String.isNotBlank(v.nepa_discipline__c)) {
                nepaVisits.add(v);
                disciplines.add(v.nepa_discipline__c);
            }
        }
        if (nepaVisits.isEmpty()) { return; }

        // Map discipline → APT developer name via CMT
        Map<String, String> disciplineToAptName = new Map<String, String>();
        for (NEPA_Layer_Discipline__mdt cmt : [ //NOPMD
            SELECT Discipline__c, APT_Developer_Name__c
            FROM NEPA_Layer_Discipline__mdt
            WHERE Active__c = true
              AND Discipline__c IN :disciplines
              AND APT_Developer_Name__c != null
        ]) {
            if (!disciplineToAptName.containsKey(cmt.Discipline__c)) {
                disciplineToAptName.put(cmt.Discipline__c, cmt.APT_Developer_Name__c);
            }
        }
        if (disciplineToAptName.isEmpty()) { return; }

        // Collect APT unique names and look up active versions
        Set<String> aptNames = new Set<String>(disciplineToAptName.values());
        Map<String, Id> aptNameToVersionId = new Map<String, Id>();
        for (ActionPlanTemplate apt : [
            SELECT Id, UniqueName,
                   (SELECT Id FROM ActionPlanTemplateVersions WHERE Status = 'Final' ORDER BY Version DESC LIMIT 1)
            FROM ActionPlanTemplate
            WHERE UniqueName IN :aptNames
            WITH USER_MODE
        ]) {
            if (!apt.ActionPlanTemplateVersions.isEmpty()) {
                aptNameToVersionId.put(apt.UniqueName, apt.ActionPlanTemplateVersions[0].Id);
            }
        }
        if (aptNameToVersionId.isEmpty()) { return; }

        // Build ActionPlan records — one per Visit
        List<ActionPlan> plans = new List<ActionPlan>();
        for (Visit v : nepaVisits) {
            String aptName = disciplineToAptName.get(v.nepa_discipline__c);
            if (aptName == null) { continue; }
            Id versionId = aptNameToVersionId.get(aptName);
            if (versionId == null) { continue; }

            ActionPlan ap = new ActionPlan();
            ap.Name                        = v.nepa_discipline__c + ' Field Survey Milestones';
            ap.ActionPlanTemplateVersionId = versionId;
            ap.TargetId                    = v.Id;
            ap.StartDate                   = v.PlannedVisitStartTime != null
                                             ? v.PlannedVisitStartTime.date()
                                             : Date.today();
            plans.add(ap);
        }

        if (!plans.isEmpty()) {
            insert as user plans;
        }
    }
}
