/**
 * Component Name: WbAllTemplatePage
 * @description: Used LWC components to show all templates record.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 30/04/2025
 * Updated By : Divij Modi
 * Change Description :Code Rework
 ********************************************************************** */

import { LightningElement, track, wire,api } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import deleteTemplete from '@salesforce/apex/WBTemplateController.deleteTemplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';
import TEMPLATE_OBJECT from '@salesforce/schema/MVWB__Template__c';
import CATEGORY_FIELD from '@salesforce/schema/MVWB__Template__c.MVWB__Template_Category__c';
import STATUS_FIELD from '@salesforce/schema/MVWB__Template__c.MVWB__Status__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import getSyncTemplateData from '@salesforce/apex/SyncTemplateController.syncTemplate'
import confirmTemplateSync from '@salesforce/apex/SyncTemplateController.confirmTemplateSync'

export default class WbAllTemplatePage extends LightningElement {
    @track isTemplateVisible = false;
    @track isCreateTemplate = false;
    @track isCloneTemplate = false;
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
    @track subscription = null;
    channelName = '/event/MVWB__Template_Update__e';
    @track showLicenseError = false;
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track data = [];
    @track paginatedData = [];
    objectApiName = TEMPLATE_OBJECT;
    @track showModal = false;
    @track missingTemplatesList = [];
    @track orgOnlyTemplateMap = {};
    @track storedTemplateSyncData = {};
    @track isTemplateCreationConfirmed = false;
    @track isMissingTemplateCreationDisabled = true;
    @track selectedOrphanTemplateAction = 'CreateInMeta';
    @track confirmSyncChecked = false;

    get actionButtonClass(){
        return 'custom-button cus-btns' ;
    }

    get timePeriodOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Last 7 Days', value: 'last7days' },
            { label: 'Last 30 Days', value: 'last30days' },
            { label: 'Last 90 Days', value: 'last90days' }
        ];
    }

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
            console.error('Error in pagination:', error);
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

    get filterClass() {
        return this.isFilterVisible ? 'combobox-container visible' : 'combobox-container hidden';
    }

     
    get isDeleteSelected() {
        return this.selectedOrphanTemplateAction === 'DeleteFromOrg';
    }

    get isCreateSelected() {
        return this.selectedOrphanTemplateAction === 'CreateInMeta';
    }

    get hasMissingTemplates() {
        return this.missingTemplatesList.length > 0;
    }

    get hasOrgOnlyTemplates() {
        console.log('hasOrgOnlyTemplates =', this.orgOnlyTemplateMap && Object.keys(this.orgOnlyTemplateMap).length > 0);
        return this.orgOnlyTemplateMap && Object.keys(this.orgOnlyTemplateMap).length > 0;
    }

    get hasNoExtraTemplates() {
        return (this.missingTemplatesList.length === 0) && (Object.keys(this.orgOnlyTemplateMap).length === 0)
    }

    get orgOnlyTemplateArray() {
        return Object.entries(this.orgOnlyTemplateMap || {}).map(([id, name]) => ({
            id,
            name
        }));
    }

    get orphanTemplateOptions() {
        return [
            { label: 'Delete them from Org', value: 'DeleteFromOrg' },
            { label: 'Create them in Meta', value: 'CreateInMeta' }
        ];
    }

    get disableProceed() {
        const confirmChecked = this.confirmSyncChecked;
        const orphanActionSelected = this.selectedOrphanTemplateAction !== undefined && this.selectedOrphanTemplateAction !== null && this.selectedOrphanTemplateAction !== '';
        return !(confirmChecked && (this.hasOrgOnlyTemplates ? orphanActionSelected : true));
    }

    @wire(getObjectInfo, { objectApiName: TEMPLATE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CATEGORY_FIELD })
    categoryPicklist({ data, error }) {
        if (data) {
            this.categoryOptions = [{ label: 'All', value: '' }, ...data.values.map(item => ({ label: item.label, value: item.value }))];
        } else if (error) {
            console.error('Error loading category picklist values', error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: STATUS_FIELD })
    statusPicklist({ data, error }) {
        if (data) {
            this.statusOptions = [{ label: 'All', value: '' }, ...data.values.map(item => ({ label: item.label, value: item.value }))];
        } else if (error) {
            console.error('Error loading status picklist values', error);
        }
    }

    async connectedCallback(){
        try {
            this.isLoading = true;
            await this.checkLicenseStatus();
            if (this.showLicenseError) {
                return; // Stops execution if license is expired
            }
            this.isTemplateVisible = true;
            this.fetchAllTemplate(true);
            this.registerPlatformEventListener();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
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

    disconnectedCallback() {
        this.unregisterPlatformEventListener(); 
    }

    registerPlatformEventListener() {
        const messageCallback = (event) => {
            const payload = event.data.payload;
            
            if (payload.MVWB__Template_Id__c && payload.MVWB__Template_Status__c) {
                this.fetchAllTemplate(false);
            }

            // Call if Fetch_All_Templates__c is present
            if (payload.MVWB__Fetch_All_Templates__c) {
                this.fetchAllTemplate(false);
            }
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
            });
        }
    }

<<<<<<< HEAD
<<<<<<< HEAD
    
    syncTemplates() {
        console.log('syncTemplates start');
        this.isLoading = true;
        this.showModal = false;
        this.syncTemplateData();
    }

    syncTemplateData(){
        getSyncTemplateData()
        .then(data => {
            console.log('data from syncTemplatesData:', data);
            this.missingTemplatesList = data.metaToOrg;
            console.log('this.missingTemplatesList:', this.missingTemplatesList);
            this.orgOnlyTemplateMap = data.orgToMeta || {};
            console.log('this.orgOnlyTemplateMap:', this.orgOnlyTemplateMap);

            // Store full response in JS for reuse
            this.storedTemplateSyncData = data;
            console.log('this.storedTemplateSyncData =', this.storedTemplateSyncData);
            this.isLoading = false;
            this.showModal = true;
        })
        .catch(error => {
            console.error('Error fetching pending flow list: ', error);
            this.isLoading = false;
        });
    }

    handleProceed() {
        this.showToastSuccess('Template Sync Started', 'Syncing in progress. You will be notified once it is completed.');
        const cleanedData = JSON.stringify(JSON.parse(JSON.stringify(this.storedTemplateSyncData)));
        console.log('cleanedData =', cleanedData);
        console.log('Selected Orphan Action:', this.selectedOrphanTemplateAction);
        
        confirmTemplateSync({
            selectedOrphanTemplateAction: this.selectedOrphanTemplateAction,
            isSyncConfirmed: true,
            wrapperFromClientJSON: cleanedData
        })
        .then(()=>{

            this.showModal = false;
        }
        )
        .catch(error => {
            console.error('Error during template sync:', error);
        });
    }

    closeModal() {
        this.confirmSyncChecked = false;
        this.isMissingTemplateCreationDisabled = true;
        this.selectedOrphanTemplateAction = 'CreateInMeta';
        this.showModal = false;
    }

    handleConfirmationChange(event) {
        this.isTemplateCreationConfirmed = event.target.checked;
        this.isMissingTemplateCreationDisabled = !this.isTemplateCreationConfirmed;
        this.confirmSyncChecked = event.target.checked;
    }

    handleOrphanTemplateOptionChange(event) {
        this.selectedOrphanTemplateAction = event.detail.value;
        console.log('selectedOrphanTemplateAction:', this.selectedOrphanTemplateAction);
        
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

    // fetchCategoryAndStatusOptions() {
    //     getCategoryAndStatusPicklistValues()
    //         .then(data => {
    //             if (data) {
    //                 this.categoryOptions = [{ label: 'All', value: '' }, ...data.categories.map(categoryData => ({ label: categoryData, value: categoryData }))];
    //                 this.statusOptions = [{ label: 'All', value: '' }, ...data.statuses.map(statudData => ({ label: statudData, value: statudData }))];
    //             }
    //         })
    //         .catch(error => {
    //             console.error('Error fetching category and status picklist values: ', error);
    //         });
    // }

=======
>>>>>>> 7d66961c07fe822e53505444f5ebda25146c2bf2
=======
>>>>>>> 20ec72c1ee1cf1af4c1e1b8c7fa1aa95fd28fb07
    fetchAllTemplate(showSpinner){
        if(showSpinner){
            this.isLoading=true;
        }
        // this.isLoading=true;
        getWhatsAppTemplates()
        .then(data => {
            
            try {
                if (data) {
                    this.data = data.map((record, index) => {
                        const editHistories = record?.MVWB__WB_Template_Histories__r || [];
                        
                        let editedIn24Hrs = false;
                        let maxMonthEditReached = false;
                        let editedDateDisplay = '';

                        if (editHistories.length > 0) {
                            const now = new Date();
                            const mostRecentEdit = new Date(editHistories[0].MVWB__Edited_Time__c);
                            
                            const diffInHours = (now - mostRecentEdit) / (1000 * 60 * 60);
                            
                            if (diffInHours < 24) {
                                editedIn24Hrs = true;
                            }

                            editedDateDisplay = mostRecentEdit;
                            
                            // Check 10th record for month limit
                            if (editHistories.length >= 10) {
                                const tenthEdit = new Date(editHistories[9].MVWB__Edited_Time__c);
                                const oneMonthAgo = new Date();
                                oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);
                                if (tenthEdit > oneMonthAgo) {
                                    maxMonthEditReached = true;
                                }
                            }
                        } else {
                            // No edit history → fallback to LastModifiedDate
                            editedDateDisplay = new Date(record.LastModifiedDate);
                        }

                        const isButtonDisabled = record.MVWB__Status__c === ('In-Review' || 'Rejected') || editedIn24Hrs || maxMonthEditReached;
                        
                        return {
                            ...record,
                            id: record.Id,
                            serialNumber: index + 1, 
                            LastModifiedDate: this.formatDate(editedDateDisplay),
                            isButtonDisabled,
                            cssClass: isButtonDisabled ? 'action edit disabled' : 'action edit'
                        };
                    });             
                           
                    this.filteredRecords = [...this.data];
                    this.updateShownData();
                    this.isLoading=false;
                } else {
                    console.error('Error fetching WhatsApp templates: ', data);
                    this.isLoading=false;
                }
            } catch (err) {
                console.error('Unexpected error in wiredTemplates: ', err);
                this.isLoading=false;
            }
        })
        .catch(error => {
            console.error('Error in fetchAllTemplate() method: ', error);
            this.isLoading=false;
        });
    }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredRecords.slice(startIndex, endIndex);
        } catch (error) {
            console.error('Error in updateShownData() method: ', error);
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
            console.error('Error in handlePrevious() method: ', error);
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            console.error('Error in handleNext() method: ', error);
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
            console.error('Error in handlePageChange() method: ', error);
            this.showToast('Error', 'Error navigating pages', 'error');
        }
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
            let filtered = [...this.data];

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
            this.updateShownData();

        } catch (error) {
            console.error('Error while filtering records.',error);
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
                        this.fetchAllTemplate(true);                  
                        this.isLoading=false;
                    }else{
                        this.showToastError('Error in deleting template');
                        this.isLoading=false;
                    }
                })
                .catch(error => {
                    console.error('Error in deleting template', error);
                    this.showToastError('Error in deleting template');
                    this.isLoading=false;
                });
            } else{
                this.showToastError('Template not found');
                this.isLoading=false;
            }

        } catch (error) {
            console.error('Error while deleting template.',error);
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
            return;  
        }
    
        this.editTemplateId = recordId;
        this.isCreateTemplate = true; 
        this.isTemplateVisible = false; 
        this.isLoading=false; 
    }

    cloneTemplate(event) {
        this.isLoading=true;
        const recordId = event.currentTarget.dataset.id;        
        const record = this.filteredRecords.find(record => record.id === recordId);
    
        if (record && record.isButtonDisabled) {
            return;  
        }
    
        this.editTemplateId = recordId;
        this.isCloneTemplate = true;
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