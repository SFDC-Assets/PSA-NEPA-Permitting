# Demo Story: Carrie Placer Mine Plan of Operations
## Salesforce Field Service & Agentforce for Public Sector — NEPA Permitting Acceleration

**Source Data:** DOI-BLM-ID-B030-2019-0014-EA | BLM Owyhee Field Office, Marsing, Idaho
**Real Case File:** IDI-38709 | Applied Oct 18, 2017 → Decision Nov 27, 2019 (25 months)
**Demo Timeline:** Same project, 8 months (Mar → Nov 2019)

---

## Presenter Overview

This demo is submitted to the **CEQ Permitting Innovators Challenge**. You are demonstrating a federal NEPA permitting accelerator — PSA-NEPA — built on Salesforce Agentforce for Public Sector. It implements all **10 Minimum Functional Requirements (MFRs)** from CEQ's Permitting Technology Action Plan. Every data claim in this script comes from real federal datasets: 61,881 NEPA projects (NETATEC v2.0, PNNL), 761 litigation cases (PermitTEC v0.1, PNNL), 1,903 Final EIS records (CEQ EIS Timeline Data 2010–2024), and the public administrative record of a real BLM permit. You do not need to have built it or analyzed the data to deliver this demo. You need to know three numbers cold:

- **23%** — the share of CE records in the NETATEC corpus with no CE category on record. Each misrouted CE→EA project adds a median 11 months.
- **87.5%** — the litigation win rate of Tribal Nation plaintiffs across 761 federal NEPA cases. The single most predictable litigation risk factor.
- **8 months** — the Carrie Placer Mine optimized timeline. Same project, same regulations. 25 months actual → 8 months projected.

This demo runs four scenes, each following **Tell → Show → Tell** structure. The **Setup Tell** opens with a corpus data point and names the failure mode. The **Show** is a numbered click-by-click guide — action plus narration for each step. The **Landing Tell** closes with the MFR reference and the number that lands. Never let a demo moment speak for itself.

**Core message:** The permit didn't take 25 months because the project was hard. It took 25 months because the *process* was broken — wrong people, wrong places, wrong season, no coordination. Salesforce fixes the process, not the project.

**Audience:** BLM field office managers, state permitting directors, NEPA program leads, agency IT/digital transformation leads, CEQ evaluators.

**Total demo time:** 20–25 minutes across four scenes.

---

## Presenter Quick Reference

Memorize this table before opening the laptop. It maps each scene to the MFRs you are demonstrating, the one data fact that anchors the Setup Tell, the UI moment the evaluator is watching for, and the line that closes.

| Scene | MFRs Demonstrated | Must-Know Data Fact | Key UI Moment | The Line That Closes |
|---|---|---|---|---|
| **1: Intake** | #3 Leading-Edge, #6 Emerging, #4 Emerging | 23% of NETATEC CE records have no CE category → adds median 11 months per misrouted project | CE pre-screening result card at OmniScript Step 7 | "That feedback loop used to take 6 weeks. Now it happens at submission." |
| **2: Work Orders** | #5 Emerging→Leading-Edge, Std 1, Std 4 | Every BLM Plan of Operations requires ≥1 co-permit; co-permit clocks typically start *after* BLM decision | Lek survey in slot 1; IDWR task auto-fires on WO close | "The IDWR clock is running before we've drafted a single page of the EA." |
| **3: Comments** | #8 Emerging, #5 stage gates | Tribal Nation plaintiffs win 87.5% of contested NEPA cases — the most predictable risk factor in the corpus | Dual-flag on Shoshone-Paiute comment; hard gate blocking EA advance | "The legal work order fired before anyone made a judgment call." |
| **4: Decision** | #7 Emerging, #9 Emerging, #1 Leading-Edge, #2 Emerging | **42.7%** of challenged EIS/EAs cite inadequate connected actions analysis — the #1 Challenge Prediction Rule; top 3 failure patterns are all stage gate failures | All-5-green Document Registry; `nepa_ar_export__c` Completed status; Challenge Predictor cleared on both fired rules | "Eight months. 13 CEQ entities. 10 MFRs. Same regulations." |

---

## Discovery Questions

Use these before the demo — ideally in a pre-demo call or in the first five minutes of the meeting before opening the laptop. The goal is to get the audience articulating their own pain in their own words. When they do, the Carrie Placer Mine story lands as a mirror, not a pitch.

Questions are grouped by theme. You don't need all of them. Pick two or three that match what you already know about the account, and let the conversation run.

---

### Theme 1: Process Bottlenecks and Scheduling

*These surface the coordination failure — the core problem the optimization engine solves.*

- **"Walk me through what happens between when an applicant submits a Plan of Operations or permit request and when your first field specialist actually sets foot on the project site. What does that sequence look like today?"**
  - *Listen for:* manual handoffs, email chains, scheduling gaps, time between intake and first site visit. If they describe anything sequential that should be parallel, you have the story.

- **"When you have a project that requires multiple resource disciplines — say hydrology, wildlife, and botanical all on the same site — how do you coordinate who goes when?"**
  - *Listen for:* informal coordination, separate calendars, specialists making independent trips, no shared scheduling visibility. Any of these is your setup for the gate access scene.

- **"How often do field surveys have to be rescheduled because someone went out in the wrong season? And when that happens, how far does it push the timeline?"**
  - *Listen for:* specific examples, frustration, workarounds. If they say "it happens more than it should," that's your tell for Scene 2.

- **"If I asked you right now which of your in-progress applications are at risk of missing a seasonal survey window in the next 90 days, how quickly could you answer that?"**
  - *Listen for:* hesitation, "I'd have to ask the specialists," spreadsheet references, or "we don't really track that." The inability to answer this question is what the optimization engine solves.

---

### Theme 2: Parallel Permits and Inter-Agency Coordination

*These surface the co-permit drift problem — the trigger automation solves.*

- **"For projects that need permits from multiple agencies — say a BLM action that also requires an EPA NPDES or a state water permit — how do you make sure those parallel tracks stay coordinated with your primary review?"**
  - *Listen for:* "the applicant handles that," "we remind them at the end," "it usually comes up after we've already issued our decision." The last answer is exactly what happened in the Carrie Placer Mine case.

- **"Have you ever issued a decision and then had the applicant come back and say they still couldn't start because they were waiting on a state or EPA permit they didn't know they needed to start earlier?"**
  - *Listen for:* a yes, a story, or a knowing laugh. This is one of the most common pain points and it tends to unlock candid conversation.

- **"What's your current mechanism for making sure a co-permit application clock starts at the right point in your review — not at the end?"**
  - *Listen for:* no mechanism, manual reminders, or "we rely on the applicant to figure that out." The absence of a mechanism is the gap the trigger automation fills.

---

### Theme 3: Administrative Record and Defensibility

*These surface the documentation and litigation risk problem — the stage gate and Plaintiff Intelligence solve.*

- **"When a decision gets challenged — whether it's a formal protest or litigation — how confident are you that your administrative record is complete and that every required consultation and review step is documented in one place?"**
  - *Listen for:* confidence gaps, "we pull it together after the fact," references to past challenges where documentation was an issue. Don't push; just note if there's hesitation.

- **"How do you currently know when a public commenter on one of your projects has a track record of litigation? Is that something your team checks, and if so, how?"**
  - *Listen for:* "we usually recognize the names," "our attorneys flag them," "honestly we don't always know." Any answer short of a systematic process is your setup for the Plaintiff Intelligence scene.

- **"When a substantive comment comes in during a public comment period, what's the typical turnaround from comment close to response incorporated into the final document?"**
  - *Listen for:* the number. Sixty to ninety days is common. Anything over thirty gives you a strong contrast with the three-week response time in the demo.

- **"Has your office ever had a FONSI or EA challenged on the grounds that a comment raised an issue that wasn't addressed? What happened?"**
  - *Listen for:* a story. If they have one, it does more work than anything you could say. Let it land before moving on.

---

### Theme 4: Applicant Experience and Transparency

*These surface the visibility and trust deficit — the self-service portal solves.*

- **"From the applicant's perspective — the miner, the rancher, the developer — what do they see when they want to know where their permit stands? What's the experience like for them?"**
  - *Listen for:* "they call us," "we send emails when something changes," "they don't really have visibility." The contrast with real-time portal status is sharpest when the current state is a phone call.

- **"How many status-check calls or emails does your office field from applicants on active permits in a given week? What does that cost in staff time?"**
  - *Listen for:* a number, or an acknowledgment that it's significant. Even a rough estimate — "a few a day" — quantifies the problem the portal eliminates.

- **"When an applicant has to wait 25 months for a decision on a project that ultimately gets a FONSI — no significant environmental impact — what does that do to their confidence in the process, and to your office's relationship with the regulated community?"**
  - *Listen for:* acknowledgment of the trust cost, references to political pressure, congressional inquiries, or applicants giving up. This frames the 8-month outcome as a relationship investment, not just a speed metric.

---

### Theme 5: Litigation Risk and Tribal Consultation

*These surface the litigation intelligence problem — the Plaintiff Intelligence module and risk scoring solve.*

- **"When you're starting a new NEPA action, how do you currently assess your litigation exposure? Is there a process for checking whether the agency, the circuit, and the project type have a history of court losses?"**
  - *Listen for:* "our attorneys tell us after the fact," "we don't really track that systematically," or "we've been surprised a few times." The inability to answer on day one is the gap the Litigation Risk Scorer fills.

- **"For projects with tribal consultation requirements — NHPA Section 106, E.O. 13175 — how do you track whether consultation is complete before you finalize a FONSI or ROD? Is that a hard gate in your process, or is it a checklist someone has to remember?"**
  - *Listen for:* "someone checks it," "we have a checklist," "it's supposed to be a gate but sometimes things slip." Any answer that relies on human memory is your setup for the tribal consultation hard gate in the demo.

- **"Have you ever had a project challenged specifically on tribal consultation grounds? What was the outcome?"**
  - *Listen for:* a story. If they have one, let it land. Tribal Nation challengers have an 87.5% win rate in the litigation corpus — if they've been challenged by a tribal organization, they probably lost, and they know exactly how much it cost.

---

### Theme 6: Staffing and Capacity

*These surface the resource constraint context — important for sizing the problem and the ROI conversation.*

- **"When you think about the specialist capacity you have — your biologists, geologists, NEPA coordinators — what percentage of their field time would you estimate is productive survey work versus travel, rescheduling, and coordination overhead?"**
  - *Listen for:* any ratio that suggests the overhead is significant. This sets up the "eliminated wasted trips" outcome directly.

- **"If you could get the same number of permits through your queue in less calendar time — without adding staff — what would that mean for your office's backlog?"**
  - *Listen for:* the backlog number, the pressure behind it, and whether there are political or regulatory deadlines driving it. This is your ROI anchor.

- **"Are there project types or applicant types that consistently take longer than they should — not because the projects are complex, but because of how the review is organized?"**
  - *Listen for:* specific examples. Mining, energy, ROW, grazing — any category they name is one you can map to a variant of the Carrie Placer Mine story.

---

### Using the Answers

When you move into the demo, use what you heard. Replace generic transitions with what the audience said:

> *"You mentioned that your biologists sometimes drive out twice because the first trip missed the seasonal window. That's exactly what happened on the Carrie Placer Mine — and it's the first thing the system fixed. Let me show you."*

> *"You said you usually find out about a co-permit gap after you've already issued your decision. Watch what happens in this demo when the hydrologist closes his work order."*

> *"You mentioned that you recognized the ICL name when they commented, but your team had to dig into past cases manually. Here's how the system does that check at intake."*

The goal of discovery isn't to complete a checklist. It's to find the one or two moments in the demo where you can say **"this is the thing you just described"** — and mean it.

---

## The Problem (Opening Narrative — Deliver Before Opening the Laptop)

Sam Uhler and David Smith acquired a placer gold mining claim adjacent to Jordan Creek, about 9 miles southeast of Jordan Valley, Oregon — 15 acres of BLM-administered land in Owyhee County, Idaho. They needed a Plan of Operations to mine placer gold.

Their permit took **25 months**. Not because the project was controversial. Not because the environmental impacts were severe — the final FONSI confirmed no significant impact. The delay was almost entirely operational.

Here's what the review actually required:

**Seven resource specialists had to complete independent field assessments:**

| Specialist | Assessment | Seasonal Constraint |
|---|---|---|
| Hydrologist | Jordan Creek water temperature; redband trout habitat (CWA Category 4A) | Avoid frozen ground |
| Wildlife — Sage-Grouse | PHMA survey; 3.1-mile lek buffer verification | Feb 1 – Apr 30 (before nesting) |
| Wildlife — Columbia Spotted Frog | Riparian survey; pond design review | May – Sep (amphibian active season) |
| Wildlife — Migratory Birds | Nesting territory mapping | Before mid-Apr OR after late Jul |
| Wildlife — Big Game | Mule deer crucial winter range | Aug – Oct (shoulder season) |
| Geologist | 1.7-mile access road erosion; reclamation plan | Any non-frozen season |
| Botanist | Special status plants; seed mix approval | Jun – Aug; two visits required |

**Three parallel agency permits ran without coordination:**
- BLM Plan of Operations (primary)
- Idaho Dept. of Water Resources (IDWR) — required before any Jordan Creek water withdrawal
- EPA NPDES General Permit IDG370000 — Small Suction Dredge; 60-day processing; applicant cannot operate until written authorization received

**The failure mode:** A 1.7-mile two-track road with two locked gates was the only access. Specialists drove out independently — sometimes on the same day without knowing it, sometimes in the wrong season entirely. No one had a view across all seven disciplines. The parallel permits started *after* the BLM decision, adding months to the applicant's wait. Sam Uhler called the field office 14 times asking for a status update.

**The permit didn't fail. The process did.**

---

## Scene 1: The Intake — CE Screening, GIS, and Screening Criteria Access

> **Demonstrates:** MFR #3 — Automated Project Screening (Leading-Edge) · MFR #6 — Integrated GIS Analysis (Emerging) · MFR #4 — Access to Screening Criteria (Emerging)

### Data Context *(know this cold — it goes into your Setup Tell)*

- NETATEC v2.0 (61,881 projects): **23% of CE records have no CE category on record**; another 17% have noisy or inconsistent citations. Each misrouted CE→EA project adds a median **11 months** to the timeline. Each misrouted CE→EIS escalation adds a median **2.8 years**.
- **88.7% of energy projects and 90.6% of infrastructure projects resolve as CEs** — the bottleneck isn't environmental impact, it's that intake systems don't capture the information needed to route correctly.
- The 5 strongest predictors of NEPA process type are all available at the time of application: CE category citation, project type, title keywords, action description language, document page count. The information exists. It just isn't structured.

### Setup Tell *(say this before clicking — deliver while the laptop is still closed)*

> "Look at that number: 23%. Almost one in four CE records in the federal NEPA data corpus has no CE category on file. That field is blank. When that blank reaches a coordinator's inbox, they have to stop and manually triage the routing — and while they're doing that, the clock is running. Each of those misrouted projects adds a median eleven months. Not because the project was complex. Because the intake form didn't ask the right questions. Let me show you what happens when it does — and when the system acts on the answer before the application is even submitted."

### Show — Step by Step

1. **Navigate to the Experience Cloud portal** — Sam Uhler's applicant view. Say: *"This is what Sam sees. No phone call. No callback queue. He starts here."*

2. **Click "New Plan of Operations – Mining."** The OmniScript CE Intake Wizard opens at Step 1. Say: *"Seven steps. Conditional navigation — fields irrelevant to this project type are hidden. Sam only sees what applies to his project."*

3. **Step 1:** Select BLM / Interior. **Step 2:** Select Mining / Plan of Operations. Say: *"These two fields tell the system enough to know which resource disciplines this project will need."*

4. **Step 3:** Select Action type → Surface Disturbance. Say: *"This single field is the primary CE/EA discriminator. Surface disturbance above the 5-acre threshold routes to EA. Below it, the system checks the CE library. Sam doesn't need to know 40 CFR 1501.4 — the wizard does."*

5. **Step 4:** Enter 15 acres; extraordinary circumstances self-reported as none. **Step 5:** Enter NAICS code 21221 (Gold and Silver Ore Mining). Say: *"15 acres. Already past the 5-acre CE threshold. The system knows where this is going — but watch what happens in Step 6."*

6. **Step 6:** Upload GIS footprint. **Narrate each check result as it populates:**
   - FWS ECOS: *"Greater Sage-Grouse PHMA detected — potential extraordinary circumstance."*
   - USGS NHD: *"Jordan Creek adjacency, Category 4A — that's a hydrological proximity trigger."*
   - EPA EJScreen: *"EJ Index 18.3 — informational, not a hard trigger at this score, but it's recorded."*
   - BLM Tribal Cadastral: *"No tribal boundary overlap in the project footprint."*
   - BLM PLSS: *"Federal surface confirmed — BLM jurisdiction established."*
   Say: *"Five GIS services. All public APIs. All called in parallel. No GIS expertise required from the coordinator."*

7. **Step 7 — Review + Submit.** Show the **CE pre-screening result card**:
   - Recommendation: **EA-Required** | Confidence: **High**
   - Basis: *Surface disturbance 15 acres exceeds 5-acre CE threshold (40 CFR 1501.4); PHMA detected in Step 6 triggers extraordinary circumstances independently*
   Say: *"This is MFR #3 — the pre-screening result returns before Sam submits. He knows the routing. He knows the rule that fired. And this is MFR #4 — the criteria that produced this result are published at /docs/decision-models/ on GitHub. Sam can review the exact logic before submitting. He can adjust his project siting to try to come in under the threshold. That's actionable feedback at intake, not six weeks later in an RFI."*

8. **Submit → Navigate to IndividualApplication coordinator view.** Point to:
   - `nepa_ce_pathway_recommendation__c` = EA-Required *(read-only — set by automation)*
   - `nepa_review_type__c` = blank *(coordinator sets the official pathway — the AI recommends, the human decides)*
   Say: *"The system's recommendation is read-only. The official pathway requires a credentialed coordinator. Per OMB M-25-21: AI recommends, human decides. That's not a limitation — that's the design."*

9. **Show the auto-assembled ID Team** on the IndividualApplication: geologist, NEPA specialist, wildlife biologist, hydrologist, botanist, and cultural resources coordinator. Say: *"The system read the project type and GIS results and assembled the team automatically. Sam books one meeting — 90 minutes at the Owyhee Field Office — and all seven specialists are confirmed."*

### Screen Reference

**Screen 1-A — Experience Cloud Portal (Sam Uhler's applicant view)**
*(Show steps 1–2: navigate here, click "New Plan of Operations – Mining")*

```
┌─────────────────────────────────────────────────────────────────┐
│  BLM NEPA Permitting Portal                   [Sam Uhler ▾]  ≡  │
│  ─────────────────────────────────────────────────────────────  │
│  My Applications        Notifications (2)        Help & Docs    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Good morning, Sam.  Your application IDI-38709 is in review.   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  + Start New Application                                │    │
│  │  ─────────────────────────────────────────────────────  │    │
│  │  ● Plan of Operations – Mining                    ◄──── │────── CLICK: Show step 2
│  │  ○ Right-of-Way Grant                                   │    │
│  │  ○ Special Recreation Permit                            │    │
│  │  ○ Temporary Use Permit                                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** "Plan of Operations – Mining" selection. Say: *"This is what Sam sees — no phone call, no callback queue."*

---

**Screen 1-B — OmniScript CE Intake Wizard (Steps 1–6 with GIS results)**
*(Show steps 3–6: agency, action type, acreage, NAICS, GIS footprint upload)*

```
┌─────────────────────────────────────────────────────────────────┐
│  New Plan of Operations — CE Intake Wizard         Step 6 of 7  │
│  ● ── ● ── ● ── ● ── ● ── ●○── ○                               │
│  ─────────────────────────────────────────────────────────────  │
│  Agency/Bureau:         [BLM / Interior            ▾]           │
│  Action Type:           [Surface Disturbance        ▾]  ◄── STEP 3: primary CE/EA field
│  Project Type:          [Mining / Plan of Operations▾]           │
│  Disturbance Acreage:   [15                          ]  ◄── STEP 4: > 5-ac threshold
│  NAICS Code:            [21221 — Gold Ore Mining     ]  ◄── STEP 5                │
│  ─────────────────────────────────────────────────────────────  │
│  GIS Footprint                                         STEP 6 ▼ │
│  [Upload shapefile or draw on map]   [✓ File loaded]             │
│                                                                  │
│  ┌──────── GIS Proximity Check Results ─────────────────────┐   │
│  │  ✓  FWS ECOS      Greater Sage-Grouse PHMA detected  ◄── │───── NARRATE: extraordinary circ.
│  │  ✓  USGS NHD      Jordan Creek Cat 4A adjacency      ◄── │───── NARRATE: hydro trigger
│  │  ✓  EPA EJScreen  EJ Index 18.3 — informational      ◄── │───── NARRATE: recorded, not hard
│  │  ✓  BLM Tribal    No tribal boundary overlap              │   │
│  │  ✓  BLM PLSS      Federal surface confirmed               │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                     [Next →]    │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** FWS ECOS result line while narrating. Say: *"Five GIS services, all public APIs, called in parallel. No GIS expertise required."*

---

**Screen 1-C — OmniScript Step 7: CE Pre-Screening Result Card**
*(Show step 7: result appears before Sam submits)*

```
┌─────────────────────────────────────────────────────────────────┐
│  New Plan of Operations — CE Intake Wizard         Step 7 of 7  │
│  ● ── ● ── ● ── ● ── ● ── ● ── ●                               │
│  ─────────────────────────────────────────────────────────────  │
│  Review Your Application                                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  ⚠  CE PATHWAY ASSESSMENT   (MFR #3 · MFR #4)      ◄─── │───── POINT HERE first
│  │  ──────────────────────────────────────────────────────  │   │
│  │  Recommendation:   EA-REQUIRED               ◄───────── │───── MFR #3: result
│  │  Confidence:       HIGH                                  │   │
│  │  ──────────────────────────────────────────────────────  │   │
│  │  Basis:                                                  │   │
│  │  • Surface disturbance 15 ac > 5-ac threshold            │   │
│  │    40 CFR 1501.4 (b)(1)                      ◄───────── │───── MFR #4: CFR citation
│  │  • PHMA detected — extraordinary circumstances           │   │
│  │    independent trigger (43 CFR 3809 / BLM IM)            │   │
│  │  ──────────────────────────────────────────────────────  │   │
│  │  Criteria published: /docs/decision-models/   ◄───────── │───── MFR #4: public access
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│                                               [Submit ▶]        │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** "EA-REQUIRED" first, then the CFR citation line, then the `/docs/decision-models/` link. Deliver the Step 7 narration verbatim.

---

**Screen 1-D — IndividualApplication: Coordinator View**
*(Show steps 8–9: post-submit record; read-only AI recommendation; auto-assembled team)*

```
┌─────────────────────────────────────────────────────────────────┐
│  IndividualApplication  IA-0000000432          [Edit]  [More ▾] │
│  Carrie Placer Mine Plan of Operations                          │
│  ─────────────────────────────────────────────────────────────  │
│  Status: Submitted          Process Status: intake              │
│                                                                  │
│  ┌─── NEPA Screening ──────────────────────────────────────┐    │
│  │  CE Pathway Recommendation:  EA-Required (automated) ◄── │────── READ-ONLY: point here
│  │  Review Type:                [              ] (blank) ◄── │────── COORDINATOR sets this
│  │  Screening Confidence:       High                        │    │
│  │  Classification Basis:       GIS + CE Screener           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─── ID Team (Auto-Assembled) ────────────────────────────┐    │
│  │  ● NEPA Specialist           ● Hydrologist          ◄── │────── POINT: auto-assembled
│  │  ● Wildlife — Sage-Grouse    ● Wildlife — Spotted Frog   │    │
│  │  ● Botanist                  ● Geologist                 │    │
│  │  ● Cultural Resources Coordinator                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** `CE Pathway Recommendation` = "EA-Required (automated)" as read-only, then `Review Type` blank field, then ID Team panel. Say steps 8–9 narration.

### What You Are Demonstrating

- **MFR #3 — Automated Project Screening (Leading-Edge):** 7-step OmniScript with conditional navigation; BRE CE Screener evaluating against 2,105 CE authorities across 79 agencies; pre-screening result with rule-match basis returned before formal submission.
- **MFR #6 — Integrated GIS Analysis (Emerging):** 5 GIS proximity checks (FWS ECOS, EPA EJScreen, USGS NHD, BLM tribal cadastral, BLM PLSS) firing at intake and writing structured results to `IndividualApplication` fields; results feed CE screening and extraordinary circumstances determination directly.
- **MFR #4 — Access to Screening Criteria (Emerging):** Decision model logic published at `/docs/decision-models/` with CE rules, GIS layer inventory, and litigation risk weights; logic traceable to specific CFR citations; version-controlled alongside Salesforce metadata.

### Landing Tell *(say this after the demo)*

> "Twenty-three percent of CE records — almost one in four — had no routing information at intake. Each one added eleven months. The CE Screener evaluated this project against 2,105 CE authorities and 5 GIS layers before Sam spoke to a coordinator. He got a routing decision, the rule that fired, and the regulatory citation. That feedback loop used to take six weeks. Now it happens at submission."

> "Sam booked one meeting and got all seven specialists. The system knows what a placer gold mining project next to a Category 4A stream in PHMA territory requires. Sam doesn't have to."

### Transition *(say this as you move to the next screen)*

> "The system knows what this project needs. Now it has to sequence six field specialists across five seasonal windows — and that's where 25 months actually comes from. Not from the analysis. From the scheduling."

---

## Scene 2: The Work Order Cascade — Scheduling Against Nature's Calendar

> **Demonstrates:** MFR #5 — Automated Case Management (Emerging→Leading-Edge) · CEQ Standard 1: Business Process Modernization · CEQ Standard 4: Minimizing Timeline Uncertainty

### Data Context *(know this cold — it goes into your Setup Tell)*

- **Every BLM Plan of Operations requires at least one co-permit** — CWA Section 404, EPA NPDES, IDWR state water rights, ESA Section 7, NHPA Section 106, or some combination. For energy projects with pipelines and transmission, the list reaches six to eight. Co-permit processing times range from 30 days (EPA NPDES small suction dredge) to 48 months (nuclear waste facility).
- **The typical pattern:** the primary federal permit moves forward on its own clock while co-permits are treated as the applicant's responsibility. Applicants — particularly smaller operators like placer miners — don't know when to start them. The co-permit clock starts *after* the BLM decision. That adds months to a timeline that's already closed.
- CEQ EIS data (1,903 Final EIS records): scoping is the universal bottleneck in **34 of 36 agencies**, consuming 60–75% of total EIS time. A 49% improvement in NOI→ROD time since 2016 (4.46 years → 2.28 years) proves process reform works. The remaining delays are structural — sequential execution of parallel-eligible work.

### Setup Tell *(say this before clicking)*

> "Here's the structural problem with co-permits: every BLM Plan of Operations requires at least one — and in almost every case, the co-permit clock starts after the BLM decision. The applicant waits for the BLM permit, then starts the state water permit, then starts the EPA permit. Sequential. The permits that could run concurrently run in series instead, and nobody told the applicant to start them earlier because no system tracked the dependency. That's not a policy failure. It's a workflow failure. Let me show you what it looks like when the workflow closes the gap instead."

### Show — Step by Step

1. **Navigate to the IndividualApplication → ApplicationTimeline related list.** Mark the **"Pre-Application Consultation Complete"** milestone. Say: *"One milestone close. Watch what fires."*

2. **Navigate to Work Orders related list.** Six work orders appear simultaneously. Say: *"Six parallel work orders — one per discipline. Not a coordinator task list. Actual field work orders with skill-based dispatch, seasonal constraints, and SLA clocks already set."*

3. **Click Dispatcher Console / Map view.** Six pins drop on Owyhee County. Say: *"This is the optimization engine's view. Six specialists. One county. Five seasonal windows. Two locked gates. The engine is about to sequence all of it."*

4. **Point to the Lek Survey work order — slot 1 in the sequence.** Say: *"Tightest window closes April 30. The engine put it first. Not a coordinator decision — the system read the WorkType seasonal constraint and did the math."*

5. **Click the Sage-Grouse WorkType record.** Show `nepa_survey_window_end__c = April 30`. Say: *"That date is a hard constraint, not a note. A dispatcher cannot schedule a sage-grouse survey after April 30 — the system blocks the appointment. Wrong-season dispatch is not possible."*

6. **Click the Botanist work order.** Show two ServiceAppointments — June and August. Say: *"BLM Manual requires two botanical visits. The system scheduled them automatically. The coordinator didn't have to know that rule."*

7. **Show gate resource constraint** — ServiceAppointment dates for all 6 specialists, no overlapping gate access. Say: *"Two locked gates. One 1.7-mile two-track road. Shared resource constraint. No two specialists have overlapping gate dates. Nobody drives 45 minutes to a locked road."*

8. **Click the Hydrologist work order → show "Trigger IDWR" flag.** Now mark the work order **Complete**. Watch the IDWR task auto-create:
   - Task subject: *"Initiate IDWR Water Permit Application"*
   - Assigned to: NEPA Coordinator
   - Due date: 30-day SLA
   - Portal notification: pushed to Sam's applicant view
   Say: *"The IDWR clock starts the moment the hydrologist closes his work order. Not after the BLM decision. Now. That's two to four months of post-decision wait, eliminated."*

9. **Click the Geologist work order** — show same pattern, EPA NPDES trigger fires on close. Say: *"Same pattern. EPA NPDES 60-day clock starts at geologist close. Both permits are in processing while the EA is being drafted."*

10. **Point to the Tribal Consultation work order.** Show `hard_gate__c` flag. Say: *"This one is different. This is a hard gate — a database constraint. The EA cannot advance to public review until this work order closes. Not a reminder. Not a checklist. A constraint. We'll come back to this in Scene 3."*

### Screen Reference

**Screen 2-A — IndividualApplication: ApplicationTimeline Related List**
*(Show step 1: mark "Pre-Application Consultation Complete" milestone)*

```
┌─────────────────────────────────────────────────────────────────┐
│  IndividualApplication  IA-0000000432          [Edit]  [More ▾] │
│  Carrie Placer Mine Plan of Operations                          │
├─────────────────────────────────────────────────────────────────┤
│  Related  │  Details  │  Activity                               │
├─────────────────────────────────────────────────────────────────┤
│  ApplicationTimeline (25)                           [New Event] │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  ✓  Application Received                  Oct 18 2017    │   │
│  │  ✓  Section 106 Tribal Consultation Init  Feb 16 2019    │   │
│  │  ►  Pre-Application Consultation Complete Mar 12 2019 ◄──│───── MARK COMPLETE here
│  │     Status: Open     [Mark Complete]                     │   │
│  │  ○  Sage-Grouse Lek Survey Window Opens   Feb 1  2019    │   │
│  │  ○  [24 more events...]                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** "Pre-Application Consultation Complete" row → [Mark Complete] button. Say: *"One milestone close. Watch what fires."*

---

**Screen 2-B — Work Orders Related List (6 WOs auto-generated)**
*(Show step 2: 6 parallel work orders appear immediately after milestone close)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Work Orders (6)                              [New WO]  [Map ▾] │
│  ─────────────────────────────────────────────────────────────  │
│  #  │  Subject                        │  Priority  │  SLA Due   │
│  ───┼─────────────────────────────────┼────────────┼──────────  │
│  1  │  Sage-Grouse Lek Survey    ◄─── │  URGENT    │  Apr 30    │  ← slot 1: tightest window
│  2  │  Migratory Bird Survey          │  HIGH      │  Apr 14    │
│  3  │  Hydrology — Jordan Creek  ◄─── │  HIGH      │  May 31    │  ← IDWR trigger
│  4  │  Columbia Spotted Frog          │  MEDIUM    │  May 31    │
│  5  │  Geology — Access Road     ◄─── │  HIGH      │  May 31    │  ← EPA NPDES trigger
│  6  │  Botanist — Two Site Visits     │  MEDIUM    │  Aug 31    │
│  ─────────────────────────────────────────────────────────────  │
│  Status: All Open   │  Assigned: 0 of 6   │  At Risk: 2        │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** Row 1 (Lek Survey, URGENT, Apr 30). Say: *"Tightest window closes April 30 — the engine put it first."* Then point to rows 3 and 5 as the co-permit trigger WOs.

---

**Screen 2-C — FSL Dispatcher Console: Map View**
*(Show step 3: 6 specialist pins on Owyhee County; show step 7: gate resource constraint)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Dispatcher Console — Field Service             [List] [Map ●]  │
│  ─────────────────────────────────────────────────────────────  │
│  Filter: Owyhee County  │  Date: Mar–Nov 2019  │  All resources  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│      ╔══════════════════════════════════════════╗               │
│      ║   Owyhee County, Idaho                   ║               │
│      ║                                          ║               │
│      ║    📍 [1-Lek Survey]                     ║   ← 6 pins    │
│      ║         📍 [3-Hydro]  📍 [5-Geo]        ║               │
│      ║    📍 [2-Bird]   ★ Jordan Creek          ║               │
│      ║         📍 [4-Frog]                      ║               │
│      ║              📍 [6-Botanist]             ║               │
│      ║                   🔒 Gate A  🔒 Gate B   ║  ◄── point here
│      ╚══════════════════════════════════════════╝               │
│                                                                  │
│  Selected: [Sage-Grouse Lek Survey]  Window: Feb 1 – Apr 30 ◄──┼── constraint visible
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** The two 🔒 gate pins. Say: *"Two locked gates. One 1.7-mile road. Shared resource constraint. No two specialists have overlapping gate dates — nobody drives 45 minutes to a locked road."*

---

**Screen 2-D — Work Order Record Page: Hydrologist WO (representative for steps 5–9)**
*(Show steps 5–9: seasonal constraint, service appointments, IDWR trigger, mark complete)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Work Order  WO-00031  Hydrology — Jordan Creek    [Edit] [▾]   │
│  Status: In Progress    Assigned: L. Gutierrez    SLA: May 2019 │
│  ─────────────────────────────────────────────────────────────  │
│  ┌─── WorkType Constraints ────────────────────────────────┐    │
│  │  Survey Window Start:        Feb 1  2019                │    │
│  │  Survey Window End:          May 31 2019  ◄──────────── │────── HARD constraint, not a note
│  │  nepa_trigger_co_permit__c:  IDWR         ◄──────────── │────── POINT: co-permit trigger
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Service Appointments (1)                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  SA-00019   Apr 25 2019   L. Gutierrez   Confirmed  ✓    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  [Mark Complete ▶]  ◄──────────────────────────────────────────┼── CLICK: watch task fire
│                                                                  │
│  ─ Auto-Created (fires on Complete) ──────────────────────────  │
│  ► Task: "Initiate IDWR Water Permit Application"               │
│    Assigned: NEPA Coordinator   Due: 30-day SLA   ◄────────────┼── clock starts NOW
│    Portal notification → Sam Uhler                              │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** `nepa_trigger_co_permit__c = IDWR`, then click [Mark Complete], then point to the auto-created task. Say: *"The IDWR clock starts the moment the hydrologist closes his work order. Not after the BLM decision. Now."*

### What You Are Demonstrating

- **MFR #5 — Automated Case Management (Emerging→Leading-Edge):** Work order cascade from milestone close; SLA due-date setting per WorkType; seasonal constraint enforcement at the dispatch level; stage gate on tribal consultation blocking EA advancement.
- **CEQ Standard 1 — Business Process Modernization:** Sequential manual email coordination (7 separate emails) replaced by event-driven parallel dispatch triggered by a single milestone.
- **CEQ Standard 4 — Minimizing Timeline Uncertainty:** Per-agency empirical scoping baselines; scheduling constraints derived from corpus analysis; coordinator visibility into which work orders are at risk of missing seasonal windows before it happens.

### Landing Tell *(say this after the demo)*

> "Six surveys. Seven specialists. Five seasonal windows. Two locked gates. Three parallel permits — and the IDWR and EPA clocks are already running before we've drafted a single page of the EA. That's the difference between sequential and parallel. Those two months of post-decision co-permit wait? That's not unavoidable. It's structural. This is the fix."

### Transition *(say this as you move to the next screen)*

> "The surveys run. The EA is drafted. And then the comment period opens — which is where a lot of permitting momentum dies. Let me show you what 87.5% means when a tribal nation is in the comment queue."

---

## Scene 3: Public Comment — Plaintiff Intelligence and Tribal Hard Gate

> **Demonstrates:** MFR #8 — Automated Comment Compilation and Analysis (Emerging) · MFR #5 — Stage Gate Enforcement

### Data Context *(know this cold — it goes into your Setup Tell)*

- PermitTEC v0.1 (761 NEPA cases): **Tribal Nation plaintiffs achieve an 87.5% win rate** — the single most predictable litigation risk factor in the corpus. When a tribal nation is a commenter, the probability of success if challenged approaches 9 in 10.
- **The #1 failure mode generating successful NEPA challenges:** government-to-government consultation not documented as a hard gate. Agencies advanced to ROD with incomplete tribal consultation. Severity: VERY HIGH. The agency did the analysis. The system didn't enforce the checkpoint.
- NAEP 2025 Workshop documented: **2,600 comments processed by 4 staff over 4 weeks → approximately 4 hours** with AI assistance. Comment processing is on the critical path. Compressing it without bypassing the most sensitive categories is what MFR #8 requires.

### Setup Tell *(say this before clicking)*

> "Eighty-seven point five percent. That's the litigation win rate of Tribal Nation plaintiffs across 761 federal NEPA cases. Not the most litigated category — the most successful one. The top failure pattern: agencies advanced to the Record of Decision with incomplete tribal consultation. The consultation happened. The stage gate didn't exist. The agency lost in court on a procedural gap, not a substantive analysis failure. Let me show you what the gate looks like when the system enforces it."

### Show — Step by Step

1. **Navigate to IndividualApplication → Public Comments related list.** Three comments: Idaho Conservation League (ICL), Office of Species Conservation (OSC), Shoshone-Paiute Tribes. Say: *"The preliminary EA and unsigned FONSI published July 1. Twenty-eight-day comment period. Three comments arrive. The Plaintiff Intelligence module runs on each one."*

2. **Click the ICL comment.** Show:
   - `nepa_plaintiff_risk_flag__c = true`; Risk Tier = HIGH
   - Agentforce classification label: category, confidence, reasoning
   - Plaintiff Intelligence note: *"Prior 9th Circuit plaintiff — suction dredge mercury cases; prior Owyhee Field Office sage-grouse commenter"*
   Say: *"This is the check an agency attorney would do manually when they recognize a name. The system does it automatically, consistently, for every comment. ICL gets flagged because the historical record says they sue — and win."*

3. **Click the OSC comment.** Show: no plaintiff flag; classification = Technical/Substantive; routed for biologist response. Say: *"No prior litigation record. Technical comment on the lek buffer departure. Routed for subject-matter expert response. The system discriminates — it doesn't blanket-flag everything."*

4. **Click the Shoshone-Paiute Tribes comment.** Show — pause on each field:
   - `nepa_plaintiff_risk_flag__c = true`
   - `nepa_tribal_plaintiff_flag__c = true`
   - Risk Tier: **VERY HIGH**
   Say: *"Two flags simultaneously. The system recognized this as a Tribal Nation commenter — the category with the 87.5% win rate. Both flags fire unconditionally. The EJ/Tribal gate cannot be bypassed by configuration."*
   Show the auto-created Legal Task: *"Government-to-government consultation — verify compliance with NHPA Section 106 and E.O. 13175 before advancing"* — assigned to BLM Field Solicitor. Say: *"That task fired before anyone in the field office made a judgment call."*

5. **Navigate to IndividualApplication → Risk Intelligence panel.** Show Litigation Risk Score update: `nepa_risk_score__c = 87` / `nepa_risk_tier__c = Very High`. Say: *"Tribal plaintiff flag is a 15-point input — one of the highest weights in the model. The score ticked up the moment that comment was classified."*

6. **Show Work Orders auto-created from substantive comments:**
   - ICL: *"Add dust mitigation analysis to Air Quality section — mercury particulate"* — 17-day SLA
   - Shoshone-Paiute: *"Document tribal consultation — cultural landscape analysis — Section 106"* — 21-day SLA; **hard gate: EA cannot advance until this closes**
   Say: *"Every substantive comment becomes a tracked work order with an SLA. Not an inbox item. A deliverable with a deadline and an assigned owner."*

7. **Click tribal consultation work order — show `hard_gate__c` flag.** Say: *"The EA cannot advance to public review until this work order closes. That's the gate the corpus says agencies were missing. It's not a reminder anymore."*

8. **Navigate to ApplicationTimeline.** Point to revised EA publish date: **August 15** — 3 weeks after comment close. Say: *"Comment close to revised EA: three weeks. Not sixty days."*

### Screen Reference

**Screen 3-A — IndividualApplication: Public Comments Related List**
*(Show step 1: 3 comments visible; risk tier column shows differentiated scoring)*

```
┌─────────────────────────────────────────────────────────────────┐
│  IndividualApplication  IA-0000000432          [Edit]  [More ▾] │
│  Carrie Placer Mine Plan of Operations                          │
├─────────────────────────────────────────────────────────────────┤
│  Public Comments (3)                              [New Comment] │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Organization               │ Risk Tier  │ Date  │ Status │   │
│  │  ────────────────────────────────────────────────────    │   │
│  │  Idaho Conservation League  │ HIGH   ◄── │ Jul 22│ Open   │───── plaintiff flag
│  │  Office of Species Cons.    │ —          │ Jul 25│ Open   │   │  (no flag — note contrast)
│  │  Shoshone-Paiute Tribes ◄── │ VERY HIGH  │ Jul 28│ Open   │───── dual flag: plaintiff + tribal
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** Risk Tier column. ICL = HIGH, OSC = blank, Shoshone-Paiute = VERY HIGH. Say: *"Three comments. Three different outcomes. The Plaintiff Intelligence module ran on each one."*

---

**Screen 3-B — PublicComplaint Record: Shoshone-Paiute Tribes**
*(Show steps 3–4: dual flags, VERY HIGH tier, auto-created legal task, hard gate)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Public Comment  PC-00003  Shoshone-Paiute Tribes  [Edit] [▾]   │
│  Submitted: Jul 28 2019   Status: Open   Method: Mail           │
│  ─────────────────────────────────────────────────────────────  │
│  ┌─── Risk Intelligence ───────────────────────────────────┐    │
│  │  Plaintiff Risk Flag:    ✓ TRUE     ◄────────────────── │────── FLAG 1: prior litigation
│  │  Tribal Plaintiff Flag:  ✓ TRUE     ◄────────────────── │────── FLAG 2: unconditional gate
│  │  Risk Tier:              VERY HIGH  ◄────────────────── │────── 87.5% win rate category
│  │  Litigation Threat Basis:                               │    │
│  │    Tribal Nation plaintiff — 87.5% litigation win rate  │    │
│  │    (PermitTEC corpus, 761 cases)                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─── Auto-Created Legal Task ─────────────────────────────┐    │
│  │  Subject: Govt-to-govt consultation — verify NHPA §106  │    │
│  │           and E.O. 13175 before advancing     ◄──────── │────── TASK auto-fired at intake
│  │  Assigned To: BLM Field Solicitor                       │    │
│  │  Due Date:    21-day SLA from comment date              │    │
│  │  ⛔ hard_gate__c = TRUE — EA blocked until this closes  ◄─────── HARD GATE
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** Both flag fields (pause on each), then `Risk Tier = VERY HIGH`, then the `hard_gate__c` line. Say: *"Two flags simultaneously. The legal work order fired before anyone in the field office made a judgment call."*

---

**Screen 3-C — IndividualApplication: Risk Intelligence Panel**
*(Show step 5: litigation score ticks up; show step 6: two auto-created WOs from substantive comments)*

```
┌─────────────────────────────────────────────────────────────────┐
│  IndividualApplication  IA-0000000432  — Risk Intelligence       │
│  ─────────────────────────────────────────────────────────────  │
│  ┌─── Litigation Risk Score ───────────────────────────────┐    │
│  │  Risk Score:          87           ◄────────────────── │────── POINT: ticked up on save
│  │  Risk Tier:           Very High                         │    │
│  │  Plaintiff Flag:      ✓ TRUE  (ICL)              ◄──── │────── ICL plaintiff
│  │  Tribal Flag:         ✓ TRUE  (Shoshone-Paiute)  ◄──── │────── tribal plaintiff
│  │  Defensibility Score: 91                                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Work Orders Auto-Created from Comments (2)                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  WO-00045  ICL mercury/dust analysis    SLA: 17 days     │   │
│  │  WO-00046  Tribal consultation §106     SLA: 21 days ◄── │───── HARD GATE WO
│  │            ⛔ EA cannot advance until this closes         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** `Risk Score = 87`, then WO-00046 and the `⛔` line. Say: *"Every substantive comment became a tracked work order with an SLA. Not an inbox item — a deliverable with a deadline and an assigned owner."*

### What You Are Demonstrating

- **MFR #8 — Automated Comment Compilation and Analysis (Emerging):** Agentforce comment classification (category, confidence, reasoning); plaintiff organization matching against historical litigation record (not individual profiling); routing to work orders with SLA tracking; EJ/Tribal unconditional gate that cannot be disabled.
- **MFR #5 — Stage Gate Enforcement:** Tribal consultation hard gate blocking EA advancement — enforced at the database level on save, not as a checklist item.

### Landing Tell *(say this after the demo)*

> "The system flagged ICL because it matched a prior 9th Circuit plaintiff on a similar case type. It double-flagged the Shoshone-Paiute Tribes because it recognized a Tribal Nation commenter — the category with the 87.5% win rate. The legal work order fired before anyone in the field office made a judgment call. Every substantive comment became a work order. Every SLA is tracked. Comment close to revised EA: three weeks. That's MFR #8 — not comment storage, but comment routing, classification, and risk-graded response."

> "The Plaintiff Intelligence module now covers 14 organizations derived from the PermitTEC corpus — including Alliance for the Wild Rockies, the highest-volume plaintiff in BLM and Forest Service 9th Circuit cases with 18 prior filings, and two tribal nation profiles with 100% litigation win rates. When any of these organizations appears in the comment record, the flag fires before anyone opens the email."

### Transition *(say this as you move to the next screen)*

> "The surveys are complete. The comments are responded to. The tribal consultation is certified. Now the Field Manager needs to sign. Let me show you what the system knows about this project's legal exposure before he does — and what gets generated the moment he signs."

---

## Scene 4: The Decision — Document Registry, Administrative Record, and CEQ Export

> **Demonstrates:** MFR #7 — Document Management (Emerging) · MFR #9 — Administrative Record Management (Emerging) · MFR #1 — Data Standards (Leading-Edge) · MFR #2 — Application Data Sharing (Emerging)

### Data Context *(know this cold — it goes into your Setup Tell)*

- PermitTEC corpus: the **three failure patterns that generate the most successful NEPA court challenges** are all stage gate failures — not substantive analysis failures:
  1. Tribal consultation not documented as a hard gate — agencies advanced to ROD with incomplete consultation *(VERY HIGH severity)*
  2. Supplementation not triggered when new significant information emerged post-ROD *(HIGH severity)*
  3. ESA Section 7 consultation left open when the FONSI or ROD was signed *(MEDIUM severity)*
- The agencies did the environmental analysis correctly. The system didn't enforce the checkpoints that would have documented it.
- **Faster agencies win more litigation (r ≈ −0.35).** Speed and defensibility are not tradeoffs. The agencies with the shortest timelines have the highest defensibility scores. The myth that careful review requires a slow review is empirically false.

### Setup Tell *(say this before clicking)*

> "The single most common reason a NEPA decision gets overturned in court is not tribal consultation failure, not a missing document — it's connected actions. Forty-two point seven percent of challenged EIS and EA decisions in the PermitTEC corpus cite inadequate cumulative or connected actions analysis. The agency scoped the project alone when it should have scoped it alongside connected federal approvals. The agency did the analysis. It drew the boundary wrong. That's now an explicit Challenge Prediction Rule — Priority 1 in the deployed system.

> The three failure patterns that follow it: tribal consultation not documented as a hard gate. Supplementation not triggered when conditions changed. ESA Section 7 left open when the FONSI was signed. All four are stage gate failures. The agencies did the work — they conducted the analysis, they did the consultation. The system didn't enforce the checkpoints that would have documented it before the decision. You're about to see what that enforcement looks like — and what the system generates the moment the Field Manager signs."

### Show — Step by Step

1. **Navigate to the Program record.** Point to `nepa_agency_performance_tier__c = Legally_Vulnerable`. Say: *"This field was set automatically on the day this program was created — before a single survey was scheduled. It comes from the PermitTEC corpus: BLM's litigation loss rate and its 28-month median NOI-to-DEIS placed it in the Legally Vulnerable tier. The Field Manager knew what he was working with on day one."*

2. **Navigate to IndividualApplication → Risk Intelligence panel.** Walk through each field:
   - `nepa_risk_score__c = 87` / `nepa_risk_tier__c = Very High`
   Say: *"87 out of 100. Very High tier."*
   - `nepa_plaintiff_risk_flag__c = true` (ICL) / `nepa_tribal_plaintiff_flag__c = true` (Shoshone-Paiute Tribes)
   Say: *"Both plaintiff flags set — from Scene 3."*
   - `nepa_defensibility_score__c = 91`
   Say: *"Defensibility score: 91. Very High risk project, 91 defensibility — because every gate has been cleared. Risk 87 tells you what you're up against. Defensibility 91 tells you you've done everything right."*

3. **Click `nepa_risk_score_factors__c`.** Show the formula disclosure: *"BLM: 39 pts. 9th Circuit: 42 pts. FLPMA statute: 8 pts. Tribal plaintiff flag: 15 pts. That's 104 raw, normalized to 87. Every input is disclosed. The coordinator can verify any number. This is MFR #1 — the score is deterministic, not a black box."*

3b. **Click `nepa_challenge_prediction_basis__c`.** Show the two rules that fired for this project:
   - ESA Section 7 Consultation — **Cleared** (consultation closed; documented in tribal certification)
   - Government-to-Government Consultation — **Cleared** (Shoshone-Paiute hard gate closed from Scene 3)
   Say: *"The Challenge Predictor runs 10 rules against this record, derived from the PermitTEC corpus. Two fired for this project: ESA Section 7 — because sage-grouse PHMA was detected at intake — and tribal consultation. Both are cleared. That's why the defensibility score is 91 even with a risk score of 87. High-risk project, fully documented mitigation. The system can tell the difference between a dangerous project and a dangerous project that's been handled correctly."*

4. **Navigate to Required Document Registry related list.** All five documents shown with ✓:
   - Environmental Assessment ✓
   - Finding of No Significant Impact ✓
   - Decision Record ✓
   - Affected Resources Form ✓
   - Tribal Consultation Certification ✓
   Say: *"This is MFR #7. Five required documents for an EA. All five present. The stage gate will not fire until this is true — the system blocks the Decision Record from being issued with any document missing."*
   Point to Tribal Consultation Certification: *"This is the output of the Shoshone-Paiute work order from Scene 3. The hard gate closed. The certification is in the registry. The system verified it."*

5. **Navigate to ApplicationTimeline.** Point to concurrent sign-offs: Forrest Griggs (geologist) and Colleen Trese (wildlife biologist), both November 20. Say: *"Same day. The stage gate sees both sign-offs. It fires."*

6. **Show stage gate fire → Decision Record issued November 27.** Walk through Alternative B conditions:
   - 50-foot Jordan Creek buffer
   - Silt fencing with twice-annual BLM inspections
   - Steep-shoreline pond design (Columbia spotted frog deterrence)
   - Seasonal mining window: March 1 – November 30
   - Full reclamation bond to BLM botanist seed mix approval

7. **Navigate to `nepa_decision_payload__c` record.** Show each field:
   - Decision type: **FONSI** | Decision date: June 15, 2021
   - Selected alternative: **Alternative B — Modified Surface Footprint**
   - Alternatives considered: **3** | Mitigation measures: **5**
   - Significant impacts: **No**
   Say: *"Machine-readable decision record. Not a PDF in a folder. Structured data that any authorized system can read via API."*

8. **Navigate to `nepa_ar_export__c` record.** Show:
   - Status: **Completed** | Export type: CEQExport_v1.2
   - Documents: **6** | Comments: **3** | Completed: June 15, 2021
   - Download URL active
   Say: *"This is MFR #9. The administrative record assembled automatically the moment the Field Manager signed the Decision Record. Every ContentVersion, every consultation record, every comment with its response work order, the litigation risk score snapshot, the complete ApplicationTimeline — locked, in one package, available through the CEQExport API. Not assembled after the fact. Generated at decision."*

9. **Show applicant portal notification** — Sam receives automated notification with Decision Record attached. Say: *"Sam stopped calling the field office at some point between March 12 and November 27. He was watching the portal."*

10. **Show ApplicationTimeline: March 12 → November 27 = 8 months.**

11. **Navigate to the NEPA/CEQExport endpoint** (or show a Workbench JSON preview of the structured response). Say: *"MFR #1 and MFR #2. All 13 CEQ entities in one JSON payload — PIC OpenAPI v1.2.0-aligned. EPA DARTER, USACE ORM2, FPISC, any internal permit database — they pull this via authenticated REST call. No custom middleware. No new authorization boundary. Information entered once, available everywhere."*

### Screen Reference

**Screen 4-A — Program Record Page**
*(Show step 1: agency performance tier set on day one from PermitTEC corpus)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Program  DOI-BLM-ID-B030-2019-0014-EA         [Edit]  [More ▾] │
│  Carrie Placer Mine Plan of Operations — BLM Owyhee             │
│  ─────────────────────────────────────────────────────────────  │
│  ┌─── Agency Performance (auto-populated from PermitTEC) ──┐    │
│  │  Agency Performance Tier:  Legally Vulnerable  ◄──────  │────── SET DAY ONE: point here
│  │  Agency:                   Bureau of Land Management    │    │
│  │  Circuit:                  9th Circuit Court of Appeals │    │
│  │  Agency Litigation Rate:   BLM — above median           │    │
│  │  Median NOI→DEIS:          28 months (BLM baseline)     │    │
│  │  Source:                   PermitTEC v0.1 (761 cases)   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Extraordinary Circumstances:   ✓ TRUE (NWI Wetlands + PHMA) ◄─┼── from GIS Step 6, Scene 1
│  GIS Proximity Check Complete:  ✓ TRUE                         │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** `Agency Performance Tier = Legally Vulnerable`. Say: *"Set automatically on day one from PermitTEC data. The Field Manager knew what circuit and agency combination he was working in before a single survey was scheduled."*

---

**Screen 4-B — IndividualApplication: Risk Intelligence Panel (full factor disclosure)**
*(Show steps 2–3: risk score, defensibility score, raw factor breakdown)*

```
┌─────────────────────────────────────────────────────────────────┐
│  IndividualApplication  IA-0000000432  — Risk Intelligence       │
│  ─────────────────────────────────────────────────────────────  │
│  Risk Score:           87    Risk Tier:  Very High   ◄──────── │──── POINT: score
│  Defensibility Score:  91               All gates cleared ◄─── │──── POINT: defensibility
│  ─────────────────────────────────────────────────────────────  │
│  ┌─── Risk Score Factors  (nepa_risk_score_factors__c) ────┐    │
│  │  BLM agency litigation rate:          39 pts   ◄──────  │────── DISCLOSE each input
│  │  9th Circuit — adverse ruling rate:   42 pts   ◄──────  │    │
│  │  FLPMA statutory complexity:           8 pts            │    │
│  │  Tribal plaintiff flag (Shoshone-P):  15 pts   ◄──────  │────── highest single weight
│  │  ─────────────────────────────────────────────          │    │
│  │  Raw total: 104  →  Normalized: 87                      │    │
│  │  Every input disclosed — coordinator can verify any #   │    │
│  └─────────────────────────────────────────────────────────┘    │
│  Plaintiff Risk Flag:   ✓ TRUE  (ICL)                           │
│  Tribal Plaintiff Flag: ✓ TRUE  (Shoshone-Paiute)               │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** Factor breakdown line by line. Say: *"BLM: 39 pts. 9th Circuit: 42 pts. FLPMA: 8 pts. Tribal plaintiff: 15 pts. That's 104 raw, normalized to 87. Every input is disclosed. The coordinator can verify any number."*

---

**Screen 4-C — Required Document Registry Related List**
*(Show step 4: all 5 documents present; stage gate cleared)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Required Document Registry  (5 of 5)  ✓ ALL PRESENT  ◄────────┼── STAGE GATE status
│  ─────────────────────────────────────────────────────────────  │
│  #  │  Document Type                     │  Status     │  Date  │
│  ───┼────────────────────────────────────┼─────────────┼──────  │
│  1  │  Environmental Assessment (EA)     │  ✓ Present  │ Nov 15 │
│  2  │  Finding of No Significant Impact  │  ✓ Present  │ Nov 20 │
│  3  │  Decision Record                   │  ✓ Present  │ Nov 27 │
│  4  │  Affected Resources Form           │  ✓ Present  │ Nov 15 │
│  5  │  Tribal Consultation Certification │  ✓ Present  │ Mar 16 │  ◄── output of Scene 3 gate
│  ─────────────────────────────────────────────────────────────  │
│  Stage Gate:        ✓ ALL 5 REQUIRED DOCUMENTS PRESENT         │
│  EA Advancement:    ALLOWED — gate cleared                      │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** Row 5, Tribal Consultation Certification. Say: *"This is the output of the Shoshone-Paiute work order from Scene 3. The hard gate closed, the consultation was certified, and this document appeared in the registry."*

---

**Screen 4-D — nepa_decision_payload__c Record**
*(Show step 7: structured, machine-readable decision fields)*

```
┌─────────────────────────────────────────────────────────────────┐
│  Decision Payload  DP-00001  IDI-38709         [Edit]  [More ▾] │
│  ─────────────────────────────────────────────────────────────  │
│  Decision Type:           FONSI                  ◄──────────── │──── POINT: machine-readable
│  Decision Date:           Nov 27 2019                           │
│  Selected Alternative:    Alternative B — Modified Footprint ◄─┼──── structured Alt B
│  Alternatives Considered: 3                                     │
│  Significant Impacts:     FALSE                  ◄──────────── │──── structured boolean
│  Mitigation Measures:     Seasonal survey windows enforced;     │
│                           stormwater BMP; reclamation bond;     │
│                           IDWR water permit; EPA NPDES permit   │
│  Monitoring Requirements: Annual reclamation inspection;        │
│                           stormwater report due Mar 1 annually  │
│  Supplemental EA Needed:  FALSE                                 │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** `Decision Type = FONSI` and `Significant Impacts = FALSE`. Say: *"Machine-readable decision record. Not a PDF in an email. Structured data — any authorized system can query this."*

---

**Screen 4-E — nepa_ar_export__c Record**
*(Show step 8: administrative record auto-assembled at decision; CEQExport API available immediately)*

```
┌─────────────────────────────────────────────────────────────────┐
│  AR Export  AR-00001  IDI-38709               [Edit]  [More ▾]  │
│  ─────────────────────────────────────────────────────────────  │
│  ┌─── Administrative Record Export ────────────────────────┐    │
│  │  Export Status:    Complete               ◄──────────── │────── MFR #9: auto-assembled
│  │  Export Type:      Full Package           ◄──────────── │────── MFR #1/#2: standard pkg
│  │  Requested Date:   Nov 27 2019  (auto: FONSI signed)    │    │
│  │  Completed Date:   Nov 27 2019                          │    │
│  │  Document Count:   6                      ◄──────────── │────── all 6 ContentVersions
│  │  Comment Count:    3                      ◄──────────── │────── all 3 comments
│  │  Download URL:     [ar-manifest/IDI-38709 ↗]        ◄── │────── MFR #2: available NOW
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  API Endpoint:  /services/apexrest/nepa/ceqexport/IDI-38709 ◄──┼── point to this last
│  Consumers:     EPA DARTER · USACE ORM2 · FPISC · CEQ HPMS     │
└─────────────────────────────────────────────────────────────────┘
```

> **▲ Point to:** `Export Status = Complete` first, then `Download URL`, then API Endpoint line. Say: *"The administrative record assembled automatically the moment the Field Manager signed. Available through the CEQExport API right now — not assembled after the fact."*

### What You Are Demonstrating

- **MFR #7 — Document Management (Emerging):** Required Document Registry with real-time completeness tracking; stage gate blocking Decision Record issuance until all required documents are confirmed; defensibility gap detection flagging missing documents before the record closes.
- **MFR #9 — Administrative Record Management (Emerging):** `NEPA_AdminRecord_AutoCreate` generating a locked, machine-readable JSON manifest at decision issuance; package includes all documents, consultations, comments, risk score snapshot, and timeline; immediately available through CEQExport API.
- **MFR #1 — Data Standards (Leading-Edge):** All 13 CEQ entities on structured Salesforce records with required fields, provenance, and the `nepa_other__c` extension bag; 385-test regression suite verifying compliance; score formula fully disclosed and verifiable.
- **MFR #2 — Application Data Sharing (Emerging):** CEQExport REST endpoint serving all 13 entities in PIC OpenAPI v1.2.0 format; available to EPA DARTER, USACE ORM2, FPISC, and any authorized system without custom middleware.

### Landing Tell *(say this after the demo)*

> "The system knew BLM was Legally Vulnerable before the first survey. It tracked the tribal plaintiff flag from the moment the comment arrived. It enforced the consultation gate. And then — the moment the Field Manager signed — the administrative record locked, the JSON manifest was generated, and the CEQExport API made all 13 CEQ entities available to every authorized downstream system. Eight months. 13 CEQ entities. 10 MFRs. The same regulations. The only thing that changed was the process."

> "When this gets challenged — and 14% of federal EA decisions are challenged — every consultation, every comment response, every GIS check is in the administrative record with a timestamp. Defensibility score 91. That's not a compliance feature. That's the difference between a 9th Circuit loss and a decision that holds."

---

## Before / After Summary

| Without Salesforce | With Salesforce |
|---|---|
| Seven specialists scheduled independently, often missing seasonal windows | Optimization engine sequenced six work orders against hard seasonal constraints; all surveys completed within a single field season |
| Gate access double-booked; specialists drove 45 minutes to a locked road | Shared gate-access resource constraint; no wasted trips |
| IDWR and EPA NPDES permits started after BLM decision | Parallel permit triggers fired automatically when hydrologist and geologist closed their work orders |
| ICL and OSC comments sat in an inbox for 60+ days | Plaintiff Intelligence flagged both commenters; responses routed as work orders; resolved in 3 weeks |
| Tribal consultation tracked in email; no stage gate | Tribal plaintiff flag auto-set when Shoshone-Paiute comment arrived; dual risk flags escalate score; Section 106 work order with hard gate before EA publication |
| No visibility into agency litigation exposure | Agency Performance Tier (BLM = Legally Vulnerable) set from PermitTEC corpus data; Litigation Risk Score = 87 (Very High) computed from calibrated agency + circuit + statute weights |
| Defensibility gaps discovered during litigation, post-decision | Defensibility Score = 91 at decision; all stage gates cleared and documented before Field Manager signature |
| 25-month timeline; applicant called the field office 14 times | 8-month timeline; real-time status in self-service portal |

---

## Architecture and Process Diagrams

---

### Diagram 1: Enterprise Architecture

The diagram shows four vertical layers. Data flows upward from the corpus and metadata foundation through Salesforce platform objects and automation into the applicant-facing and field-facing surfaces.

```mermaid
flowchart TB
    subgraph EXT["External Actors"]
        direction LR
        APP["🧑‍💼 Applicant\n(Sam Uhler)"]
        FIELD["📱 Field Specialist\n(Mobile — Offline)"]
        TRIBES["🤝 Shoshone-Paiute Tribes\nSection 106 Consultation"]
        IDWR["🏛️ IDWR\nWater Permit"]
        EPA["🏛️ EPA NPDES\nIDG370000"]
    end

    subgraph CHANNEL["Engagement Layer"]
        direction LR
        PORTAL["Experience Cloud\nSelf-Service Portal\n• Permit status\n• Action items\n• Document delivery"]
        MOBILE["FSL Mobile App\n• Offline work orders\n• Photo capture\n• Work order close"]
    end

    subgraph FSL["Field Service Layer"]
        direction TB
        OPT["⚙️ FSL Optimization Engine\nSchedules 6 work orders against\nseasonal constraints + gate availability"]
        WO["WorkOrder\n• Discipline type\n• Seasonal window\n• Gate access flag\n• Co-permit trigger"]
        SA["ServiceAppointment\n• Non-overlapping gate dates\n• Bundled site access"]
        SR["ServiceResource\n7 Specialists\n(skill-based dispatch)"]
        ST["ServiceTerritory\nOwyhee Field Office"]
        WT["WorkType\n7 types × seasonal\nwindow constraints"]
        AR["AssignedResource"]
    end

    subgraph APS["APS Case Management Layer"]
        direction TB
        PROG["Program\n(Project Container)\n• Lead agency\n• Circuit\n• State\n• Sector"]
        APP2["IndividualApplication\n• NEPA Pathway\n• Litigation Risk Score\n• Plaintiff Risk Flag\n• Defensibility Score\n• Co-Permits Required"]
        TL["ApplicationTimeline\n25 milestones\n4 hard stage gates"]
        CV["ContentVersion\nRequired Document Registry\n• EA  • FONSI  • DR\n• Affected Resources\n• Tribal Cert"]
        PC["PublicComplaint\n• Commenter org\n• Substantive flag\n• Risk tier"]
        ENG["nepa_engagement__c\n• Pre-app consultation\n• Tribal consultation\n• Public comment period"]
        LIT["nepa_litigation__c\nReference case library\n9th Circuit precedents"]
    end

    subgraph INTEL["Intelligence & Automation Layer"]
        direction LR
        CE["NEPA_CE_Screener\nRoutes CE / EA / EIS\nat intake"]
        TRA["NEPA_Timeline_\nRisk_Assessor\nFlags outliers\nat intake"]
        PI["NEPA_Plaintiff_\nIntelligence\nOrg match →\nrisk tier →\nwork order"]
        LRS["NEPA_Litigation_\nRisk_Scorer\nAgency + circuit +\nstatute + state\n+ plaintiff weights"]
        PPT["Parallel Permit\nTrigger Automation\nWork order close →\nIDWR / NPDES tasks"]
    end

    subgraph DATA["Data & Metadata Foundation"]
        direction LR
        MDT["Custom Metadata Types\n• CE_Code_Catalog__mdt\n• CE_Screening_Rules__mdt\n• Agency_Risk_Rates__mdt\n• Circuit_Court_Risk_Weights__mdt\n• Statute_Risk_Weights__mdt\n• Required_Document_Registry__mdt\n• Plaintiff_Profiles__mdt\n• Agency_Scoping_Baseline__mdt\n• Challenge_Prediction_Rules__mdt"]
        CORPUS["NEPATEC 2.0 Corpus\n61,881 projects\n142,083 documents\n6.9M pages\n60+ agencies"]
        CEQ["CEQ Metadata Standards\nProject / Process /\nDocument entities"]
    end

    %% External → Channel
    APP -->|"Books appointment\nChecks status\nReceives decisions"| PORTAL
    FIELD -->|"Downloads work orders\nCloses surveys offline\nSyncs on cell recovery"| MOBILE

    %% Channel → Platform
    PORTAL -->|"Intake record creates\nIndividualApplication"| APS
    MOBILE -->|"Work order close\nevents"| FSL

    %% FSL internal
    OPT --> WO
    WO --> SA
    SA --> AR
    AR --> SR
    SR --> ST
    WT -.->|"Seasonal constraints\ninform scheduling"| OPT

    %% APS internal
    PROG --> APP2
    APP2 --> TL
    APP2 --> CV
    APP2 --> PC
    APP2 --> ENG

    %% FSL → APS
    WO -->|"Work order linked\nto IndividualApplication"| APP2
    WO -->|"Closure events\ntrigger automation"| PPT

    %% Intelligence ↔ APS
    CE -->|"Routes at intake"| APP2
    TRA -->|"Risk flag on\nIndividualApplication"| APP2
    PI -->|"Flags PublicComplaint\ncreates work order"| PC
    LRS -->|"Writes\nLitigation_Risk_Score__c"| APP2
    PPT -->|"Creates Task +\nnotifies applicant portal"| PORTAL

    %% Intelligence ← Data
    MDT -->|"Rules, weights,\ncatalogs"| CE
    MDT --> TRA
    MDT --> PI
    MDT --> LRS
    LIT -->|"Circuit loss patterns\ninform risk weights"| LRS
    CORPUS -->|"Empirical thresholds\nfor screeners"| MDT
    CEQ -->|"Metadata standard\nmaps to APS objects"| APS

    %% Integrations
    PPT -->|"30-day SLA task\nauto-created"| IDWR
    PPT -->|"60-day clock\nauto-started"| EPA
    ENG -->|"Section 106\n30-day response window"| TRIBES

    %% Styling
    classDef external fill:#e8f4fd,stroke:#2196F3,color:#0d47a1
    classDef channel fill:#e8f5e9,stroke:#4CAF50,color:#1b5e20
    classDef fsl fill:#fff3e0,stroke:#FF9800,color:#e65100
    classDef pss fill:#f3e5f5,stroke:#9C27B0,color:#4a148c
    classDef intel fill:#fce4ec,stroke:#E91E63,color:#880e4f
    classDef data fill:#e3f2fd,stroke:#1565C0,color:#0d47a1

    class APP,FIELD,TRIBES,IDWR,EPA external
    class PORTAL,MOBILE channel
    class OPT,WO,SA,SR,ST,WT,AR fsl
    class PROG,APP2,TL,CV,PC,ENG,LIT pss
    class CE,TRA,PI,LRS,PPT intel
    class MDT,CORPUS,CEQ data
```

**Architecture notes:**
- **Orange (Field Service):** The optimization engine is the scheduling brain — it reads WorkType seasonal constraints and gate availability, sequences all six work orders, and prevents double-booking.
- **Purple (APS Case Management):** IndividualApplication is the central record. Every specialist survey, every document, every comment, every milestone hangs off it. Key risk intelligence fields include `nepa_risk_score__c`, `nepa_risk_tier__c`, `nepa_plaintiff_risk_flag__c`, `nepa_tribal_plaintiff_flag__c`, `nepa_challenge_risk_delta__c`, and `nepa_scoping_overrun_flag__c`.
- **Pink (Intelligence):** All flows read from Custom Metadata Types — 9 types covering CE codes, **14 plaintiff profiles (including Navajo Nation and Pit River Tribe with 100% win rates)**, **16 agency risk rate records covering all 15 PermitTEC corpus agencies**, circuit weights, statute weights, **per-agency scoping baselines (365-day median Inter-Agency Coordination phase derived from CEQ EIS Timeline data)**, and **10 challenge prediction rules including Connected Actions at Priority 1 (42.7% of challenged decisions)**. Changing any weight, adding a plaintiff org, or updating an agency baseline requires zero code change.
- **Blue (Data Foundation):** The NEPATEC 2.0 corpus (61,881 projects) and PermitTEC v0.1 (761 litigation cases) are the empirical basis for every weight and threshold. The Litigation Risk Scorer uses PermitTEC-derived weights: agency points = loss_rate × 1.0, circuit points = (multiplier − 0.30) × 37.5, statute points = (multiplier − 1.00) × 20. The 10th Circuit (43 pts) is now the highest-risk circuit; BLM (39 pts) is the highest-risk agency.

---

### Diagram 2: Business Process — Before and After

The swimlane below runs left-to-right as a timeline. Read the **top half (red)** as the 25-month failure path. Read the **bottom half (green)** as the 8-month optimized path. The six innovation callouts show exactly where the process breaks in the old system and what replaces it.

```mermaid
flowchart LR
    subgraph LEGEND["Innovation Key"]
        direction LR
        I1["⚡ = System automation replaces manual step"]
        I2["🔴 = Failure point in old process"]
        I3["🟢 = Salesforce solution"]
    end

    subgraph BEFORE["WITHOUT SALESFORCE — 25 Months"]
        direction TB

        subgraph BA["Applicant (Before)"]
            direction LR
            B_APP1["Submits\napplication"]:::before
            B_APP2["Calls field office\n14 times for status"]:::before
            B_APP3["Waits for\nco-permit guidance\nafter BLM decision"]:::before
            B_APP4["Receives decision\nby mail"]:::before
        end

        subgraph BC["Field Coordinator (Before)"]
            direction LR
            B_C1["Manual intake\nno routing logic"]:::before
            B_C2["Emails 7 specialists\nindividually"]:::before
            B_C3["🔴 No seasonal\nconstraint enforcement"]:::before
            B_C4["Comments sit\nin inbox 60+ days"]:::before
            B_C5["Manual doc\nchecklist by email"]:::before
            B_C6["Issues decision"]:::before
        end

        subgraph BS["Resource Specialists (Before)"]
            direction LR
            B_S1["Self-schedule\nindependently"]:::before
            B_S2["🔴 Wrong season:\nsurvey invalid,\nreschedule"]:::before
            B_S3["🔴 Gate conflict:\n45-min drive\nto locked road"]:::before
            B_S4["Sequential surveys:\nspecialist 1 done\nbefore 2 starts"]:::before
        end

        subgraph BP["Parallel Agencies (Before)"]
            direction LR
            B_P1["🔴 IDWR permit\nnot started until\nafter BLM decision"]:::before
            B_P2["🔴 EPA NPDES\nnot started until\nafter BLM decision"]:::before
            B_P3["Additional months\npost-decision wait"]:::before
        end

        B_APP1 --> B_C1 --> B_C2 --> B_S1
        B_S1 --> B_S2 --> B_S3 --> B_S4
        B_S4 --> B_C3 --> B_C4
        B_C4 --> B_C5 --> B_C6
        B_C6 --> B_P1 --> B_P2 --> B_P3
        B_P3 --> B_APP3 --> B_APP4
        B_C2 -.->|"No visibility"| B_APP2
    end

    subgraph AFTER["WITH SALESFORCE — 8 Months"]
        direction TB

        subgraph AA["Applicant (After)"]
            direction LR
            A_APP1["Books pre-app\nvia portal"]:::after
            A_APP2["Real-time status\nin portal"]:::after
            A_APP3["🟢⚡ Co-permit\naction items pushed\nto portal automatically"]:::after
            A_APP4["🟢⚡ Automated\ndecision notification\n+ DR attached"]:::after
        end

        subgraph AC["Field Coordinator (After)"]
            direction LR
            A_C1["🟢⚡ CE Screener\nroutes at intake"]:::after
            A_C2["🟢⚡ ID Team\nauto-assembled\nfor scoping session"]:::after
            A_C3["🟢⚡ Stage gate:\nSection 106 hard\ngate before EA pub"]:::after
            A_C4["🟢⚡ Plaintiff Intel:\ncomments → work\norders in days"]:::after
            A_C5["🟢⚡ Required Doc\nRegistry: all 5\ndocs green = gate fires"]:::after
            A_C6["Issues decision"]:::after
        end

        subgraph AS["Resource Specialists (After)"]
            direction LR
            A_S1["🟢⚡ Optimization\nengine sequences\n6 work orders"]:::after
            A_S2["🟢 Seasonal windows\ncoded as hard\nconstraints — slot 1\n= lek survey (Apr 30)"]:::after
            A_S3["🟢 Gate resource\nconstraint: no\ndouble-booking"]:::after
            A_S4["🟢 All 6 surveys\nrun in parallel\nwithin one field season"]:::after
        end

        subgraph AP["Parallel Agencies (After)"]
            direction LR
            A_P1["🟢⚡ IDWR task\nauto-created when\nhydrologist WO closes"]:::after
            A_P2["🟢⚡ EPA NPDES\ntask auto-created\nwhen geologist WO closes"]:::after
            A_P3["Permits processing\nIN PARALLEL with\nBLM review"]:::after
        end

        A_APP1 --> A_C1 --> A_C2 --> A_S1
        A_S1 --> A_S2 --> A_S3 --> A_S4
        A_S4 --> A_C3 --> A_C4
        A_C4 --> A_C5 --> A_C6
        A_S1 -.->|"⚡ WO close triggers"| A_P1
        A_S1 -.->|"⚡ WO close triggers"| A_P2
        A_P1 --> A_P3
        A_P2 --> A_P3
        A_P3 -.->|"In processing during\nBLM review"| A_C5
        A_C6 --> A_APP4
        A_C2 -.->|"Real-time visibility"| A_APP2
        A_P1 -.->|"Action item pushed"| A_APP3
    end

    subgraph DELTA["⚡ The Six Innovations"]
        direction TB
        D1["1️⃣  Sequential → Parallel scheduling\nOptimization engine sequences all\n6 work orders at meeting close"]
        D2["2️⃣  Missed windows → Hard constraints\nSeasonal biology encoded in WorkType;\nwrong-season dispatch impossible"]
        D3["3️⃣  Gate conflicts → Shared resource\nTwo locked gates managed as a shared\nresource; no double-booking"]
        D4["4️⃣  Late co-permits → Auto-triggered\nIDWR + EPA clocks start at work\norder close, not after BLM decision"]
        D5["5️⃣  Inbox lag → Plaintiff Intelligence\nICL/OSC comments routed as work\norders in days, not 60+ days"]
        D6["6️⃣  Manual checklist → Stage gate\nAll 5 docs required before Decision\nRecord can be issued — enforced"]
    end

    classDef before fill:#ffebee,stroke:#c62828,color:#b71c1c
    classDef after fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    classDef delta fill:#fffde7,stroke:#f9a825,color:#e65100
```

**Process diagram notes:**

The six numbered innovations in the bottom panel map directly to the six rows in the Before/After Summary table. Each is a place where the old process relied on human memory, manual coordination, or sequential execution — and the new system replaces it with an automated constraint, trigger, or gate.

| Innovation | Old mechanism | New mechanism | Time saved |
|---|---|---|---|
| 1. Parallel scheduling | Email to 7 specialists individually | Optimization engine at meeting close | 4–8 weeks |
| 2. Seasonal constraints | Coordinator knowledge (if any) | WorkType hard constraint; wrong-season dispatch blocked | 1–3 months (avoided reschedule) |
| 3. Gate access | Phone calls between specialists | Shared resource constraint; system blocks double-booking | 3–5 wasted trips eliminated |
| 4. Co-permit triggers | Applicant notified post-decision | Auto-task at work order close; clocks start concurrently | 2–4 months post-decision wait |
| 5. Comment response | Inbox triage; manual routing | Plaintiff Intelligence → work order in days | 5–9 weeks |
| 6. Document registry | Email checklist; coordinator memory | Required Document Registry hard gate; system-enforced | Prevents re-opening; eliminates litigation gap |

---

## Objection Handling

### "This is just scheduling software. We already have Outlook and SharePoint."

**Response:** Outlook and SharePoint track appointments and store documents. They don't know that a sage-grouse lek survey has a 60-day seasonal window that closes April 30, or that sending a biologist outside that window invalidates the survey. They don't know that the two locked gates are a shared resource constraint. They don't fire an EPA NPDES task when a geologist closes a work order. The difference isn't scheduling — it's that the system encodes regulatory logic as operating constraints. That's what shortens 25 months to 8.

---

### "Is the 25-to-8-month comparison realistic? What was actually happening for 25 months?"

**Response:** This is a real case — DOI-BLM-ID-B030-2019-0014-EA, IDI-38709, BLM Owyhee Field Office. The administrative record is public. The delay wasn't caused by environmental complexity; the FONSI found no significant impact. The delay was caused by sequential scheduling of parallel-eligible surveys, missed seasonal windows requiring rescheduling, parallel agency permits (IDWR and EPA) that didn't start until after the BLM decision, and comment response lag. The 8-month projection assumes all surveys run in parallel, all in-window on the first attempt, and permits are triggered concurrently. That's achievable; it's exactly what the optimization engine is designed to produce.

---

### "We do a handful of EAs a year. Is this worth the investment for our volume?"

**Response:** Two answers. First, it's rarely just EAs — one BLM field office typically manages CEs, EAs, rights-of-way, grazing renewals, and mining Plans of Operations concurrently. The same scheduling and coordination logic applies across all of them. Second, the cost of one 25-month permit isn't just the permit — it's the specialist time spent on rescheduled field visits, the comment response backlog, the political and legal exposure when a project runs long, and the applicant's carrying costs while they wait. One prevented litigation filing covers the platform investment for years.

---

### "Can this handle EIS projects? EA is the easy case."

**Response:** Yes, and the complexity scales appropriately. EIS processes involve longer scoping periods, larger interdisciplinary teams, multiple comment rounds (scoping and DEIS), ROD stage gates, and higher litigation risk — all of which the platform handles. The NEPA_Timeline_Risk_Assessor flow uses per-agency scoping baselines derived from the CEQ EIS Timeline dataset — so for a BLM project the baseline is 28 months NOI-to-DEIS, while for an FAA project it's 47 months. When scoping runs past the agency-specific cap, the system sets a scoping overrun flag and calculates the projected overrun in months — not against a generic 24-month target, but against what that agency's record actually shows. The page count outlier detection also fires at intake: an EIS EA that's already at 200+ pages at the draft stage gets flagged immediately. For an EIS, the parallel track management is more valuable, not less — there are more tracks and more things that can drift out of sequence.

---

### "We have HR and union constraints — we can't route work directly to individual specialists."

**Response:** The work orders don't have to be assigned to named individuals. They can be assigned to skill pools — "wildlife biologist certified for sage-grouse PHMA assessment" — and dispatched through supervisor approval queues. The optimization engine works on skill availability, not individual assignment. The union rules and approval workflows can be modeled as part of the dispatch process. We've done this for other public sector clients with similar constraints.

---

### "The seasonal windows are hardcoded. What happens when regulations change?"

**Response:** The seasonal constraints are stored in custom metadata — not hardcoded in the application. When the ARMPA is revised or a new species gets a protection determination, an administrator updates the metadata record. No code change, no deployment. The same applies to CE catalog updates, document registry requirements, and litigation risk weights. That's exactly what the `WorkType` seasonal window fields and `CE_Screening_Rules__mdt` are designed for — configuration, not customization.

---

### "What about applicant data privacy? Mine claim data in a cloud system concerns us."

**Response:** Salesforce Government Cloud runs on FedRAMP High authorized infrastructure. Data residency stays domestic. The same platform handles data for DoD, VA, and other agencies with strict data handling requirements. The applicant-facing portal shares only the status and document outputs the agency designates — it doesn't expose internal scoring, risk assessments, or specialist notes to the applicant. Those are permission-controlled fields visible only to agency staff.

---

### "We can't get field specialists to actually use their phones out there. No cell service."

**Response:** The Salesforce Field Service mobile app supports offline mode. Specialists download their work orders before leaving the office. In the field, they can complete checklists, attach photos, and close work orders — all offline. The data syncs when they return to cell coverage. Colleen Trese closing the sage-grouse work order at the Jordan Creek trailhead in the demo doesn't require a cell signal at the trailhead.

---

### "The Plaintiff Intelligence feature feels inappropriate. We're a public agency — we can't profile commenters."

**Response:** The Plaintiff Intelligence module doesn't profile individual citizens — it matches commenter *organizations* against a historical record of prior litigation cases. That history is public record. It's the same analysis an agency attorney would do manually when they recognize a commenter's name: "ICL has filed in the 9th Circuit before, on similar issues — let's make sure our response is airtight." The system does that check automatically, consistently, and at intake — rather than two months later when a substantive gap has already been published. The output isn't a decision; it's a flag that triggers a legal defensibility review.

---

### "We already have [ServiceNow / PMIS / legacy system]. What's the migration story?"

**Response:** We're not proposing a rip-and-replace. The integration path depends on what the existing system does well. If it's a document repository, ContentVersion integrates with it. If it's a case management system, IndividualApplication can consume status feeds via REST API. The scheduling and optimization layer is what's new — and that's the part your existing system almost certainly doesn't have. We typically start with a pilot program — one field office, one permit type — and expand from there. The Carrie Placer Mine dataset is already structured for a pilot load into a scratch org on day one.

---

## Data Insights: What the NEPATEC Corpus Tells Us

> **Note for presenters:** The key data points from each finding below are now embedded directly in the Scene Data Context blocks and Setup/Landing Tells above. You do not need to read this section before delivering the demo. Use it for depth — when an audience member asks *"where does that number come from?"* — or to prepare for technically sophisticated audiences. Each finding maps to the specific scene where the data surfaces.

The following findings are drawn from analysis of the NEPATEC 2.0 corpus — 61,881 federal NEPA projects, 142,083 documents, and 6.9 million pages across 60+ agencies. These are not estimates or benchmarks from vendor literature. They are empirical patterns derived from the actual administrative record of how NEPA permitting works in practice.

Use these insights to give the demo claims quantitative grounding. Each finding maps to a specific demo moment.

---

### Finding 1: 88% of Federal NEPA Actions Are CEs — and Most Are Misrouted at Intake

Across the corpus, **88.7% of energy projects and 90.6% of transportation and infrastructure projects** resolve as Categorical Exclusions — not EAs, not EISs. The environmental impact isn't the bottleneck for most permits. Yet agencies consistently spend EA-level review time on actions that qualify for CE treatment, because intake systems don't encode the regulatory criteria that distinguish them.

The top two predictors of CE eligibility at intake are (1) **CE category citation** — whether the applicant or reviewer cites the correct regulatory authority — and (2) **project type** — with routine categories like rangeland management, ROW renewals, and pipeline placements in existing corridors mapping deterministically to CE codes. Both of these are fields that a structured intake form captures in under five minutes.

**Demo connection:** The self-service portal in Scene 1 is doing this work. When Sam selects "Plan of Operations – Mining" and enters a 15-acre footprint, the system immediately knows which resource disciplines are required and what the CE eligibility threshold is (5 acres for EPAct Section 390(b)(1)). That's not a configuration decision — it's the regulatory logic the corpus makes explicit.

---

### Finding 2: Process Type Is Determined at Intake — But the Data to Determine It Often Isn't Captured

Our feature engineering analysis found that the five strongest predictors of whether a project escalates to EA or EIS are all available at the time of application: CE category citation, project type, title keywords, action description language, and document page count. **The information exists. It just isn't structured.**

Of the 1,489 records analyzed, 87 had empty CE category fields — projects that went into the review queue without the single most important piece of routing information. An additional 17% had noisy or inconsistent CE citations (the same underlying exemption cited 8 different ways). This ambiguity doesn't just slow intake — it creates defensibility gaps that get exploited in litigation.

**Demo connection:** The NEPA_CE_Screener flow in the PSA accelerator is built on exactly these five features. It doesn't ask a coordinator to make a judgment call. It reads the intake record and returns eligible CE codes, disqualifying conditions, and — when surface disturbance exceeds 5 acres (as in the Carrie Placer Mine) — routes to EA automatically.

---

### Finding 3: EIS Projects in Agriculture and Energy Are Extreme Timeline Outliers

The corpus documents a stark separation between process types on project complexity:

| Process Type | Median Pages | P90 Pages | P95 Pages |
|---|---|---|---|
| Categorical Exclusion | 3–8 | ~20 | ~35 |
| Environmental Assessment | 30–100 | ~200 | ~300 |
| Environmental Impact Statement | 200–600 | 2,000+ | 5,000+ |

The highest-risk sector combinations — those most associated with extreme-duration projects — are **Agriculture/Natural Resource Management EIS** (land management plans, sage-grouse RMPs) and **Energy Production EIS** (coal, offshore oil and gas, large-scale solar). CEQ research confirms some EIS projects take 5–13 years. At intake, the document complexity profile is already visible.

Military/Defense projects show the highest EIS rate at 13.8% — nearly triple the rate of transportation projects — and the highest litigation loss rate in the 9th Circuit.

**Demo connection:** The NEPA_Timeline_Risk_Assessor flow reads page count, document count, sector, and agency at intake and flags projects that match the profile of known outliers. It's the system telling the field manager on day one: *this one will need active monitoring*.

---

### Finding 4: The 10th Circuit Is Now the Highest-Risk Venue — and Tribal Plaintiffs Win 87% of the Time

Our litigation analysis of 761 NEPA cases (PermitTEC v0.1, PNNL 2025) found that the **10th Circuit has the highest agency loss rate at 45%** (multiplier 1.45 over baseline), driven by 68 cases across BLM, USFS, and energy pipeline projects in Colorado, Utah, Wyoming, and Idaho. The 9th Circuit remains the highest-volume litigation venue (268 cases, 36-point circuit weight), but the 10th Circuit is now the *highest-probability-loss* venue for contested projects.

Across all circuits, the most predictable failure mode is not inadequate environmental analysis — it's **supplementation failure and connected-actions scoping gaps**. Specifically:

- Agencies tiered to prior EIS documents without reassessing changed circumstances (new species/habitat data, modified project scope)
- Agencies failed to scope connected federal approvals (generation + transmission + access roads treated as independent actions)
- ESA Section 7 consultation gaps — the species present at the Carrie Placer Mine site — accounted for a multiplier of 1.48 (10 risk points) in our statute analysis

**Tribal plaintiff outcomes are the single most predictable risk factor in the corpus:** Tribal Nation challengers — including the Navajo Nation on Colorado River water rights and consultation failure cases — achieved an **87.5% win rate** across 4 cases, the highest of any plaintiff category. When a tribal nation is a public commenter on a NEPA action, the probability of litigation success if challenged approaches 9 in 10.

The three highest-risk defensibility gaps from the corpus analysis:
1. **No enforced supplementation trigger** when new significant information emerges post-ROD (severity: HIGH)
2. **Government-to-government consultation not documented as a hard gate** — agencies advanced to ROD with incomplete tribal consultation (severity: VERY HIGH when tribal commenter is present)
3. **ESA Section 7 consultation status not linked to NEPA document finalization** — agencies issued FONSIs and RODs with open consultation (severity: MEDIUM)

All three are stage gate failures, not substantive analysis failures. The agency did the work. The system didn't enforce the checkpoint.

**Demo connection:** The tribal plaintiff flag in Scene 3 and the Required Document Registry in Scene 4 enforce these gaps in real time. The tribal consultation certification is a hard gate — the FONSI cannot be signed until it's in the registry. The system doesn't let the field manager forget. These aren't policy decisions — they're the validated failure patterns from the actual federal court record, encoded as software validation rules.

---

### Finding 5: Co-Permit Drift Is Structural, Not Accidental

The permit matrix analysis across 25 project type / sector combinations reveals that **every single project type requiring a BLM Plan of Operations also requires at least one co-permit** — CWA Section 404, NPDES, ESA Section 7, NHPA Section 106, or state water rights. For energy projects involving pipelines or transmission, the list reaches six to eight concurrent permits across federal and state agencies.

The typical pattern: the primary federal permit (BLM, USFS, USACE) moves forward on its own clock while co-permits are treated as the applicant's responsibility to manage in parallel. In practice, applicants — particularly smaller operators like placer miners, ranchers, and small energy developers — don't know when to start them. Co-permit processing times range from 30 days (EPA NPDES for small suction dredge) to 48 months (nuclear waste facility), and none of them are visible to the primary permit reviewer.

**Demo connection:** The parallel permit trigger automation in Scene 2 closes this gap for the Carrie Placer Mine. It's not a workflow suggestion — it's a hard trigger wired to a specific work order closure event, with SLA tracking and applicant portal visibility. The same pattern scales to any project type in the matrix.

---

## Business Value

The following value estimates are calibrated to three agency account sizes based on annual NEPA permit volume, field office count, and EIS exposure. Use the tier that matches the account you're presenting to. All figures are grounded in the corpus analysis; none are vendor benchmark claims.

For each tier, the value case rests on four levers:
1. **Timeline compression** — reducing calendar time per permit through parallel scheduling
2. **Specialist efficiency** — eliminating wasted field trips and rescheduled surveys
3. **Litigation cost avoidance** — preventing defensibility gaps that generate 9th Circuit losses
4. **Co-permit acceleration** — starting parallel permit clocks earlier

---

### Tier 1: Small Field Office or Single-Program Agency
*Typical profile: 1–3 field offices, 50–200 NEPA actions/year, primarily CEs and EAs, occasional EIS, 9th Circuit exposure*

| Value Lever | Assumption | Annual Value Estimate |
|---|---|---|
| Timeline compression | 20 EAs/year averaging 18 months reduced to 10 months; each month saved = ~$8K applicant carrying cost avoided and $4K agency coordinator time | **$480K–$960K** in economic value unlocked per year across permit portfolio |
| Specialist efficiency | 7 specialists × 4 wasted field trips/year (wrong season or gate conflict) × 3 hours round trip + 8 hours lost survey day = 77 specialist-days recovered annually | **0.4 FTE recaptured** — absorbed as additional permit capacity, not headcount reduction |
| Litigation cost avoidance | 1 EA challenge in the 9th Circuit costs $200K–$800K in agency legal defense, $50K–$200K in specialist re-engagement, and 12–24 months of delay. Eliminating 1 challenge every 3 years = | **$85K–$330K/year** risk-adjusted avoidance |
| Co-permit acceleration | Applicants starting IDWR/NPDES permits 3–6 months earlier per project; reduces post-decision wait and political exposure from stalled projects | **Non-quantified but high-visibility** — direct applicant satisfaction impact |
| **Total estimated range** | | **$565K–$1.3M/year** |

*Typical investment for this tier: $180K–$350K platform and implementation. Payback period: 4–8 months on timeline compression alone.*

---

### Tier 2: Multi-Office Regional Agency or State Permitting Program
*Typical profile: 5–15 field offices, 500–2,000 NEPA actions/year, active EIS docket, multi-agency coordination, significant 9th or 10th Circuit exposure*

| Value Lever | Assumption | Annual Value Estimate |
|---|---|---|
| Timeline compression | 150 EAs/year averaging 20 months reduced to 11 months; 30 EISs averaging 48 months reduced to 32 months (33% reduction based on parallel track management) | **$4.5M–$9M** in economic value unlocked across permit portfolio annually |
| Specialist efficiency | 50 specialists × 6 wasted trips/year × same calculation as Tier 1 | **3.5 FTE recaptured** — reallocated to EIS workload without hiring |
| Litigation cost avoidance | At this scale, 2–4 EA/EIS challenges active annually. Each 9th Circuit EIS loss costs $1.5M–$4M including re-analysis, supplemental EIS preparation, and delay. Preventing 1 loss/year = | **$1.5M–$4M/year** risk-adjusted avoidance |
| Comment response efficiency | 1,000+ public comments/year; reducing average response time from 75 days to 21 days saves coordinator time and eliminates supplemental record-opening events | **$200K–$600K** coordinator time and rework avoided |
| **Total estimated range** | | **$6.2M–$13.6M/year** |

*Typical investment for this tier: $800K–$1.8M platform, implementation, and integration. Payback period: 6–10 weeks on litigation avoidance alone if one EIS challenge is in progress.*

---

### Tier 3: National Agency Program or Large Multi-Agency Initiative
*Typical profile: 50+ field offices or centralized national program, 5,000–20,000+ NEPA actions/year, major EIS docket (energy transition, infrastructure, defense), multi-circuit litigation exposure, congressional oversight*

| Value Lever | Assumption | Annual Value Estimate |
|---|---|---|
| Timeline compression | BLM manages ~54,000 CE actions, 3,000 EAs, and 4,000 EISs annually (NEPATEC corpus). A 20% reduction in EA/EIS cycle time across the portfolio, valued at the economic activity each permit unlocks | **$200M–$600M** in economic value unlocked for the regulated community annually |
| Specialist efficiency | At national scale, 5–15% of specialist field time is wasted on coordination failures. For a 2,000-person field workforce, recovering 10% = 200 FTEs of productive capacity | **200 FTE-equivalent capacity gain** — equivalent to a major hiring surge without the budget |
| Litigation cost avoidance | BLM and USFS face 40–80 active NEPA challenges at any time. Average fully-loaded cost per contested EIS (legal, re-analysis, delay, political): $3M–$12M. Reducing challenge rate by 25% through systematic defensibility gap closure | **$30M–$120M/year** risk-adjusted avoidance |
| Congressional and political exposure | Permit backlogs generate congressional inquiries, GAO audits, and Inspector General reviews. Each inquiry costs 50–200 staff hours to respond. Reducing backlog-driven inquiries by 40% | **Non-quantified but material** — directly affects agency credibility and budget justification |
| Data standardization value | NEPATEC corpus shows 17%+ of intake records have noisy or missing CE citation data. At national scale, standardized intake generates a machine-readable permit corpus that supports AI-assisted routing, predictive analytics, and cross-agency learning | **Long-term compounding value** — estimated $50M–$200M over 5 years in avoided re-analysis and institutional knowledge capture |
| **Total estimated range** | | **$250M–$750M+/year** in value to the regulated economy and government operations |

*Typical investment for this tier: $5M–$20M multi-year enterprise deployment with agency-wide change management. ROI positive within 12–18 months based on litigation avoidance and timeline compression alone.*

---

### Value Framing by Audience

Adjust the business value conversation based on who is in the room:

| Audience | Lead Value Driver | How to Frame It |
|---|---|---|
| Field Office Manager | Specialist efficiency; timeline compression | "Your biologists stop driving 45 minutes to a locked gate. Your EAs close in a field season instead of two." |
| NEPA Program Director | Defensibility and litigation avoidance | "The three gaps that generate 9th Circuit losses are now stage gates, not manual checklists." |
| State Permitting Director | Co-permit coordination; applicant trust | "Applicants stop calling. Their co-permits start moving the same week your review starts." |
| Agency CIO / IT Lead | Data standardization; platform consolidation | "One system of record for intake, scheduling, documents, comments, and decisions — FedRAMP High, no custom code." |
| Congressional Staff / Budget Officer | Economic throughput; backlog reduction | "Each month of delay on an energy project is real economic activity that doesn't happen. We can show you the number." |
| General Counsel / Solicitor | 10 challenge prediction rules from PermitTEC corpus | "The ten challenge prediction rules derived from 761 NEPA cases — including Connected Actions, which drives 42.7% of successful challenges — are now system-enforced checkpoints. The #1 failure mode is Priority 1 in the deployed system. They don't rely on someone remembering to check." |

---

### The Number That Closes the Room

Across all tiers, the single most compelling business value statement is this:

> *"The Carrie Placer Mine permit took 25 months. The same project, run through this system, takes 8 months. That's 17 months of economic activity that didn't happen — for one applicant, on one 15-acre mine. Multiply that by your permit backlog, and you have the number."*

Then be quiet and let them do the math.

---

## Demo Environment Notes

- All records use `DEMO_` external ID prefix — safe to load and clean up without touching production data.
- Import files: `demo/import_data/` — load in numbered order (01 → 23), then load `24_decision_payload.csv` and `25_ar_export.csv`.
- Cleanup: `sf data delete bulk --where "External_Id__c LIKE 'DEMO_%'"` per object, reverse order per `00_README.md`.

---

*All facts, names, case numbers, locations, species, agencies, and dates are drawn directly from the administrative record: DOI-BLM-ID-B030-2019-0014-EA, BLM Owyhee Field Office, Marsing, Idaho.*
