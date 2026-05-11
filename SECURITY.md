## Security

Please report any security issue to [security@salesforce.com](mailto:security@salesforce.com) as soon as it is discovered. This library limits its runtime dependencies in order to reduce the total cost of ownership as much as can be, but all consumers should remain vigilant and have their security stakeholders review all third-party products (3PP) like this one and their dependencies.

---

## Data Classification

This Accelerator processes federal environmental permitting data. Agencies deploying it should classify records according to their own data governance policies. Fields to review:

- **PII fields**: `Contact` name/email/phone (applicant contacts), `IndividualApplication.nepa_applicant_*` fields, public comment submitter details on `PublicComplaint`
- **CUI candidates**: litigation case details (`nepa_litigation__c`), internal agency scoring outputs (`nepa_litigation_risk_score__c`, `nepa_defensibility_score__c`)
- **Public data**: project descriptions, NOIs, Final EIS/ROD documents once publicly released

No PII is included in the seed/sample data. Test data generation scripts (`scripts/seed-sample-data.apex`) use fictional names and placeholder identifiers.

---

## Authentication and Authorization

This Accelerator does not implement its own authentication. It relies entirely on the Salesforce platform security model:

- **Object and field access** is controlled by the included `NEPA_Permitting` permission set. Assign only to users who need access; do not assign to all users by default.
- **Record-level access** uses Salesforce org-wide defaults and sharing rules. Configure sharing to match your agency's need-to-know requirements before going live.
- **AI features** (Comment Triage Agentforce agent, CE Screening, Litigation Risk Scoring) require Agentforce and Einstein licenses. Review the [AI Use Policy](AI-Use-Policy.md) before enabling these features.
- **External callouts** (GIS proximity checks) use Named Credentials. Review remote site settings and Named Credential configurations before deploying to a production org.

---

## FedRAMP and Government Cloud

For U.S. federal deployments:

- Deploy to **Salesforce Government Cloud Plus** (FedRAMP High authorized) for data classified as CUI or above.
- Salesforce Government Cloud (FedRAMP Moderate) is the minimum for systems handling non-public permitting data.
- Commercial Salesforce orgs are appropriate for development, testing, and non-sensitive pilot use only.
- This Accelerator's metadata is platform-agnostic and deploys to any Salesforce org type. The security posture depends entirely on which Salesforce cloud tier you deploy to.

---

## Known Security Scope Limitations

This Accelerator is a **starting point**, not a production-hardened system. Before go-live, agencies must:

1. **Review and harden sharing rules** — default org-wide sharing settings are not configured by this Accelerator; apply least-privilege sharing appropriate to your agency.
2. **Audit the permission set** — `NEPA_Permitting` grants broad access for accelerator validation; scope it down to the minimum necessary fields for production roles.
3. **Configure Named Credentials** — GIS callout Named Credentials require agency-specific configuration. Do not leave placeholder credentials active.
4. **Conduct a security review** — run Salesforce's Security Health Check and review the org's Security Center before production launch.
5. **Review AI guardrails** — the Comment Triage agent includes EJ/tribal escalation gates and human-in-the-loop requirements; verify these are active before enabling public comment triage in production. See [AI-Use-Policy.md](AI-Use-Policy.md).

---

## Dependency Security

All runtime dependencies are Salesforce-platform-native (Flows, Apex, OmniStudio). There are no npm or third-party runtime packages deployed to the org. The `node_modules/` directory is used only for local development tooling (Jest for LWC tests) and is not deployed.
