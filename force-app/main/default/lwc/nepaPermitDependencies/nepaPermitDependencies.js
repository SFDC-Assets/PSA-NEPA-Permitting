import { LightningElement, api, track } from 'lwc';
import getPermitStatuses from '@salesforce/apex/NepaAgencyPermitService.getPermitStatuses';

const STATUS_CLASS = {
    'in progress'    : 'slds-badge_inverse',
    'completed'      : 'slds-badge slds-theme_success',
    'Issued'         : 'slds-badge slds-theme_success',
    'Under Review'   : 'slds-badge slds-theme_warning',
    'paused'         : 'slds-badge slds-theme_warning',
    'Denied'         : 'slds-badge slds-theme_error',
    'cancelled'      : 'slds-badge slds-theme_error',
    'Withdrawn'      : 'slds-badge slds-theme_error',
};

export default class NepaPermitDependencies extends LightningElement {
    @api recordId;

    @track permits = [];
    @track isLoading = false;
    @track errorMessage = null;

    get hasError()        { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()         { return !this.isLoading && !this.errorMessage && this.permits.length === 0; }
    get hasCachedWarning(){ return this.permits.some(p => !p.calloutSuccess); }

    connectedCallback() {
        this.load();
    }

    handleRefresh() {
        this.load();
    }

    load() {
        this.isLoading    = true;
        this.errorMessage = null;

        getPermitStatuses({ processId: this.recordId })
            .then(results => {
                this.permits   = results.map(r => this.enrich(r));
                this.isLoading = false;
            })
            .catch(err => {
                this.errorMessage = err.body?.message || 'Failed to load permit statuses.';
                this.isLoading    = false;
            });
    }

    enrich(r) {
        const displayStatus = r.calloutSuccess ? r.liveStatus : r.localStatus;
        return {
            ...r,
            statusClass     : STATUS_CLASS[displayStatus] || 'slds-badge_lightest',
            rowClass        : r.isCriticalPath ? 'slds-hint-parent nepa-critical-row' : 'slds-hint-parent',
            displayExpected : r.calloutSuccess && r.liveExpectedCompletion
                                ? r.liveExpectedCompletion
                                : r.expectedCompletion,
        };
    }
}
