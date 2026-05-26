/**
 * Apex REST service producing a full CEQ NEPA and Permitting Data and Technology
 * Standard v1.2 compliant JSON payload for a single Project (Program).
 *
 * URL:    POST /services/apexrest/nepa/v1/export/project
 * Body:   { "projectId": "<Program.Id>" }
 * Output: { "success": true, "data": { "schema_version": "1.2", "project": { ... } } }
 *
 * All SOQL queries are outside loops (bulk-safe). Max ~11 queries per request.
 * Hard limit: 500 processes per export request.
 */
@RestResource(urlMapping='/nepa/v1/export/*')
global with sharing class NepaCeqFullExportService {

    private static final Integer MAX_PROCESSES = 500;

    @HttpPost
    global static void doPost() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
                req.requestBody != null ? req.requestBody.toString() : '{}'
            );
            String projectId = (String) body.get('projectId');

            if (String.isBlank(projectId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    errorResponse('MISSING_PARAM', 'projectId is required')
                ));
                return;
            }

            Id programId;
            try {
                programId = Id.valueOf(projectId);
            } catch (Exception e) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    errorResponse('INVALID_PARAM', 'projectId is not a valid Salesforce Id')
                ));
                return;
            }

            List<Program> programs = Database.query(
                'SELECT Id, nepa_project_id__c, nepa_project_title__c, Name,'
                + ' nepa_project_description__c, nepa_project_sector__c, nepa_project_type__c,'
                + ' nepa_current_status__c, nepa_lead_agency__c, nepa_project_sponsor__c,'
                + ' nepa_funding__c, nepa_start_date__c, nepa_location__c,'
                + ' nepa_location_lat__c, nepa_location_lon__c, nepa_location_text__c,'
                + ' nepa_polygon__c, nepa_parent_project__c,'
                + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                + ' FROM Program'
                + ' WHERE Id = :programId'
                + ' LIMIT 1',
                AccessLevel.USER_MODE
            );

            if (programs.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    errorResponse('NOT_FOUND', 'No project found for id: ' + projectId)
                ));
                return;
            }

            Program proj = programs[0];

            // ── Query all child entities in bulk (no queries in loops) ─────────

            List<IndividualApplication> processes = Database.query(
                'SELECT Id, nepa_federal_unique_id__c, nepa_agency_id__c, nepa_process_code__c,'
                + ' Name, nepa_description__c, nepa_purpose_need__c, nepa_review_type__c,'
                + ' nepa_process_status__c, nepa_process_stage__c, nepa_process_outcome__c,'
                + ' nepa_related_project__c, nepa_parent_process__c, nepa_joint_lead_agency__c,'
                + ' nepa_start_date__c, nepa_completion_date__c,'
                + ' nepa_public_comment_period_start__c, nepa_public_comment_period_end_date__c,'
                + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                + ' FROM IndividualApplication'
                + ' WHERE nepa_related_project__c = :programId'
                + ' ORDER BY nepa_start_date__c ASC NULLS LAST, Id ASC'
                + ' LIMIT ' + (MAX_PROCESSES + 1),
                AccessLevel.USER_MODE
            );

            Boolean truncated = processes.size() > MAX_PROCESSES;
            if (truncated) {
                List<IndividualApplication> trimmed = new List<IndividualApplication>();
                for (Integer i = 0; i < MAX_PROCESSES; i++) {
                    trimmed.add(processes[i]);
                }
                processes = trimmed;
            }

            Set<Id> processIds = new Set<Id>();
            for (IndividualApplication ia : processes) {
                processIds.add(ia.Id);
            }

            // Documents
            List<ContentVersion> documents = new List<ContentVersion>();
            Map<Id, List<ContentVersion>> docsByProcess = new Map<Id, List<ContentVersion>>();
            Set<Id> docIds = new Set<Id>();
            if (!processIds.isEmpty()) {
                documents = Database.query(
                    'SELECT Id, Title, Description, nepa_document_type__c,'
                    + ' nepa_record_category__c, nepa_status__c, nepa_public_access__c,'
                    + ' nepa_publish_date__c, nepa_url__c, nepa_prepared_by__c,'
                    + ' nepa_contributing_agencies__c, nepa_document_summary__c,'
                    + ' nepa_document_files__c, nepa_volume_title__c, nepa_document_revision__c,'
                    + ' nepa_revision_number__c, nepa_supplement_number__c,'
                    + ' nepa_related_document__c, nepa_related_case_event__c,'
                    + ' nepa_main_document__c, nepa_process__c,'
                    + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                    + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                    + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                    + ' FROM ContentVersion'
                    + ' WHERE nepa_process__c IN :processIds AND IsLatest = true'
                    + ' ORDER BY nepa_process__c, nepa_publish_date__c ASC NULLS LAST',
                    AccessLevel.USER_MODE
                );
                for (ContentVersion cv : documents) {
                    Id pid = cv.nepa_process__c;
                    if (!docsByProcess.containsKey(pid)) {
                        docsByProcess.put(pid, new List<ContentVersion>());
                    }
                    docsByProcess.get(pid).add(cv);
                    docIds.add(cv.Id);
                }
            }

            // Comments (linked to documents via nepa_parent_document__c)
            Map<Id, List<PublicComplaint>> commentsByDoc = new Map<Id, List<PublicComplaint>>();
            if (!docIds.isEmpty()) {
                List<PublicComplaint> comments = Database.query(
                    'SELECT Id, Name, nepa_parent_document__c, nepa_organization__c,'
                    + ' nepa_category__c, nepa_date_submitted__c, Method_of_Submission__c,'
                    + ' nepa_document_location_ref__c, nepa_public_source__c,'
                    + ' nepa_agency_response__c, nepa_public_access__c,'
                    + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                    + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                    + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                    + ' FROM PublicComplaint'
                    + ' WHERE nepa_parent_document__c IN :docIds'
                    + ' ORDER BY nepa_parent_document__c, nepa_date_submitted__c ASC NULLS LAST',
                    AccessLevel.USER_MODE
                );
                for (PublicComplaint pc : comments) {
                    Id did = pc.nepa_parent_document__c;
                    if (!commentsByDoc.containsKey(did)) {
                        commentsByDoc.put(did, new List<PublicComplaint>());
                    }
                    commentsByDoc.get(did).add(pc);
                }
            }

            // Engagement events
            Map<Id, List<nepa_engagement__c>> engagementsByProcess = new Map<Id, List<nepa_engagement__c>>();
            if (!processIds.isEmpty()) {
                List<nepa_engagement__c> engagements = Database.query(
                    'SELECT Id, Name, nepa_process__c, nepa_engagement_type__c,'
                    + ' nepa_start_datetime__c, nepa_end_datetime__c, nepa_location_format__c,'
                    + ' nepa_location__c, nepa_attendance_count__c, nepa_document__c,'
                    + ' nepa_public_access__c, nepa_notes__c,'
                    + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                    + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                    + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                    + ' FROM nepa_engagement__c'
                    + ' WHERE nepa_process__c IN :processIds'
                    + ' ORDER BY nepa_process__c, nepa_start_datetime__c ASC NULLS LAST',
                    AccessLevel.USER_MODE
                );
                for (nepa_engagement__c eng : engagements) {
                    Id pid = eng.nepa_process__c;
                    if (!engagementsByProcess.containsKey(pid)) {
                        engagementsByProcess.put(pid, new List<nepa_engagement__c>());
                    }
                    engagementsByProcess.get(pid).add(eng);
                }
            }

            // Case events
            Map<Id, List<ApplicationTimeline>> caseEventsByProcess = new Map<Id, List<ApplicationTimeline>>();
            if (!processIds.isEmpty()) {
                List<ApplicationTimeline> caseEvents = Database.query(
                    'SELECT Id, Name, nepa_event_type__c, nepa_event_description__c,'
                    + ' nepa_source__c, nepa_tier__c, nepa_status__c, nepa_outcome__c,'
                    + ' nepa_assigned_entity__c, nepa_following_segment__c, nepa_public_access__c,'
                    + ' nepa_parent_case_event__c, nepa_related_engagement__c,'
                    + ' nepa_related_process__c,'
                    + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                    + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                    + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                    + ' FROM ApplicationTimeline'
                    + ' WHERE nepa_related_process__c IN :processIds'
                    + ' ORDER BY nepa_related_process__c, nepa_start_date__c ASC NULLS LAST',
                    AccessLevel.USER_MODE
                );
                for (ApplicationTimeline evt : caseEvents) {
                    Id pid = evt.nepa_related_process__c;
                    if (!caseEventsByProcess.containsKey(pid)) {
                        caseEventsByProcess.put(pid, new List<ApplicationTimeline>());
                    }
                    caseEventsByProcess.get(pid).add(evt);
                }
            }

            // Team members
            Map<Id, List<nepa_process_team_member__c>> teamByProcess = new Map<Id, List<nepa_process_team_member__c>>();
            if (!processIds.isEmpty()) {
                List<nepa_process_team_member__c> teamMembers = Database.query(
                    'SELECT Id, Name, nepa_process__c, nepa_user__c, nepa_agency__c,'
                    + ' nepa_role_type__c, nepa_active__c, nepa_start_date__c, nepa_end_date__c,'
                    + ' nepa_notes__c,'
                    + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                    + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                    + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                    + ' FROM nepa_process_team_member__c'
                    + ' WHERE nepa_process__c IN :processIds'
                    + ' ORDER BY nepa_process__c, Name ASC',
                    AccessLevel.USER_MODE
                );
                for (nepa_process_team_member__c tm : teamMembers) {
                    Id pid = tm.nepa_process__c;
                    if (!teamByProcess.containsKey(pid)) {
                        teamByProcess.put(pid, new List<nepa_process_team_member__c>());
                    }
                    teamByProcess.get(pid).add(tm);
                }
            }

            // Project-level GIS data
            List<nepa_gis_data__c> projectGis = Database.query(
                'SELECT Id, Name, nepa_parent_project__c, nepa_parent_process__c,'
                + ' nepa_parent_document_id__c, nepa_parent_case_event__c,'
                + ' nepa_parent_comment__c, nepa_parent_engagement__c,'
                + ' nepa_description__c, nepa_extent__c,'
                + ' nepa_centroid_lat__c, nepa_centroid_lon__c, nepa_address__c,'
                + ' nepa_notes__c, nepa_creator__c, nepa_creator_contact__c,'
                + ' nepa_container_inventory__c, nepa_map_image__c,'
                + ' nepa_data_container__c, nepa_other__c,'
                + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                + ' FROM nepa_gis_data__c'
                + ' WHERE nepa_parent_project__c = :programId'
                + ' ORDER BY Name ASC',
                AccessLevel.USER_MODE
            );

            // Process-level GIS data
            Map<Id, List<nepa_gis_data__c>> gisByProcess = new Map<Id, List<nepa_gis_data__c>>();
            if (!processIds.isEmpty()) {
                List<nepa_gis_data__c> processGis = Database.query(
                    'SELECT Id, Name, nepa_parent_project__c, nepa_parent_process__c,'
                    + ' nepa_parent_document_id__c, nepa_parent_case_event__c,'
                    + ' nepa_parent_comment__c, nepa_parent_engagement__c,'
                    + ' nepa_description__c, nepa_extent__c,'
                    + ' nepa_centroid_lat__c, nepa_centroid_lon__c, nepa_address__c,'
                    + ' nepa_notes__c, nepa_creator__c, nepa_creator_contact__c,'
                    + ' nepa_container_inventory__c, nepa_map_image__c,'
                    + ' nepa_data_container__c, nepa_other__c,'
                    + ' nepa_data_record_version__c, nepa_data_source_agency__c,'
                    + ' nepa_data_source_system__c, nepa_record_owner_agency__c,'
                    + ' nepa_retrieved_timestamp__c, LastModifiedDate'
                    + ' FROM nepa_gis_data__c'
                    + ' WHERE nepa_parent_process__c IN :processIds'
                    + ' ORDER BY nepa_parent_process__c, Name ASC',
                    AccessLevel.USER_MODE
                );
                for (nepa_gis_data__c g : processGis) {
                    Id pid = g.nepa_parent_process__c;
                    if (!gisByProcess.containsKey(pid)) {
                        gisByProcess.put(pid, new List<nepa_gis_data__c>());
                    }
                    gisByProcess.get(pid).add(g);
                }
            }

            // Permits
            Map<Id, List<nepa_required_permit__c>> permitsByProcess = new Map<Id, List<nepa_required_permit__c>>();
            if (!processIds.isEmpty()) {
                List<nepa_required_permit__c> permits = Database.query(
                    'SELECT Id, Name, nepa_permit_type__c, nepa_lead_agency__c,'
                    + ' nepa_regulatory_citation__c, nepa_is_critical_path__c,'
                    + ' nepa_permit_status__c, nepa_nepa_stage_gate__c,'
                    + ' nepa_expected_completion__c, nepa_actual_completion__c,'
                    + ' nepa_sla_due_date__c, nepa_sla_overdue__c,'
                    + ' nepa_statutory_deadline_days__c, nepa_external_federal_id__c,'
                    + ' nepa_agency_endpoint_ref__c, nepa_agency_system_url__c,'
                    + ' nepa_last_synced__c, nepa_permit_notes__c, nepa_process__c,'
                    + ' LastModifiedDate'
                    + ' FROM nepa_required_permit__c'
                    + ' WHERE nepa_process__c IN :processIds'
                    + ' ORDER BY nepa_process__c, nepa_is_critical_path__c DESC, Name ASC',
                    AccessLevel.USER_MODE
                );
                for (nepa_required_permit__c p : permits) {
                    Id pid = p.nepa_process__c;
                    if (!permitsByProcess.containsKey(pid)) {
                        permitsByProcess.put(pid, new List<nepa_required_permit__c>());
                    }
                    permitsByProcess.get(pid).add(p);
                }
            }

            // ── Assemble output ───────────────────────────────────────────────

            List<Map<String, Object>> processDtos = new List<Map<String, Object>>();
            for (IndividualApplication ia : processes) {
                Id pid = ia.Id;

                // Documents with nested comments
                List<Map<String, Object>> docDtos = new List<Map<String, Object>>();
                for (ContentVersion cv : docsByProcess.containsKey(pid) ? docsByProcess.get(pid) : new List<ContentVersion>()) {
                    Map<String, Object> docDto = documentDto(cv);
                    List<Map<String, Object>> commentDtos = new List<Map<String, Object>>();
                    for (PublicComplaint pc : commentsByDoc.containsKey(cv.Id) ? commentsByDoc.get(cv.Id) : new List<PublicComplaint>()) {
                        commentDtos.add(commentDto(pc));
                    }
                    docDto.put('comments', commentDtos);
                    docDtos.add(docDto);
                }

                Map<String, Object> processDto = processDto(ia);
                processDto.put('documents', docDtos);
                processDto.put('public_engagement_events', engagementDtos(engagementsByProcess.get(pid)));
                processDto.put('case_events', caseEventDtos(caseEventsByProcess.get(pid)));
                processDto.put('team_members', teamMemberDtos(teamByProcess.get(pid)));
                processDto.put('legal_structure', new List<Object>());
                processDto.put('gis_data', gisDtos(gisByProcess.get(pid)));
                processDto.put('permits', permitDtos(permitsByProcess.get(pid)));
                processDtos.add(processDto);
            }

            Map<String, Object> projectDto = projectDto(proj);
            projectDto.put('gis_data', gisDtos(projectGis));
            projectDto.put('processes', processDtos);

            Map<String, Object> payload = new Map<String, Object>{
                'schema_version' => '1.2',
                'standard'       => 'CEQ NEPA and Permitting Data and Technology Standard',
                'exported_at'    => Datetime.now(),
                'project'        => projectDto
            };

            Map<String, Object> responseBody = new Map<String, Object>{
                'success' => true,
                'data'    => payload
            };
            if (truncated) {
                responseBody.put('warning', 'Project has more than ' + MAX_PROCESSES
                    + ' processes. Export truncated to first ' + MAX_PROCESSES + '.');
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                errorResponse('SERVER_ERROR', 'An internal error occurred. Contact your administrator.')
            ));
            NEPA_Error_Event__e evt = new NEPA_Error_Event__e(
                Flow_Name__c       = 'NepaCeqFullExportService',
                Error_Message__c   = e.getMessage() + '\n' + e.getStackTraceString(),
                Running_User_Id__c = UserInfo.getUserId(),
                Occurred_At__c     = Datetime.now(),
                Error_Context__c   = 'URI:' + RestContext.request.requestURI
            );
            EventBus.publish(evt);
        }
    }

    // ── DTO builders ──────────────────────────────────────────────────────────

    private static Map<String, Object> projectDto(Program p) {
        return new Map<String, Object>{
            'id'                  => p.Id,
            'project_id'          => p.nepa_project_id__c,
            'project_title'       => p.nepa_project_title__c,
            'name'                => p.Name,
            'project_description' => p.nepa_project_description__c,
            'project_sector'      => p.nepa_project_sector__c,
            'project_type'        => p.nepa_project_type__c,
            'status'              => p.nepa_current_status__c,
            'lead_agency'         => p.nepa_lead_agency__c,
            'project_sponsor'     => p.nepa_project_sponsor__c,
            'funding_sources'     => p.nepa_funding__c,
            'start_date'          => p.nepa_start_date__c,
            'location'            => p.nepa_location__c,
            'location_latitude'   => p.nepa_location_lat__c,
            'location_longitude'  => p.nepa_location_lon__c,
            'location_text'       => p.nepa_location_text__c,
            'polygon_id'          => p.nepa_polygon__c,
            'parent_project_id'   => p.nepa_parent_project__c,
            'data_record_version' => p.nepa_data_record_version__c,
            'data_source_agency'  => p.nepa_data_source_agency__c,
            'data_source_system'  => p.nepa_data_source_system__c,
            'record_owner_agency' => p.nepa_record_owner_agency__c,
            'retrieved_timestamp' => p.nepa_retrieved_timestamp__c,
            'last_updated'        => p.LastModifiedDate
        };
    }

    private static Map<String, Object> processDto(IndividualApplication ia) {
        return new Map<String, Object>{
            'id'                         => ia.Id,
            'federal_unique_id'          => ia.nepa_federal_unique_id__c,
            'agency_process_id'          => ia.nepa_agency_id__c,
            'process_code'               => ia.nepa_process_code__c,
            'name'                       => ia.Name,
            'process_description'        => ia.nepa_description__c,
            'purpose_and_need'           => ia.nepa_purpose_need__c,
            'nepa_review_type'           => ia.nepa_review_type__c,
            'status'                     => ia.nepa_process_status__c,
            'stage'                      => ia.nepa_process_stage__c,
            'outcome'                    => ia.nepa_process_outcome__c,
            'project_id'                 => ia.nepa_related_project__c,
            'parent_process_id'          => ia.nepa_parent_process__c,
            'joint_lead_agency'          => ia.nepa_joint_lead_agency__c,
            'start_date'                 => ia.nepa_start_date__c,
            'completion_date'            => ia.nepa_completion_date__c,
            'public_comment_period_start'=> ia.nepa_public_comment_period_start__c,
            'public_comment_period_end'  => ia.nepa_public_comment_period_end_date__c,
            'data_record_version'        => ia.nepa_data_record_version__c,
            'data_source_agency'         => ia.nepa_data_source_agency__c,
            'data_source_system'         => ia.nepa_data_source_system__c,
            'record_owner_agency'        => ia.nepa_record_owner_agency__c,
            'retrieved_timestamp'        => ia.nepa_retrieved_timestamp__c,
            'last_updated'               => ia.LastModifiedDate
        };
    }

    private static Map<String, Object> documentDto(ContentVersion cv) {
        return new Map<String, Object>{
            'id'                   => cv.Id,
            'title'                => cv.Title,
            'description'          => cv.Description,
            'document_type'        => cv.nepa_document_type__c,
            'record_category'      => cv.nepa_record_category__c,
            'status'               => cv.nepa_status__c,
            'public_access'        => cv.nepa_public_access__c,
            'publish_date'         => cv.nepa_publish_date__c,
            'url'                  => cv.nepa_url__c,
            'prepared_by'          => cv.nepa_prepared_by__c,
            'contributing_agencies'=> cv.nepa_contributing_agencies__c,
            'document_summary'     => cv.nepa_document_summary__c,
            'document_files'       => cv.nepa_document_files__c,
            'volume_title'         => cv.nepa_volume_title__c,
            'document_revision'    => cv.nepa_document_revision__c,
            'revision_number'      => cv.nepa_revision_number__c,
            'supplement_number'    => cv.nepa_supplement_number__c,
            'related_document_id'  => cv.nepa_related_document__c,
            'related_case_event_id'=> cv.nepa_related_case_event__c,
            'main_document'        => cv.nepa_main_document__c,
            'process_id'           => cv.nepa_process__c,
            'data_record_version'  => cv.nepa_data_record_version__c,
            'data_source_agency'   => cv.nepa_data_source_agency__c,
            'data_source_system'   => cv.nepa_data_source_system__c,
            'record_owner_agency'  => cv.nepa_record_owner_agency__c,
            'retrieved_timestamp'  => cv.nepa_retrieved_timestamp__c,
            'last_updated'         => cv.LastModifiedDate
        };
    }

    private static Map<String, Object> commentDto(PublicComplaint pc) {
        return new Map<String, Object>{
            'id'                         => pc.Id,
            'name'                       => pc.Name,
            'parent_document_id'         => pc.nepa_parent_document__c,
            'organization'               => pc.nepa_organization__c,
            'comment_category'           => pc.nepa_category__c,
            'date_submitted'             => pc.nepa_date_submitted__c,
            'method_of_submission'       => pc.Method_of_Submission__c,
            'document_location_reference'=> pc.nepa_document_location_ref__c,
            'public_source'              => pc.nepa_public_source__c,
            'agency_response'            => pc.nepa_agency_response__c,
            'public_access'              => pc.nepa_public_access__c,
            'data_record_version'        => pc.nepa_data_record_version__c,
            'data_source_agency'         => pc.nepa_data_source_agency__c,
            'data_source_system'         => pc.nepa_data_source_system__c,
            'record_owner_agency'        => pc.nepa_record_owner_agency__c,
            'retrieved_timestamp'        => pc.nepa_retrieved_timestamp__c,
            'last_updated'               => pc.LastModifiedDate
        };
    }

    private static List<Map<String, Object>> engagementDtos(List<nepa_engagement__c> engagements) {
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        if (engagements == null) { return dtos; }
        for (nepa_engagement__c eng : engagements) {
            dtos.add(new Map<String, Object>{
                'id'                  => eng.Id,
                'name'                => eng.Name,
                'process_id'          => eng.nepa_process__c,
                'engagement_type'     => eng.nepa_engagement_type__c,
                'start_datetime'      => eng.nepa_start_datetime__c,
                'end_datetime'        => eng.nepa_end_datetime__c,
                'location_format'     => eng.nepa_location_format__c,
                'location'            => eng.nepa_location__c,
                'attendance_count'    => eng.nepa_attendance_count__c,
                'document_id'         => eng.nepa_document__c,
                'public_access'       => eng.nepa_public_access__c,
                'notes'               => eng.nepa_notes__c,
                'data_record_version' => eng.nepa_data_record_version__c,
                'data_source_agency'  => eng.nepa_data_source_agency__c,
                'data_source_system'  => eng.nepa_data_source_system__c,
                'record_owner_agency' => eng.nepa_record_owner_agency__c,
                'retrieved_timestamp' => eng.nepa_retrieved_timestamp__c,
                'last_updated'        => eng.LastModifiedDate
            });
        }
        return dtos;
    }

    private static List<Map<String, Object>> caseEventDtos(List<ApplicationTimeline> events) {
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        if (events == null) { return dtos; }
        for (ApplicationTimeline evt : events) {
            dtos.add(new Map<String, Object>{
                'id'                   => evt.Id,
                'name'                 => evt.Name,
                'event_type'           => evt.nepa_event_type__c,
                'event_description'    => evt.nepa_event_description__c,
                'source'               => evt.nepa_source__c,
                'tier'                 => evt.nepa_tier__c,
                'status'               => evt.nepa_status__c,
                'outcome'              => evt.nepa_outcome__c,
                'assigned_entity'      => evt.nepa_assigned_entity__c,
                'following_segment'    => evt.nepa_following_segment__c,
                'public_access'        => evt.nepa_public_access__c,
                'parent_case_event_id' => evt.nepa_parent_case_event__c,
                'related_engagement_id'=> evt.nepa_related_engagement__c,
                'data_record_version'  => evt.nepa_data_record_version__c,
                'data_source_agency'   => evt.nepa_data_source_agency__c,
                'data_source_system'   => evt.nepa_data_source_system__c,
                'record_owner_agency'  => evt.nepa_record_owner_agency__c,
                'retrieved_timestamp'  => evt.nepa_retrieved_timestamp__c,
                'last_updated'         => evt.LastModifiedDate
            });
        }
        return dtos;
    }

    private static List<Map<String, Object>> teamMemberDtos(List<nepa_process_team_member__c> members) {
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        if (members == null) { return dtos; }
        for (nepa_process_team_member__c tm : members) {
            dtos.add(new Map<String, Object>{
                'id'                  => tm.Id,
                'name'                => tm.Name,
                'process_id'          => tm.nepa_process__c,
                'user_id'             => tm.nepa_user__c,
                'agency_id'           => tm.nepa_agency__c,
                'role_type'           => tm.nepa_role_type__c,
                'active'              => tm.nepa_active__c,
                'start_date'          => tm.nepa_start_date__c,
                'end_date'            => tm.nepa_end_date__c,
                'notes'               => tm.nepa_notes__c,
                'data_record_version' => tm.nepa_data_record_version__c,
                'data_source_agency'  => tm.nepa_data_source_agency__c,
                'data_source_system'  => tm.nepa_data_source_system__c,
                'record_owner_agency' => tm.nepa_record_owner_agency__c,
                'retrieved_timestamp' => tm.nepa_retrieved_timestamp__c,
                'last_updated'        => tm.LastModifiedDate
            });
        }
        return dtos;
    }

    private static List<Map<String, Object>> gisDtos(List<nepa_gis_data__c> gisRecords) {
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        if (gisRecords == null) { return dtos; }
        for (nepa_gis_data__c g : gisRecords) {
            dtos.add(new Map<String, Object>{
                'id'                  => g.Id,
                'name'                => g.Name,
                'parent_project_id'   => g.nepa_parent_project__c,
                'parent_process_id'   => g.nepa_parent_process__c,
                'parent_document_id'  => g.nepa_parent_document_id__c,
                'parent_case_event_id'=> g.nepa_parent_case_event__c,
                'parent_comment_id'   => g.nepa_parent_comment__c,
                'parent_engagement_id'=> g.nepa_parent_engagement__c,
                'description'         => g.nepa_description__c,
                'extent'              => g.nepa_extent__c,
                'centroid_lat'        => g.nepa_centroid_lat__c,
                'centroid_lon'        => g.nepa_centroid_lon__c,
                'address'             => g.nepa_address__c,
                'notes'               => g.nepa_notes__c,
                'creator'             => g.nepa_creator__c,
                'creator_contact'     => g.nepa_creator_contact__c,
                'container_inventory' => g.nepa_container_inventory__c,
                'map_image'           => g.nepa_map_image__c,
                'data_container'      => g.nepa_data_container__c,
                'other'               => g.nepa_other__c,
                'data_record_version' => g.nepa_data_record_version__c,
                'data_source_agency'  => g.nepa_data_source_agency__c,
                'data_source_system'  => g.nepa_data_source_system__c,
                'record_owner_agency' => g.nepa_record_owner_agency__c,
                'retrieved_timestamp' => g.nepa_retrieved_timestamp__c,
                'last_updated'        => g.LastModifiedDate
            });
        }
        return dtos;
    }

    private static List<Map<String, Object>> permitDtos(List<nepa_required_permit__c> permits) {
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        if (permits == null) { return dtos; }
        for (nepa_required_permit__c p : permits) {
            dtos.add(new Map<String, Object>{
                'id'                      => p.Id,
                'name'                    => p.Name,
                'permit_type'             => p.nepa_permit_type__c,
                'lead_agency'             => p.nepa_lead_agency__c,
                'regulatory_citation'     => p.nepa_regulatory_citation__c,
                'is_critical_path'        => p.nepa_is_critical_path__c,
                'permit_status'           => p.nepa_permit_status__c,
                'nepa_stage_gate'         => p.nepa_nepa_stage_gate__c,
                'expected_completion'     => p.nepa_expected_completion__c,
                'actual_completion'       => p.nepa_actual_completion__c,
                'sla_due_date'            => p.nepa_sla_due_date__c,
                'sla_overdue'             => p.nepa_sla_overdue__c,
                'statutory_deadline_days' => p.nepa_statutory_deadline_days__c,
                'external_federal_id'     => p.nepa_external_federal_id__c,
                'agency_endpoint_key'     => p.nepa_agency_endpoint_ref__c,
                'agency_system_url'       => p.nepa_agency_system_url__c,
                'last_synced'             => p.nepa_last_synced__c,
                'permit_notes'            => p.nepa_permit_notes__c,
                'process_id'              => p.nepa_process__c,
                'last_updated'            => p.LastModifiedDate
            });
        }
        return dtos;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Map<String, Object> errorResponse(String code, String message) {
        return new Map<String, Object>{
            'success'   => false,
            'errorCode' => code,
            'message'   => message
        };
    }
}
