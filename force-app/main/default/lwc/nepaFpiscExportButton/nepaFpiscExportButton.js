import { LightningElement, api, track } from 'lwc';
import generateFPISCExport from '@salesforce/apex/NepaCeqExportService.generateFPISCExport';

export default class NepaFpiscExportButton extends LightningElement {
    @api recordId;

    @track isLoading = false;
    @track error;
    @track rowCount;

    handleExportProject() {
        this._runExport(this.recordId);
    }

    handleExportAll() {
        this._runExport(null);
    }

    _runExport(programId) {
        this.isLoading = true;
        this.error = undefined;
        this.rowCount = undefined;

        generateFPISCExport({ programId })
            .then(rows => {
                this.rowCount = rows.length;
                this._downloadJson(rows, programId ? `FPISC_Project_Export_${this._today()}.json` : `FPISC_All_Export_${this._today()}.json`);
            })
            .catch(err => {
                this.error = err?.body?.message ?? 'Export failed. Check the browser console for details.';
            })
            .finally(() => {
                this.isLoading = false;
            });
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
