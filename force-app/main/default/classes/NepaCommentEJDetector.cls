/**
 * Deterministic keyword gate for Environmental Justice, tribal sovereignty,
 * sacred sites, low-income impact, and civil rights triggers in public comments.
 *
 * Mandate 3: this runs BEFORE any LLM processing. When any trigger category
 * matches, the comment is routed directly to mandatory human review, bypassing
 * AI triage entirely.
 *
 * Designed as an invocable action consumable by Flows and Agentforce agent
 * scripts via the apex:// target.
 */
global with sharing class NepaCommentEJDetector {

    // ── Trigger category keyword maps ────────────────────────────────────────

    private static final Map<String, List<String>> TRIGGER_KEYWORDS = new Map<String, List<String>>{
        'Tribal Sovereignty' => new List<String>{
            'tribe', 'tribal', 'sovereignty', 'treaty rights', 'indigenous',
            'first nation', 'native american', 'american indian', 'pueblo',
            'navajo', 'cherokee', 'lakota', 'sioux', 'cheyenne', 'arapaho',
            'crow nation', 'osage', 'comanche', 'apache', 'federally recognized'
        },
        'Sacred Sites' => new List<String>{
            'sacred site', 'sacred ground', 'sacred land', 'ancestral land',
            'burial ground', 'ceremonial site', 'holy site', 'culturally significant'
        },
        'Environmental Justice' => new List<String>{
            'environmental justice', 'ej community', 'overburdened community',
            'cumulative impact', 'disproportionate impact', 'fence line community',
            'sacrifice zone'
        },
        'Low-Income Impact' => new List<String>{
            'low income', 'low-income', 'poverty', 'affordable housing',
            'public housing', 'disadvantaged community', 'title vi',
            'majority minority', 'communities of color'
        },
        'Civil Rights' => new List<String>{
            'civil rights', 'equal protection', 'disparate impact',
            'discrimination', '14th amendment', 'fair housing', 'title vi',
            'environmental racism'
        }
    };

    // ── Invocable wrapper classes ─────────────────────────────────────────────

    /** Input wrapper for the invocable method. */
    global class Request {
        @InvocableVariable(label='Comment Body' description='The public comment text to scan for EJ and tribal sovereignty triggers' required=true)
        global String commentBody;

        @InvocableVariable(label='Comment Id' description='Optional record Id of the comment for audit logging' required=false)
        global String commentId;
    }

    /** Output wrapper returned by the invocable method. */
    global class Result {
        @InvocableVariable(label='Requires Human Review' description='True when any EJ or tribal sovereignty trigger matched')
        global Boolean requiresHumanReview;

        @InvocableVariable(label='Detected Triggers' description='Comma-separated list of trigger categories found')
        global String detectedTriggers;

        @InvocableVariable(label='Trigger Details' description='Description of what was found and required escalation protocols')
        global String triggerDetails;
    }

    // ── Invocable entry point ─────────────────────────────────────────────────

    @InvocableMethod(
        label='Detect EJ and Tribal Sovereignty Triggers'
        description='Deterministic gate that scans public comment text for Environmental Justice, tribal sovereignty, sacred sites, low-income impact, and civil rights keywords before AI triage. Returns true when mandatory human review is required per federal EJ guidelines.'
    )
    global static List<Result> detect(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(scanComment(req));
        }
        return results;
    }

    // ── Core scanning logic ──────────────────────────────────────────────────

    private static Result scanComment(Request req) {
        Result res = new Result();

        if (String.isBlank(req.commentBody)) {
            res.requiresHumanReview = false;
            res.detectedTriggers = '';
            res.triggerDetails = 'No EJ or tribal sovereignty triggers detected.';
            return res;
        }

        String normalizedBody = req.commentBody.toLowerCase();
        List<String> matchedCategories = new List<String>();

        for (String category : TRIGGER_KEYWORDS.keySet()) {
            List<String> keywords = TRIGGER_KEYWORDS.get(category);
            for (String keyword : keywords) {
                if (normalizedBody.contains(keyword)) {
                    matchedCategories.add(category);
                    break; // one match per category is sufficient
                }
            }
        }

        res.requiresHumanReview = !matchedCategories.isEmpty();
        res.detectedTriggers = String.join(matchedCategories, ', ');

        if (res.requiresHumanReview) {
            res.triggerDetails = 'Mandatory human review required: '
                + res.detectedTriggers
                + '. Comment contains language triggering EJ/tribal sovereignty escalation protocols under federal environmental justice guidelines.';
        } else {
            res.triggerDetails = 'No EJ or tribal sovereignty triggers detected.';
        }

        return res;
    }
}
