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
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';

export default class WbAllFlowsPage extends LightningElement {
    @track allRecords = [];
    @track filteredRecords = [];
    @track statusValues = 'All';
    @track statusOptions = [];
    @track isFlowVisible = false;
    @track iscreateflowvisible = false;
    @track searchInput;
    @track isLoading = false;
    @track flowPreviewURL = '';
    @track showPopup = false;
    @track isFlowDraft = false;
    @track showLicenseError = false;
    @track isEditMode = false;
    @track isCloneFlow = false;
    @track isNameClicked = false;
    @track showDeletePopup = false;
    @track showDeprecatePopup = false;
    @track selectedFlowId = '';
    @track selectedFlowName = '';
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track paginatedData = [];
    @track showCloneModal = false;
    @track cloneFlowName = '';
    @track selectedFlowDatasetId;
    @track selectedFlowDatasetStatus;

    get showNoRecordsMessage() {
        return this.filteredRecords.length === 0;
    }

    get totalItems() {
        return this.filteredRecords.length;
    }
    
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }
    
    get pageNumbers() {
        try {
            const totalPages = this.totalPages;
            const currentPage = this.currentPage;
            const visiblePages = this.visiblePages;

            let pages = [];

            if (totalPages <= visiblePages) {
                for (let i = 1; i <= totalPages; i++) {
                    pages.push({
                        number: i,
                        isEllipsis: false,
                        className: `pagination-button ${i === currentPage ? 'active' : ''}`
                    });
                }
            } else {
                pages.push({
                    number: 1,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === 1 ? 'active' : ''}`
                });

                if (currentPage > 3) {
                    pages.push({ isEllipsis: true });
                }

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
                    pages.push({ isEllipsis: true });
                }

                pages.push({
                    number: totalPages,
                    isEllipsis: false,
                    className: `pagination-button ${currentPage === totalPages ? 'active' : ''}`
                });
            }
            return pages;
        } catch (error) {
            this.showToast('Error', 'Error in pageNumbers->' + error, 'error');
            return null;
        }
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    get isDisabledCloneNext() {
        return this.cloneFlowName.trim() === '';
    }

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

    async connectedCallback(){
        try {
            this.isLoading = true;
            await this.checkLicenseStatus();
            if (this.showLicenseError) {
                return; // Stops execution if license is expired
            }
            
            this.isFlowVisible = true;
            this.fetchWhatsAppFlows();
            document.addEventListener('click', this.handleOutsideClick);
            
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
    }

    async checkLicenseStatus() {
        try {
            const isLicenseValid = await checkLicenseUsablility();
            if (!isLicenseValid) {
                this.showLicenseError = true;
            }
        } catch (error) {
            console.error('Error checking license:', error);
        }
    }

    handlePackageUpdate(event){
        this.showLicenseError = event.detail.isPackageValid;
    }

    fetchWhatsAppFlows(){
        try {
            getWhatsAppFlows()
                .then((data) => {
                    this.allRecords = data.map((record, index) => {
                        return {
                            ...record,
                            serialNumber: index + 1,
                            isEditable: record.MVWB__Status__c === 'Published' || record.MVWB__Status__c === 'Draft',
                            isDraft: record.MVWB__Status__c === 'Draft',
                            isPublished: record.MVWB__Status__c === 'Published',
                            isDeprecated: record.MVWB__Status__c === 'Deprecated',
                            LastModifiedDate: this.formatDate(record.LastModifiedDate)
                        };
                    });
                    this.filterRecords();
                })
                .catch((error) => {
                    console.error('Error in fetchWhatsAppFlows:::', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Error in fetchWhatsAppFlows : ' , error);
        }
    }

    showCreateFlow(){
        this.isEditMode = false;
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
    }
    
    handleNameClick(event) {
        this.selectedFlowId = event.target.dataset.recordId;
        this.selectedFlowName = event.currentTarget.textContent;
        this.isNameClicked = true;
    }

    handleStatusChange(event) {
        this.statusValues = event.target.value;
        this.filterRecords();
    }

    handleSearchInputChange(event) {
        this.searchInput = event.target.value.trim().toLowerCase();
        this.filterRecords();
    }

    filterRecords() {
        try {
            let filtered = [...this.allRecords];
    
            if (this.statusValues && this.statusValues !== 'All') {
                filtered = filtered.filter(record => record.MVWB__Status__c === this.statusValues);
            }
    
            if (this.searchInput) {
                filtered = filtered.filter(record => record.MVWB__Flow_Name__c.toLowerCase().includes(this.searchInput));
            }
    
            this.filteredRecords = filtered;
            this.isLoading = false;
            this.updateShownData();
        } catch (error) {
            console.error('Error in filtering records:', error);
            this.isLoading = false;
        }
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredRecords.slice(startIndex, endIndex);
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handlePrevious() {
        try{
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating to previous page', 'error');
        }
    }

    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handlePageChange(event) {
        try{
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentPage) {
                this.currentPage = selectedPage;
                this.updateShownData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handleOutsideClick = (event) => {
        // Check if the click is outside the component
        if (!this.template.contains(event.target)) {
            this.template.querySelectorAll('.dropdown-menu').forEach(menu => {
                menu.classList.add('hidden');
            });
        }
    };

    toggleDropdown(event) {
        event.stopPropagation();

        const allMenus = this.template.querySelectorAll('.dropdown-menu');
        allMenus.forEach(menu => {
            menu.classList.add('hidden');
        });

        const container = event.currentTarget.closest('.action-container');
        const dropdown = container.querySelector('.dropdown-menu');

        if (dropdown) {
            dropdown.classList.toggle('hidden');
        }
    }

    cloneFlow(event) {
        console.log('cloneFlow clicked')
        this.selectedFlowId = event.currentTarget.dataset.id;
        console.log('this.selectedFlowId =', this.selectedFlowId);
        this.isCloneFlow = true;
        this.showCloneModal = true;
    }

    handleFlowNameChange(event) {
        this.cloneFlowName = event.target.value;
    }

    closeCloneModal() {
        this.showCloneModal = false;
        this.cloneFlowName = '';
        this.isCloneFlow = false;
        this.selectedFlowId = '';
    }

    handleCloneNext() {
        this.showCloneModal = false;
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
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

    editFlow(event){
        this.selectedFlowId = event.currentTarget.dataset.id;
        this.isEditMode = true;
        this.isFlowVisible = false;
        this.iscreateflowvisible = true;
    }
    
    confirmDeleteFlow(event) {
        this.selectedFlowDatasetId = event.currentTarget.dataset.id;
        this.selectedFlowDatasetStatus = event.currentTarget.dataset.status;
        this.showDeletePopup = true;
    }

    deleteFlow(){
        try {
            var flowId = this.selectedFlowDatasetId;
            var status = this.selectedFlowDatasetStatus;
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
            this.showDeletePopup = false;
            this.updateShownData();
        } catch (error) {
            console.error('Error in deleteFlow : ' , error);
        }
    }

    closeDeprecatePopup() {
        this.showDeprecatePopup = false;
        this.showDeletePopup = false;
    }

    confirmDeprecateFlow(event) {
        this.selectedFlowDatasetId = event.currentTarget.dataset.id;
        this.selectedFlowDatasetStatus = event.currentTarget.dataset.status;
        this.showDeprecatePopup = true;
    }

    deprecateFlow(){
        try {
            var flowId = this.selectedFlowDatasetId;
            var status = this.selectedFlowDatasetStatus;
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
            this.showDeprecatePopup = false;
            this.updateShownData();
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