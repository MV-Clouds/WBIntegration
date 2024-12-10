/**
 * Component Name: WbAllTemplatePage
 * @description: Used LWC components to show all templates record.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 7/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : 
 * Change Description :Change the UI as per figma design.
 ********************************************************************** */

import { LightningElement, track, wire } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getCategoryAndStatusPicklistValues from '@salesforce/apex/WBTemplateController.getCategoryAndStatusPicklistValues';
import deleteTemplete from '@salesforce/apex/WBTemplateController.deleteTemplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {loadStyle} from 'lightning/platformResourceLoader';
import wbPreviewTemplateStyle from '@salesforce/resourceUrl/wbPreviewTemplateStyle';

export default class WbAllTemplatePage extends LightningElement {
    @track isTemplateVisible = true;
    @track isCreateTemplate = false;
    @track categoryValue;
    @track timePeriodValue;
    @track statusValues = [];
    @track searchInput;
    @track categoryOptions = [];
    @track statusOptions = [];
    @track allRecords = [];
    @track isLoading=false;
    @track filteredRecords=[];
    
    @track selectedTemplateId='';
    @track showPreview = false;
    // @track filterIcon=filterIcon;

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

    @wire(getWhatsAppTemplates)
    wiredTemplates({ error, data }) {
        try {
            if (data) {
                this.allRecords = data.map((record, index) => {
                    return {
                        ...record,
                        id: record.Id,
                        serialNumber: index + 1, 
                        LastModifiedDate: this.formatDate(record.LastModifiedDate)
                    };
                });
                this.filteredRecords = [...this.allRecords];
            } else if (error) {
                console.error('Error fetching WhatsApp templates: ', error);
            }
        } catch (err) {
            console.error('Unexpected error in wiredTemplates: ', err);
        }
    }

    connectedCallback(){
        console.log('default option selected==> '+ this.selectedOption);
    }

    renderedCallback() {
        loadStyle(this, wbPreviewTemplateStyle).then(() => {
            console.log("Loaded Successfully")
        }).catch(error => {
            console.error("Error in loading the colors",error)
        })
    }

    get timePeriodOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Last 7 Days', value: 'last7days' },
            { label: 'Last 30 Days', value: 'last30days' },
            { label: 'Last 90 Days', value: 'last90days' }
        ];
    }

    @track isFilterVisible = false;

    // Getter for dynamic class
    get filterClass() {
        return this.isFilterVisible ? 'combobox-container visible' : 'combobox-container hidden';
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
        console.log(`${fieldName}: ${value}`);
        this.filterRecords();
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
                filtered = filtered.filter(record => record.Template_Category__c === this.categoryValue);
                console.log('category filter=> ',filtered);
            }
    
            if (this.timePeriodValue) {
                const today = new Date();
                let fromDate;
                if (this.timePeriodValue === 'last7days') {
                    fromDate = new Date(today.setDate(today.getDate() - 8));
                    console.log('from date 7 days==>',fromDate);
                } else if (this.timePeriodValue === 'last30days') {
                    fromDate = new Date(today.setDate(today.getDate() - 30));
                    console.log('from date 30 days==>',fromDate);
                } else if (this.timePeriodValue === 'last90days') {
                    fromDate = new Date(today.setDate(today.getDate() - 90));
                    console.log('from date 90 days==>',fromDate);
                }
                filtered = filtered.filter(record => new Date(record.CreatedDate) >= fromDate);
                console.log('date filter==>',filtered);
            }
    
            if (this.statusValues.length > 0) {
                filtered = filtered.filter(record => this.statusValues.includes(record.Status__c));
                console.log('status filter==>',filtered);
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.Name.toLowerCase().includes(this.searchInput));
            }
    
            this.filteredRecords = filtered;

        } catch (error) {
            console.error('Error in filterRecords:', error);
            this.showToastError('An error occurred while filtering the records.');
        }
       
    }

    deleteTemplate(event){
        this.isLoading=true;
        const recordId = event.currentTarget.dataset.id;

        console.log('Record ID to delete:', recordId);

        try {
            if(recordId != undefined){
                deleteTemplete({templateId: recordId})
                .then(data => {
                    if(data == 'Template deleted successfully'){
                        console.log('Template deleted successfully');
                        this.showToastSuccess('Template deleted successfully');
                        this.allRecords = this.allRecords.filter(record => record.Id !== recordId);                        
                        this.isLoading=false;
                    }else{
                        console.log(data);
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
                console.log('recordId undifined');
                this.showToastError('Template not found');
                this.isLoading=false;
            }

        } catch (error) {
            console.error('Error in deleteTemplate:', error);
            this.showToastError('An unexpected error occurred while deleting the template');
            this.isLoading = false;
        }
        
    }

    previewTemplate(event) {
        this.selectedTemplateId =  event.currentTarget.dataset.id;
        this.showPreview = true;
    }

    closePreview(){
        this.showPreview = false;
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
