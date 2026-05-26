/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */

import { LightningElement, api, track, wire } from "lwc";
import { OmniscriptBaseMixin } from "omnistudio/omniscriptBaseMixin";
import getAllOptions from "@salesforce/apex/NepaIndustryCodePickerController.getAllOptions";

const DEBUG = false;
const CLASS_NAME = "NepaIndustryCodePickerOmni";

function parseOptionsJson(input) {
  if (!input) return [];
  if (Array.isArray(input)) return input;
  if (typeof input === "object") {
    return input.value !== undefined ? [input] : [];
  }
  if (typeof input === "string") {
    let jsonStr = input;
    if (
      jsonStr.includes("\\[") ||
      jsonStr.includes("\\{") ||
      jsonStr.includes('\\"')
    ) {
      jsonStr = jsonStr
        .replace(/\\\[/g, "[")
        .replace(/\\\]/g, "]")
        .replace(/\\\{/g, "{")
        .replace(/\\\}/g, "}")
        .replace(/\\"/g, '"')
        .replace(/\\\\/g, "\\");
    }
    try {
      const parsed = JSON.parse(jsonStr);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function decorateOptions(options, selectedValue) {
  return options.map((opt) => ({
    ...opt,
    selected: opt.value === selectedValue
  }));
}

function filterByParentValue(options, parentValue) {
  if (!parentValue) return [];
  return options.filter((opt) => opt.parentValue === parentValue);
}

export default class NepaIndustryCodePickerOmni extends OmniscriptBaseMixin(
  LightningElement
) {
  @api label = "Select NAICS Code";
  @api helpText = "";
  @api required = false;
  @api disabled = false;
  @api optional = false;
  @api errorMessage;

  @api fieldName = "naicsCode";
  @api sectorFieldName = "";
  @api subSectorFieldName = "";
  @api industryGroupFieldName = "";
  @api industryFieldName = "";

  @api sectorLabel = "Sector";
  @api subSectorLabel = "Sub sector";
  @api industryGroupLabel = "Industry group";
  @api industryLabel = "Industry";
  @api nationalIndustryLabel = "National industry";

  @api sectorOptionsJson;
  @api subSectorOptionsJson;
  @api industryGroupOptionsJson;
  @api industryOptionsJson;
  @api nationalIndustryOptionsJson;

  @track _sector = "";
  @track _subSector = "";
  @track _industryGroup = "";
  @track _industry = "";
  @track _nationalIndustry = "";

  _sectorOptions = [];
  _subSectorOptions = [];
  _industryGroupOptions = [];
  _industryOptions = [];
  _nationalIndustryOptions = [];

  @wire(getAllOptions)
  wiredOptions({ data, error }) {
    if (data && !this.sectorOptionsJson) {
      this._sectorOptions = data.sectorOptions || [];
      this._subSectorOptions = data.subSectorOptions || [];
      this._industryGroupOptions = data.industryGroupOptions || [];
      this._industryOptions = data.industryOptions || [];
      this._nationalIndustryOptions = data.nationalIndustryOptions || [];
    }
    if (error && DEBUG) console.error(CLASS_NAME, "wiredOptions error", error);
  }

  connectedCallback() {
    if (DEBUG) {
      console.log(CLASS_NAME, "connectedCallback", {
        label: this.label,
        sectorOptionsJson: this.sectorOptionsJson?.substring(0, 50)
      });
    }
    if (this.sectorOptionsJson) {
      this._sectorOptions = parseOptionsJson(this.sectorOptionsJson);
      this._subSectorOptions = parseOptionsJson(this.subSectorOptionsJson);
      this._industryGroupOptions = parseOptionsJson(this.industryGroupOptionsJson);
      this._industryOptions = parseOptionsJson(this.industryOptionsJson);
      this._nationalIndustryOptions = parseOptionsJson(this.nationalIndustryOptionsJson);
    }
  }

  get sectorOptionsWithSelected() {
    return decorateOptions(this._sectorOptions, this._sector);
  }

  get subSectorOptions() {
    return filterByParentValue(this._subSectorOptions, this._sector);
  }

  get subSectorOptionsWithSelected() {
    return decorateOptions(this.subSectorOptions, this._subSector);
  }

  get industryGroupOptions() {
    return filterByParentValue(this._industryGroupOptions, this._subSector);
  }

  get industryGroupOptionsWithSelected() {
    return decorateOptions(this.industryGroupOptions, this._industryGroup);
  }

  get industryOptions() {
    return filterByParentValue(this._industryOptions, this._industryGroup);
  }

  get industryOptionsWithSelected() {
    return decorateOptions(this.industryOptions, this._industry);
  }

  get nationalIndustryOptions() {
    return filterByParentValue(this._nationalIndustryOptions, this._industry);
  }

  get nationalIndustryOptionsWithSelected() {
    return decorateOptions(this.nationalIndustryOptions, this._nationalIndustry);
  }

  get isSubSectorDisabled() {
    return this.disabled || !this._sector;
  }

  get isIndustryGroupDisabled() {
    return this.disabled || !this._subSector;
  }

  get isIndustryDisabled() {
    return this.disabled || !this._industryGroup;
  }

  get isNationalIndustryDisabled() {
    return this.disabled || !this._industry;
  }

  get value() {
    return this._nationalIndustry;
  }

  get hasValue() {
    return Boolean(this._nationalIndustry);
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  _dispatchChange() {
    const detail = {
      value: this._nationalIndustry,
      sector: this._sector,
      subSector: this._subSector,
      industryGroup: this._industryGroup,
      industry: this._industry
    };
    if (DEBUG) console.log(CLASS_NAME, "dispatchChange", detail);
    this.dispatchEvent(new CustomEvent("change", { detail, bubbles: true, composed: true }));
    this._updateOmniScriptData();
  }

  _updateOmniScriptData() {
    const dataUpdate = {};
    if (this.fieldName) dataUpdate[this.fieldName] = this._nationalIndustry || "";
    if (this.sectorFieldName) dataUpdate[this.sectorFieldName] = this._sector || "";
    if (this.subSectorFieldName) dataUpdate[this.subSectorFieldName] = this._subSector || "";
    if (this.industryGroupFieldName) dataUpdate[this.industryGroupFieldName] = this._industryGroup || "";
    if (this.industryFieldName) dataUpdate[this.industryFieldName] = this._industry || "";
    if (Object.keys(dataUpdate).length === 0) return;
    if (DEBUG) console.log(CLASS_NAME, "_updateOmniScriptData", dataUpdate);
    if (typeof this.omniUpdateDataJson === 'function') {
      this.omniUpdateDataJson(dataUpdate);
    }
  }

  handleSectorChange(event) {
    this._sector = event.target.value;
    this._subSector = "";
    this._industryGroup = "";
    this._industry = "";
    this._nationalIndustry = "";
    this._dispatchChange();
  }

  handleSubSectorChange(event) {
    this._subSector = event.target.value;
    this._industryGroup = "";
    this._industry = "";
    this._nationalIndustry = "";
    this._dispatchChange();
  }

  handleIndustryGroupChange(event) {
    this._industryGroup = event.target.value;
    this._industry = "";
    this._nationalIndustry = "";
    this._dispatchChange();
  }

  handleIndustryChange(event) {
    this._industry = event.target.value;
    this._nationalIndustry = "";
    this._dispatchChange();
  }

  handleNationalIndustryChange(event) {
    this._nationalIndustry = event.target.value;
    this._dispatchChange();
  }
}
