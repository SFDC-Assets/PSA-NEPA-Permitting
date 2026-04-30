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
        // IndividualApplicationId is the PSS native lookup to the process record
        comment.IndividualApplicationId         = input.processId;
        // PSS uses Name as the commenter identity field on PublicComplaint
        comment.Name                            = sanitize(input.commenterName);
        comment.nepa_organization__c            = sanitize(input.organization);
        comment.nepa_category__c                = sanitize(input.category);
        comment.nepa_comment_body__c            = sanitize(input.commentBody);
        comment.nepa_date_submitted__c          = Date.today();
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
            throw new AuraHandledException('Insufficient permissions to submit a comment');
        }
        // sfge-disable-next-line ApexFlsViolation -- isCreateable() guard above + USER_MODE on insert enforces FLS at runtime
        Database.insert(comment, AccessLevel.USER_MODE);
        return comment.Id;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    @SuppressWarnings('PMD.CyclomaticComplexity')
    private static void validateInput(CommentInput input) {
        if (input == null) {
            throw new AuraHandledException('Comment input is required');
        }
        if (String.isBlank(input.processId)) {
            throw new AuraHandledException('processId is required');
        }
        if (String.isBlank(input.commenterName)) {
            throw new AuraHandledException('Commenter name is required');
        }
        if (String.isBlank(input.commentBody)) {
            throw new AuraHandledException('Comment body is required');
        }
        if (input.commentBody.length() > 32000) {
            throw new AuraHandledException('Comment body exceeds maximum length of 32,000 characters');
        }
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
            throw new AuraHandledException('Process not found');
        }

        Date today = Date.today();
        IndividualApplication ia = processes[0];

        Boolean open = (
            ia.nepa_public_comment_period_start__c != null &&
            ia.nepa_public_comment_period_end_date__c != null &&
            ia.nepa_public_comment_period_start__c.date() <= today &&
            ia.nepa_public_comment_period_end_date__c.date() >= today
        );

        if (!open) {
            throw new AuraHandledException('The public comment period for this process is not currently open');
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
