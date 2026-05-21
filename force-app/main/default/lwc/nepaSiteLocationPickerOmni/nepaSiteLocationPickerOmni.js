/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
import { LightningElement, api, track } from 'lwc';
import { OmniscriptBaseMixin } from 'omnistudio/omniscriptBaseMixin';
import fetchCommunityURL from '@salesforce/apex/NepaMapCreateCtr.fetchCommunityURL';
import fetchVFDomainURL from '@salesforce/apex/NepaMapCreateCtr.fetchVFDomainURL';
import defaultAddressCoordinates from '@salesforce/apex/NepaMapCreateCtr.defaultAddressCoordinates';

const LOCATION_NAME = 'siteLocation';

export default class NepaSiteLocationPickerOmni extends OmniscriptBaseMixin(LightningElement) {

    @api label = 'Site Location';
    @api helpText = '';
    @api required = false;
    @api disabled = false;

    /** OmniScript field name for the full location object {lat, lng, geometry} */
    @api fieldName = 'siteLocation';
    /** Optional: write latitude as a separate flat field */
    @api latFieldName = '';
    /** Optional: write longitude as a separate flat field */
    @api lngFieldName = '';

    @track pathtoVFPage = '';
    @track showMap = false;
    @track capturedLat = '';
    @track capturedLng = '';
    @track errorMessage = '';

    @track showToastMessage = false;
    @track toastTitle = '';
    @track toastMessage = '';
    @track toastVariant = '';

    vfPageDomain = '';
    _messageHandler = null;

    get hasCapture() {
        return Boolean(this.capturedLat && this.capturedLng);
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    get toastContainerClass() {
        const variant = this.toastVariant === 'error' ? 'slds-theme_error'
            : this.toastVariant === 'success' ? 'slds-theme_success'
            : this.toastVariant === 'warning' ? 'slds-theme_warning'
            : 'slds-theme_info';
        return `slds-notify_container slds-is-relative ${variant}`;
    }

    async connectedCallback() {
        try {
            const domain = await fetchVFDomainURL();
            this.vfPageDomain = domain;
            const lat = (this.omniJsonData && this.omniJsonData.Latitude) || '';
            const lng = (this.omniJsonData && this.omniJsonData.Longitude) || '';
            this.pathtoVFPage = `${domain}/apex/NEPA_Site_Location_Page?latitude=${lat}&longitude=${lng}`;
        } catch (err) {
            this.vfPageDomain = window.location.origin;
            this.pathtoVFPage = '/apex/NEPA_Site_Location_Page';
        }

        this._messageHandler = (message) => {
            if (message.data && message.data.name === 'storeDetails' && message.data.location === LOCATION_NAME) {
                this._handlePolygonData(message.data.payload);
            }
            if (message.data && message.data.name === 'pageLoaded') {
                const msg = { title: 'fetchDetails', detail: { name: LOCATION_NAME } };
                this._fireToVF(JSON.stringify(msg));
                this.showMap = true;
            }
        };
        window.addEventListener('message', this._messageHandler);
    }

    disconnectedCallback() {
        if (this._messageHandler) {
            window.removeEventListener('message', this._messageHandler);
        }
    }

    handleFindOnMap() {
        this.errorMessage = '';
        this.capturedLat = '';
        this.capturedLng = '';
        const msg = { title: 'fetchDetails', detail: { name: LOCATION_NAME } };
        const sent = this._fireToVF(JSON.stringify(msg));
        if (!sent) {
            this.showMap = true;
        }
    }

    handleCaptureLocation() {
        this.errorMessage = '';
        const msg = { title: 'captureDetails', detail: { name: LOCATION_NAME } };
        this._fireToVF(JSON.stringify(msg));
    }

    _fireToVF(msg) {
        const iframe = this.template.querySelector('iframe');
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage(msg, this.vfPageDomain);
            return true;
        }
        return false;
    }

    _handlePolygonData(payload) {
        let data;
        try {
            data = typeof payload === 'string' ? JSON.parse(payload) : payload;
        } catch {
            this.errorMessage = 'Failed to read location data from map.';
            return;
        }

        if (data.error) {
            this.errorMessage = data.error;
            this._showToast('Error', data.error, 'error');
            return;
        }

        this.capturedLat = String(data.lat || '');
        this.capturedLng = String(data.lng || '');

        const update = {};
        if (this.fieldName) {
            update[this.fieldName] = { lat: data.lat, lng: data.lng, geometry: data.geometry };
        }
        if (this.latFieldName) update[this.latFieldName] = data.lat;
        if (this.lngFieldName) update[this.lngFieldName] = data.lng;

        if (Object.keys(update).length > 0) {
            this.omniUpdateDataJson(update);
        }

        this._showToast('Success', 'Site location captured.', 'success');
    }

    _showToast(title, msg, variant) {
        this.toastTitle = title;
        this.toastMessage = msg;
        this.toastVariant = variant;
        this.showToastMessage = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showToastMessage = false; }, 3000);
    }

    hideToastMessage() {
        this.showToastMessage = false;
    }
}
