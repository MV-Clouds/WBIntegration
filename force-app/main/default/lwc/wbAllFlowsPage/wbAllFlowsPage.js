import { LightningElement, track, wire } from 'lwc';
import getWhatsAppFlows from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlows';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.getPreviewURLofWhatsAppFlow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import FLOW_OBJECT from "@salesforce/schema/MVWB__Flow__c";
import STATUS_FIELD from "@salesforce/schema/MVWB__Flow__c.MVWB__Status__c";
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';


export default class WbAllFlowsPage extends LightningElement {
    @track allRecords = [];
    @track filteredRecords = [];
    @track statusValues = [];
    @track statusOptions = [];
    isFlowVisible = false;
    iscreateflowvisible = false;
    searchInput;
    isLoading = false;
    flowPreviewURL = '';
    showPopup = false;
    isFlowDraft = false;
    selectedFlowId = '';
    @track showLicenseError = false;

    @wire(getObjectInfo, { objectApiName: FLOW_OBJECT })
    flowMetadata;

    @wire(getPicklistValues, { recordTypeId: "$flowMetadata.data.defaultRecordTypeId", fieldApiName: STATUS_FIELD })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.statusOptions = data.values;
        } else if (error) {
            console.error(`Error fetching Status picklist values: ${error}`);
            this.statusOptions = [];
        }
    }

    connectedCallback(){
    }
    async connectedCallback(){
        try {
            this.showSpinner = true;
            await this.checkLicenseStatus();
            if (this.showLicenseError) {
                return; // Stops execution if license is expired
            }
            
            this.isFlowVisible = true;
            this.fetchWhatsAppFlows();
            
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    async checkLicenseStatus() {
        try {
            const isLicenseValid = true;
            console.log('isLicenseValid => ', isLicenseValid);
            if (!isLicenseValid) {
                this.showLicenseError = true;
            }
        } catch (error) {
            console.error('Error checking license:', error);
        }
    }

    fetchWhatsAppFlows(){
        try {
            getWhatsAppFlows()
                .then((data) => {
                    this.allRecords = data.map(record => {
                        return {
                            ...record,
                            isDraft: record.MVWB__Status__c === 'Draft',
                            isPublished: record.MVWB__Status__c === 'Published',
                            isDeprecated: record.MVWB__Status__c === 'Deprecated',
                            LastModifiedDate: this.formatDate(record.LastModifiedDate)
                        };
                    });
                    this.filterRecords();
                })
                .catch((error) => {
                    console.error(error);
                })
        } catch (error) {
            console.error('Error in fetchWhatsAppFlows : ' , error);
        }
    }

    showCreateFlow(){
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
    }

    handleStatusChange(event) {
        this.statusValues = event.detail.value;
        this.filterRecords();
    }

    handleSearchInputChange(event) {
        this.searchInput = event.target.value.trim().toLowerCase();
        this.filterRecords();
    }

    filterRecords() {
        try {
            let filtered = [...this.allRecords];
    
            if (this.statusValues.length > 0) {
                filtered = filtered.filter(record => this.statusValues.includes(record.MVWB__Status__c));
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.MVWB__Flow_Name__c.toLowerCase().includes(this.searchInput));
            }
    
            this.filteredRecords = filtered;
            this.isLoading = false;
        } catch (error) {
            console.error('Error in filtering records:', error);
            this.isLoading = false;
        }
    }

    formatDate(dateString) {
        if(dateString){
            const date = new Date(dateString);
            return date.toLocaleDateString('en-GB', {
                day: 'numeric',
                month: 'short',
                year: 'numeric'
            });
        }
    }   
    
    deleteFlow(event){
        try {
            var flowId = event.currentTarget.dataset.id;
            var status = event.currentTarget.dataset.status;
            if(status === 'Draft' || status === 'Published') {
                this.isLoading = true;
                deleteWhatsAppFlow({flowId : flowId})
                    .then((result) => {
                        if(!result.startsWith('Failed')){
                            this.showToast('Success', 'Flow deleted successfully', 'success');
                            this.fetchWhatsAppFlows();
                        } else {
                            this.showToast('Error', 'Failed to delete flow', 'error');
                            console.error('Error in deleting WhatsApp Flow:', error);
                        }
                    })
                    .catch((error) => {
                        this.showToast('Error', 'Failed to delete flow', 'error');
                        console.error('Failed to delete flow : ' , error);
                    })
            } else {
                this.showToast('Error', 'Only flows in Draft or Published status can be deleted.', 'error');
            }
        } catch (error) {
            console.error('Error in deleteFlow : ' , error);
        }
    }

    deprecateFlow(event){
        try {
            var flowId = event.currentTarget.dataset.id;
            var status = event.currentTarget.dataset.status;
            if(status === 'Draft' || status === 'Published'){
                this.isLoading = true;
                deprecateWhatsAppFlow({flowId : flowId})
                    .then((result) => {
                        if(!result.startsWith('Failed')){
                            this.showToast('Success', 'Flow deprecated successfully', 'success');
                            this.fetchWhatsAppFlows();
                        } else {
                            this.showToast('Error', 'Failed to deprecate flow', 'error');
                            console.error('Error in deprecate WhatsApp Flow:', error);
                        }
                    })
                    .catch((error) => {
                        this.showToast('Error', 'Failed to deprecate flow', 'error');
                        console.error('Failed to deldeprecateete flow : ' , error);
                    })
            } else {
                this.showToast('Error', 'Only flows in Draft or Published status can be deleted.', 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Failed to deprecate flow', 'error');
            console.error('Error in deprecateflow : ' , error);
        }
    }

    previewTemplate(event){
        try {
            var flowId = event.currentTarget.dataset.id;
            this.showPopup = true;

            let matchingRecord = this.filteredRecords.find(record => record.MVWB__Flow_Id__c === flowId);
            if (matchingRecord && matchingRecord.MVWB__Status__c === 'Draft') {
                this.isFlowDraft = true;
            }

            this.selectedFlowId = flowId;
            getPreviewURLofWhatsAppFlow({ flowId : flowId })
                .then((data) => {
                    if(data != 'failed'){
                        this.flowPreviewURL = data;
                    } else {
                        this.showToast('Error', 'Failed to get flow preview', 'error');
                        console.error('Error in getting Flow Preview URL:', error);
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to get flow preview', 'error');
                    console.error('Error in getting Flow Preview URL:', error);
                });
        } catch (error) {
            this.showToast('Error', 'Failed to get flow preview', 'error');
            console.error('Error in getting Flow Preview URL:', error);
        }
    }

    closePopup(){
        this.showPopup = false;
        this.flowPreviewURL = '';
        this.selectedFlowId = '';
    }

    publishFlow(){
        try {
            this.isLoading = true;
            publishWhatsAppFlow({flowId : this.selectedFlowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.closePopup();
                        this.fetchWhatsAppFlows();
                        this.showToast('Success', 'Flow Published Successfully', 'success');
                    } else {
                        this.showToast('Error', 'Failed to publish flow', 'error');
                        console.error('Error in publishing WhatsApp Flow:', error);
                    }
                })
                .catch((error) => {
                    this.showToast('Error', 'Failed to publish flow', 'error');
                    console.error('Failed to publish flow : ' , error);
                })
        } catch (error) {
            this.showToast('Error', 'Failed to publish flow', 'error');
            console.error('Error in publishFlow : ' , error);
        }
    }

    showToast(title, message, varient) {
        const toastEvent = new ShowToastEvent({title: title, message: message, variant: varient});
        this.dispatchEvent(toastEvent);
    }
}