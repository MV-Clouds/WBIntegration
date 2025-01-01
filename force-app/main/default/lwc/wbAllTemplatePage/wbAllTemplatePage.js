/**
 * Component Name: WbAllTemplatePage
 * @description: Used LWC components to show all templates record.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 23/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : Beta 10 bugs
 * Change Description :Beta 10 bug resolved
 ********************************************************************** */

import { LightningElement, track, wire,api } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getCategoryAndStatusPicklistValues from '@salesforce/apex/WBTemplateController.getCategoryAndStatusPicklistValues';
import deleteTemplete from '@salesforce/apex/WBTemplateController.deleteTemplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {loadStyle} from 'lightning/platformResourceLoader';
import wbPreviewTemplateStyle from '@salesforce/resourceUrl/wbPreviewTemplateStyle';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class WbAllTemplatePage extends LightningElement {
    @track isTemplateVisible = true;
    @track isCreateTemplate = false;
    @track categoryValue='';
    @track timePeriodValue='';
    @track statusValues='';
    @track searchInput='';
    @track categoryOptions = [];
    @track statusOptions = [];
    @track allRecords = [];
    @track isLoading=false;
    @track filteredRecords=[];
    @track selectedTemplateId='';
    @track showPopup = false; 
    @track isFilterVisible = false;
    @track editTemplateId='';
    subscription = null;
    channelName = '/event/MVWB__Template_Update__e';

    @wire(getCategoryAndStatusPicklistValues)
    wiredCategoryAndStatus({ error, data }) {
        try {
            if (data) {
                this.categoryOptions = [{ label: 'All', value: '' }, ...data.categories.map(cat => ({ label: cat, value: cat }))];
                this.statusOptions = [{ label: 'All', value: '' }, ...data.statuses.map(stat => ({ label: stat, value: stat }))];
            } else if (error) {
                console.error('Error fetching category and status picklist values: ', error);
            }
        } catch (err) {
            console.error('Unexpected error in wiredCategoryAndStatus: ', err);
        }
    }

    get actionButtonClass(){
        return this.allRecords?.length >= 5 ? 'custom-button create-disabled' : 'custom-button cus-btns' ;
    }

    get timePeriodOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Last 7 Days', value: 'last7days' },
            { label: 'Last 30 Days', value: 'last30days' },
            { label: 'Last 90 Days', value: 'last90days' }
        ];
    }


    get filterClass() {
        return this.isFilterVisible ? 'combobox-container visible' : 'combobox-container hidden';
    }

    connectedCallback(){
        this.fetchAllTemplate();
        this.registerPlatformEventListener();
    }

    renderedCallback() {
        loadStyle(this, wbPreviewTemplateStyle).then(() => {
            console.log("Loaded Successfully")
        }).catch(error => {
            console.error("Error in loading the colors",error)
        })
    }

    disconnectedCallback() {
        this.unregisterPlatformEventListener(); 
    }

    registerPlatformEventListener() {
        const messageCallback = (event) => {
            const payload = event.data.payload;
            this.updateRecord(payload.MVWB__Template_Id__c, payload.MVWB__Template_Status__c);
        };

        subscribe(this.channelName, -1, messageCallback)
            .then((response) => {
                this.subscription = response;
            })
            .catch((error) => {
                console.error('Error subscribing to platform event:', error);
            });

        onError((error) => {
            console.error('Streaming API error:', error);
        });
    }

    unregisterPlatformEventListener() {
        if (this.subscription) {
            unsubscribe(this.subscription, (response) => {
                console.log('Unsubscribed from platform event:', response);
            });
        }
    }

    updateRecord(templateId, newStatus) {
        const recordIndex = this.allRecords.findIndex((record) => record.Id === templateId);
        if (recordIndex !== -1) {
            const updatedRecord = { ...this.allRecords[recordIndex], MVWB__Status__c: newStatus };
            updatedRecord.isButtonDisabled = newStatus === 'In-Review';
            updatedRecord.cssClass = updatedRecord.isButtonDisabled ? 'action edit disabled' : 'action edit';

            this.allRecords[recordIndex] = updatedRecord;
            this.filteredRecords = [...this.allRecords]; 
        }
    }

    fetchAllTemplate(){
        this.isLoading=true;
        getWhatsAppTemplates()
        .then(data => {
            try {
                if (data) {
                    this.allRecords = data.map((record, index) => {
                        const isButtonDisabled = record.MVWB__Status__c === 'In-Review';
                        return {
                            ...record,
                            id: record.Id,
                            serialNumber: index + 1, 
                            LastModifiedDate: this.formatDate(record.LastModifiedDate),
                            isButtonDisabled,
                            cssClass: isButtonDisabled ? 'action edit disabled' : 'action edit'
                        };
                    });                    
                    this.filteredRecords = [...this.allRecords];
                    this.isLoading=false;
                } else if (error) {
                    console.error('Error fetching WhatsApp templates: ', error);
                    this.isLoading=false;
                }
            } catch (err) {
                console.error('Unexpected error in wiredTemplates: ', err);
                this.isLoading=false;
            }
        })
        .catch(error => {
            console.log(error);
            this.isLoading=false;
        });
    }

    handleTemplateUpdate(event) {
        this.allRecords = event.detail; 
        this.filteredRecords = [...this.allRecords];
    }

    // Toggle visibility
    toggleFilterVisibility() {
        this.isFilterVisible = !this.isFilterVisible;
    }

    showCreateTemplate(){
        this.isLoading=true;
        setTimeout(() => {
            this.isCreateTemplate=true;
            this.isTemplateVisible = false;  
            this.isLoading=false;          
        }, 1000);
        
    }

    handleChange(event) {
        try {
            const fieldName = event.target.name; 
            const value = event.detail?.value || event.target.value; 
        
            switch (fieldName) {
                case 'category':
                    this.categoryValue = value;
                    break;
                case 'timePeriod':
                    this.timePeriodValue = value;
                    break;
                case 'status':
                    this.statusValues = value;
                    break;
                case 'searchInput':
                    this.searchInput = value.toLowerCase();
                    break;
                default:
                    console.warn(`Unhandled field: ${fieldName}`);
                    break;
            }
            this.filterRecords();
        } catch (error) {
            console.error('Error while handling changes in the filter.',error);
        }
    }
  
    formatDate(dateString) {
        if (!dateString) return '';
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return new Date(dateString).toLocaleDateString(undefined, options);
    }

    filterRecords() {
        try {
            let filtered = [...this.allRecords];

            if (this.categoryValue) {
                filtered = filtered.filter(record => record.MVWB__Template_Category__c === this.categoryValue);
            }
    
            if (this.timePeriodValue) {
                const today = new Date();
                let fromDate;
                if (this.timePeriodValue === 'last7days') {
                    fromDate = new Date(today.setDate(today.getDate() - 8));
                } else if (this.timePeriodValue === 'last30days') {
                    fromDate = new Date(today.setDate(today.getDate() - 30));
                } else if (this.timePeriodValue === 'last90days') {
                    fromDate = new Date(today.setDate(today.getDate() - 90));
                }
                filtered = filtered.filter(record => new Date(record.CreatedDate) >= fromDate);
            }
    
            if (this.statusValues.length > 0) {
                filtered = filtered.filter(record => this.statusValues.includes(record.MVWB__Status__c));
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.MVWB__Template_Name__c.toLowerCase().includes(this.searchInput));
            }
    
            this.filteredRecords = filtered;

        } catch (error) {
            this.showToastError('An error occurred while filtering the records.');
        }
       
    }

    deleteTemplate(event){
        this.isLoading=true;
        try {
            const recordId = event.currentTarget.dataset.id;
            if(recordId != undefined){
                deleteTemplete({templateId: recordId})
                .then(data => {
                    if(data == 'Template deleted successfully'){
                        this.showToastSuccess('Template deleted successfully');
                        this.allRecords = this.allRecords.filter(record => record.Id !== recordId); 
                        this.allRecords = this.allRecords.map((record, index) => ({
                            ...record,
                            serialNumber: index + 1
                        }));   
                        this.filteredRecords = [...this.allRecords];                    
                        this.isLoading=false;
                    }else{
                        this.showToastError('Error in deleting template');
                        this.isLoading=false;
                    }
                })
                .catch(error => {
                    console.log(error);
                    this.showToastError('Error in deleting template');
                    this.isLoading=false;
                });
            } else{
                this.showToastError('Template not found');
                this.isLoading=false;
            }

        } catch (error) {
            this.showToastError('Error in deleteTemplate:', error);
            this.isLoading = false;
        }
        
    }

    previewTemplate(event) {
        this.selectedTemplateId =  event.currentTarget.dataset.id;
        this.showPopup = true;
    }

    editTemplate(event) {
        this.isLoading=true;
        const recordId = event.currentTarget.dataset.id;        
        const record = this.filteredRecords.find(record => record.id === recordId);
    
        if (record && record.isButtonDisabled) {
            console.log('Button is disabled, action not allowed.');
            return;  
        }
    
        this.editTemplateId = recordId;
        this.isCreateTemplate = true; 
        this.isTemplateVisible = false; 
        this.isLoading=false; 
    }
    

    handlePopupClose() {
        this.showPopup = false; 
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