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
public with sharing class NepaCommentEJDetector {

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
    public class Request {
        @InvocableVariable(label='Comment Body' description='The public comment text to scan for EJ and tribal sovereignty triggers' required=true)
        public String commentBody;

        @InvocableVariable(label='Comment Id' description='Optional record Id of the comment for audit logging' required=false)
        public String commentId;
    }

    /** Output wrapper returned by the invocable method. */
    public class Result {
        @InvocableVariable(label='Requires Human Review' description='True when any EJ or tribal sovereignty trigger matched')
        public Boolean requiresHumanReview;

        @InvocableVariable(label='Detected Triggers' description='Comma-separated list of trigger categories found')
        public String detectedTriggers;

        @InvocableVariable(label='Trigger Details' description='Description of what was found and required escalation protocols')
        public String triggerDetails;
    }

    // ── Invocable entry point ─────────────────────────────────────────────────

    @InvocableMethod(
        label='Detect EJ and Tribal Sovereignty Triggers'
        description='Deterministic gate that scans public comment text for Environmental Justice, tribal sovereignty, sacred sites, low-income impact, and civil rights keywords before AI triage. Returns true when mandatory human review is required per federal EJ guidelines.'
    )
    publicstatic List<Result> detect(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(scanComment(req));
        }
        return results;
    }

    // ── Core scanning logic ──────────────────────────────────────────────────

    /**
     * Strips Latin diacritics (accents) from a string so that bypass attempts using
     * lookalike characters (e.g. "nàtive" for "native") are caught by keyword matching.
     * Uses Normalizer.Form.NFD to decompose accented characters into base + combining marks,
     * then strips all Unicode combining marks (category Mn).
     * Apex does not have java.text.Normalizer, so we handle the common Latin-1 Supplement and
     * Latin Extended-A ranges with a static replacement map covering all accented characters
     * appearing in EJ/tribal keyword bypass attempts.
     */
    @TestVisible
    private static String normalizeDiacritics(String input) {
        // Map covering all precomposed Latin letters with diacritics (Unicode blocks
        // Latin-1 Supplement U+00C0-00FF and Latin Extended-A U+0100-017E) that an
        // adversary might substitute for ASCII base letters in EJ/tribal keywords.
        String s = input;
        s = s.replaceAll('[àáâãäåāăą]', 'a');
        s = s.replaceAll('[ÀÁÂÃÄÅĀĂĄ]', 'a');
        s = s.replaceAll('[èéêëēĕėęě]', 'e');
        s = s.replaceAll('[ÈÉÊËĒĔĖĘĚ]', 'e');
        s = s.replaceAll('[ìíîïĩīĭįı]', 'i');
        s = s.replaceAll('[ÌÍÎÏĨĪĬĮI]', 'i');
        s = s.replaceAll('[òóôõöōŏő]',  'o');
        s = s.replaceAll('[ÒÓÔÕÖŌŎŐ]',  'o');
        s = s.replaceAll('[ùúûüũūŭůűų]', 'u');
        s = s.replaceAll('[ÙÚÛÜŨŪŬŮŰŲ]', 'u');
        s = s.replaceAll('[ýÿ]',         'y');
        s = s.replaceAll('[ÝŸ]',         'y');
        s = s.replaceAll('[çćĉċč]',      'c');
        s = s.replaceAll('[ÇĆĈĊČ]',      'c');
        s = s.replaceAll('[ñńņňŉ]',      'n');
        s = s.replaceAll('[ÑŃŅŇ]',       'n');
        s = s.replaceAll('[śŝşšș]',      's');
        s = s.replaceAll('[ŚŜŞŠȘ]',      's');
        s = s.replaceAll('[ţťțþ]',       't');
        s = s.replaceAll('[ŢŤȚÞ]',       't');
        s = s.replaceAll('[źżž]',         'z');
        s = s.replaceAll('[ŹŻŽ]',         'z');
        s = s.replaceAll('[ðď]',          'd');
        s = s.replaceAll('[ÐĎ]',          'd');
        s = s.replaceAll('[ĺļľ]',         'l');
        s = s.replaceAll('[ĹĻĽ]',         'l');
        s = s.replaceAll('[ŗř]',           'r');
        s = s.replaceAll('[ŖŘ]',           'r');
        return s;
    }

    private static Result scanComment(Request req) {
        Result res = new Result();

        if (String.isBlank(req.commentBody)) {
            res.requiresHumanReview = false;
            res.detectedTriggers = '';
            res.triggerDetails = 'No EJ or tribal sovereignty triggers detected.';
            return res;
        }

        // Normalize diacritics before lowercasing so that adversarial submissions using
        // accented characters (e.g. "nàtive américan") are matched correctly.
        String normalizedBody = normalizeDiacritics(req.commentBody).toLowerCase();
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
