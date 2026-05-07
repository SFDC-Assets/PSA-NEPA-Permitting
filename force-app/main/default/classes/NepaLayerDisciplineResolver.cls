/**
 * Invocable action for NEPA_Team_Assembly_Orchestrator.
 * Performs all CMT-to-hit-layer matching, ServiceResource lookup, team member
 * creation, and Work Order creation in a single Apex transaction — avoiding the
 * platform restriction that rejects dot-field access on SObject collection
 * variables (outputReference or storeOutputAutomatically) inside Flow loops.
 *
 * The Flow handles deactivation/cancellation via filter-based recordUpdates,
 * then calls this action once per program to assemble the team and create WOs.
 */
public with sharing class NepaLayerDisciplineResolver {

    public class Request {
        @InvocableVariable(label='Program Id' required=true)
        public Id programId;
        @InvocableVariable(label='Related App Id' required=true)
        public Id relatedAppId;
        @InvocableVariable(label='Account Id' required=false)
        public Id accountId;
    }

    public class Result {
        @InvocableVariable(label='Team Members Created')
        public Integer teamMembersCreated;
        @InvocableVariable(label='Work Orders Created')
        public Integer workOrdersCreated;
        @InvocableVariable(label='Any Hits Found')
        public Boolean anyHitsFound;
        @InvocableVariable(label='Unmatched Disciplines')
        public String unmatchedDisciplines;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Assemble NEPA Team and Create Work Orders'
        description='Matches active NEPA_Layer_Discipline__mdt records against detected GIS hits for a Program, finds ServiceResources by discipline, and bulk-inserts nepa_process_team_member__c and WorkOrder records.'
        category='NEPA'
    )
    public static List<Result> assemble(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(assembleOne(req));
        }
        return results;
    }

    private static Result assembleOne(Request req) {
        Result res = new Result();
        res.teamMembersCreated = 0;
        res.workOrdersCreated = 0;
        res.anyHitsFound = false;
        res.unmatchedDisciplines = '';

        try {
            // 1. Load hit layers for this program
            Map<String, Id> layerDevNameToId = new Map<String, Id>();
            for (nepa_detected_protection_layer__c layer : [
                SELECT Id, nepa_layer_developer_name__c
                FROM nepa_detected_protection_layer__c
                WHERE nepa_program__c = :req.programId
                  AND nepa_is_hit__c = true
                WITH SECURITY_ENFORCED
            ]) {
                layerDevNameToId.put(layer.nepa_layer_developer_name__c, layer.Id);
            }

            if (layerDevNameToId.isEmpty()) {
                res.anyHitsFound = false;
                return res;
            }
            res.anyHitsFound = true;

            // 2. Match CMT records to hits, dedupe by discipline
            List<NEPA_Layer_Discipline__mdt> matchedCMTs = new List<NEPA_Layer_Discipline__mdt>();
            Set<String> seenDisciplines = new Set<String>();
            Map<String, Id> disciplineToLayerId = new Map<String, Id>();

            for (NEPA_Layer_Discipline__mdt cmt : [
                SELECT GIS_Layer_Developer_Name__c, Discipline__c,
                       Work_Type_Developer_Name__c, WO_Subject_Template__c,
                       WO_Description_Template__c, WO_Duration_Minutes__c,
                       WO_Priority__c, APT_Developer_Name__c
                FROM NEPA_Layer_Discipline__mdt
                WHERE Active__c = true
                ORDER BY Sort_Order__c ASC NULLS LAST
            ]) {
                if (!layerDevNameToId.containsKey(cmt.GIS_Layer_Developer_Name__c)) continue;
                if (seenDisciplines.contains(cmt.Discipline__c)) continue;
                seenDisciplines.add(cmt.Discipline__c);
                disciplineToLayerId.put(cmt.Discipline__c, layerDevNameToId.get(cmt.GIS_Layer_Developer_Name__c));
                matchedCMTs.add(cmt);
            }

            if (matchedCMTs.isEmpty()) {
                return res;
            }

            // 3. Look up ServiceResources by discipline
            Set<String> disciplines = new Set<String>();
            for (NEPA_Layer_Discipline__mdt cmt : matchedCMTs) {
                disciplines.add(cmt.Discipline__c);
            }
            Map<String, Id> disciplineToSRId = new Map<String, Id>();
            for (ServiceResource sr : [
                SELECT Id, nepa_discipline__c
                FROM ServiceResource
                WHERE nepa_discipline__c IN :disciplines
                  AND IsActive = true
                WITH SECURITY_ENFORCED
            ]) {
                if (!disciplineToSRId.containsKey(sr.nepa_discipline__c)) {
                    disciplineToSRId.put(sr.nepa_discipline__c, sr.Id);
                }
            }

            // 4. Look up WorkTypes by ExternalId
            Set<String> workTypeDeveloperNames = new Set<String>();
            for (NEPA_Layer_Discipline__mdt cmt : matchedCMTs) {
                if (String.isNotBlank(cmt.Work_Type_Developer_Name__c)) {
                    workTypeDeveloperNames.add(cmt.Work_Type_Developer_Name__c);
                }
            }
            Map<String, Id> workTypeExtIdToId = new Map<String, Id>();
            if (!workTypeDeveloperNames.isEmpty()) {
                for (WorkType wt : [
                    SELECT Id, External_ID__c
                    FROM WorkType
                    WHERE External_ID__c IN :workTypeDeveloperNames
                    WITH SECURITY_ENFORCED
                ]) {
                    workTypeExtIdToId.put(wt.External_ID__c, wt.Id);
                }
            }

            // 5. Build team members and work orders
            List<nepa_process_team_member__c> newMembers = new List<nepa_process_team_member__c>();
            List<WorkOrder> newWOs = new List<WorkOrder>();
            List<String> unmatched = new List<String>();

            String programName = '';
            List<Program> programs = [SELECT Name FROM Program WHERE Id = :req.programId WITH SECURITY_ENFORCED LIMIT 1];
            if (!programs.isEmpty()) programName = programs[0].Name;

            for (NEPA_Layer_Discipline__mdt cmt : matchedCMTs) {
                Id layerId = disciplineToLayerId.get(cmt.Discipline__c);
                Id srId = disciplineToSRId.get(cmt.Discipline__c);

                if (srId == null) {
                    unmatched.add(cmt.Discipline__c);
                } else {
                    nepa_process_team_member__c member = new nepa_process_team_member__c(
                        nepa_process__c           = req.relatedAppId,
                        nepa_service_resource__c  = srId,
                        nepa_discipline__c        = cmt.Discipline__c,
                        nepa_assembly_source__c   = 'GIS_Auto_Assembly',
                        nepa_active__c            = true,
                        nepa_trigger_layer__c     = layerId
                    );
                    newMembers.add(member);
                }

                // Build WO regardless of SR match
                String woSubject = tokenReplace(cmt.WO_Subject_Template__c, programName, cmt.Discipline__c);
                String woDesc   = tokenReplace(cmt.WO_Description_Template__c, programName, cmt.Discipline__c);
                Id workTypeId   = String.isNotBlank(cmt.Work_Type_Developer_Name__c)
                                  ? workTypeExtIdToId.get(cmt.Work_Type_Developer_Name__c)
                                  : null;

                WorkOrder wo = new WorkOrder(
                    Subject                = woSubject,
                    Description            = woDesc,
                    WorkTypeId             = workTypeId,
                    AccountId              = req.accountId,
                    Duration               = cmt.WO_Duration_Minutes__c,
                    DurationType           = 'Minutes',
                    Priority               = String.isNotBlank(cmt.WO_Priority__c) ? cmt.WO_Priority__c : 'Normal',
                    Status                 = 'New',
                    nepa_process__c        = req.relatedAppId,
                    nepa_discipline__c     = cmt.Discipline__c,
                    nepa_trigger_layer__c  = layerId,
                    nepa_auto_generated__c = true
                );
                newWOs.add(wo);
            }

            if (!newMembers.isEmpty()) {
                insert as user newMembers;
                res.teamMembersCreated = newMembers.size();
            }
            if (!newWOs.isEmpty()) {
                insert as user newWOs;
                res.workOrdersCreated = newWOs.size();
            }
            if (!unmatched.isEmpty()) {
                res.unmatchedDisciplines = String.join(unmatched, '; ');
            }

        } catch (Exception e) {
            res.errorMessage = e.getTypeName() + ': ' + e.getMessage();
        }
        return res;
    }

    private static String tokenReplace(String template, String projectName, String layerLabel) {
        if (String.isBlank(template)) return '';
        return template
            .replace('{ProjectName}', projectName != null ? projectName : '')
            .replace('{LayerLabel}', layerLabel != null ? layerLabel : '');
    }
}
