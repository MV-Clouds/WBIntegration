/**
 * Component Name: WbAllTemplatePage
 * @description: Used LWC components to show all templates record.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 25/11/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : 
 * Change Description :
 ********************************************************************** */

import { LightningElement, track, wire } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getCategoryAndStatusPicklistValues from '@salesforce/apex/WBTemplateController.getCategoryAndStatusPicklistValues';
import deleteTemplete from '@salesforce/apex/WBTemplateController.deleteTemplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class WbAllTemplatePage extends LightningElement {
    @track isTemplateVisible = true;
    @track isCreateTemplate = false;
    @track categoryValue;
    @track timePeriodValue;
    @track statusValues = [];
    @track searchInput;
    @track filteredRecords = [];
    @track paginatedRecords = [];
    @track currentPage = 1;
    @track totalPages = 1;
    @track categoryOptions = [];
    @track statusOptions = [];
    @track allRecords = [];
    @track pageNumber = 1;
    @track pageSize = 10;
    @track currentPage = 1;
    @track visiblePages = 3;
    @track isLoading=false;


    @wire(getCategoryAndStatusPicklistValues)
    wiredCategoryAndStatus({ error, data }) {
        if (data) {
            this.categoryOptions = [{ label: 'All', value: '' }, ...data.categories.map(cat => ({ label: cat, value: cat }))];
            this.statusOptions = [{ label: 'All', value: '' }, ...data.statuses.map(stat => ({ label: stat, value: stat }))];
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getWhatsAppTemplates)
    wiredTemplates({ error, data }) {
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

    connectedCallback(){
        console.log('default option selected==> '+ this.selectedOption);
    }

    // pagination logic start
    get totalItems() {
        return this.allRecords.length;
    }

    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    get pageNumbers() {
        try{
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                // If the total pages are less than or equal to the visible pages, show all
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                // Always show the first page
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    // Show ellipsis if the current page is greater than 3
                    pages.push({ isEllipsis: true });
                }

                // Show the middle pages
                let start = Math.max(2, currentPage - 1);
                let end = Math.min(currentPage + 1, totalPages - 1);

                for (let i = start; i <= end; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }

                if (currentPage < totalPages - 2) {
                    // Show ellipsis if the current page is less than totalPages - 2
                    pages.push({ isEllipsis: true });
                }

                // Always show the last page
                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
            return pages;
        }catch(error){
            console.log('Error pageNumbers ->'+error);
        }
    }

    get showEllipsis() {
        return Math.ceil(this.totalItems / this.pageSize) > this.visiblePages;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    get startIndex() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get endIndex() {
        return Math.min(this.currentPage * this.pageSize, this.totalItems);
    }

    updateShownData() {
        try{
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = startIndex + this.pageSize;
            this.paginatedRecords = this.filteredRecords.slice(startIndex, endIndex);
        }catch(error){
            console.log('Error updateShownData ->'+error);
        }
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateShownData();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateShownData();
        }
    }

    handlePageChange(event) {
        const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.updateShownData();
        }
    }
    showCreateTemplate(){
        this.isCreateTemplate=true;
        this.isTemplateVisible = false;
    }

    // pagination logic end
    get timePeriodOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Last 7 Days', value: 'last7days' },
            { label: 'Last 30 Days', value: 'last30days' },
            { label: 'Last 90 Days', value: 'last90days' }
        ];
    }

    get languageOptions(){
        return[
            { label: 'English (US)', value: 'English (US)' }
        ];      
    }

    handleCategoryChange(event) {
        this.categoryValue = event.detail.value;
        console.log(this.categoryValue);
        this.filterRecords();
    }

    handleTimePeriodChange(event) {
        this.timePeriodValue = event.detail.value;
        console.log(this.timePeriodValue);
        this.filterRecords();
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

    handleLanguage(event){
        this.selectedLanguage = event.target.value;
        console.log(this.selectedLanguage);
        
    }

    filterRecords() {
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
        this.currentPage = 1;
        this.totalPages = Math.ceil(this.filteredRecords.length / this.pageSize);
        this.updateShownData();
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return new Date(dateString).toLocaleDateString(undefined, options);
    }

    deleteTemplate(event){
        this.isLoading=true;
        const recordId = event.currentTarget.dataset.id;

        // Now you can use the recordId to perform delete operation
        console.log('Record ID to delete:', recordId);

        if(recordId != undefined){
            deleteTemplete({templateId: recordId})
            .then(data => {
                if(data == 'Template deleted successfully'){
                    console.log('Template deleted successfully');
                    this.showToastSuccess('Template deleted successfully');
                    this.allRecords = this.allRecords.filter(record => record.Id !== recordId);
                    
                    this.filteredRecords = this.allRecords; 
                    this.updateShownData();
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