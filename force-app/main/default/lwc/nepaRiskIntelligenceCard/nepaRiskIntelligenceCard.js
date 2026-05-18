import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import RISK_SCORE from '@salesforce/schema/IndividualApplication.nepa_risk_score__c';
import RISK_TIER from '@salesforce/schema/IndividualApplication.nepa_risk_tier__c';
import RISK_SCORE_FACTORS from '@salesforce/schema/IndividualApplication.nepa_risk_score_factors__c';
import RISK_SCORE_UPDATED from '@salesforce/schema/IndividualApplication.nepa_risk_score_updated__c';
import LITIGATION_DURATION_COST from '@salesforce/schema/IndividualApplication.nepa_litigation_duration_cost__c';

const FIELDS = [RISK_SCORE, RISK_TIER, RISK_SCORE_FACTORS, RISK_SCORE_UPDATED, LITIGATION_DURATION_COST];

const COST_SECTION_DELIMITER = '== LITIGATION COST EXPOSURE ==';
const PROB_SECTION_DELIMITER = '== LITIGATION PROBABILITY SCORE ==';

export default class NepaRiskIntelligenceCard extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';

    _riskScore;
    _riskTier;
    _factorsRaw;
    _scoreUpdated;
    _durationCost;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        this.isLoading = false;
        if (error) {
            this.hasError = true;
            this.errorMessage = 'Unable to load risk intelligence data.';
        } else if (data) {
            this._riskScore = getFieldValue(data, RISK_SCORE);
            this._riskTier = getFieldValue(data, RISK_TIER);
            this._factorsRaw = getFieldValue(data, RISK_SCORE_FACTORS) || '';
            this._scoreUpdated = getFieldValue(data, RISK_SCORE_UPDATED);
            this._durationCost = getFieldValue(data, LITIGATION_DURATION_COST);
        }
    }

    get riskScore() {
        return this._riskScore != null ? Math.round(this._riskScore) : '--';
    }

    get riskTier() {
        return this._riskTier || 'Not Scored';
    }

    get tierBadgeClass() {
        const tier = (this._riskTier || '').toLowerCase().replace(/\s+/g, '-');
        const map = {
            'low': 'nepa-tier-low',
            'moderate': 'nepa-tier-moderate',
            'high': 'nepa-tier-high',
            'very-high': 'nepa-tier-very-high'
        };
        return map[tier] || 'nepa-tier-moderate';
    }

    get hasEsaLowConfidence() {
        return this._factorsRaw.includes('LOW CONFIDENCE') || this._factorsRaw.includes('ECOS API unavailable');
    }

    get probabilityFactors() {
        return this._parseSectionLines(this._factorsRaw, 'probability');
    }

    get costFactors() {
        return this._parseSectionLines(this._factorsRaw, 'cost');
    }

    get hasDurationData() {
        return this._durationCost != null;
    }

    get durationDisplay() {
        if (!this.hasDurationData) return null;
        // Reverse-normalize: months = (normalized * (33.4 - 6.5)) + 6.5
        const months = (this._durationCost * 26.9) + 6.5;
        return `~${months.toFixed(1)} months`;
    }

    get durationPercentileDisplay() {
        if (!this.hasDurationData) return '--';
        return `${Math.round(this._durationCost * 100)}th`;
    }

    get durationPathway() {
        const lines = this._parseSectionLines(this._factorsRaw, 'cost');
        const pathwayLine = lines.find(l => l.toLowerCase().includes('pathway') || l.toLowerCase().includes('circuit'));
        return pathwayLine || '';
    }

    get lastScoredDisplay() {
        if (!this._scoreUpdated) return 'Not yet scored';
        return new Date(this._scoreUpdated).toLocaleDateString('en-US', {
            year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
        });
    }

    _parseSectionLines(raw, section) {
        if (!raw) return [];
        const costIdx = raw.indexOf(COST_SECTION_DELIMITER);
        const probIdx = raw.indexOf(PROB_SECTION_DELIMITER);

        let sectionText;
        if (section === 'probability') {
            if (probIdx >= 0) {
                const end = costIdx >= 0 ? costIdx : raw.length;
                sectionText = raw.substring(probIdx + PROB_SECTION_DELIMITER.length, end);
            } else if (costIdx >= 0) {
                sectionText = raw.substring(0, costIdx);
            } else {
                sectionText = raw;
            }
        } else {
            if (costIdx >= 0) {
                sectionText = raw.substring(costIdx + COST_SECTION_DELIMITER.length);
            } else {
                return [];
            }
        }

        return sectionText
            .split(/[;\n]/)
            .map(s => s.trim())
            .filter(s => s.length > 0 && !s.startsWith('=='));
    }
}
