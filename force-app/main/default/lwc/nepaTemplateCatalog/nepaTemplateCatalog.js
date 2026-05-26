import { LightningElement, api, track, wire } from 'lwc';
import getCatalog from '@salesforce/apex/NepaTemplateCatalogController.getCatalog';
import installTemplate from '@salesforce/apex/NepaTemplateCatalogController.installTemplate';

const REVIEW_TYPE_OPTIONS = [
    { label: 'All', value: 'All' },
    { label: 'CE — Categorical Exclusion', value: 'CE' },
    { label: 'EA — Environmental Assessment', value: 'EA' },
    { label: 'EIS — Environmental Impact Statement', value: 'EIS' },
    { label: 'Visit — Field Survey', value: 'Visit' }
];

const SECTOR_OPTIONS = [
    { label: 'All Sectors', value: '' },
    { label: 'Agriculture / Public Lands', value: 'Agriculture' },
    { label: 'Energy — Oil/Gas/Coal', value: 'Oil/Gas' },
    { label: 'Energy — Renewables', value: 'Renewables' },
    { label: 'Energy — Pipeline/LNG', value: 'Pipeline' },
    { label: 'Energy — Hydro/Transmission', value: 'Hydro' },
    { label: 'Energy — Nuclear/Waste', value: 'Nuclear' },
    { label: 'Energy — Offshore', value: 'Offshore' },
    { label: 'Materials / Mining', value: 'Mining' },
    { label: 'Military / Urban / Regulatory', value: 'Military' },
    { label: 'Transportation — Land', value: 'Transportation - Land' },
    { label: 'Transportation — Water', value: 'Transportation - Water' },
    { label: 'Water Resources', value: 'Water Resources' }
];

export default class NepaTemplateCatalog extends LightningElement {
    @api recordId;
    @track templates = [];
    @track isLoading = false;
    @track isInstalling = false;
    @track error;
    @track installMessage;
    @track installMessageClass = 'slds-notify slds-notify_toast slds-theme_success slds-m-top_small';

    selectedReviewType = 'All';
    selectedSector = '';

    reviewTypeOptions = REVIEW_TYPE_OPTIONS;
    sectorOptions = SECTOR_OPTIONS;

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = null;
        getCatalog({
            reviewType: this.selectedReviewType,
            sector: this.selectedSector
        })
            .then(data => {
                this.templates = data;
            })
            .catch(err => {
                this.error = err.body ? err.body.message : String(err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleReviewTypeChange(event) {
        this.selectedReviewType = event.detail.value;
        this.load();
    }

    handleSectorChange(event) {
        this.selectedSector = event.detail.value;
        this.load();
    }

    handleClearFilters() {
        this.selectedReviewType = 'All';
        this.selectedSector = '';
        this.load();
    }

    handleInstall(event) {
        const aptName = event.currentTarget.dataset.aptName;
        if (!aptName) {
            this.showMessage('No APT name found on this template.', 'error');
            return;
        }
        if (!this.recordId) {
            this.showMessage('Open this component on a record page to install a template.', 'error');
            return;
        }

        this.isInstalling = true;
        this.installMessage = null;

        installTemplate({ recordId: this.recordId, aptUniqueName: aptName })
            .then(actionPlanId => {
                this.showMessage('Template installed successfully. Action Plan ID: ' + actionPlanId, 'success');
            })
            .catch(err => {
                const msg = err.body ? err.body.message : String(err);
                this.showMessage('Install failed: ' + msg, 'error');
            })
            .finally(() => {
                this.isInstalling = false;
            });
    }

    showMessage(message, type) {
        this.installMessage = message;
        this.installMessageClass = type === 'error'
            ? 'slds-notify slds-notify_toast slds-theme_error slds-m-top_small'
            : 'slds-notify slds-notify_toast slds-theme_success slds-m-top_small';
    }

    get isEmpty() {
        return !this.isLoading && !this.error && this.templates.length === 0;
    }

    get hasResults() {
        return !this.isLoading && this.templates.length > 0;
    }
}
