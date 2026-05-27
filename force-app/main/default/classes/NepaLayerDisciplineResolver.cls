/**
 * Invocable action for NEPA_Team_Assembly_Orchestrator.
 * Performs all CMT-to-hit-layer matching, ServiceResource lookup, team member
 * creation, and Visit creation in a single Apex transaction — avoiding the
 * platform restriction that rejects dot-field access on SObject collection
 * variables (outputReference or storeOutputAutomatically) inside Flow loops.
 *
 * The Flow handles deactivation/cancellation via filter-based recordUpdates,
 * then calls this action once per program to assemble the team and create Visits.
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.NcssMethodCount')
public with sharing class NepaLayerDisciplineResolver {

    /** Input variables for the invocable method. */
    public class Request {
        @InvocableVariable(label='Program Id' required=true)
        public Id programId;
        @InvocableVariable(label='Related App Id' required=true)
        public Id relatedAppId;
        @InvocableVariable(label='Account Id' required=false)
        public String accountId;
    }

    /** Output variables from the invocable method. */
    public class Result {
        @InvocableVariable(label='Team Members Created')
        public Integer teamMembersCreated;
        @InvocableVariable(label='Visits Created')
        public Integer visitsCreated;
        @InvocableVariable(label='Any Hits Found')
        public Boolean anyHitsFound;
        @InvocableVariable(label='Unmatched Disciplines')
        public String unmatchedDisciplines;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Assemble NEPA Team and Create Visits'
        description='Matches active NEPA_Layer_Discipline__mdt records against detected GIS hits for a Program, finds ServiceResources by discipline, and bulk-inserts nepa_process_team_member__c and Visit records.'
        category='NEPA'
    )
    public static List<Result> assemble(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(assembleOne(req));
        }
        return results;
    }

    @SuppressWarnings('PMD.NcssCount,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
    private static Result assembleOne(Request req) {
        Result res = new Result();
        res.teamMembersCreated = 0;
        res.visitsCreated = 0;
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

            for (NEPA_Layer_Discipline__mdt cmt : [ //NOPMD — CMT is always readable; SECURITY_ENFORCED not applicable
                SELECT GIS_Layer_Developer_Name__c, Discipline__c,
                       Work_Type_Developer_Name__c, WO_Subject_Template__c,
                       WO_Description_Template__c, WO_Duration_Minutes__c,
                       WO_Priority__c, APT_Developer_Name__c
                FROM NEPA_Layer_Discipline__mdt
                WHERE Active__c = true
                ORDER BY Sort_Order__c ASC NULLS LAST
            ]) {
                if (!layerDevNameToId.containsKey(cmt.GIS_Layer_Developer_Name__c)) { continue; }
                if (seenDisciplines.contains(cmt.Discipline__c)) { continue; }
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

            // 4. Look up WorkTypes by External_ID__c (used as VisitType)
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

            // 5. Build team members and visits
            List<nepa_process_team_member__c> newMembers = new List<nepa_process_team_member__c>();
            List<Visit> newVisits = new List<Visit>();
            List<String> unmatched = new List<String>();

            // Determine visit priority label
            Map<String, String> disciplineToWTPriority = new Map<String, String>();
            if (!workTypeDeveloperNames.isEmpty()) {
                for (WorkType wt : [
                    SELECT Id, External_ID__c
                    FROM WorkType
                    WHERE External_ID__c IN :workTypeDeveloperNames
                    WITH SECURITY_ENFORCED
                ]) {
                    disciplineToWTPriority.put(wt.External_ID__c, null);
                }
            }

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
                        nepa_role_type__c         = 'Field Team Member',
                        nepa_assembly_source__c   = 'GIS_Auto_Assembly',
                        nepa_active__c            = true,
                        nepa_trigger_layer__c     = layerId
                    );
                    newMembers.add(member);
                }

                // Build Visit regardless of SR match — VisitorId optional
                Id workTypeId = String.isNotBlank(cmt.Work_Type_Developer_Name__c)
                                ? workTypeExtIdToId.get(cmt.Work_Type_Developer_Name__c)
                                : null;

                String visitSubject = tokenReplace(cmt.WO_Subject_Template__c, '', cmt.Discipline__c);

                Visit v = new Visit(
                    VisitTypeId            = workTypeId,
                    VisitorId              = srId,
                    ContextId              = req.relatedAppId,
                    PlaceId                = null,
                    Status                 = 'Planned',
                    VisitPriority          = mapPriority(cmt.WO_Priority__c),
                    InstructionDescription = tokenReplace(cmt.WO_Description_Template__c, '', cmt.Discipline__c),
                    nepa_process__c        = req.relatedAppId,
                    nepa_discipline__c     = cmt.Discipline__c,
                    nepa_trigger_layer__c  = layerId,
                    nepa_auto_generated__c = true
                );
                newVisits.add(v);
            }

            if (!newMembers.isEmpty()) {
                insert as user newMembers;
                res.teamMembersCreated = newMembers.size();
            }
            if (!newVisits.isEmpty()) {
                insert as user newVisits;
                res.visitsCreated = newVisits.size();
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
        if (String.isBlank(template)) { return ''; }
        return template
            .replace('{ProjectName}', projectName != null ? projectName : '')
            .replace('{LayerLabel}', layerLabel != null ? layerLabel : '');
    }

    private static String mapPriority(String woPriority) {
        if (woPriority == 'Critical') { return 'Critical'; }
        if (woPriority == 'High')     { return 'High'; }
        if (woPriority == 'Low')      { return 'Low'; }
        return 'Medium';
    }
}