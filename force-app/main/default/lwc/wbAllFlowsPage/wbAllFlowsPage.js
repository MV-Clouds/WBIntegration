import { LightningElement, track, wire } from 'lwc';
import getWhatsAppFlows from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlows';
import getStatusPicklistValues from '@salesforce/apex/WhatsAppFlowController.getStatusPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WbAllFlowsPage extends LightningElement {
    @track isFlowVisible = true;
    @track iscreateflowvisible = false;
    @track statusValues = [];
    @track searchInput;
    @track filteredRecords = [];
    @track categoryOptions = [];
    @track statusOptions = [];
    @track allRecords = [];
    @track isLoading=false;

    @wire(getStatusPicklistValues)
    wiredCategoryAndStatus({ error, data }) {
        if (data) {
            this.statusOptions = [{ label: 'All', value: '' }, ...data.statuses.map(stat => ({ label: stat, value: stat }))];
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getWhatsAppFlows)
    wiredWhatsappFlows({ error, data }) {
        if (data) {
            this.allRecords = data.map(record => {
                return {
                    ...record,
                    id: record.Id,
                    LastModifiedDate: this.formatDate(record.LastModifiedDate)
                };
            });
            this.filterRecords();
        } else if (error) {
            console.error(error);
        }
    }

    showCreateFlow(){
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
    }

    handleStatusChange(event) {
        this.statusValues = event.detail.value;
        console.log(this.statusValues);
        this.filterRecords();
    }

    handleSearchInputChange(event) {
        this.searchInput = event.target.value.toLowerCase();
        this.filterRecords();
    }

    filterRecords() {
        let filtered = [...this.allRecords];

        if (this.statusValues.length > 0) {
            filtered = filtered.filter(record => this.statusValues.includes(record.Flow_Status__c));
            console.log('status filter==>',filtered);
        }

        if (this.searchInput) {
            filtered = filtered.filter(record => record.Name.toLowerCase().includes(this.searchInput));
        }

        this.filteredRecords = filtered;
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-GB', {
            day: 'numeric',
            month: 'short',
            year: 'numeric'
        });
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