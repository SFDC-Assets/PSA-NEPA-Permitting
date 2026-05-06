/** Shared test data factory for NEPA controller unit tests. */
@IsTest
@SuppressWarnings('PMD.ExcessivePublicCount')
public class NepaTestFactory {

    // ── Field declarations ────────────────────────────────────────────────────

    private static final Map<String, Id> AGENCY_CACHE = new Map<String, Id>();
    private static Id licenseTypeId;
    private static Id regulatoryAuthorityId;
    private static Integer cvCounter = 0;

    // ── Agency Account cache ──────────────────────────────────────────────────

    private static Id getOrCreateAgencyAccount(String agencyName) {
        if (AGENCY_CACHE.containsKey(agencyName)) {
            return AGENCY_CACHE.get(agencyName);
        }
        Account a = new Account(Name = agencyName);
        insert a;
        AGENCY_CACHE.put(agencyName, a.Id);
        return a.Id;
    }

    // ── RegulatoryAuthority cache ─────────────────────────────────────────────

    private static Id getOrCreateRegulatoryAuthority() {
        if (regulatoryAuthorityId != null) {
            return regulatoryAuthorityId;
        }
        List<RegulatoryAuthority> existing = [
            SELECT Id FROM RegulatoryAuthority WHERE Name = 'CEQ' LIMIT 1
        ];
        if (!existing.isEmpty()) {
            regulatoryAuthorityId = existing[0].Id;
        } else {
            RegulatoryAuthority ra = new RegulatoryAuthority(Name = 'CEQ');
            insert ra;
            regulatoryAuthorityId = ra.Id;
        }
        return regulatoryAuthorityId;
    }

    // ── RegulatoryAuthorizationType cache ─────────────────────────────────────

    private static Id getOrCreateLicenseType() {
        if (licenseTypeId != null) {
            return licenseTypeId;
        }
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review' LIMIT 1
        ];
        if (!existing.isEmpty()) {
            licenseTypeId = existing[0].Id;
        } else {
            RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
                Name = 'NEPA Environmental Review',
                RegulatoryAuthCategory = 'Permit'
            );
            insert rat;
            licenseTypeId = rat.Id;
        }
        return licenseTypeId;
    }

    // ── Program (CEQ Project) ─────────────────────────────────────────────────

    /**
     * Builds an unsaved Program record.
     * @param projectId Value for nepa_project_id__c
     * @param title Value for Name and nepa_project_title__c
     * @param agency Account Name for nepa_lead_agency__c (Account is created/cached automatically)
     * @return Unsaved Program record
     */
    public static Program makeProgram(String projectId, String title, String agency) {
        Program p = new Program();
        p.Name                   = title;
        p.nepa_project_id__c     = projectId;
        p.nepa_project_title__c  = title;
        p.nepa_lead_agency__c    = getOrCreateAgencyAccount(agency);
        p.nepa_project_sector__c = 'Energy';
        p.nepa_project_type__c   = 'EIS';
        p.nepa_current_status__c = 'in progress';
        return p;
    }

    /**
     * Inserts and returns a Program record.
     * @param projectId Value for nepa_project_id__c
     * @param title Value for Name and nepa_project_title__c
     * @param agency Value for nepa_lead_agency__c
     * @return Saved Program record
     */
    public static Program insertProgram(String projectId, String title, String agency) {
        Program p = makeProgram(projectId, title, agency);
        insert p;
        return p;
    }

    // ── IndividualApplication (CEQ Process) ───────────────────────────────────

    /**
     * Builds an unsaved IndividualApplication with an explicit comment period window.
     * @param projectId Parent Program Id
     * @param reviewType Value for nepa_review_type__c (CE/EA/EIS)
     * @param periodStart Comment period open date; null to leave unset
     * @param periodEnd Comment period close date; null to leave unset
     * @return Unsaved IndividualApplication record
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static IndividualApplication makeProcess(Id projectId, String reviewType, Date periodStart, Date periodEnd) {
        IndividualApplication ia = new IndividualApplication();
        ia.Category                                = 'Permit';
        ia.LicenseTypeId                           = getOrCreateLicenseType();
        ia.nepa_related_project__c                 = projectId;
        ia.nepa_review_type__c                     = reviewType;
        ia.nepa_process_status__c                  = 'in progress';
        ia.nepa_process_stage__c                   = 'Scoping';
        ia.nepa_public_comment_period_start__c     = periodStart != null ? (DateTime)periodStart : null;
        ia.nepa_public_comment_period_end_date__c  = periodEnd   != null ? (DateTime)periodEnd   : null;
        return ia;
    }

    /**
     * Inserts and returns an IndividualApplication with an explicit comment period window.
     * @param projectId Parent Program Id
     * @param reviewType Value for nepa_review_type__c (CE/EA/EIS)
     * @param periodStart Comment period open date; null to leave unset
     * @param periodEnd Comment period close date; null to leave unset
     * @return Saved IndividualApplication record
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static IndividualApplication insertProcess(Id projectId, String reviewType, Date periodStart, Date periodEnd) {
        IndividualApplication ia = makeProcess(projectId, reviewType, periodStart, periodEnd);
        insert ia;
        return ia;
    }

    /**
     * Inserts a process whose comment period is currently open (starts 5 days ago, ends 25 days from now).
     * @param projectId Parent Program Id
     * @param reviewType Value for nepa_review_type__c (CE/EA/EIS)
     * @return Saved IndividualApplication record with an open comment period
     */
    public static IndividualApplication insertOpenProcess(Id projectId, String reviewType) {
        Date today = Date.today();
        return insertProcess(projectId, reviewType, today.addDays(-5), today.addDays(25));
    }

    /**
     * Inserts a process whose comment period is closed (ended yesterday).
     * @param projectId Parent Program Id
     * @return Saved IndividualApplication record with a closed comment period
     */
    public static IndividualApplication insertClosedProcess(Id projectId) {
        Date today = Date.today();
        return insertProcess(projectId, 'EIS', today.addDays(-60), today.addDays(-1));
    }

    /**
     * Builds an unsaved IndividualApplication with DateTime-precision comment period boundaries.
     * Use this overload when sub-day precision is needed (e.g., exact-minute deadline tests).
     * @param projectId Parent Program Id
     * @param reviewType Value for nepa_review_type__c (CE/EA/EIS)
     * @param periodStart DateTime the comment period opens
     * @param periodEnd DateTime the comment period closes (exact-minute precision)
     * @return Unsaved IndividualApplication record
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static IndividualApplication makeProcessWithDateTimes(
        Id projectId, String reviewType, DateTime periodStart, DateTime periodEnd
    ) {
        IndividualApplication ia = new IndividualApplication();
        ia.Category                               = 'Permit';
        ia.LicenseTypeId                          = getOrCreateLicenseType();
        ia.nepa_related_project__c                = projectId;
        ia.nepa_review_type__c                    = reviewType;
        ia.nepa_process_status__c                 = 'in progress';
        ia.nepa_process_stage__c                  = 'Scoping';
        ia.nepa_public_comment_period_start__c    = periodStart;
        ia.nepa_public_comment_period_end_date__c = periodEnd;
        return ia;
    }

    /**
     * Inserts and returns an IndividualApplication with DateTime-precision comment period boundaries.
     * @param projectId Parent Program Id
     * @param reviewType Value for nepa_review_type__c (CE/EA/EIS)
     * @param periodStart DateTime the comment period opens
     * @param periodEnd DateTime the comment period closes (exact-minute precision)
     * @return Saved IndividualApplication record
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static IndividualApplication insertProcessWithDateTimes(
        Id projectId, String reviewType, DateTime periodStart, DateTime periodEnd
    ) {
        IndividualApplication ia = makeProcessWithDateTimes(projectId, reviewType, periodStart, periodEnd);
        insert ia;
        return ia;
    }

    // ── nepa_engagement__c ────────────────────────────────────────────────────

    /**
     * Inserts a public engagement event linked to a process.
     * @param processId Parent IndividualApplication Id
     * @return Saved nepa_engagement__c record with nepa_public_access__c = true
     */
    public static nepa_engagement__c insertPublicEngagement(Id processId) {
        return insertEngagementRecord(processId, true);
    }

    /**
     * Inserts a non-public engagement event linked to a process.
     * @param processId Parent IndividualApplication Id
     * @return Saved nepa_engagement__c record with nepa_public_access__c = false
     */
    public static nepa_engagement__c insertPrivateEngagement(Id processId) {
        return insertEngagementRecord(processId, false);
    }

    private static nepa_engagement__c insertEngagementRecord(Id processId, Boolean publicAccess) {
        nepa_engagement__c e = new nepa_engagement__c();
        e.nepa_process__c         = processId;
        e.nepa_engagement_type__c = 'Public Hearing';
        e.nepa_location_format__c = 'In-Person';
        e.nepa_start_datetime__c  = DateTime.now().addDays(5);
        e.nepa_end_datetime__c    = DateTime.now().addDays(5).addHours(2);
        e.nepa_public_access__c   = publicAccess;
        insert e;
        return e;
    }

    // ── ApplicationTimeline ───────────────────────────────────────────────────

    /**
     * Inserts a public timeline event linked to a process.
     * @param processId Parent IndividualApplication Id
     * @return Saved ApplicationTimeline record with nepa_public_access__c = true
     */
    public static ApplicationTimeline insertPublicTimelineEvent(Id processId) {
        return insertTimelineRecord(processId, true);
    }

    /**
     * Inserts a non-public timeline event linked to a process.
     * @param processId Parent IndividualApplication Id
     * @return Saved ApplicationTimeline record with nepa_public_access__c = false
     */
    public static ApplicationTimeline insertPrivateTimelineEvent(Id processId) {
        return insertTimelineRecord(processId, false);
    }

    private static ApplicationTimeline insertTimelineRecord(Id processId, Boolean publicAccess) {
        ApplicationTimeline evt = new ApplicationTimeline();
        evt.Name                    = 'NEPA Test Event';
        evt.nepa_event_type__c      = 'NOI';
        evt.nepa_status__c          = 'Completed';
        evt.nepa_tier__c            = '1';
        evt.nepa_source__c          = 'Test';
        evt.nepa_start_date__c      = Date.today().addDays(-30);
        evt.nepa_end_date__c        = Date.today().addDays(-20);
        evt.nepa_public_access__c   = publicAccess;
        evt.nepa_related_process__c = processId;
        insert evt;
        return evt;
    }

    // ── ContentVersion + ContentDocumentLink ─────────────────────────────────

    /**
     * Inserts a public ContentVersion linked to the given entity.
     * @param linkedEntityId Id of the record to link the document to
     * @param docType Value for nepa_document_type__c
     * @return Saved ContentVersion record with nepa_public_access__c = true
     */
    public static ContentVersion insertPublicContentVersion(Id linkedEntityId, String docType) {
        return insertContentVersionRecord(linkedEntityId, true, docType);
    }

    /**
     * Inserts a non-public ContentVersion linked to the given entity.
     * @param linkedEntityId Id of the record to link the document to
     * @param docType Value for nepa_document_type__c
     * @return Saved ContentVersion record with nepa_public_access__c = false
     */
    public static ContentVersion insertPrivateContentVersion(Id linkedEntityId, String docType) {
        return insertContentVersionRecord(linkedEntityId, false, docType);
    }

    // ── nepa_gis_data_element__c (CEQ Entity 7) ──────────────────────────────

    /**
     * Builds an unsaved GIS data element.
     * @param processId Optional parent IndividualApplication Id (may be null)
     * @param purpose   Value for nepa_purpose__c picklist
     * @return Unsaved nepa_gis_data_element__c record
     */
    public static nepa_gis_data_element__c makeGisDataElement(Id processId, String purpose) {
        nepa_gis_data_element__c g = new nepa_gis_data_element__c();
        g.nepa_purpose__c            = purpose != null ? purpose : 'Resource Layer';
        g.nepa_format__c             = 'GeoJSON';
        g.nepa_access_method__c      = 'URL';
        g.nepa_coordinate_system__c  = 'WGS84';
        g.nepa_access_information__c = 'https://services.arcgis.com/test/layer';
        g.nepa_data_source_agency__c = 'USFWS';
        g.nepa_data_source_system__c = 'ArcGIS Online';
        g.nepa_data_record_version__c  = '1.0';
        g.nepa_retrieved_timestamp__c  = DateTime.now();
        return g;
    }

    /**
     * Inserts and returns a GIS data element.
     * @param processId Optional parent IndividualApplication Id (may be null)
     * @param purpose   Value for nepa_purpose__c picklist
     * @return Saved nepa_gis_data_element__c record
     */
    public static nepa_gis_data_element__c insertGisDataElement(Id processId, String purpose) {
        nepa_gis_data_element__c g = makeGisDataElement(processId, purpose);
        insert g;
        return g;
    }

    // ── nepa_process_team_member__c (CEQ Entity 8) ───────────────────────────

    /**
     * Builds an unsaved process team member.
     * @param processId Parent IndividualApplication Id (required — MasterDetail)
     * @param userId    User to assign; if null uses the running user
     * @param roleType  Value for nepa_role_type__c picklist
     * @return Unsaved nepa_process_team_member__c record
     */
    public static nepa_process_team_member__c makeTeamMember(Id processId, Id userId, String roleType) {
        nepa_process_team_member__c tm = new nepa_process_team_member__c();
        tm.nepa_process__c   = processId;
        tm.nepa_user__c      = userId != null ? userId : UserInfo.getUserId();
        tm.nepa_role_type__c = roleType != null ? roleType : 'Reviewer';
        tm.nepa_active__c    = true;
        tm.nepa_start_date__c = Date.today();
        return tm;
    }

    /**
     * Inserts and returns a process team member.
     * @param processId Parent IndividualApplication Id (required — MasterDetail)
     * @param userId    User to assign; if null uses the running user
     * @param roleType  Value for nepa_role_type__c picklist
     * @return Saved nepa_process_team_member__c record
     */
    public static nepa_process_team_member__c insertTeamMember(Id processId, Id userId, String roleType) {
        nepa_process_team_member__c tm = makeTeamMember(processId, userId, roleType);
        insert tm;
        return tm;
    }

    // ── RegulatoryCode (CEQ Entity 9) ─────────────────────────────────────

    /**
     * Builds an unsaved RegulatoryCode record.
     * RegulatoryAuthorityId (Lookup → Account) is required in this org;
     * the factory creates/caches a "CEQ" agency account automatically.
     * @param name     Citation string, e.g., "40 CFR 1501.4"
     * @param subject  Subject / description line
     * @return Unsaved RegulatoryCode record
     */
    public static RegulatoryCode makeRegulatoryCode(String name, String subject) {
        RegulatoryCode rc = new RegulatoryCode();
        rc.Name                        = name != null ? name : '40 CFR 1501.4';
        rc.Subject                     = subject != null ? subject : 'CE Determination';
        rc.EffectiveFrom               = DateTime.now().addDays(-365);
        rc.RegulatoryAuthorityId       = getOrCreateRegulatoryAuthority();
        rc.nepa_data_source_agency__c  = 'CEQ';
        rc.nepa_data_source_system__c  = 'eCFR';
        rc.nepa_data_record_version__c = '1.0';
        return rc;
    }

    /**
     * Inserts and returns a RegulatoryCode record.
     * @param name     Citation string, e.g., "40 CFR 1501.4"
     * @param subject  Subject / description line
     * @return Saved RegulatoryCode record
     */
    public static RegulatoryCode insertRegulatoryCode(String name, String subject) {
        RegulatoryCode rc = makeRegulatoryCode(name, subject);
        insert rc;
        return rc;
    }

    private static ContentVersion insertContentVersionRecord(Id linkedEntityId, Boolean publicAccess, String docType) {
        // Unique title per insert prevents ContentDocument index lock contention when
        // multiple test classes run in parallel and Salesforce serializes on title dedup.
        cvCounter++;
        String uniqueLabel = docType + ' ' + cvCounter + ' ' + String.valueOf(linkedEntityId).right(4);
        ContentVersion cv = new ContentVersion();
        cv.Title                    = uniqueLabel;
        cv.PathOnClient             = uniqueLabel.replaceAll('[^a-zA-Z0-9]', '_') + '.pdf';
        cv.VersionData              = Blob.valueOf('test content');
        cv.FirstPublishLocationId   = linkedEntityId;
        cv.nepa_public_access__c    = publicAccess;
        cv.nepa_document_type__c    = docType;
        cv.nepa_status__c           = 'Draft';
        cv.nepa_publish_date__c     = Date.today();
        cv.nepa_process__c          = linkedEntityId;
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv;
    }
}
