/** Controller handling public comment submissions from the Experience Cloud portal. */
public with sharing class NepaCommentController {

    /** Input DTO for a public comment submission. */
    public class CommentInput {
        @AuraEnabled public String processId;
        @AuraEnabled public String commenterName;
        @AuraEnabled public String organization;
        @AuraEnabled public String email;
        @AuraEnabled public String category;
        @AuraEnabled public String commentBody;
        @AuraEnabled public Boolean notifyMe;
        @AuraEnabled public String contentVersionId;  // optional attachment
    }

    /**
     * Submits a public comment for the given process after validating the comment period is open.
     * @param input CommentInput DTO with processId, commenterName, commentBody, and optional fields
     * @return Id of the newly created PublicComplaint record
     */
    @AuraEnabled
    public static String submitComment(CommentInput input) {
        validateInput(input);
        assertCommentPeriodOpen(input.processId);

        PublicComplaint comment = new PublicComplaint();
        // nepa_related_process__c drives both the NEPA_Comment_Period_Gate before-save flow
        // and the NEPA_Comment_Period_Closed validation rule deadline enforcement.
        comment.nepa_related_process__c         = input.processId;
        // PSS PublicComplaint uses LastName as the commenter identity field (Name is auto-composed)
        comment.LastName                        = sanitize(input.commenterName);
        comment.nepa_organization__c            = sanitize(input.organization);
        comment.nepa_category__c                = sanitize(input.category);
        comment.nepa_comment_body__c            = sanitize(input.commentBody);
        comment.nepa_date_submitted__c          = Date.today();
        comment.IncidentDate                    = Date.today();
        comment.nepa_public_source__c           = true;
        comment.Method_of_Submission__c         = 'Online';
        comment.nepa_public_access__c           = 'Public';

        if (input.notifyMe == true && String.isNotBlank(input.email)) {
            comment.nepa_email__c = sanitize(input.email);
        }

        if (String.isNotBlank(input.contentVersionId)) {
            comment.nepa_document_location_ref__c = input.contentVersionId;
        }

        if (!Schema.sObjectType.PublicComplaint.isCreateable()) {
            throw auraEx('Insufficient permissions to submit a comment');
        }
        // sfge-disable-next-line ApexFlsViolation -- isCreateable() guard above + USER_MODE on insert enforces FLS at runtime
        Database.insert(comment, AccessLevel.USER_MODE);
        return comment.Id;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    @SuppressWarnings('PMD.CyclomaticComplexity')
    private static void validateInput(CommentInput input) {
        if (input == null) {
            throw auraEx('Comment input is required');
        }
        if (String.isBlank(input.processId)) {
            throw auraEx('processId is required');
        }
        if (String.isBlank(input.commenterName)) {
            throw auraEx('Commenter name is required');
        }
        if (String.isBlank(input.commentBody)) {
            throw auraEx('Comment body is required');
        }
        if (input.commentBody.length() > 32000) {
            throw auraEx('Comment body exceeds maximum length of 32,000 characters');
        }
    }

    private static AuraHandledException auraEx(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }

    private static void assertCommentPeriodOpen(String processId) {
        List<IndividualApplication> processes = [
            SELECT nepa_public_comment_period_start__c,
                   nepa_public_comment_period_end_date__c
            FROM IndividualApplication
            WHERE Id = :processId
            WITH USER_MODE
            LIMIT 1
        ];

        if (processes.isEmpty()) {
            throw auraEx('Process not found');
        }

        // Use DateTime.now() — NOT Date.today() — so the exact-minute deadline is enforced.
        // Date.today() comparison would allow submissions on the deadline day after the
        // cutoff time, defeating the compressed 5-day emergency comment period kill-switch.
        // The before-save Flow and validation rule both use $Flow.CurrentDateTime / NOW()
        // (UTC-based second precision); this method must match that precision.
        DateTime now = DateTime.now();
        IndividualApplication ia = processes[0];

        Boolean open = (
            ia.nepa_public_comment_period_start__c != null &&
            ia.nepa_public_comment_period_end_date__c != null &&
            ia.nepa_public_comment_period_start__c <= now &&
            ia.nepa_public_comment_period_end_date__c > now
        );

        if (!open) {
            throw auraEx('The public comment period for this process is not currently open');
        }
    }

    // Strip HTML tags to prevent stored XSS in long text fields
    private static String sanitize(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        return input.stripHtmlTags().trim();
    }
}
