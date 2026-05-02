/**
 * Parses the structured JSON response returned by the NEPA_Comment_Triage_Analysis
 * prompt template into typed fields for deterministic downstream use in the
 * NEPA_Comment_Triage AgentScript agent.
 *
 * Expected JSON shape from the prompt:
 * {
 *   "sentiment": "Opposed",
 *   "is_substantive": true,
 *   "confidence_score": 85,
 *   "cluster_hint": "water quality concern",
 *   "response_status": "Pending",
 *   "triage_rationale": "Substantive: raises specific water quality claim...",
 *   "litigation_threat": false,
 *   "litigation_threat_basis": ""
 * }
 */
global with sharing class NepaCommentTriageParser {

    global class Request {
        @InvocableVariable(label='Triage JSON' description='Raw JSON string returned by the NEPA_Comment_Triage_Analysis prompt template' required=true)
        global String triageJson;
    }

    global class Result {
        @InvocableVariable(label='Sentiment' description='Parsed sentiment: Supportive, Neutral, Opposed, or Mixed')
        global String sentiment;

        @InvocableVariable(label='Is Substantive' description='Parsed substantive determination')
        global Boolean isSubstantive;

        @InvocableVariable(label='Confidence Score' description='Parsed AI confidence score 0-100')
        global Decimal confidenceScore;

        @InvocableVariable(label='Cluster Hint' description='Parsed near-duplicate cluster hint phrase')
        global String clusterHint;

        @InvocableVariable(label='Triage Rationale' description='Parsed triage rationale explaining the substantive determination')
        global String triageRationale;

        @InvocableVariable(label='Parse Success' description='True when JSON was parsed successfully')
        global Boolean parseSuccess;

        @InvocableVariable(label='Parse Error' description='Error message if parsing failed')
        global String parseError;

        @InvocableVariable(label='Litigation Threat' description='True when the comment was identified as a Vermont Yankee issue exhaustion litigation threat')
        global Boolean litigationThreat;

        @InvocableVariable(label='Litigation Threat Basis' description='AI explanation of the specific legal/technical standard cited and the alleged deficiency')
        global String litigationThreatBasis;
    }

    @InvocableMethod(
        label='Parse NEPA Comment Triage JSON'
        description='Parses the structured JSON output from the NEPA_Comment_Triage_Analysis prompt template into typed scalar fields for deterministic use in the Comment Triage agent.'
    )
    global static List<Result> parse(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(parseTriageJson(req));
        }
        return results;
    }

    private static Result parseTriageJson(Request req) {
        Result res = new Result();
        res.parseSuccess = False;
        res.sentiment = 'Neutral';
        res.isSubstantive = False;
        res.confidenceScore = 0;
        res.clusterHint = '';
        res.triageRationale = '';
        res.litigationThreat = False;
        res.litigationThreatBasis = '';

        if (String.isBlank(req.triageJson)) {
            res.parseError = 'triageJson input is blank or null.';
            return res;
        }

        try {
            // Strip markdown code fences if the LLM wrapped the JSON
            String raw = req.triageJson.trim();
            if (raw.startsWith('```')) {
                Integer firstNewline = raw.indexOf('\n');
                Integer lastFence = raw.lastIndexOf('```');
                if (firstNewline > 0 && lastFence > firstNewline) {
                    raw = raw.substring(firstNewline + 1, lastFence).trim();
                }
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(raw);

            if (parsed.containsKey('sentiment') && parsed.get('sentiment') != null) {
                res.sentiment = String.valueOf(parsed.get('sentiment'));
            }

            if (parsed.containsKey('is_substantive') && parsed.get('is_substantive') != null) {
                res.isSubstantive = Boolean.valueOf(String.valueOf(parsed.get('is_substantive')));
            }

            if (parsed.containsKey('confidence_score') && parsed.get('confidence_score') != null) {
                res.confidenceScore = Decimal.valueOf(String.valueOf(parsed.get('confidence_score')));
            }

            if (parsed.containsKey('cluster_hint') && parsed.get('cluster_hint') != null) {
                res.clusterHint = String.valueOf(parsed.get('cluster_hint'));
            }

            if (parsed.containsKey('triage_rationale') && parsed.get('triage_rationale') != null) {
                res.triageRationale = String.valueOf(parsed.get('triage_rationale'));
            }

            if (parsed.containsKey('litigation_threat') && parsed.get('litigation_threat') != null) {
                res.litigationThreat = Boolean.valueOf(String.valueOf(parsed.get('litigation_threat')));
            }

            if (parsed.containsKey('litigation_threat_basis') && parsed.get('litigation_threat_basis') != null) {
                res.litigationThreatBasis = String.valueOf(parsed.get('litigation_threat_basis'));
            }

            // Validate sentiment is a known value; default to Neutral if unexpected
            Set<String> validSentiments = new Set<String>{'Supportive', 'Neutral', 'Opposed', 'Mixed'};
            if (!validSentiments.contains(res.sentiment)) {
                res.sentiment = 'Neutral';
            }

            res.parseSuccess = True;
            res.parseError = '';

        } catch (Exception e) {
            res.parseError = 'JSON parse error: ' + e.getMessage()
                + '. Raw input: ' + req.triageJson.abbreviate(500);
        }

        return res;
    }
}
