/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 */
import { LightningElement, track, wire } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { gql, graphql } from 'lightning/graphql';
import createIntake from '@salesforce/apex/NepaCEIntakeController.createIntake';
import getScreeningResult from '@salesforce/apex/NepaCEIntakeController.getScreeningResult';
import INDIVIDUAL_APPLICATION_OBJECT from '@salesforce/schema/IndividualApplication';
import ACTION_TYPE_FIELD from '@salesforce/schema/IndividualApplication.nepa_action_type__c';
import PROGRAM_OBJECT from '@salesforce/schema/Program';
import PROJECT_SECTOR_FIELD from '@salesforce/schema/Program.nepa_project_sector__c';
import PROJECT_TYPE_FIELD from '@salesforce/schema/Program.nepa_project_type__c';

const TOTAL_STEPS = 5;

const AGENCY_QUERY = gql`
    query searchAgencies($searchTerm: String) {
        uiapi {
            query {
                Account(
                    where: { Name: { like: $searchTerm } }
                    first: 5
                ) {
                    edges {
                        node {
                            Id
                            Name { value }
                        }
                    }
                }
            }
        }
    }
`;

export default class NepaCeIntakeWizard extends LightningElement {

    @track currentStep = 1;
    @track wizardData = {
        projectTitle: '',
        projectDescription: '',
        leadAgencyId: null,
        startDate: '',
        lat: null,
        lng: null,
        locationText: '',
        naicsCode: '',
        projectSector: '',
        projectType: '',
        actionType: '',
        disturbanceAcres: null,
        purposeNeed: '',
        regulatoryCitation: '',
        ecMultiDod: false,
        ecUsaczma: false
    };

    @track leadAgencyName = '';
    @track agencySuggestions = [];
    @track showAgencySuggestions = false;
    @track agencySearchTerm = '';

    @track isSubmitting = false;
    @track submitError = '';
    @track iaId = null;
    @track screeningResult = null;
    @track pollCount = 0;

    _pollInterval = null;

    // --- Picklist wiring ---

    @wire(getObjectInfo, { objectApiName: INDIVIDUAL_APPLICATION_OBJECT })
    iaObjectInfo;

    @wire(getObjectInfo, { objectApiName: PROGRAM_OBJECT })
    programObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$iaObjectInfo.data.defaultRecordTypeId',
        fieldApiName: ACTION_TYPE_FIELD
    })
    wiredActionTypes;

    @wire(getPicklistValues, {
        recordTypeId: '$programObjectInfo.data.defaultRecordTypeId',
        fieldApiName: PROJECT_SECTOR_FIELD
    })
    wiredProjectSectors;

    @wire(getPicklistValues, {
        recordTypeId: '$programObjectInfo.data.defaultRecordTypeId',
        fieldApiName: PROJECT_TYPE_FIELD
    })
    wiredProjectTypes;

    get actionTypeOptions() {
        if (!this.wiredActionTypes.data) return [];
        return this.wiredActionTypes.data.values.map(v => ({ label: v.label, value: v.value }));
    }

    get projectSectorOptions() {
        if (!this.wiredProjectSectors.data) return [];
        return this.wiredProjectSectors.data.values.map(v => ({ label: v.label, value: v.value }));
    }

    get projectTypeOptions() {
        if (!this.wiredProjectTypes.data) return [];
        return this.wiredProjectTypes.data.values.map(v => ({ label: v.label, value: v.value }));
    }

    // --- Agency GraphQL search ---

    @wire(graphql, {
        query: AGENCY_QUERY,
        variables: '$_agencyQueryVars',
        operationName: 'searchAgencies'
    })
    wiredAgencies({ data }) {
        if (data) {
            const edges = data?.uiapi?.query?.Account?.edges ?? [];
            this.agencySuggestions = edges.map(e => ({ id: e.node.Id, name: e.node.Name.value }));
            this.showAgencySuggestions = this.agencySuggestions.length > 0;
        }
    }

    get _agencyQueryVars() {
        return { searchTerm: `%${this.agencySearchTerm}%` };
    }

    // --- Step guards ---

    get currentStepStr() { return String(this.currentStep); }
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }

    get hasLocation() {
        return Boolean(this.wizardData.lat && this.wizardData.lng);
    }

    get hasScreeningReviewType() {
        return Boolean(this.screeningResult && this.screeningResult.reviewType);
    }

    get screeningResultConfidencePct() {
        const conf = this.screeningResult && this.screeningResult.confidence;
        if (conf == null) return '—';
        return `${Math.round(conf * 100)}%`;
    }

    get iaRecordUrl() {
        return this.iaId ? `/lightning/r/IndividualApplication/${this.iaId}/view` : '#';
    }

    // --- Event handlers ---

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const isCheckbox = event.target.dataset.type === 'checkbox';
        this.wizardData = {
            ...this.wizardData,
            [field]: isCheckbox ? event.target.checked : event.target.value
        };
    }

    handleAgencySearch(event) {
        this.agencySearchTerm = event.target.value;
        this.leadAgencyName = event.target.value;
        if (!this.agencySearchTerm) {
            this.showAgencySuggestions = false;
            this.wizardData = { ...this.wizardData, leadAgencyId: null };
        }
    }

    handleAgencySelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.wizardData = { ...this.wizardData, leadAgencyId: id };
        this.leadAgencyName = name;
        this.showAgencySuggestions = false;
    }

    handleLocationChange(event) {
        const detail = event.detail;
        this.wizardData = {
            ...this.wizardData,
            lat: detail.lat,
            lng: detail.lng,
            siteLocation: detail.siteLocation
        };
    }

    handleNaicsChange(event) {
        this.wizardData = { ...this.wizardData, naicsCode: event.detail.value };
    }

    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    handleNext() {
        if (this.currentStep < TOTAL_STEPS) {
            this.currentStep += 1;
        }
    }

    async handleSubmit() {
        this.isSubmitting = true;
        this.submitError = '';
        this.pollCount = 0;

        const programData = {
            projectTitle:       this.wizardData.projectTitle,
            projectDescription: this.wizardData.projectDescription,
            leadAgencyId:       this.wizardData.leadAgencyId,
            projectSector:      this.wizardData.projectSector,
            projectType:        this.wizardData.projectType,
            naicsCode:          this.wizardData.naicsCode,
            lat:                this.wizardData.lat,
            lng:                this.wizardData.lng,
            locationText:       this.wizardData.locationText,
            startDate:          this.wizardData.startDate || null
        };
        const processData = {
            actionType:         this.wizardData.actionType,
            disturbanceAcres:   this.wizardData.disturbanceAcres,
            purposeNeed:        this.wizardData.purposeNeed,
            regulatoryCitation: this.wizardData.regulatoryCitation,
            ecMultiDod:         this.wizardData.ecMultiDod,
            ecUsaczma:          this.wizardData.ecUsaczma
        };

        try {
            this.iaId = await createIntake({ programData, processData });
            this._startPolling();
        } catch (err) {
            this.isSubmitting = false;
            this.submitError = err.body?.message ?? err.message ?? 'Submission failed.';
        }
    }

    _startPolling() {
        this._pollInterval = setInterval(async () => {
            try {
                const result = await getScreeningResult({ processId: this.iaId });
                if (result.reviewType || ++this.pollCount >= 5) {
                    this._stopPolling();
                    this.screeningResult = result;
                    this.isSubmitting = false;
                }
            } catch {
                this._stopPolling();
                this.screeningResult = { reviewType: null, ceCode: null, confidence: null, basis: null };
                this.isSubmitting = false;
            }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        }, 3000);
    }

    _stopPolling() {
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }
    }

    handleReset() {
        this._stopPolling();
        this.currentStep = 1;
        this.wizardData = {
            projectTitle: '', projectDescription: '', leadAgencyId: null,
            startDate: '', lat: null, lng: null, locationText: '',
            naicsCode: '', projectSector: '', projectType: '',
            actionType: '', disturbanceAcres: null, purposeNeed: '',
            regulatoryCitation: '', ecMultiDod: false, ecUsaczma: false
        };
        this.leadAgencyName = '';
        this.agencySuggestions = [];
        this.showAgencySuggestions = false;
        this.iaId = null;
        this.screeningResult = null;
        this.pollCount = 0;
        this.submitError = '';
        this.isSubmitting = false;
    }

    disconnectedCallback() {
        this._stopPolling();
    }
}
