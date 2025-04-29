import { LightningElement,track,api } from 'lwc';

export default class wbTemplateParent extends LightningElement {
    @track showTemplateCategory = true;
    @track showCreateTemplateTest = false;

    selectedOption = 'custom';
    selectedTab = 'section1';
    activeTab;
    showLicenseError = false;

    connectedCallback(){
        console.log('Connected Callnack ::: ');
        
    }

    // Handling 'Next' event from Category page
    handleNext(event) {
        const { selectedOption, selectedTab, activeTab } = event.detail;
        // this.selectedTabName = selectedTabName;
        this.selectedOption = selectedOption;
        this.selectedTab = selectedTab;
        this.activeTab = activeTab;

        this.showTemplateCategory = false;
        this.showCreateTemplateTest = true;
    }

    // Handling 'Previous' event from CreateTemplate page
    handlePrevious(event) {
        const { selectedOption, selectedTab, activeTab } = event.detail;
        this.selectedOption = selectedOption;
        this.selectedTab = selectedTab;
        this.activeTab = activeTab;

        this.showTemplateCategory = true;
        this.showCreateTemplateTest = false;
    }

    // Handling special case if createTemplate clicks "back" (same as previous)
    handleCreatedTemplateBack(event) {
        this.handlePrevious(event);
    }
}