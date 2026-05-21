// create_visit_apts_blm.apex
// Creates 7 Visit-targeted NEPA_WO_* ActionPlanTemplates with _BLM UniqueName suffix.
// Required because the original UniqueNames are permanently locked by the platform
// even after hard-delete. The Display Names (Name field) are unchanged.
// Pattern: insert template → query auto-created Draft version → insert items (linked
// to version) → insert item values → update version Status to Final.
// Run: sf apex run --file scripts/create_visit_apts_blm.apex --target-org NEPA_INNOVATOR

// ─── Template definitions ────────────────────────────────────────────────────
// [uniqueName, displayName, description]
List<List<String>> templates = new List<List<String>>{
    new List<String>{
        'NEPA_WO_Aquatic_Milestones_BLM',
        'NEPA WO Aquatic Milestones',
        'Field survey milestones for a Fisheries and Wildlife Biologist (Aquatic) Work Order. Covers riparian survey, amphibian presence/absence, and CWA Section 404 memo. Target object: Visit.'
    },
    new List<String>{
        'NEPA_WO_BigGame_Milestones_BLM',
        'NEPA WO Big Game Milestones',
        'Field survey milestones for a Wildlife Biologist (Big Game) Work Order. Covers shoulder-season assessment, winter range mapping, and pronghorn/elk migration corridor analysis. Target object: Visit.'
    },
    new List<String>{
        'NEPA_WO_Botanical_Milestones_BLM',
        'NEPA WO Botanical Milestones',
        'Field survey milestones for a Botanist Work Order. Two seasonal site visits (June-July and August) for rare plant detection, plus seed mix approval. Target object: Visit.'
    },
    new List<String>{
        'NEPA_WO_Geology_Milestones_BLM',
        'NEPA WO Geology Milestones',
        'Field survey milestones for a Geologist Visit triggered by EPA Superfund NPL or contamination-related GIS layer detection. Covers soils assessment, access road erosion review, CERCLA coordination, and reclamation bond memo. Target object: Visit.'
    },
    new List<String>{
        'NEPA_WO_Hydrology_Milestones_BLM',
        'NEPA WO Hydrology Milestones',
        'Field survey milestones for a hydrologist Visit triggered by NWI Wetlands or other aquatic/riparian GIS layer detection. Covers pre-survey prep, field assessment, CWA/NPDES review, and delineation report. Target object: Visit.'
    },
    new List<String>{
        'NEPA_WO_MigratoryBird_Milestones_BLM',
        'NEPA WO Migratory Bird Milestones',
        'Field survey milestones for a Wildlife Biologist (Avian) Work Order. Covers spring nesting window survey (April-August), MBTA compliance, and avian collision risk assessment. Target object: Visit.'
    },
    new List<String>{
        'NEPA_WO_SageGrouse_Milestones_BLM',
        'NEPA WO Sage-Grouse Milestones',
        'Field survey milestones for a Wildlife Biologist (Sage-Grouse) Visit triggered by FWS Critical Habitat detection. Covers lek survey window compliance, ARMPA conformance check, and survey report. Target object: Visit.'
    }
};

// ─── Task items per template ─────────────────────────────────────────────────
// [uniqueName, itemName, subject, priority, description]
Map<String, List<List<String>>> taskDefs = new Map<String, List<List<String>>>{
    'NEPA_WO_Aquatic_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_Aqua_1_Desktop_BLM', 'Aquatic Species Desktop Review',
            'Aquatic Species Desktop Review', 'High',
            'Query USFWS IPaC, NatureServe, and state Natural Heritage Program for T&E fish, amphibian, and aquatic invertebrate species within the HUC-12 watershed. Review state fish passage barrier databases. Pull NHD reaches and classify all water features within 1,000 feet of project footprint as perennial, intermittent, or ephemeral. Identify CWA Section 7 consultation triggers.'
        },
        new List<String>{
            'NEPA_WO_Aqua_2_Riparian_BLM', 'Riparian Survey and Fish Habitat Assessment',
            'Riparian Survey and Fish Habitat Assessment', 'High',
            'Conduct habitat assessment of all water features within 300 feet of project APE per Proper Functioning Condition or Rosgen method. Document channel condition, substrate, pool-riffle ratio, riparian vegetation, bank stability, and flow regime. Conduct visual electrofishing or snorkel survey for fish species documentation.'
        },
        new List<String>{
            'NEPA_WO_Aqua_3_Amphibian_BLM', 'Amphibian Presence/Absence Survey',
            'Amphibian Presence/Absence Survey', 'High',
            'Conduct presence/absence surveys for T&E amphibian species (boreal toad, Columbia spotted frog, western toad) using visual encounter surveys and call playback. Survey all suitable breeding habitat within project APE. Conduct three surveys spaced at least 7 days apart during active breeding season (April-July).'
        },
        new List<String>{
            'NEPA_WO_Aqua_4_Memo_BLM', 'CWA Section 404 and ESA Section 7 Memo',
            'CWA Section 404 and ESA Section 7 Aquatic Species Memo', 'High',
            'Compile riparian survey, fish habitat, and amphibian survey results. Provide CWA Section 404 jurisdictional determination memo. Document ESA Section 7 effect determination for each aquatic T&E species. If formal Section 7 consultation is required, draft Biological Assessment sections. Upload report as ContentVersion linked to the Visit and IndividualApplication. Mark Visit Status = Completed when approved.'
        }
    },
    'NEPA_WO_BigGame_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_BigGame_1_Desktop_BLM', 'Big Game Desktop Review',
            'Big Game Desktop Review and Range Assessment', 'High',
            'Query BLM big game habitat management maps, state wildlife agency seasonal range data, and USFWS T&E species list for deer, elk, pronghorn, bighorn sheep, and mountain goat. Review Rocky Mountain Elk Foundation habitat layers. Identify any federally listed big game species with confirmed occurrences within 10 miles of project APE. Map project footprint overlap with state-designated crucial winter range, calving areas, and migration corridors.'
        },
        new List<String>{
            'NEPA_WO_BigGame_2_ShoulderSeason_BLM', 'Shoulder-Season Field Assessment',
            'Shoulder-Season Field Assessment — Big Game Use', 'High',
            'Conduct field habitat assessment during shoulder season (October-November or March-April) for big game species. Document habitat quality, forage availability, water sources, cover types, and evidence of big game use (tracks, scat, wallows, rubs, trails). Record GPS coordinates of all sign and habitat patches. Note proximity of proposed project features to crucial habitat components.'
        },
        new List<String>{
            'NEPA_WO_BigGame_3_WinterRange_BLM', 'Winter Range and Migration Corridor Mapping',
            'Winter Range Mapping and Migration Corridor Analysis', 'High',
            'Map project footprint against state-designated pronghorn and elk migration corridors using state agency GIS data. Identify any fence-crossing pinch points or proposed infrastructure within 0.5 miles of documented migration routes. Assess project timing overlap with migration windows (October-November, March-May). Document any proposed fencing — evaluate compatibility with BLM Fence Standards for big game passage (top wire height, bottom clearance, smooth wire requirement).'
        },
        new List<String>{
            'NEPA_WO_BigGame_4_Report_BLM', 'Big Game Survey Report',
            'Big Game Assessment and Mitigation Report', 'High',
            'Compile desktop review, habitat assessment, and migration corridor analysis into a single big game report. Document species-specific mitigation measures: fence modifications, seasonal construction restrictions (November 15 – April 30 in crucial winter range), road crossing treatments, and habitat restoration commitments. Upload report as ContentVersion linked to the Visit and IndividualApplication. Mark Visit Status = Completed when report is approved by NEPA lead.'
        }
    },
    'NEPA_WO_Botanical_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_Bot_1_Desktop_BLM', 'Botanical Desktop Review and Survey Planning',
            'Botanical Desktop Review and Survey Planning', 'High',
            'Query USDA PLANTS database, state Natural Heritage Program, and BLM sensitive species list for T&E and BLM sensitive plant species within 5 miles of project APE. Identify peak bloom windows for each species requiring detection surveys. Review existing survey reports from BLM field office. Prepare species-specific survey protocols and field data forms. Identify suitable habitat patches requiring 100% coverage surveys.'
        },
        new List<String>{
            'NEPA_WO_Bot_2_Visit1_BLM', 'Site Visit 1 — Early Season Survey',
            'Botanical Site Visit 1 — Early Season Survey (June-July)', 'High',
            'Conduct early-season floristic survey of entire APE plus 50-foot buffer. Survey all suitable habitat patches for early-blooming T&E and BLM sensitive species. Use 100% coverage transect methodology for high-potential habitat. Document all occurrences with GPS coordinates, population size, phenological stage, and condition. Photograph diagnostic features of any potentially T&E individuals.'
        },
        new List<String>{
            'NEPA_WO_Bot_3_Visit2_BLM', 'Site Visit 2 — Late Season Survey',
            'Botanical Site Visit 2 — Late Season Survey (August)', 'High',
            'Conduct late-season floristic survey targeting late-blooming species not detectable in June-July survey. Re-survey high-potential habitat patches with negative results from Visit 1 to confirm absence. Collect voucher specimens for any unidentified individuals requiring taxonomic confirmation. Revisit known populations to document status and current condition.'
        },
        new List<String>{
            'NEPA_WO_Bot_4_SeedMix_BLM', 'Reclamation Seed Mix Approval',
            'Reclamation Seed Mix Review and Approval', 'High',
            'Develop native seed mix appropriate to plant communities documented in survey. Use only locally adapted, weed-free seed from certified sources. Specify seeding rates (lbs PLS/acre) for each species component. Verify mix against BLM state office approved seed lists. Exclude invasive or non-native species. Upload seed mix memo as ContentVersion linked to Visit and IndividualApplication. Mark Visit Status = Completed when approved by NEPA lead.'
        }
    },
    'NEPA_WO_Geology_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_Geo_1_Desktop_BLM', 'Geology and Soils Desktop Review',
            'Geology and Soils Desktop Review', 'High',
            'Review EPA Superfund NPL hit data and site Record of Decision if available on EPA CERCLIS. Pull NRCS Web Soil Survey data for project APE — document all map units, erodibility (K-factor), and limitations. Review state geological survey maps for bedrock depth, fault zones, and groundwater vulnerability. Identify applicable state VPDES/NPDES stormwater requirements for ground-disturbing activities.'
        },
        new List<String>{
            'NEPA_WO_Geo_2_Field_BLM', 'Field Soils Assessment and Road Review',
            'Field Soils Assessment and Access Road Erosion Review', 'High',
            'Conduct field reconnaissance of project APE. Excavate soil pits to characterize texture, structure, organic matter, and contamination indicators. Photograph and describe all access road crossings — note slope, drainage structures, cut/fill configuration, and erosion potential. Collect soil samples if visual contamination indicators (staining, odor, sheen) are present.'
        },
        new List<String>{
            'NEPA_WO_Geo_3_CERCLA_BLM', 'CERCLA Coordination and Phase I/II Trigger',
            'CERCLA Coordination and Phase I/II ESA Trigger Assessment', 'High',
            'Determine if project activities disturb CERCLA-regulated media or require EPA/state oversight notification under the NPL site ROD. Evaluate whether Phase I ESA triggers apply under ASTM E1527-21. If contamination indicators were found in field, document Phase II ESA scope and timeline. Coordinate with EPA or state cleanup program if remediation oversight applies to proposed ground disturbance.'
        },
        new List<String>{
            'NEPA_WO_Geo_4_Report_BLM', 'Reclamation Bond and Geology Report',
            'Reclamation Bond Memo and Geology Assessment Report', 'High',
            'Compile soils assessment, road erosion risk findings, CERCLA coordination memo, and Phase I/II trigger determination into geology report. Provide reclamation bond cost estimate per applicable state or federal bond schedule, including topsoil salvage, revegetation, and contamination contingency costs. Upload report as ContentVersion linked to the Work Order and NEPA IndividualApplication. Mark Visit Status = Completed when report is approved by NEPA lead.'
        }
    },
    'NEPA_WO_Hydrology_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_Hydro_1_Desktop_BLM', 'Pre-Survey Desktop Review — Hydrology',
            'Pre-Survey Desktop Review — Hydrology', 'High',
            'Review NWI Wetlands layer detection output, USGS NHD flowlines, and project-area topo maps. Identify all water features within 300 feet of the project footprint. Compile jurisdictional determination history for the APE from Army Corps OMBIL database. Request hydric soils data from NRCS Web Soil Survey. Identify applicable Corps district and draft JD request if warranted.'
        },
        new List<String>{
            'NEPA_WO_Hydro_2_Field_BLM', 'Wetland and Waterway Field Assessment',
            'Wetland and Waterway Field Assessment', 'High',
            'Conduct field-based wetland delineation per the Corps of Engineers Wetland Delineation Manual and applicable regional supplement. Document hydrology indicators, hydric soils, and hydrophytic vegetation at representative data points. GPS-mark all wetland boundaries, ordinary high water mark (OHWM), and ephemeral/intermittent channel crossings. Photograph delineation transects.'
        },
        new List<String>{
            'NEPA_WO_Hydro_3_CWA_BLM', 'CWA Section 404/401 and NPDES Review',
            'CWA Section 404/401 and NPDES Permit Review', 'High',
            'Determine whether project activities require CWA Section 404 individual or nationwide permit based on wetland acreage, jurisdictional waters impacts, and applicable NWP conditions. Document applicable NWP general conditions checklist. Evaluate need for 401 Water Quality Certification from state. Assess stormwater discharge triggers for NPDES Construction General Permit (CGP) coverage.'
        },
        new List<String>{
            'NEPA_WO_Hydro_4_Report_BLM', 'Hydrology Assessment Report',
            'Hydrology Assessment Report — Final Submission', 'High',
            'Compile wetland delineation report, CWA jurisdictional determination summary, permit triggers matrix, and recommended mitigation measures. Include delineation data forms, hydric soil indicators, and GPS boundary maps as appendices. Upload final report as ContentVersion linked to Visit and IndividualApplication. Confirm Section 7 USFWS coordination needs for aquatic T&E species. Mark Visit Status = Completed when approved.'
        }
    },
    'NEPA_WO_MigratoryBird_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_Bird_1_Desktop_BLM', 'Avian Desktop Review and Raptor Nest Search',
            'Avian Desktop Review and Raptor Nest Pre-Search', 'High',
            'Query eBird, GBIF, USFWS IPaC, and state Natural Heritage Program for T&E and MBTA-protected avian species with confirmed occurrences within 5 miles of project APE. Pull BLM raptor nest database and state raptor nesting surveys for golden eagle, bald eagle, ferruginous hawk, and prairie falcon within 0.5-mile radius. Review USFWS Eagle Conservation Plan for wind/transmission projects if applicable. Identify species-specific survey protocols and MBTA-compliant no-disturbance buffer distances during nesting season.'
        },
        new List<String>{
            'NEPA_WO_Bird_2_NestSurvey_BLM', 'Nesting Season Survey — Spring/Summer Window',
            'Nesting Season Survey — Spring/Summer Window (April-August)', 'High',
            'Conduct comprehensive nesting bird survey of project APE plus 100-foot buffer during peak nesting window (April 15 - August 15). Use point count method (5-minute, 50-meter radius, unlimited distance) at systematically placed stations. Conduct separate raptor nest surveys via circular transects at 0.5-mile radius using binoculars and spotting scope. Document all active nests with GPS coordinates, species, stage of nesting, and distance to project features.'
        },
        new List<String>{
            'NEPA_WO_Bird_3_MBTA_BLM', 'MBTA Compliance Analysis',
            'MBTA Compliance and BGEPA Applicability Analysis', 'High',
            'Document proposed construction and operational activities that could result in incidental take under MBTA. Identify take-avoidance measures: construction timing windows avoiding active nests, pre-construction nest sweeps, raptor nest buffer distances. Assess Bald and Golden Eagle Protection Act (BGEPA) applicability for any eagle nests within 0.5 miles of project components. Document Eagle Take Permit applicability if avoidance is not achievable. Note: clearing within 300 feet of active raptor nests without incidental take authorization is prohibited.'
        },
        new List<String>{
            'NEPA_WO_Bird_4_Report_BLM', 'Avian Survey Report and MBTA Compliance Memo',
            'Avian Survey Report and MBTA/BGEPA Compliance Memo', 'High',
            'Compile nesting survey results, raptor nest map, MBTA compliance analysis, BGEPA applicability determination, and recommended avoidance/minimization measures into final avian report. Document species-specific buffer distances, construction timing restrictions, and pre-construction sweep requirements to be included in project conditions of approval. Upload report as ContentVersion linked to Visit and IndividualApplication. Mark Visit Status = Completed when report is approved by NEPA lead.'
        }
    },
    'NEPA_WO_SageGrouse_Milestones_BLM' => new List<List<String>>{
        new List<String>{
            'NEPA_WO_SGrouse_1_Desktop_BLM', 'Sage-Grouse Desktop Pre-Assessment',
            'Sage-Grouse Desktop Pre-Assessment', 'High',
            'Review USFWS Critical Habitat designation maps and FWS Critical Habitat layer GIS hit data. Determine applicable GRSG Management Plan category (Core Area, Important Habitat, General Habitat) and applicable ARMPA sub-object thresholds. Identify any known lek locations within 4 miles via BLM lek database. Determine if lek survey season (April 1 - May 15 for active leks) timing permits field survey this cycle or requires scheduling for next season window.'
        },
        new List<String>{
            'NEPA_WO_SGrouse_2_LekSurvey_BLM', 'Lek Survey — Active Season Window',
            'Lek Survey — Active Season Window (April 1 - May 15)', 'High',
            'Conduct dawn lek count surveys per Wyoming/state protocol (minimum 3 visits during peak display: 30 min before to 1 hr after sunrise). Record male attendance, strutting ground activity, and female presence. GPS all lek center points. Photograph strutting males if possible without disturbing display. Document buffer distance from proposed project footprint to nearest active lek center. Note: if survey window has closed, document in work order and schedule for next April-May window.'
        },
        new List<String>{
            'NEPA_WO_SGrouse_3_ARMPA_BLM', 'ARMPA Conformance Check',
            'ARMPA Conformance Check and Waivers Review', 'High',
            'Map project footprint against ARMPA habitat category. Apply applicable ARMPA stipulations: seasonal timing restrictions (April 1 - June 30 no-surface-disturbance), density caps for surface disturbance, powerline height restrictions in core habitat. Document any applicable waivers, exceptions, or modifications. Evaluate cumulative surface disturbance against Wyoming or applicable state lek buffer and Core Area caps. Record conformant/non-conformant determination with citation.'
        },
        new List<String>{
            'NEPA_WO_SGrouse_4_Report_BLM', 'Sage-Grouse Survey Report',
            'Sage-Grouse Survey and ARMPA Conformance Report', 'High',
            'Compile lek survey results, ARMPA conformance determination, seasonal timing restriction analysis, and recommended avoidance/mitigation measures into a single report. Upload to ContentVersion linked to the Visit and NEPA IndividualApplication. Coordinate BLM/USFWS review if non-conformance waivers are required. Mark Visit Status = Completed when report is approved by NEPA lead.'
        }
    }
};

// ─── Idempotency check ───────────────────────────────────────────────────────
Set<String> blmNames = new Set<String>();
for (List<String> t : templates) {
    blmNames.add(t[0]);
}
Set<String> alreadyExists = new Set<String>();
for (ActionPlanTemplate existing : [
    SELECT UniqueName FROM ActionPlanTemplate WHERE UniqueName IN :blmNames
]) {
    alreadyExists.add(existing.UniqueName);
}

// ─── Create templates ────────────────────────────────────────────────────────
Integer created = 0;
Integer skipped = 0;

for (List<String> tpl : templates) {
    String uniqueName = tpl[0];
    String tplName    = tpl[1];
    String tplDesc    = tpl[2];

    if (alreadyExists.contains(uniqueName)) {
        System.debug('SKIP (exists): ' + uniqueName);
        skipped++;
        continue;
    }

    // Insert template — platform auto-creates a Draft version
    ActionPlanTemplate apt = new ActionPlanTemplate(
        Name = tplName,
        UniqueName = uniqueName,
        TargetEntityType = 'Visit',
        Description = tplDesc,
        ActionPlanType = 'Retail',
        IsAdHocItemCreationEnabled = false
    );
    insert apt;

    // Query auto-created Draft version
    ActionPlanTemplateVersion draftVer = [
        SELECT Id FROM ActionPlanTemplateVersion
        WHERE ActionPlanTemplateId = :apt.Id LIMIT 1
    ];

    // Insert task items linked to the Draft version
    List<ActionPlanTemplateItem> items = new List<ActionPlanTemplateItem>();
    Integer order = 1;
    for (List<String> task : taskDefs.get(uniqueName)) {
        items.add(new ActionPlanTemplateItem(
            ActionPlanTemplateVersionId = draftVer.Id,
            Name = task[1],
            UniqueName = task[0],
            DisplayOrder = order++,
            IsRequired = true,
            ItemEntityType = 'Task'
        ));
    }
    insert items;

    // Insert item values (Subject, Priority, Description)
    List<ActionPlanTemplateItemValue> vals = new List<ActionPlanTemplateItemValue>();
    Integer idx = 0;
    for (List<String> task : taskDefs.get(uniqueName)) {
        Id itemId = items[idx++].Id;
        vals.add(new ActionPlanTemplateItemValue(
            ActionPlanTemplateItemId = itemId,
            ItemEntityFieldName = 'Task.Subject',
            ValueLiteral = task[2]
        ));
        vals.add(new ActionPlanTemplateItemValue(
            ActionPlanTemplateItemId = itemId,
            ItemEntityFieldName = 'Task.Priority',
            ValueLiteral = task[3]
        ));
        vals.add(new ActionPlanTemplateItemValue(
            ActionPlanTemplateItemId = itemId,
            ItemEntityFieldName = 'Task.Description',
            ValueLiteral = task[4]
        ));
    }
    insert vals;

    // Publish: Draft → Final
    draftVer.Status = 'Final';
    update draftVer;

    System.debug('CREATED: ' + uniqueName + ' | tplId=' + apt.Id + ' | verId=' + draftVer.Id);
    created++;
}

System.debug('Done — created: ' + created + ', skipped: ' + skipped);

// Verification count
Integer finalCount = [
    SELECT COUNT() FROM ActionPlanTemplateVersion
    WHERE ActionPlanTemplate.UniqueName LIKE 'NEPA_WO_%_BLM' AND Status = 'Final'
];
System.debug('Published V2 versions: ' + finalCount + ' of 7');
