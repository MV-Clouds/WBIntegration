import { LightningElement, track, wire } from 'lwc';
import getWhatsAppFlows from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlows';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.getPreviewURLofWhatsAppFlow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import FLOW_OBJECT from "@salesforce/schema/Flow__c";
import STATUS_FIELD from "@salesforce/schema/Flow__c.Status__c";

export default class WbAllFlowsPage extends LightningElement {
    @track allRecords = [];
    @track filteredRecords = [];
    @track statusValues = [];
    @track statusOptions = [];
    isFlowVisible = true;
    iscreateflowvisible = false;
    searchInput;
    isLoading = false;
    flowPreviewURL = '';
    showPopup = false;
    isFlowDraft = false;
    selectedFlowId = '';

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
        this.fetchWhatsAppFlows();
    }

    fetchWhatsAppFlows(){
        try {
            getWhatsAppFlows()
                .then((data) => {
                    this.allRecords = data.map(record => {
                        return {
                            ...record,
                            isDraft: record.Status__c === 'Draft',
                            isPublished: record.Status__c === 'Published',
                            isDeprecated: record.Status__c === 'Deprecated',
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
                filtered = filtered.filter(record => this.statusValues.includes(record.Status__c));
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.Flow_Name__c.toLowerCase().includes(this.searchInput));
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
                            this.fetchWhatsAppFlows();
                        } else {
                            console.error('Error in deleting WhatsApp Flow:', error);
                        }
                    })
                    .catch((error) => {
                        console.error('Failed to delete flow : ' , error);
                    })
            } else {
                this.showToastError('Only flows in Draft or Published status can be deleted.')
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
                            this.fetchWhatsAppFlows();
                        } else {
                            console.error('Error in deleting WhatsApp Flow:', error);
                        }
                    })
                    .catch((error) => {
                        console.error('Failed to delete flow : ' , error);
                    })
            } else {
                this.showToastError('Only flows in Draft or Published status can be deleted.')
            }
        } catch (error) {
            console.error('Error in deprecateflow : ' , error);
        }
    }

    previewTemplate(event){
        try {
            var flowId = event.currentTarget.dataset.id;
            this.showPopup = true;

            let matchingRecord = this.filteredRecords.find(record => record.Flow_Id__c === flowId);
            console.log({matchingRecord});
            if (matchingRecord && matchingRecord.Status__c === 'Draft') {
                this.isFlowDraft = true;
            }

            this.selectedFlowId = flowId;
            getPreviewURLofWhatsAppFlow({ flowId : flowId })
                .then((data) => {
                    if(data != 'failed'){
                        this.flowPreviewURL = data;
                    } else {
                        console.error('Error in getting Flow Preview URL:', error);
                    }
                })
                .catch(error => {
                    console.error('Error in getting Flow Preview URL:', error);
                });
        } catch (error) {
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
                        this.showToastSuccess('Flow successfully published.');
                    } else {
                        console.error('Error in publishing WhatsApp Flow:', error);
                    }
                })
                .catch((error) => {
                    console.error('Failed to publish flow : ' , error);
                })
        } catch (error) {
            console.error('Error in publishFlow : ' , error);
        }
    }

    showToastError(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
    }

    showToastSuccess(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success'
        });
        this.dispatchEvent(toastEvent);
    }
}