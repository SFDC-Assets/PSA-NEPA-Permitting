![Public Sector Accelerators logo](/docs/Logo_GPSAccelerators_v01.png)

# NEPA and Permitting Data Model

Ready-made NEPA and permitting data model that aligns with the CEQ's new Data and Technology Standard.

[Accelerator Listing](https://gpsaccelerators.developer.salesforce.com/accelerator/a0wDo000000BBN7IAO/nepa-and-permitting-data-model)


## Description

The NEPA and Permitting Data Model Accelerator helps U.S. federal and state agencies modernize their permitting systems in alignment with the [_**NEPA and Permitting Data and Technology Standard**_](https://permitting.innovation.gov/CEQ_NEPA_and_Permitting_Data_and_Technology_Standard.pdf) issued by the Council on Environmental Quality (CEQ). Built on the Salesforce Public Sector Solutions (PSS) data model, this Accelerator introduces new custom objects and fields to support data interoperability, transparency, and improved decision-making across environmental permitting programs.

This Accelerator extends the PSS [**Application and Authorization Data Model**](https://developer.salesforce.com/docs/atlas.en-us.psc_api.meta/psc_api/psc_data_model_application_authorization.htm) by mapping CEQ’s defined entities and attributes to Salesforce data components - adding fields to Public Sector Solutions core objects. It provides agencies with a concrete starting point to comply with Title II of the Evidence Act and open data guidance outlined in the Office of Management and Budget (OMB) Memorandum [**M-25-05**](https://www.whitehouse.gov/wp-content/uploads/2025/01/M-25-05-Phase-2-Implementation-of-the-Foundations-for-Evidence-Based-Policymaking-Act-of-2018-Open-Government-Data-Access-and-Management-Guidance.pdf).

![NEPA to Application and Authorization Data Model Mapping](/docs/NEPA%20to%20Salesforce%20Mapping.jpeg)

**Key benefits include**:
- **Compliance out of the box**: Implements CEQ's NEPA and Permitting Data and Technology Standard using Salesforce-native components.
- **Faster implementation**: Accelerates modernization efforts across permitting systems with ready-made metadata aligned to federal guidance.
- **Interoperability-first architecture**: Promotes structured, shareable data models that improve transparency and data exchange across agencies.
- **Future extensibility**: Designed to grow with your permitting system needs - providing a scalable foundation for GIS integration, process modeling, and decision payloads.

Whether you're beginning a modernization journey or enhancing an existing permitting solution, this Accelerator gives you the head start needed to meet federal standards and accelerate public outcomes.


## Included Assets

[Required. List of the assets included in the Accelerator and where to find them. This can be as detailed as desired, but at a minimum it should be detailed by asset type (unmanaged package, datapack, documentation, and other assets) and the next level metadata type (Salesforce metadata, datapack contents, separate documentation files, etc.) and their counts.]

This Accelerator includes the following assets:
<ol>
  <li><strong>Custom Fields</strong> on the following standard PSS objects:
    <ul>
      <li>Individual Application (11 fields)</li>
      <li>Content Version (10 fields)</li>
      <li>Program (9 fields)</li>
      <li>Public Complaint (3 fields)</li>
    </ul>
  </li>
  <li><strong>Custom Objects</strong> (x2)
    <ul>
      <li>Process Agency Relationship</li>
      <li>Project Agency Relationship</li>
    </ul>
  </li>
  <li><strong>Lightning Record Page</strong> (x1)
    <ul>
      <li>Public Comment Record Page</li>
    </ul>
  </li>
  <li><strong>Page Layouts</strong> (x3)
    <ul>
      <li>Content Version Permit Document</li>
      <li>Process Agency Relationship</li>
      <li>Project Agency Relationship</li>
    </ul>
  </li>   
  <li><strong>Permission Set</strong> (x1)
    <ul>
      <li>NEPA Permitting</li>
    </ul>
  </li>      
  <li><strong>Documentation</strong>, including:
    <ul>
      <li>This readme file</li>
    </ul>
  </li>
</ol>


## Before You Install
* Spin up a Public Sector Solutions trial org [here](https://developer.salesforce.com/free-trials/comparison/public-sector)

**License Requirements** [Required]
* License Public Sector Solutions - requires Foundations or Advanced for internal; requires Communities for external

## Installation

Use the links below to install the unmanaged package into your org:

* [Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfn000001UoMz)
* [Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfn000001UoMz)

## Post-Install Setup & Configuration
* Assign users the Permission Set `NEPA Permitting`
* Navigate to Setup, Object Manager, `Individual Application`, Page Layouts.  Edit the page layout that you use for permits and add the following fields:
  * `Federal Unique Id`, `Joint Lead Agency`, `Process Outcome`, `Process Stage`, `Purpose and Need`, `Related Project`
  * Add the `Related Agencies` related list to the layout as well
* Navigate to Setup, Object Manager, `Program`, Page Layouts.  Edit the page layout that you use for programs (or projects) that require multiple permits and add the following fields:
  * `Current Status`, `Lead Agency`, `Location`, `Parent Project`, `Project Description`, `Project Id`, `Project Sector`, `Project Sponsor`, `Project Title`, `Start Date`
  * Add the `Related Agencies` related list to the layout as well
* Navigate to Setup, Object Manager, `Content Version`, Page Layouts.
    * Use the Page Layout Assignment to assign the `Permit Document` page layout to profiles as appropriate for your Salesforce org.
* Navigate to Setup, Object Manager, `Public Complaint`, Lightning Record Pages and `Public Comment Record Page`.
    * Click the link and the Edit button on the corresponding page.
    * Use the Activation button to assign this page as an Org Default, App Default, etc as appropriate for your Salesforce organization.


## Revision History

<strong>1.0 Initial release (19 Sept 2025)</strong> - Minimal viable compliance with NEPA data model



## Terms of Use

Thank you for using Global Public Sector (GPS) Accelerators.  Accelerators are provided by Salesforce.com, Inc., located at 1 Market Street, San Francisco, CA 94105, United States.

By using this site and these accelerators, you are agreeing to these terms. Please read them carefully.

Accelerators are not supported by Salesforce, they are supplied as-is, and are meant to be a starting point for your organization. Salesforce is not liable for the use of accelerators.

For more about the Accelerator program, visit: [https://gpsaccelerators.developer.salesforce.com/](https://gpsaccelerators.developer.salesforce.com/)
