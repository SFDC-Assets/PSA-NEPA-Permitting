# NEPA Public Permitting Portal — Component Manifest

**Version:** 1.0  
**Date:** 2026-04-30  
**Consuming design:** [NEPA-ExperienceCloud-Portal-Design.md](./NEPA-ExperienceCloud-Portal-Design.md)  
**Implementation project:** Separate LWC / OmniStudio project (namespace `c`, API version 62.0)  
**Runtime:** Lightning Web Runtime (LWR) · Lightning Web Security (LWS) · Experience Cloud  
**USWDS version:** 3.13

This document enumerates every component, utility module, Apex class, OmniStudio artifact, and static resource that must be created in the implementation project. It is the dependency contract between the portal design and the build team.

---

## Table of Contents

1. [Conventions](#1-conventions)
2. [Static Resources](#2-static-resources)
3. [LWC Utility Modules](#3-lwc-utility-modules)
4. [LWC Page Components](#4-lwc-page-components)
5. [LWC Shared Components — Global Chrome](#5-lwc-shared-components--global-chrome)
6. [LWC Shared Components — Navigation](#6-lwc-shared-components--navigation)
7. [LWC Shared Components — Data Display](#7-lwc-shared-components--data-display)
8. [LWC Shared Components — Form](#8-lwc-shared-components--form)
9. [LWC Shared Components — Content and Layout](#9-lwc-shared-components--content-and-layout)
10. [OmniStudio Override Components](#10-omnistudio-override-components)
11. [OmniStudio Artifacts](#11-omnistudio-artifacts)
12. [Apex Controllers and Inner Classes](#12-apex-controllers-and-inner-classes)
13. [Experience Cloud Configuration](#13-experience-cloud-configuration)
14. [Dependency Graph](#14-dependency-graph)

---

## 1. Conventions

### Naming

| Type | Convention | Example |
|---|---|---|
| LWC component | `camelCase`, `nepa` prefix | `nepaProjectTable` |
| LWC page component | `camelCase`, `nepaPage` prefix | `nepaPageProjects` |
| LWC utility module | `camelCase` in `utils/` folder | `utils/nepaDateUtils` |
| OmniStudio FlexCard override LWC | `camelCase`, `nepaCard` prefix | `nepaCardProject` |
| OmniStudio OmniScript override LWC | `camelCase`, `nepaForm` prefix | `nepaFormComment` |
| Apex controller | `PascalCase`, `Nepa` prefix, `Controller` suffix | `NepaProjectController` |
| Apex inner class / DTO | `PascalCase`, nested inside controller | `NepaProjectController.ProjectResult` |
| Static resource | `snake_case` | `nepa_uswds_assets`, `nepa_uswds_styles` |

### Priority tiers

| Tier | Meaning |
|---|---|
| **P0 — Blocking** | Portal cannot render without this. Required for initial launch. |
| **P1 — Core** | Required for full read-path. Portal degrades without it. |
| **P2 — Enhanced** | Improves usability but portal is functional without it. |
| **P3 — Future** | Post-launch; design calls for it but out of initial scope. |

### LWS flags

| Flag | Meaning |
|---|---|
| `⚠ toggle` | JS-driven toggle (accordion, banner, modal). Must use LWC `@track` — no USWDS JS. |
| `⚠ focus-trap` | Must manage programmatic focus in `connectedCallback` / `disconnectedCallback`. |
| `⚠ live-region` | Must declare `aria-live` region; do not use DOM mutation. |
| `⚠ resource-url` | Uses `@salesforce/resourceUrl` to resolve static asset paths. |
| `⚠ no-eval` | Component logic that USWDS JS would handle with `eval` — re-implemented declaratively. |

---

## 2. Static Resources

These artifacts are built from the USWDS source in the implementation project and deployed to the Experience Cloud org as static resources.

### 2.1 `nepa_uswds_styles`

| Attribute | Value |
|---|---|
| **Type** | Static Resource (single CSS file) |
| **Priority** | P0 |
| **Source** | Compiled from `packages/uswds-core` + USWDS component packages in `uswds3.13/` |
| **Build input** | `_uswds-theme.scss` (see design doc §6) |
| **Build output** | `nepa-uswds.min.css` |
| **Deployment** | Loaded as global stylesheet in Experience Cloud Site Configuration → CSS Resources |
| **Contains** | USWDS tokens, layout grid (`usa-layout-grid`), utilities (`uswds-utilities`), typography (`uswds-typography`), and all component styles for every USWDS component used in this portal |
| **Does not contain** | USWDS JavaScript — all JS behavior is re-implemented in LWC |
| **USWDS packages included** | `uswds-core`, `uswds-tokens`, `uswds-utilities`, `uswds-typography`, `uswds-elements`, `usa-layout-grid`, `usa-banner`, `usa-header`, `usa-nav`, `usa-footer`, `usa-identifier`, `usa-skipnav`, `usa-hero`, `usa-breadcrumb`, `usa-search`, `usa-tag`, `usa-table`, `usa-pagination`, `usa-select`, `usa-alert`, `usa-site-alert`, `usa-summary-box`, `usa-card`, `usa-step-indicator`, `usa-process-list`, `usa-accordion`, `usa-collection`, `usa-sidenav`, `usa-in-page-navigation`, `usa-form`, `usa-form-group`, `usa-label`, `usa-hint`, `usa-input`, `usa-textarea`, `usa-character-count`, `usa-checkbox`, `usa-radio`, `usa-file-input`, `usa-button`, `usa-modal`, `usa-error-message`, `usa-validation`, `usa-icon`, `usa-icon-list`, `usa-section`, `usa-prose` |

### 2.2 `nepa_uswds_assets`

| Attribute | Value |
|---|---|
| **Type** | Static Resource (ZIP archive) |
| **Priority** | P0 |
| **Source** | Extracted from `uswds3.13/dist/` |
| **Contents** | `img/us_flag_small.png`, `img/icon-dot-gov.svg`, `img/icon-https.svg`, `img/sprite.svg` (icon sprite), `fonts/public-sans/` (all weights and variants) |
| **Referenced by** | All components using `@salesforce/resourceUrl/nepa_uswds_assets` via `utils/nepaAssets.js` |
| **LWS note** | `⚠ resource-url` — URL resolution must use `@salesforce/resourceUrl` import, never a hardcoded path. |

---

## 3. LWC Utility Modules

Utility modules are JavaScript ES modules in the LWC project's `utils/` directory. They export pure functions and constants — no LWC lifecycle, no template. They are imported by components using relative paths.

### 3.1 `utils/nepaAssets`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **Purpose** | Resolves `@salesforce/resourceUrl/nepa_uswds_assets` once and exports typed path constants |
| **LWS note** | `⚠ resource-url` |
| **Exports** |  |

```js
export const SPRITE_URL;       // .../nepa_uswds_assets/img/sprite.svg
export const FLAG_URL;         // .../nepa_uswds_assets/img/us_flag_small.png
export const DOT_GOV_ICON_URL; // .../nepa_uswds_assets/img/icon-dot-gov.svg
export const HTTPS_ICON_URL;   // .../nepa_uswds_assets/img/icon-https.svg
```

### 3.2 `utils/nepaDateUtils`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **Purpose** | Date formatting and deadline calculation using `Intl.DateTimeFormat`. No external library. |
| **LWS note** | Uses `Intl.DateTimeFormat` (available in LWS sandbox). No `new Date()` string parsing from untrusted input. |
| **Exports** |  |

```js
export function formatDisplayDate(isoString);            // → "June 15, 2026"
export function formatShortDate(isoString);              // → "Jun 15, 2026"
export function daysUntil(isoString);                    // → Number (negative = past)
export function isCommentPeriodOpen(startIso, endIso);  // → Boolean
export function deadlineUrgency(endIso);                 // → 'urgent' | 'warning' | 'open' | 'closed'
// 'urgent' = ≤3 days, 'warning' = ≤7 days, 'open' = future, 'closed' = past
```

### 3.3 `utils/nepaReviewTypeUtils`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **Purpose** | Maps Salesforce picklist API values to display labels, USWDS tag color modifiers, and plain-language descriptions |
| **Exports** |  |

```js
export function reviewTypeLabel(apiValue);        // "EIS" → "Environmental Impact Statement"
export function reviewTypeTagModifier(apiValue);  // "EIS" → "usa-tag--big"
export function reviewTypeDescription(apiValue);  // "EIS" → plain-language paragraph
export const REVIEW_TYPE_OPTIONS;                 // [{value, label}] for usa-select
```

### 3.4 `utils/nepaStageUtils`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **Purpose** | Maps `nepa_process_stage__c` picklist values to `usa-step-indicator` step array shape and status |
| **Exports** |  |

```js
export const STAGE_SEQUENCE;           // ordered array of stage API values
export function buildStepIndicator(currentStage, reviewType);
// → [{label, status: 'complete'|'current'|'incomplete'}]
export function stageDisplayLabel(apiValue);  // human-readable stage name
```

### 3.5 `utils/nepaNavigationUtils`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **Purpose** | Builds typed `pageReference` objects for LWR `NavigationMixin` calls and constructs portal URLs from `nepa_federal_unique_id__c` values |
| **Exports** |  |

```js
export function projectPageRef(federalUniqueId);         // pageReference for /projects/[id]
export function processPageRef(federalUniqueId);         // /projects/[id]/process
export function documentsPageRef(federalUniqueId);       // /projects/[id]/process/documents
export function commentsPageRef(federalUniqueId);        // /projects/[id]/process/comments
export function buildBreadcrumbs(pageName, project);     // → [{label, href}] for nepaBreadcrumb
```

### 3.6 `utils/nepaFormValidation`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **Purpose** | Client-side validation rules for the comment submission form. Returns structured error objects compatible with `usa-error-message` and `usa-validation` components. |
| **Exports** |  |

```js
export function validateCommentForm(formData);
// → { valid: Boolean, errors: [{field, message}], summary: String }
export function validateEmail(value);      // → String | null (null = valid)
export function validateRequired(value, fieldLabel);
export const MAX_COMMENT_LENGTH;           // 5000
```

---

## 4. LWC Page Components

Page components are route-mapped in the LWR site configuration. Each receives URL parameters via `@wire(CurrentPageReference)` and assembles the full page from shared components.

### 4.1 `nepaPageHome`

| Attribute | Value |
|---|---|
| **Route** | `/` |
| **Priority** | P0 |
| **USWDS composition** | `usa-hero`, `usa-process-list`, `usa-card-group`, `usa-summary-box`, `usa-section`, `usa-dark-background` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaSiteAlert`, `nepaHero`, `nepaProcessList`, `nepaCommentPeriodCards`, `nepaPortalSummary`, `nepaFooter` |
| **Wire / Apex** | `@wire(getOpenCommentPeriods)` for the featured comment period card group |
| **LWS notes** | None beyond standard |

### 4.2 `nepaPageProjects`

| Attribute | Value |
|---|---|
| **Route** | `/projects` |
| **Priority** | P0 |
| **USWDS composition** | `usa-search`, `usa-tag` (filter chips), `usa-select`, `usa-table--stacked --sortable`, `usa-pagination`, `usa-alert` (empty state) |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaProjectSearch`, `nepaTagFilter`, `nepaProjectTable`, `nepaPagination`, `nepaAlert`, `nepaFooter` |
| **Wire / Apex** | `@wire(getProjectList, {...})` reactive to search, filter, sort, page state |
| **URL params consumed** | `q` (search term), `reviewType`, `sort`, `page` |
| **LWS notes** | URL param read/write via `NavigationMixin` + `CurrentPageReference` |

### 4.3 `nepaPageProjectDetail`

| Attribute | Value |
|---|---|
| **Route** | `/projects/:federalUniqueId` |
| **Priority** | P0 |
| **USWDS composition** | `usa-breadcrumb`, `usa-tag`, `usa-site-alert--warning`, `usa-summary-box`, `usa-step-indicator`, `usa-in-page-navigation`, `usa-collection`, `usa-alert`, `usa-button` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaDeadlineAlert`, `nepaProjectSummary`, `nepaReviewTypeTag`, `nepaStepIndicator`, `nepaInPageNav`, `nepaRecentDocuments`, `nepaEngagementList`, `nepaCommentCta`, `nepaFooter` |
| **Wire / Apex** | `@wire(getProjectDetail, {federalUniqueId: '$federalUniqueId'})` |
| **URL params consumed** | `federalUniqueId` (path segment) |
| **LWS notes** | `⚠ resource-url` for project location map fallback image |

### 4.4 `nepaPageProcessDetail`

| Attribute | Value |
|---|---|
| **Route** | `/projects/:federalUniqueId/process` |
| **Priority** | P1 |
| **USWDS composition** | `usa-breadcrumb`, `usa-step-indicator`, `usa-summary-box`, `usa-alert`, `usa-table`, `usa-accordion`, `usa-process-list`, `usa-button` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaStepIndicator`, `nepaCommentPeriodSummary`, `nepaDeadlineAlert`, `nepaProcessTimeline`, `nepaProcessAccordion`, `nepaNextSteps`, `nepaCommentCta`, `nepaFooter` |
| **Wire / Apex** | `@wire(getProcessDetail, {federalUniqueId: '$federalUniqueId'})` |
| **LWS notes** | Accordion: `⚠ toggle` |

### 4.5 `nepaPageDocuments`

| Attribute | Value |
|---|---|
| **Route** | `/projects/:federalUniqueId/process/documents` |
| **Priority** | P1 |
| **USWDS composition** | `usa-breadcrumb`, `usa-tag` (type filters), `usa-table--stacked --sortable`, `usa-pagination`, `usa-alert` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaTagFilter`, `nepaDocumentTable`, `nepaPagination`, `nepaAlert`, `nepaFooter` |
| **Wire / Apex** | `@wire(getPublicDocuments, {processId: '$processId', docType: '$docTypeFilter', page: '$page'})` |
| **LWS notes** | Download links resolve `ContentVersion` `VersionData` endpoint via `@salesforce/apex` — cannot use hardcoded content domain |

### 4.6 `nepaPageCommentSubmit`

| Attribute | Value |
|---|---|
| **Route** | `/projects/:federalUniqueId/process/comments` |
| **Priority** | P0 |
| **USWDS composition** | `usa-breadcrumb`, `usa-alert--warning`, `usa-summary-box`, `usa-form` (full), `usa-modal`, `usa-alert--success` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaDeadlineAlert`, `nepaCommentGuidance`, `nepaCommentForm`, `nepaCommentModal`, `nepaSubmitSuccessAlert`, `nepaFooter` |
| **Wire / Apex** | `@wire(getProcessRecord)` for deadline/open validation; `submitComment()` Apex imperative call |
| **LWS notes** | Modal: `⚠ toggle`, `⚠ focus-trap`. Character count: `⚠ live-region`. File input limited to `application/pdf`. |
| **Guard** | Page redirects to `/projects/:id` if comment period is closed |

### 4.7 `nepaPageLearnIndex`

| Attribute | Value |
|---|---|
| **Route** | `/learn` |
| **Priority** | P2 |
| **USWDS composition** | `usa-breadcrumb`, `usa-sidenav`, `usa-card-group` (section links) |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaLearnSidenav`, `nepaLearnCards`, `nepaFooter` |
| **Wire / Apex** | Static content only |

### 4.8 `nepaPageLearnContent`

| Attribute | Value |
|---|---|
| **Route** | `/learn/:slug` (handles `what-is-nepa`, `review-types`, `comment-guide`) |
| **Priority** | P2 |
| **USWDS composition** | `usa-breadcrumb`, `usa-sidenav`, `usa-in-page-navigation`, `usa-process-list`, `usa-accordion`, `usa-table`, `usa-summary-box`, `usa-icon-list` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaLearnSidenav`, `nepaInPageNav`, `nepaLearnContentBlock`, `nepaFooter` |
| **Wire / Apex** | Static content loaded by slug — can be driven by `RegulatoryCode` records for regulatory content pages |

### 4.9 `nepaPageAbout`

| Attribute | Value |
|---|---|
| **Route** | `/about` |
| **Priority** | P2 |
| **USWDS composition** | `usa-breadcrumb`, `usa-summary-box`, `usa-icon-list` |
| **Child LWCs** | `nepaBanner`, `nepaHeader`, `nepaBreadcrumb`, `nepaFooter` |
| **Wire / Apex** | Static content only |

---

## 5. LWC Shared Components — Global Chrome

Components used on every page. Rendered in the LWR theme layout, not inside page components.

### 5.1 `nepaBanner`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-banner` |
| **`@api` props** | None — static content only |
| **LWS notes** | `⚠ toggle` — expand/collapse the "An official website" panel. `isExpanded: @track Boolean`. Escape key collapses via `keydown` listener on `this.template`. |
| **Accessibility** | `aria-expanded` on button. Panel `id` referenced by `aria-controls`. |
| **Assets** | `FLAG_URL`, `DOT_GOV_ICON_URL`, `HTTPS_ICON_URL` from `utils/nepaAssets` |

### 5.2 `nepaHeader`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-header usa-header--basic`, `usa-nav`, `usa-nav__primary` |
| **`@api` props** | `agencyName: String`, `agencyLogoUrl: String`, `navItems: Array<{label, href, active}>` |
| **LWS notes** | `⚠ toggle` — mobile hamburger. `isMenuOpen: @track Boolean`. Overlay (`usa-overlay`) toggled by same flag. |
| **Events fired** | `nepanavigated` (custom, bubbles) on nav item click — consumed by page component for analytics |
| **Accessibility** | `aria-expanded` on hamburger. Active link receives `aria-current="page"` driven by comparison to `currentPageReference`. |
| **Child LWCs** | `nepaSearchBar` (embedded in nav) |

### 5.3 `nepaFooter`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-footer usa-footer--slim`, `usa-identifier` |
| **`@api` props** | `agencyName: String`, `agencyUrl: String`, `parentAgencyName: String`, `parentAgencyUrl: String`, `agencyLogoUrl: String`, `contactEmail: String`, `legalLinks: Array<{label, href}>` |
| **LWS notes** | `⚠ resource-url` for agency logo and identifier logo images |
| **Required links** | Accessibility statement, Privacy Policy, FOIA, No Fear Act, Inspector General, Performance reports — all `@api`-configurable |
| **Assets** | Agency logo via `@api agencyLogoUrl` |

### 5.4 `nepaSiteAlert`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-site-alert`, `usa-site-alert--warning` |
| **`@api` props** | `variant: 'info'|'warning'`, `heading: String`, `message: String`, `ctaLabel: String`, `ctaHref: String` |
| **Wire / Apex** | Called from parent page component with data from `@wire(getOpenCommentPeriods)` |
| **LWS notes** | `⚠ toggle` — dismissible variant uses `@track isDismissed`. Dismiss persists to `sessionStorage` if available. |
| **Conditional render** | Only rendered when parent passes non-null `message` |

---

## 6. LWC Shared Components — Navigation

### 6.1 `nepaBreadcrumb`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-breadcrumb` |
| **`@api` props** | `crumbs: Array<{label: String, href: String|null}>` — last item is current page (no href, `aria-current="page"`) |
| **Helper** | `utils/nepaNavigationUtils.buildBreadcrumbs()` constructs the array |
| **Accessibility** | `<nav aria-label="Breadcrumb">`, last item has `aria-current="page"` |

### 6.2 `nepaLearnSidenav`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-sidenav` with `usa-sidenav__sublist` |
| **`@api` props** | `items: Array<{label, href, current, subnav?}>` |
| **Accessibility** | `<nav aria-label="Section navigation">`. Active item has `class="usa-current"`. |

### 6.3 `nepaInPageNav`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-in-page-navigation` |
| **`@api` props** | `sections: Array<{label: String, anchor: String}>` |
| **Behavior** | Renders a static link list; does not auto-generate from DOM `<h2>` elements (USWDS JS approach). Scroll-spy highlighting handled via `IntersectionObserver` in `connectedCallback`. |
| **LWS notes** | `IntersectionObserver` is available in LWS sandbox. DOM references use `this.template.querySelectorAll()`. |
| **Responsive** | At < 1024px, renders as a `<details>` / `<summary>` dropdown ("On this page") instead of fixed sidebar. |

### 6.4 `nepaPagination`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-pagination` |
| **`@api` props** | `currentPage: Number`, `totalPages: Number`, `ariaLabel: String` |
| **Events fired** | `nepapagechange` with `{detail: {page: Number}}` — consumed by parent page component to update wire reactive property |
| **Accessibility** | `<nav aria-label>`, current page button `aria-current="page"`. Previous/Next use `aria-label="Previous page"` / `"Next page"`. |

### 6.5 `nepaTagFilter`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-tag`, `usa-button-group` (toggle button group pattern) |
| **`@api` props** | `options: Array<{label, value}>`, `selectedValue: String`, `name: String` |
| **Events fired** | `nepafilterchange` with `{detail: {value}}` — consumed by parent page component |
| **LWS notes** | Each tag rendered as a `<button type="button">` with `aria-pressed` for selected state, not purely as `<span>`. This is a USWDS pattern extension for accessibility. |
| **Accessibility** | `role="group"`, `aria-label` describes the filter purpose |

---

## 7. LWC Shared Components — Data Display

### 7.1 `nepaProjectTable`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-table usa-table--stacked usa-table--sortable` |
| **`@api` props** | `projects: Array<ProjectResult>`, `sortField: String`, `sortDirection: 'asc'|'desc'` |
| **Events fired** | `nepasortchange` with `{detail: {field, direction}}` |
| **Child LWCs** | `nepaReviewTypeTag` (in Review Type column) |
| **Accessibility** | `<caption>` on table. `aria-sort="ascending"` / `"descending"` / `"none"` on sortable `<th>` elements. Download links include `aria-label="Download [doc name]"`. |
| **Mobile** | `usa-table--stacked` — columns reflow to labeled rows at < 640px. `data-label` attributes on each `<td>` match `<th>` text. |

### 7.2 `nepaDocumentTable`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-table usa-table--stacked usa-table--sortable` |
| **`@api` props** | `documents: Array<DocumentRecord>`, `sortField: String`, `sortDirection: 'asc'|'desc'` |
| **Events fired** | `nepasortchange` |
| **Columns** | Document Name (link), Type (tag), Published Date, Status |
| **Download** | Links resolve to `ContentVersion VersionData` endpoint via `@wire(getContentDownloadUrl, {contentVersionId})` — not a raw `/sfc/servlet` URL |
| **Accessibility** | Same `aria-sort` pattern as `nepaProjectTable`. Download links include filename in `aria-label`. |

### 7.3 `nepaProjectSummary`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-summary-box` |
| **`@api` props** | `project: ProjectDetail` (Federal ID, Lead Agency, Location, Sector, Start Date, Project Type) |
| **Child LWCs** | `nepaReviewTypeTag` |

### 7.4 `nepaStepIndicator`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-step-indicator` |
| **`@api` props** | `currentStage: String`, `reviewType: String` |
| **Helper** | `utils/nepaStageUtils.buildStepIndicator()` converts stage + review type to the step array |
| **Accessibility** | Segment `aria-current="true"` on current step. Complete segments include `<span class="usa-sr-only">completed</span>`. Incomplete segments include `<span class="usa-sr-only">not completed</span>`. |

### 7.5 `nepaCommentPeriodSummary`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-summary-box` |
| **`@api` props** | `startDate: String`, `endDate: String`, `processTitle: String` |
| **Helper** | `utils/nepaDateUtils.formatDisplayDate()`, `daysUntil()` |
| **Displays** | Comment period open/closed status, formatted start/end dates, days remaining countdown |

### 7.6 `nepaDeadlineAlert`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-alert usa-alert--warning`, `usa-alert usa-alert--info`, `usa-alert usa-alert--error` |
| **`@api` props** | `endDate: String`, `processTitle: String` |
| **Behavior** | Uses `utils/nepaDateUtils.deadlineUrgency()` to determine variant: `urgent` → warning, `open` → info, `closed` → renders nothing (parent decides). |
| **Accessibility** | `role="region"` with `aria-label`. Does not use `role="alert"` (not an immediate interruption). |

### 7.7 `nepaProcessTimeline`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-table` |
| **`@api` props** | `timelineEvents: Array<{stage, startDate, endDate, status}>` |
| **Derived from** | `ApplicationTimeline` records fetched by parent page component |
| **Accessibility** | `<caption>` on table. Date cells use `<time datetime>` element. |

### 7.8 `nepaEngagementList`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-collection` |
| **`@api` props** | `engagements: Array<EngagementRecord>` |
| **Derived from** | `nepa_engagement__c` records where `nepa_public_access__c = true` |
| **Displays** | Event title, type tag, date/time, location format (in-person / virtual / hybrid) |
| **Accessibility** | Each collection item `<li>` contains `<time datetime>` for machine-readable dates. |

### 7.9 `nepaRecentDocuments`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-collection` (abbreviated — 5 most recent) |
| **`@api` props** | `documents: Array<DocumentRecord>`, `viewAllHref: String` |
| **Displays** | Document title, type, publish date — truncated to 5 records with "View all documents" link |

### 7.10 `nepaCommentPeriodCards`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-card-group`, `usa-card` |
| **`@api` props** | `periods: Array<OpenCommentPeriod>` (max 3) |
| **Card contents** | Project title, review type tag, deadline date tag, "Submit a Comment" button |
| **Accessibility** | Card heading links are the primary interactive element. Buttons include project name in `aria-label`. |

### 7.11 `nepaReviewTypeTag`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-tag` |
| **`@api` props** | `reviewType: String` (API value: `EIS`, `EA`, `CE`, `Other Authorization`) |
| **Helper** | `utils/nepaReviewTypeUtils.reviewTypeLabel()`, `reviewTypeTagModifier()` |
| **Accessibility** | Tag text is always the plain English label. `title` attribute provides the expanded form for tooltip. Never color-only. |

### 7.12 `nepaAlert`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-alert`, all variants |
| **`@api` props** | `variant: 'info'|'success'|'warning'|'error'`, `heading: String`, `message: String`, `slim: Boolean` |
| **LWS notes** | `⚠ live-region` — `role="alert"` when `variant = 'error'` or `'success'` (immediate announcement). `aria-live="polite"` for `'info'` and `'warning'`. |

### 7.13 `nepaProcessAccordion`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-accordion` |
| **`@api` props** | `sections: Array<{id, heading, content, defaultOpen: Boolean}>`, `allowMultipleOpen: Boolean` |
| **LWS notes** | `⚠ toggle`, `⚠ no-eval`. Each section tracks `isOpen` in `@track expandedIds: Set`. USWDS accordion JS is not loaded. |
| **Accessibility** | `aria-expanded` on button. `aria-controls` references content panel `id`. Content panel has `hidden` attribute when closed. |

### 7.14 `nepaIconList`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-icon-list` |
| **`@api` props** | `items: Array<{iconName, content, color?}>`, `color: String`, `size: String` |
| **Assets** | Icons from `SPRITE_URL` via `utils/nepaAssets` |
| **Accessibility** | All `<svg>` icons have `aria-hidden="true"`. Content is always text, never icon-only. |

### 7.15 `nepaProcessList`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-process-list` |
| **`@api` props** | `steps: Array<{heading, body}>` |
| **Usage** | Home page "How it works" + Learn pages + authenticated next-steps on Process Detail |

### 7.16 `nepaNextSteps`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-process-list` |
| **`@api` props** | `reviewType: String`, `currentStage: String`, `isAuthenticated: Boolean` |
| **Behavior** | Shows applicant-specific next-step process list only if `isAuthenticated = true`. Driven by static configuration per review type + stage combination. |

### 7.17 `nepaCommentCta`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-button`, `usa-alert usa-alert--info` |
| **`@api` props** | `federalUniqueId: String`, `commentPeriodStart: String`, `commentPeriodEnd: String` |
| **Behavior** | Renders "Submit a Comment" button if period is open; info alert with start date if period is future; nothing if period is closed. Uses `utils/nepaDateUtils.isCommentPeriodOpen()`. |

---

## 8. LWC Shared Components — Form

### 8.1 `nepaCommentForm`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-form`, `usa-form-group`, `usa-label`, `usa-hint`, `usa-input`, `usa-textarea`, `usa-character-count`, `usa-select`, `usa-checkbox`, `usa-file-input`, `usa-button`, `usa-error-message`, `usa-validation` |
| **`@api` props** | `processId: String`, `federalUniqueId: String`, `projectTitle: String` |
| **State** | `@track formData: {name, org, email, category, body, attachFile, notifyMe}`, `@track errors: {}`, `@track submitting: Boolean`, `@track submitted: Boolean` |
| **Child LWCs** | `nepaFormGroup`, `nepaCommentModal` |
| **Events fired** | `nepacommentsubmitted` with `{detail: {referenceId}}` — consumed by `nepaPageCommentSubmit` to show success alert |
| **LWS notes** | File input: reads `File` object via `event.target.files[0]`. Uses `FormData` API (available in LWS) for multipart submit if file attachment is in scope. Character count: `⚠ live-region`. |
| **Validation** | `utils/nepaFormValidation.validateCommentForm()` on submit. Errors displayed as `usa-error-message` inline + `usa-validation` summary at top. |
| **Guard** | `connectedCallback` checks `isCommentPeriodOpen()` and dispatches navigation event to parent if closed. |

### 8.2 `nepaFormGroup`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-form-group`, `usa-label`, `usa-hint`, `usa-error-message` |
| **`@api` props** | `fieldId: String`, `label: String`, `hint: String`, `required: Boolean`, `error: String` |
| **Slots** | Default slot receives the input control (`nepaInput`, `nepaTextarea`, `nepaSelect`, etc.) |
| **Behavior** | Adds `usa-form-group--error` class and renders `usa-error-message` when `error` is non-null. Associates `aria-describedby` on child input with hint and error element IDs. |

### 8.3 `nepaInput`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-input` |
| **`@api` props** | `fieldId: String`, `type: String`, `value: String`, `maxLength: Number`, `required: Boolean`, `hasError: Boolean`, `ariaDescribedby: String` |
| **Events fired** | `neparchange` with `{detail: {value}}` |

### 8.4 `nepaTextarea`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-textarea`, `usa-character-count` |
| **`@api` props** | `fieldId: String`, `value: String`, `maxLength: Number`, `required: Boolean`, `hasError: Boolean`, `ariaDescribedby: String` |
| **LWS notes** | `⚠ live-region` — character count region has `aria-live="polite"` and updates on every `input` event. |
| **Events fired** | `nepachange` with `{detail: {value}}` |

### 8.5 `nepaSelect`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-select` |
| **`@api` props** | `fieldId: String`, `options: Array<{value, label}>`, `value: String`, `required: Boolean`, `hasError: Boolean` |
| **Events fired** | `nepachange` with `{detail: {value}}` |

### 8.6 `nepaFileInput`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-file-input` |
| **`@api` props** | `fieldId: String`, `accept: String`, `maxSizeBytes: Number`, `hasError: Boolean` |
| **LWS notes** | File size validation performed client-side via `file.size` check before submit. `accept="application/pdf"` enforced on the input element. |
| **Events fired** | `nepafileselected` with `{detail: {file: File|null}}` |
| **Accessibility** | Drag-and-drop affordance is supplemental — all upload functionality available via native file picker. |

### 8.7 `nepaCheckbox`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-checkbox` |
| **`@api` props** | `fieldId: String`, `label: String`, `checked: Boolean`, `hint: String` |
| **Events fired** | `nepachange` with `{detail: {checked: Boolean}}` |

### 8.8 `nepaCommentModal`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-modal` |
| **`@api` props** | `isOpen: Boolean`, `formData: Object` (read-only preview of comment) |
| **Events fired** | `nepamodalconfirm` (user clicks "Submit Comment"), `nepamodalcancel` (user clicks "Go back and edit" or presses Escape) |
| **LWS notes** | `⚠ toggle`, `⚠ focus-trap`. On `isOpen` transition to `true`: `connectedCallback`-registered `keydown` listener intercepts Escape. Focus moves to modal container via `this.template.querySelector('.usa-modal').focus()`. On close: focus returns to the "Review and Submit" button via stored reference. |
| **Accessibility** | `aria-labelledby` references modal heading id. `aria-describedby` references comment preview id. `aria-modal="true"`. Scrollable content inside modal has `tabindex="0"`. |

### 8.9 `nepaSubmitSuccessAlert`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-alert usa-alert--success` |
| **`@api` props** | `referenceId: String` |
| **LWS notes** | `⚠ live-region` — `role="alert"` so screen reader announces immediately after submit. Focus moves to this element on render. |
| **Displays** | "Your comment was received. Your reference ID is [referenceId]." |

### 8.10 `nepaCommentGuidance`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **USWDS** | `usa-summary-box` |
| **`@api` props** | None — static content |
| **Displays** | Bulleted guidance on what makes a comment effective; links to `/learn/comment-guide` |

---

## 9. LWC Shared Components — Content and Layout

### 9.1 `nepaHero`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-hero` |
| **`@api` props** | `heading: String`, `subheading: String` |
| **Child LWCs** | `nepaSearchBar` (embedded in hero callout box) |

### 9.2 `nepaSearchBar`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **USWDS** | `usa-search`, `usa-search--big` |
| **`@api` props** | `variant: 'big'|'medium'|'small'`, `initialValue: String`, `placeholder: String` |
| **Events fired** | `nepasearch` with `{detail: {query: String}}` — consumed by page component to update URL param and trigger wire |
| **Accessibility** | `<form role="search">`. `<label class="usa-sr-only">` always present even when visually hidden. Submit button `aria-label="Search"`. |

### 9.3 `nepaPortalSummary`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-summary-box`, `usa-dark-background`, `usa-section` |
| **`@api` props** | None — static content |
| **Displays** | Portal mission statement, links to `/learn` and `/about` |

### 9.4 `nepaLearnCards`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-card-group`, `usa-card` |
| **`@api` props** | None — static content |
| **Displays** | Three cards: "What is NEPA", "Review Types", "How to Comment" — each links to corresponding `/learn/:slug` |

### 9.5 `nepaLearnContentBlock`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **USWDS** | `usa-prose`, `usa-process-list`, `usa-accordion`, `usa-table`, `usa-icon-list` |
| **`@api` props** | `slug: String` (drives which static content set renders) |
| **LWS notes** | Content is authored as static LWC template sections selected by `slug`, not as raw HTML injection. No `innerHTML`. |
| **Accessibility** | All headings follow logical H1 → H2 → H3 hierarchy. Section anchors use `id` attributes matching `nepaInPageNav` section anchors. |

---

## 10. OmniStudio Override Components

OmniStudio override components replace the default OmniStudio renderer for specific FlexCards and OmniScripts with USWDS-compliant LWC implementations. They use the OmniStudio mixin APIs and are registered by setting the `lwcName` on the parent OmniStudio artifact.

### 10.1 `nepaCardProjectOverride`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **Type** | FlexCard LWC Override |
| **Overrides FlexCard** | `NEPA_Project_Card` (see §11.2) |
| **USWDS** | `usa-card`, `usa-card__container`, `usa-card__header`, `usa-card__body`, `usa-card__footer` |
| **Mixin** | `import { FlexCardMixin } from 'omnistudio/flexCardMixin'` |
| **Props received from FlexCard** | Standard FlexCard `cardData`, `cardActions`, `cardStates` props via mixin |
| **Renders** | Project title (card heading as link), review type `nepaReviewTypeTag`, process stage, comment deadline with urgency coloring |
| **Events** | Consumes standard FlexCard action events; routes "View Project" to `utils/nepaNavigationUtils.projectPageRef()` |
| **LWS notes** | FlexCard mixin wiring is LWS-safe. No direct window access needed. |
| **Accessibility** | Card heading `<h2>` or `<h3>` depending on context. CTA button includes project name in `aria-label`. |

### 10.2 `nepaCardDocumentOverride`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **Type** | FlexCard LWC Override |
| **Overrides FlexCard** | `NEPA_Document_Card` (see §11.3) |
| **USWDS** | `usa-collection__item` (collection list item pattern) |
| **Mixin** | `import { FlexCardMixin } from 'omnistudio/flexCardMixin'` |
| **Renders** | Document name (download link), type tag, publish date `<time>`, status, download icon button |
| **Accessibility** | Download link includes full document name in accessible text. `<time datetime>` for publish date. |

### 10.3 `nepaCardProcessStatusOverride`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **Type** | FlexCard LWC Override |
| **Overrides FlexCard** | `NEPA_Process_Status` (see §11.4) |
| **USWDS** | `usa-step-indicator`, `usa-tag`, `usa-alert` |
| **Mixin** | `import { FlexCardMixin } from 'omnistudio/flexCardMixin'` |
| **Renders** | Step indicator driven by FlexCard data action result from `DR_Extract_NEPA_Process`; review type tag; timeline risk tier (internal users only — hidden from guest via FlexCard state condition) |
| **Helper** | `utils/nepaStageUtils.buildStepIndicator()` |

### 10.4 `nepaCardEngagementOverride`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **Type** | FlexCard LWC Override |
| **Overrides FlexCard** | `NEPA_Engagement_Card` (see §11.5) |
| **USWDS** | `usa-collection__item`, `usa-tag`, `usa-icon-list` |
| **Mixin** | `import { FlexCardMixin } from 'omnistudio/flexCardMixin'` |
| **Renders** | Event title, engagement type tag, formatted `<time>` element, location format indicator (in-person / virtual / hybrid icon) |
| **Assets** | USWDS icons from `SPRITE_URL` |

### 10.5 `nepaFormCommentOverride`

| Attribute | Value |
|---|---|
| **Priority** | P0 |
| **Type** | OmniScript LWC Override |
| **Overrides OmniScript** | `NEPA_Comment_Submission` (see §11.6) |
| **USWDS** | Full comment form — same component inventory as `nepaCommentForm` (§8.1) |
| **Mixin** | `import { OmniscriptBaseMixin } from 'omnistudio/omniscriptBaseMixin'` |
| **Behavior** | Wraps the OmniScript step data in the USWDS form layout. OmniScript handles server-side Integration Procedure call (`NEPA_Comment_Submit`); LWC override handles all visual rendering and client-side validation. |
| **OmniScript data flow** | LWC reads step JSON from `this.jsonData` (provided by mixin). Writes field values back via `this.omniApplyCallResp()`. Advances step via `this.omniNextStep()`. |
| **LWS notes** | OmniScript mixin APIs are LWS-safe in Salesforce Industries namespace. `⚠ toggle` for confirmation modal. `⚠ focus-trap` for modal. `⚠ live-region` for character count. |
| **Accessibility** | All form accessibility requirements from §8.1 apply. OmniScript step navigation uses `aria-live="polite"` for step transition announcements. |

### 10.6 `nepaFormSearchOverride`

| Attribute | Value |
|---|---|
| **Priority** | P1 |
| **Type** | OmniScript LWC Override |
| **Overrides OmniScript** | `NEPA_Project_Search` (see §11.7) |
| **USWDS** | `usa-search`, `usa-tag` (filter chips), `usa-table`, `usa-pagination` |
| **Mixin** | `import { OmniscriptBaseMixin } from 'omnistudio/omniscriptBaseMixin'` |
| **Behavior** | Overrides the default OmniScript search results renderer with the USWDS table + pagination pattern. Reads search results from `this.jsonData.searchResults` and filter options from `this.jsonData.filterOptions`. |
| **OmniScript data flow** | Search term and filter values written back to OmniScript JSON via `this.omniApplyCallResp()`. Pagination offset written as OmniScript step variable. |

### 10.7 `nepaOmniWrapper`

| Attribute | Value |
|---|---|
| **Priority** | P2 |
| **Type** | OmniScript wrapper / container |
| **Purpose** | Generic LWC wrapper that embeds any NEPA OmniScript in an Experience Cloud page with USWDS layout context (header/footer excluded — those are provided by the LWR theme). Provides the `usa-section` container, breadcrumb injection, and page-level error boundary. |
| **`@api` props** | `omniScriptType: String`, `omniScriptSubType: String`, `omniScriptLanguage: String`, `breadcrumbs: Array` |
| **Child LWCs** | `nepaBreadcrumb`, `nepaAlert` (error boundary), `omnistudio/omniscriptBasic` (or the override component) |
| **LWS notes** | Uses `lightning/platformResourceLoader` to load OmniStudio runtime if not already present in the LWR bundle. |

---

## 11. OmniStudio Artifacts

These OmniStudio artifacts are consumed by the portal and must be created in the PSA-NEPA org. They are listed here as dependencies the LWC project relies on for data and process execution.

### 11.1 DataRaptors (Extract)

DataRaptors are server-side data transforms that the portal's Integration Procedures and FlexCards use to read from PSS objects and shape data for the UI.

| Artifact | Type | Source object(s) | Output shape |
|---|---|---|---|
| `DR_Extract_NEPA_Project` | DataRaptor Extract | `Program` | Project summary fields for card/table display |
| `DR_Extract_NEPA_Process` | DataRaptor Extract | `IndividualApplication` | Process fields + comment period dates (guest-safe field set) |
| `DR_Extract_NEPA_Document` | DataRaptor Extract | `ContentVersion` | Public documents filtered to `nepa_public_access__c = true` |
| `DR_Extract_NEPA_Comment` | DataRaptor Extract | `PublicComplaint` | Comment reference ID only (no cross-user read) |
| `DR_Extract_NEPA_EngagementEvent` | DataRaptor Extract | `nepa_engagement__c` | Public engagement events filtered to `nepa_public_access__c = true` |
| `DR_Extract_NEPA_CaseEvent` | DataRaptor Extract | `ApplicationTimeline` | Public process timeline events |

### 11.2 FlexCard: `NEPA_Project_Card`

| Attribute | Value |
|---|---|
| **LWC override** | `nepaCardProjectOverride` |
| **Data action** | Calls `DR_Extract_NEPA_Project` |
| **States** | `default`, `comment-open`, `comment-urgent` (drives override rendering variant) |
| **Exposed on** | Home page comment period section, `/projects` search results (as card fallback) |

### 11.3 FlexCard: `NEPA_Document_Card`

| Attribute | Value |
|---|---|
| **LWC override** | `nepaCardDocumentOverride` |
| **Data action** | Calls `DR_Extract_NEPA_Document` |
| **States** | `default`, `no-documents` (empty state) |
| **Exposed on** | Project overview recent documents section |

### 11.4 FlexCard: `NEPA_Process_Status`

| Attribute | Value |
|---|---|
| **LWC override** | `nepaCardProcessStatusOverride` |
| **Data action** | Calls `DR_Extract_NEPA_Process` |
| **States** | One state per `nepa_process_stage__c` value |
| **Exposed on** | Project overview, process detail page |

### 11.5 FlexCard: `NEPA_Engagement_Card`

| Attribute | Value |
|---|---|
| **LWC override** | `nepaCardEngagementOverride` |
| **Data action** | Calls `DR_Extract_NEPA_EngagementEvent` |
| **States** | `upcoming`, `past` |
| **Exposed on** | Project overview engagement section |

### 11.6 OmniScript: `NEPA_Comment_Submission`

| Attribute | Value |
|---|---|
| **LWC override** | `nepaFormCommentOverride` |
| **Type / SubType** | `NEPA` / `CommentSubmission` |
| **Steps** | Step 1: Commenter info (name, org, email). Step 2: Comment body + category + file. Step 3: Review + confirm. Step 4: Success. |
| **IP called** | `NEPA_Comment_Submit` Integration Procedure (on final step action) |
| **Pre-conditions** | `processId` and `federalUniqueId` injected as launch parameters |
| **Error handling** | IP error response surfaced as `usa-alert--error` via override component's error state |

### 11.7 OmniScript: `NEPA_Project_Search`

| Attribute | Value |
|---|---|
| **LWC override** | `nepaFormSearchOverride` |
| **Type / SubType** | `NEPA` / `ProjectSearch` |
| **Steps** | Step 1: Search input + filter selection. Step 2: Results display with pagination. |
| **IP called** | `NEPA_Project_Search_IP` Integration Procedure |
| **Purpose** | Alternative to pure Apex-wired search for deployments where OmniStudio is the preferred data layer |

### 11.8 Integration Procedure: `NEPA_Comment_Submit`

| Attribute | Value |
|---|---|
| **Called by** | `NEPA_Comment_Submission` OmniScript (final step action) |
| **Actions** | DataRaptor Transform (map comment fields to `PublicComplaint` shape) → DataRaptor Load (create `PublicComplaint` record) → Response action (return created record ID) |
| **Guest user** | Runs as the Experience Cloud guest user; `PublicComplaint` object must allow guest Create |
| **Error response** | Structured error JSON returned to OmniScript for surface in override component |

### 11.9 Integration Procedure: `NEPA_Project_Search_IP`

| Attribute | Value |
|---|---|
| **Called by** | `NEPA_Project_Search` OmniScript, and optionally directly from `nepaPageProjects` via `OmniRemoteCall` |
| **Actions** | DataRaptor Extract (`DR_Extract_NEPA_Project`) with dynamic filter parameters → sort/pagination transform → response |
| **Parameters** | `searchTerm`, `reviewTypeFilter`, `sortBy`, `pageNumber`, `pageSize` |

### 11.10 Integration Procedure: `NEPA/CEQExport` *(existing)*

| Attribute | Value |
|---|---|
| **Status** | Already defined in `package.xml` |
| **Portal role** | Not directly called from the public portal; invoked by authenticated agency users for bulk CEQ data export. No portal LWC needed. |
| **Note** | Included here for completeness — the implementation project should not add portal LWC hooks to this IP. |

---

## 12. Apex Controllers and Inner Classes

All Apex methods must enforce guest-user visibility in their SOQL WHERE clauses — never rely on profile-based FLS alone.

### 12.1 `NepaProjectController`

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `getProjectList` | `(String searchTerm, String reviewTypeFilter, String sortBy, Integer pageNumber, Integer pageSize)` | `true` | `ProjectListResult` |
| `getProjectDetail` | `(String federalUniqueId)` | `true` | `ProjectDetail` |
| `getOpenCommentPeriods` | `()` | `true` | `List<OpenCommentPeriod>` |

**Inner classes:**

```apex
public class ProjectListResult {
    @AuraEnabled public List<ProjectResult> projects;
    @AuraEnabled public Integer totalCount;
    @AuraEnabled public Integer pageSize;
    @AuraEnabled public Integer pageNumber;
}

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

public class OpenCommentPeriod {
    @AuraEnabled public String projectTitle;
    @AuraEnabled public String federalUniqueId;
    @AuraEnabled public String reviewType;
    @AuraEnabled public String commentPeriodEnd;
    @AuraEnabled public Integer daysRemaining;
}
```

### 12.2 `NepaDocumentController`

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `getPublicDocuments` | `(String processId, String docTypeFilter, Integer pageNumber, Integer pageSize)` | `true` | `DocumentListResult` |
| `getContentDownloadUrl` | `(String contentVersionId)` | `true` | `String` (CDN URL) |

**SOQL filter required:**
```sql
WHERE nepa_public_access__c = true
  AND ContentDocument.LinkedEntityId = :processId
```

**Inner classes:**

```apex
public class DocumentListResult {
    @AuraEnabled public List<DocumentRecord> documents;
    @AuraEnabled public Integer totalCount;
}

public class DocumentRecord {
    @AuraEnabled public String contentVersionId;
    @AuraEnabled public String documentTitle;
    @AuraEnabled public String documentType;
    @AuraEnabled public String status;
    @AuraEnabled public String publishDate;
    @AuraEnabled public String downloadUrl;
}
```

### 12.3 `NepaEngagementController`

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `getPublicEngagements` | `(String processId)` | `true` | `List<EngagementRecord>` |

**SOQL filter required:**
```sql
WHERE nepa_public_access__c = true
  AND nepa_process__c = :processId
```

**Inner class:**

```apex
public class EngagementRecord {
    @AuraEnabled public String id;
    @AuraEnabled public String title;
    @AuraEnabled public String engagementType;
    @AuraEnabled public String startDatetime;
    @AuraEnabled public String endDatetime;
    @AuraEnabled public String locationFormat;
    @AuraEnabled public String location;
}
```

### 12.4 `NepaCommentController`

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `submitComment` | `(CommentInput input)` | `false` | `String` (reference ID) |

**Security requirements:**
- Validate comment period is still open before insert (server-side, not client-side only)
- Sanitize all string inputs (strip HTML tags)
- Rate-limit by IP or session using a custom Platform Event + check approach (implementation detail)

**Inner class:**

```apex
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
```

### 12.5 `NepaTimelineController`

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `getProcessTimeline` | `(String processId)` | `true` | `List<TimelineEvent>` |

**Inner class:**

```apex
public class TimelineEvent {
    @AuraEnabled public String eventType;
    @AuraEnabled public String stage;
    @AuraEnabled public String startDate;
    @AuraEnabled public String endDate;
    @AuraEnabled public String status;
    @AuraEnabled public String source;
}
```

### 12.6 `NepaIndustryCodePickerController`

Apex controller for the `nepaIndustryCodePickerOmni` OmniScript LWC. Reads NAICS 2022 code hierarchy from `NEPA_NAICS_Code__mdt` and returns all five levels in a single cacheable call.

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `getAllOptions` | `()` | `true` | `PickerOptions` |

**Inner classes:**

```apex
public class PickerOptions {
    @AuraEnabled public List<PickerOption> sectorOptions;
    @AuraEnabled public List<PickerOption> subSectorOptions;
    @AuraEnabled public List<PickerOption> industryGroupOptions;
    @AuraEnabled public List<PickerOption> industryOptions;
    @AuraEnabled public List<PickerOption> nationalIndustryOptions;
}

public class PickerOption {
    @AuraEnabled public String value;       // NAICS code (e.g. "11", "111", "111110")
    @AuraEnabled public String label;       // Full official NAICS title
    @AuraEnabled public String parentValue; // Parent code for cascading filter
}
```

**OmniScript wiring:** Add a Custom LWC element with `componentName: nepaIndustryCodePickerOmni`. Optionally pass `fieldName` (default `naicsCode`), `sectorFieldName`, `subSectorFieldName`, `industryGroupFieldName`, `industryFieldName`. The component writes all selected level values via `omniUpdateDataJson()`.

**Data requirement:** Requires 2,129 `NEPA_NAICS_Code__mdt` records across 5 levels (Sector, SubSector, IndustryGroup, Industry, NationalIndustry) loaded via Apex anonymous. See QUICKSTART.md Step 4i for verification and reload instructions.

---

### 12.7 `NepaMapCreateCtr`

Apex controller for the `NEPA_Site_Location_Page` Visualforce page, which is embedded as an iframe inside `nepaSiteLocationPickerOmni`. Provides URL resolution methods needed for LWR-compatible postMessage origin validation.

| Method | Signature | Cacheable | Returns |
|---|---|---|---|
| `fetchCommunityURL` | `()` | `true` | `String` — Experience Cloud site secure URL (postMessage origin for VF → LWC) |
| `fetchVFDomainURL` | `()` | `true` | `String` — VF domain URL (postMessage origin for LWC → VF) |
| `defaultAddressCoordinates` | `(String inputAddress)` | `true` | `String` — `'longitude\|latitude'` from `NEPA_Map_Config__mdt` defaults |

**Configuration dependency:** Reads API key and default coordinates from `NEPA_Map_Config__mdt`. The `ApiKey` record must be set to a valid ESRI key after deploy (Setup → Custom Metadata Types → NEPA Map Config). Default coordinates ship as US center (39.5°N, 98.35°W).

**OmniScript wiring:** Add a Custom LWC element with `componentName: nepaSiteLocationPickerOmni`. Set `fieldName` (default `siteLocation`); optionally set `latFieldName` and `lngFieldName` for flat lat/lng fields. The component writes `{ lat, lng, geometry }` via `omniUpdateDataJson()`.

**CSP requirement:** The `NEPA_Site_Location_Page` VF page loads the ArcGIS JS SDK v4.29 from CDN. Two CSP Trusted Sites must be configured in Setup: `https://js.arcgis.com` (script-src) and `https://*.arcgis.com` (connect-src). See QUICKSTART.md Step 4h.

---

## 13. Experience Cloud Configuration

These items are configured in the Experience Cloud Site Builder / Administration, not in the LWC project. They are listed here as implementation dependencies.

### 13.1 LWR Theme and Branding

| Item | Requirement |
|---|---|
| Site engine | Lightning Web Runtime (LWR) — not Aura |
| Global stylesheet | `nepa_uswds_styles` static resource, loaded as CSS resource in Site Configuration |
| Global head markup | `<html lang="en">` (set in Experience Cloud theme; cannot be set from LWC) |
| Skip navigation | First element in LWR theme layout template before any rendered content |
| `<meta name="viewport">` | `width=device-width, initial-scale=1` — required for WCAG 1.4.10 Reflow |

### 13.2 Guest User Profile

| Object / Field | Access |
|---|---|
| `Program` — all fields listed in §3 of design doc | Read |
| `IndividualApplication` — `nepa_review_type__c`, `nepa_process_status__c`, `nepa_process_stage__c`, `nepa_public_comment_period_start__c`, `nepa_public_comment_period_end_date__c`, `nepa_federal_unique_id__c`, `nepa_federal_unique_id__c` | Read |
| `ContentVersion` — filtered to `nepa_public_access__c = true` | Read |
| `PublicComplaint` | Create only (no Read) |
| `nepa_engagement__c` — filtered to `nepa_public_access__c = true` | Read |
| `ApplicationTimeline` — public events only | Read |
| `NepaProjectController` Apex class | Execute |
| `NepaDocumentController` Apex class | Execute |
| `NepaEngagementController` Apex class | Execute |
| `NepaCommentController` Apex class | Execute |
| `NepaTimelineController` Apex class | Execute |
| Risk scoring fields (`nepa_risk_score__c`, `nepa_risk_tier__c`, `nepa_defensibility_*`) | **No access** |

### 13.3 Content Security Policy

| Directive | Value |
|---|---|
| `font-src` | `'self'` (Public Sans served from `nepa_uswds_assets` static resource) |
| `script-src` | `'self'` — no `'unsafe-inline'` |
| `style-src` | `'self'` — no `'unsafe-inline'` |
| `connect-src` | Salesforce instance domain only |
| `img-src` | `'self'` — all images from static resources, no external CDN |
| `frame-src` | Blocked (no iframes except map embed if approved — requires explicit allowlist entry) |

### 13.4 Page Routes

| URL path | LWC page component | Notes |
|---|---|---|
| `/` | `nepaPageHome` | |
| `/projects` | `nepaPageProjects` | URL params: `q`, `reviewType`, `sort`, `page` |
| `/projects/{federalUniqueId}` | `nepaPageProjectDetail` | Path param via `CurrentPageReference` |
| `/projects/{federalUniqueId}/process` | `nepaPageProcessDetail` | |
| `/projects/{federalUniqueId}/process/documents` | `nepaPageDocuments` | URL params: `docType`, `page` |
| `/projects/{federalUniqueId}/process/comments` | `nepaPageCommentSubmit` | Redirect to `/projects/{id}` if period closed |
| `/learn` | `nepaPageLearnIndex` | |
| `/learn/{slug}` | `nepaPageLearnContent` | Slugs: `what-is-nepa`, `review-types`, `comment-guide` |
| `/about` | `nepaPageAbout` | |

---

## 14. Dependency Graph

```
nepaPageHome
├── nepaBanner              → (static)
├── nepaHeader              → (static nav config)
├── nepaSiteAlert           → getOpenCommentPeriods()
├── nepaHero
│   └── nepaSearchBar       → fires nepasearch → URL navigation
├── nepaProcessList         → (static)
├── nepaCommentPeriodCards  → getOpenCommentPeriods()
│   └── nepaReviewTypeTag   → utils/nepaReviewTypeUtils
└── nepaFooter              → (static)

nepaPageProjects
├── nepaBanner, nepaHeader, nepaFooter
├── nepaBreadcrumb          → utils/nepaNavigationUtils
├── nepaSearchBar           → fires nepasearch
├── nepaTagFilter           → fires nepafilterchange
├── nepaAlert               → (conditional empty state)
├── nepaProjectTable        → getProjectList(@wire reactive)
│   └── nepaReviewTypeTag
└── nepaPagination          → fires nepapagechange

nepaPageProjectDetail
├── nepaBanner, nepaHeader, nepaFooter
├── nepaBreadcrumb
├── nepaDeadlineAlert       → utils/nepaDateUtils
├── nepaProjectSummary      → getProjectDetail(@wire)
│   └── nepaReviewTypeTag
├── nepaStepIndicator       → utils/nepaStageUtils
├── nepaInPageNav
├── nepaRecentDocuments     → getPublicDocuments(@wire, limit 5)
├── nepaEngagementList      → getPublicEngagements(@wire)
│   └── nepaCardEngagementOverride (FlexCard override)
└── nepaCommentCta          → utils/nepaDateUtils

nepaPageProcessDetail
├── nepaBanner, nepaHeader, nepaFooter
├── nepaBreadcrumb
├── nepaStepIndicator
├── nepaCommentPeriodSummary → utils/nepaDateUtils
├── nepaDeadlineAlert
├── nepaProcessTimeline     → getProcessTimeline(@wire)
├── nepaProcessAccordion    → getProcessDetail(@wire)
└── nepaCommentCta

nepaPageDocuments
├── nepaBanner, nepaHeader, nepaFooter
├── nepaBreadcrumb
├── nepaTagFilter
├── nepaDocumentTable       → getPublicDocuments(@wire reactive)
└── nepaPagination

nepaPageCommentSubmit
├── nepaBanner, nepaHeader, nepaFooter
├── nepaBreadcrumb
├── nepaDeadlineAlert
├── nepaCommentGuidance
├── nepaCommentForm         → getProcessRecord(@wire); submitComment() imperative
│   ├── nepaFormGroup
│   │   ├── nepaInput
│   │   ├── nepaTextarea
│   │   ├── nepaSelect
│   │   ├── nepaFileInput
│   │   └── nepaCheckbox
│   └── nepaCommentModal
└── nepaSubmitSuccessAlert

OmniStudio overrides
├── nepaCardProjectOverride     → FlexCard: NEPA_Project_Card
│                                  → DR_Extract_NEPA_Project
├── nepaCardDocumentOverride    → FlexCard: NEPA_Document_Card
│                                  → DR_Extract_NEPA_Document
├── nepaCardProcessStatusOverride → FlexCard: NEPA_Process_Status
│                                  → DR_Extract_NEPA_Process
├── nepaCardEngagementOverride  → FlexCard: NEPA_Engagement_Card
│                                  → DR_Extract_NEPA_EngagementEvent
├── nepaFormCommentOverride     → OmniScript: NEPA_Comment_Submission
│                                  → IP: NEPA_Comment_Submit
│                                  → DR Load → PublicComplaint
└── nepaFormSearchOverride      → OmniScript: NEPA_Project_Search
                                   → IP: NEPA_Project_Search_IP
                                   → DR Extract → Program + IndividualApplication

Shared utilities (imported by all components as needed)
├── utils/nepaAssets            → @salesforce/resourceUrl/nepa_uswds_assets
├── utils/nepaDateUtils         → Intl.DateTimeFormat (LWS-safe)
├── utils/nepaReviewTypeUtils   → static picklist maps
├── utils/nepaStageUtils        → static stage sequence maps
├── utils/nepaNavigationUtils   → NavigationMixin pageRef builders
└── utils/nepaFormValidation    → pure validation functions
```

---

*End of manifest. Total deliverables: 9 page components · 34 shared LWC components · 7 OmniStudio override components · 6 utility modules · 2 static resources · 5 Apex controllers · 10 OmniStudio artifacts · 1 Experience Cloud site configuration.*
