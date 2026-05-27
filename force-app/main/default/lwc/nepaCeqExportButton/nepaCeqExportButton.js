import { LightningElement, api, track } from 'lwc';
import generateCeqExport from '@salesforce/apex/NepaCeqExportService.generateCeqExport';

export default class NepaCeqExportButton extends LightningElement {
    @api recordId;

    @track isLoading = false;
    @track error;
    @track successMessage;

    handleExportProcess() {
        this._runExport(this.recordId);
    }

    handleExportAll() {
        this._runExport(null);
    }

    _runExport(processId) {
        this.isLoading = true;
        this.error = undefined;
        this.successMessage = undefined;

        generateCeqExport({ processId })
            .then(jsonString => {
                const data = JSON.parse(jsonString);
                const isArray = Array.isArray(data);
                const count = isArray ? data.length : 1;
                const filename = processId
                    ? `CEQ_Export_${this._federalId(data)}_${this._today()}.json`
                    : `CEQ_Export_All_${this._today()}.json`;
                this._downloadJson(data, filename);
                this.successMessage = `Last export: ${count} process${count !== 1 ? 'es' : ''} — file downloaded.`;
            })
            .catch(err => {
                this.error = err?.body?.message ?? 'Export failed. Check the browser console for details.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _federalId(data) {
        return data?.federalUniqueId ?? 'process';
    }

    _downloadJson(data, filename) {
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }

    _today() {
        return new Date().toISOString().slice(0, 10);
    }
}
