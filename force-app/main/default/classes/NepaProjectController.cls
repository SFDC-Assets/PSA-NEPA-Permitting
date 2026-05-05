/** Controller exposing NEPA project listings and detail to Experience Cloud portal visitors. */
public with sharing class NepaProjectController {

    // ── Query constants — declared before inner classes per PMD ───────────────

    private static final Set<String> VALID_SORT_FIELDS = new Set<String>{
        'nepa_project_title__c', 'nepa_lead_agency__c', 'nepa_start_date__c'
    };

    private static final Integer DEFAULT_PAGE_SIZE = 20;
    private static final Integer MAX_PAGE_SIZE = 100;

    // ── Public DTO classes ────────────────────────────────────────────────────

    /** Paginated project list wrapper. */
    public class ProjectListResult {
        @AuraEnabled public List<ProjectResult> projects;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer pageNumber;
    }

    /** Single project row in list view. */
    public class ProjectResult {
        @AuraEnabled public String federalUniqueId;
        @AuraEnabled public String projectTitle;
        @AuraEnabled public String leadAgencyName;
        @AuraEnabled public String reviewType;
        @AuraEnabled public String processStage;
        @AuraEnabled public String commentPeriodEndDate;
        @AuraEnabled public Boolean isCommentPeriodOpen;
        @AuraEnabled public String projectUrl;
    }

    /** Full project detail including linked process data. */
    public class ProjectDetail {
        @AuraEnabled public String federalUniqueId;
        @AuraEnabled public String projectTitle;
        @AuraEnabled public String leadAgencyName;
        @AuraEnabled public String locationText;
        @AuraEnabled public String projectSector;
        @AuraEnabled public String projectType;
        @AuraEnabled public String startDate;
        @AuraEnabled public String reviewType;
        @AuraEnabled public String processStage;
        @AuraEnabled public String processStatus;
        @AuraEnabled public String commentPeriodStart;
        @AuraEnabled public String commentPeriodEnd;
        @AuraEnabled public Boolean isCommentPeriodOpen;
        @AuraEnabled public String processId;
    }

    /** Project with an active public comment window. */
    public class OpenCommentPeriod {
        @AuraEnabled public String projectTitle;
        @AuraEnabled public String federalUniqueId;
        @AuraEnabled public String reviewType;
        @AuraEnabled public String commentPeriodEnd;
        @AuraEnabled public Integer daysRemaining;
    }

    // ── Apex methods ──────────────────────────────────────────────────────────

    /**
     * Returns a paginated, optionally filtered and sorted list of NEPA projects.
     * @param searchTerm Optional keyword to match against project title or lead agency
     * @param reviewTypeFilter Optional review type to restrict results (CE/EA/EIS)
     * @param sortBy Optional sort field; must be in VALID_SORT_FIELDS allowlist
     * @param pageNumber 1-based page number; defaults to 1
     * @param pageSize Records per page; capped at MAX_PAGE_SIZE
     * @return ProjectListResult containing projects, totalCount, pageSize, pageNumber
     */
    @SuppressWarnings('PMD.ExcessiveParameterList, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.ApexSOQLInjection')
    @AuraEnabled(cacheable=true)
    public static ProjectListResult getProjectList(
        String searchTerm,
        String reviewTypeFilter,
        String sortBy,
        Integer pageNumber,
        Integer pageSize
    ) {
        Integer safePageSize   = (pageSize   != null && pageSize   > 0 && pageSize   <= MAX_PAGE_SIZE) ? pageSize   : DEFAULT_PAGE_SIZE;
        Integer safePageNumber = (pageNumber != null && pageNumber > 0)                                ? pageNumber : 1;
        Integer offset         = (safePageNumber - 1) * safePageSize;

        // Allowlist guards injection; orderClause is safe for dynamic SOQL
        String orderClause = (String.isNotBlank(sortBy) && VALID_SORT_FIELDS.contains(sortBy.toLowerCase()))
            ? sortBy.toLowerCase()
            : 'nepa_project_title__c';

        String searchFilter = '';
        if (String.isNotBlank(searchTerm)) {
            searchFilter = ' AND (nepa_project_title__c LIKE :searchTerm OR nepa_lead_agency__r.Name LIKE :searchTerm)';
        }

        String whereClause = 'Id != null' + searchFilter;

        Integer total = Database.countQuery(
            'SELECT COUNT() FROM Program WHERE ' + whereClause,
            AccessLevel.USER_MODE
        );

        // sfge-disable-next-line ApexFlsViolation -- USER_MODE enforces FLS at runtime; sfge cannot resolve dynamic query field names
        List<Program> programs = Database.query(
            'SELECT Id, nepa_project_id__c, nepa_project_title__c, nepa_lead_agency__c, nepa_lead_agency__r.Name, nepa_start_date__c, ' +
            '(SELECT Id, nepa_federal_unique_id__c, nepa_review_type__c, nepa_process_stage__c, ' +
            'nepa_public_comment_period_end_date__c, nepa_public_comment_period_start__c, nepa_process_status__c ' +
            'FROM Individual_Applications__r ORDER BY LastModifiedDate DESC LIMIT 1) ' +
            'FROM Program WHERE ' + whereClause +
            ' ORDER BY ' + orderClause + ' ASC LIMIT :safePageSize OFFSET :offset',
            AccessLevel.USER_MODE
        );

        List<ProjectResult> results = new List<ProjectResult>();
        Date today = Date.today();

        for (Program p : programs) {
            results.add(buildProjectResult(p, today));
        }

        ProjectListResult out = new ProjectListResult();
        out.projects    = results;
        out.totalCount  = total;
        out.pageSize    = safePageSize;
        out.pageNumber  = safePageNumber;
        return out;
    }

    /**
     * Returns full project detail by federal unique ID.
     * @param federalUniqueId The CEQ/agency federal unique project identifier
     * @return ProjectDetail including process stage, comment period, and location data
     */
    @AuraEnabled(cacheable=true)
    public static ProjectDetail getProjectDetail(String federalUniqueId) {
        if (String.isBlank(federalUniqueId)) {
            throw auraEx('federalUniqueId is required');
        }

        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- String.isBlank guard immediately above
        List<Program> programs = [
            SELECT Id,
                   nepa_project_id__c,
                   nepa_project_title__c,
                   nepa_lead_agency__c,
                   nepa_lead_agency__r.Name,
                   nepa_location_text__c,
                   nepa_project_sector__c,
                   nepa_project_type__c,
                   nepa_start_date__c,
                   (SELECT Id,
                           nepa_federal_unique_id__c,
                           nepa_review_type__c,
                           nepa_process_stage__c,
                           nepa_process_status__c,
                           nepa_public_comment_period_start__c,
                           nepa_public_comment_period_end_date__c
                    FROM Individual_Applications__r
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1)
            FROM Program
            WHERE nepa_project_id__c = :federalUniqueId
            WITH USER_MODE
            LIMIT 1
        ];

        if (programs.isEmpty()) {
            throw auraEx('Project not found: ' + federalUniqueId);
        }

        Program p = programs[0];
        Date today = Date.today();

        ProjectDetail d = new ProjectDetail();
        d.federalUniqueId = p.nepa_project_id__c;
        d.projectTitle    = p.nepa_project_title__c;
        d.leadAgencyName  = p.nepa_lead_agency__r?.Name;
        d.locationText    = p.nepa_location_text__c;
        d.projectSector   = p.nepa_project_sector__c;
        d.projectType     = p.nepa_project_type__c;
        d.startDate       = p.nepa_start_date__c != null ? String.valueOf(p.nepa_start_date__c) : null;

        if (!p.Individual_Applications__r.isEmpty()) {
            IndividualApplication ia = p.Individual_Applications__r[0];
            d.processId          = ia.Id;
            d.reviewType         = ia.nepa_review_type__c;
            d.processStage       = ia.nepa_process_stage__c;
            d.processStatus      = ia.nepa_process_status__c;
            d.commentPeriodStart = ia.nepa_public_comment_period_start__c != null
                ? String.valueOf(ia.nepa_public_comment_period_start__c) : null;
            d.commentPeriodEnd   = ia.nepa_public_comment_period_end_date__c != null
                ? String.valueOf(ia.nepa_public_comment_period_end_date__c) : null;
            d.isCommentPeriodOpen = isOpen(ia, today);
        } else {
            d.isCommentPeriodOpen = false;
        }

        return d;
    }

    /**
     * Returns all processes currently within their public comment window.
     * @return List of OpenCommentPeriod records ordered by soonest-closing first
     */
    @AuraEnabled(cacheable=true)
    public static List<OpenCommentPeriod> getOpenCommentPeriods() {
        Date today = Date.today();

        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- today is always non-null (Date.today() never returns null)
        List<IndividualApplication> openProcesses = [
            SELECT Id,
                   nepa_federal_unique_id__c,
                   nepa_review_type__c,
                   nepa_public_comment_period_end_date__c,
                   nepa_related_project__r.nepa_project_title__c,
                   nepa_related_project__r.nepa_project_id__c
            FROM IndividualApplication
            WHERE nepa_public_comment_period_start__c <= :today
              AND nepa_public_comment_period_end_date__c >= :today
            WITH USER_MODE
            ORDER BY nepa_public_comment_period_end_date__c ASC
            LIMIT 50
        ];

        List<OpenCommentPeriod> results = new List<OpenCommentPeriod>();
        for (IndividualApplication ia : openProcesses) {
            OpenCommentPeriod ocp = new OpenCommentPeriod();
            ocp.projectTitle     = ia.nepa_related_project__r?.nepa_project_title__c;
            ocp.federalUniqueId  = ia.nepa_related_project__r?.nepa_project_id__c;
            ocp.reviewType       = ia.nepa_review_type__c;
            ocp.commentPeriodEnd = String.valueOf(ia.nepa_public_comment_period_end_date__c);
            ocp.daysRemaining    = today.daysBetween(ia.nepa_public_comment_period_end_date__c.date());
            results.add(ocp);
        }
        return results;
    }

    // ── private helpers ───────────────────────────────────────────────────────

    private static ProjectResult buildProjectResult(Program p, Date today) {
        ProjectResult r = new ProjectResult();
        r.federalUniqueId = p.nepa_project_id__c;
        r.projectTitle    = p.nepa_project_title__c;
        r.leadAgencyName  = p.nepa_lead_agency__r?.Name;

        if (!p.Individual_Applications__r.isEmpty()) {
            IndividualApplication ia = p.Individual_Applications__r[0];
            r.reviewType           = ia.nepa_review_type__c;
            r.processStage         = ia.nepa_process_stage__c;
            r.commentPeriodEndDate = ia.nepa_public_comment_period_end_date__c != null
                ? String.valueOf(ia.nepa_public_comment_period_end_date__c)
                : null;
            r.isCommentPeriodOpen  = isOpen(ia, today);
        } else {
            r.isCommentPeriodOpen = false;
        }
        return r;
    }

    private static AuraHandledException auraEx(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }

    private static Boolean isOpen(IndividualApplication ia, Date today) {
        return (
            ia.nepa_public_comment_period_start__c != null &&
            ia.nepa_public_comment_period_end_date__c != null &&
            ia.nepa_public_comment_period_start__c.date() <= today &&
            ia.nepa_public_comment_period_end_date__c.date() >= today
        );
    }
}
