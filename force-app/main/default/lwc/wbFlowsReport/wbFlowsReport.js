import { LightningElement, track, api } from 'lwc';
import getWhatsAppFlowById from '@salesforce/apex/WhatsAppFlowController.getWhatsAppFlowById';
import getFlowSubmissionByFlowId from '@salesforce/apex/WhatsAppFlowController.getFlowSubmissionByFlowId';
import getFlowSubmissionById from '@salesforce/apex/WhatsAppFlowController.getFlowSubmissionById';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WbFlowsReport extends LightningElement {
    @api selectedFlowId;

    @track recordId;
    @track flowDetails;
    @track flowSubmissionDetails;
    @track record;
    @track paginatedData = [];
    @track filteredData = [];
    @track filteredDetails = [];
    @track currentPage = 1;
    @track pageSize = 15;
    @track visiblePages = 5;
    @track flowReport=true;
    @track isFlowSubmissionDetails=false;
    @track isLoading = false;
    @track paginatedDetails = [];
    @track currentGrpPage = 1;
    @track pageGrpSize = 15;
    @track visibleGrpPages = 5;

    connectedCallback() {
        this.fetchFlowDetailsById();
        // this.loadBroadcastGroups();
        console.log('flowReport = ', this.flowReport);
        console.log('Selected Flow ID:', this.selectedFlowId);
        this.updateShownData();
    }

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
    }

    get isAnyReportActive() {
        return this.isFlowSubmissionDetails || this.flowReport;
    }  

    get name() {
        return this.record?.Name || '—';
    }

    get status() {
        return this.record?.MVWB__Status__c || '—';
    }

    get recipientCount() {
        return this.record?.MVWB__Recipient_Count__c || '0';
    }

    get groupName() {
        const group = this.data?.find(item => item.Id === this.selectedSubmissionId);
        return group?.Name || '—';
    }
    
    get memberCount() {
        const group = this.data?.find(item => item.Id === this.selectedSubmissionId);
        return group?.MVWB__Count_of_Members__c?.toString() || '0';
    }    

    get totalItems() {
        return this.filteredData.length;
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

    // ------ Group Member --- 

    get showNoGroupMember() {
        return this.filteredDetails.length === 0;
    }

    get totalGrpItems() {
        return this.filteredDetails.length;
    }
    
    get totalGrpPages() {
        return Math.ceil(this.totalGrpItems / this.pageGrpSize);
    }
    
    get pageGrpNumbers() {
        try {
            const totalPages = this.totalGrpPages;
            const currentPage = this.currentGrpPage;
            const visiblePages = this.visibleGrpPages;

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
            this.showToast('Error', 'Error in pageGrpNumbers->' + error, 'error');
            return null;
        }
    }
    
    get isFirstGrpPage() {
        return this.currentGrpPage === 1;
    }
    
    get isLastGrpPage() {
        return this.currentGrpPage === Math.ceil(this.totalGrpItems / this.pageGrpSize);
    }

    fetchFlowDetailsById() {
        this.isLoading = true;
        console.log('Fetching flow details for ID:', this.selectedFlowId);
        getWhatsAppFlowById({ flowId: this.selectedFlowId })
            .then(result => {
                if (result && result.length > 0) {
                    this.flowDetails = result[0];
                    this.recordId = this.flowDetails.Id;
                }
                this.fetchFlowReportById();
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load flow details', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchFlowReportById(){
        console.log('Fetching flow report for ID:', this.recordId);
        this.isLoading = true;
        getFlowSubmissionByFlowId({ flowId: this.recordId })
            .then(result => {
                this.data = result.map((item, index) => ({
                    ...item,
                    CreatedDate: this.formatDate(item.CreatedDate),
                    index: index + 1,
                }));
                this.filteredData = [...this.data];
                this.updateShownData();
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load reports', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchSubmissionDetailsById() {
        console.log('Fetching submission details for ID:', this.selectedSubmissionId);
        this.isLoading = true;

        getFlowSubmissionById({ submissionId: this.selectedSubmissionId })
            .then(result => {
                if (result && result.length > 0) {
                    const transformed = [];
                    let rowIndex = 1; // Counter for the overall row index

                    result.forEach((item) => {
                        try {
                            const parsedJson = JSON.parse(item.MVWB__Flow_Response_Mapping__c);
                            for (const key in parsedJson) {
                                const value = parsedJson[key];

                                const parts = key.split(' - ');
                                const flowScreen = parts[0]?.trim() || '';
                                let flowField = parts[1]?.trim() || '';
                                flowField = flowField.replace(/[:\-]\s*$/, '');

                                transformed.push({
                                    flowScreen,
                                    flowField,
                                    userInput: Array.isArray(value) ? value.join(', ') : value,
                                    CreatedDate: item.CreatedDate,
                                    MVWB__Submitter_Name__c: item.MVWB__Submitter_Name__c,
                                    MVWB__Submitter_Phone__c: item.MVWB__Submitter_Phone__c,
                                    Id: item.Id,
                                    index: rowIndex++
                                });
                            }
                        } catch (parseError) {
                            console.error('Error parsing Flow_Response_Mapping__c JSON:', parseError);
                        }
                    });

                    this.flowSubmissionDetails = transformed;
                    console.log('Transformed Submission Details:', JSON.stringify(this.flowSubmissionDetails));
                }

                this.isFlowSubmissionDetails = true;
                this.flowReport = false;
                this.filteredDetails = [...this.flowSubmissionDetails];
                this.updateGroupData();
            })
            .catch((e) => {
                this.showToast('Error', 'Failed to load submission details', 'error');
                console.error(e.message, e.lineNumber, e.columnNumber);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // loadBroadcastGroups() {
    //     this.isLoading = true;
    //     getBroadcastGroupsByBroadcastId({broadcastId: this.recordId})
    //         .then(result => {
    //             this.data = result.map((item, index) => ({
    //                 ...item,
    //                 index: index + 1,
    //             }));
    //             this.selectedGroupObject = this.data.Object_Name__c;
    //             this.filteredData = [...this.data];
    //             this.updateShownData();
    //         })
    //         .catch(() => {
    //             this.showToast('Error', 'Failed to load broadcast groups', 'error');
    //         })
    //         .finally(() => {
    //             this.isLoading = false;
    //         });
    // }

    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredData.slice(startIndex, endIndex);
            console.log('Paginated Data:', JSON.stringify(this.paginatedData));
            console.log('Filtered Data:', JSON.stringify(this.filteredData));
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

    handleBack() {
        if (this.isFlowSubmissionDetails) {
            // If on isFlowSubmissionDetails, go back to flowReport
            this.isFlowSubmissionDetails = false;
            this.flowReport = true;
            this.flowSubmissionDetails = null; 
            this.paginatedDetails = []; 
        } else if (this.flowReport) {
            // If on flowReport, go back to main page
            this.flowReport = false;
            this.record = null; 
            this.paginatedData = []; 
        }
    }

    handleNameClick(event){
        this.isFlowSubmissionDetails=true;
        this.flowReport=false;
        this.selectedSubmissionId = event.target.dataset.recordId;  
        this.fetchSubmissionDetailsById();
    }

    // fetchGroupMembers() {
    //     this.isLoading = true;
    //     getBroadcastMembersByGroupId({
    //         groupId: this.selectedSubmissionId,
    //         objectName: this.selectedGroupObject
    //     })
    //     .then(result => {
    //         this.flowSubmissionDetails = result.map((item, index) => ({
    //             id: item.record.Id,
    //             name: item.record.Name || 'Not Specified',
    //             phone: item.record.Phone || item.record.MobilePhone || '',
    //             status: item.status || '',
    //             index: index + 1
    //         }));
            
    //         this.filteredDetails = [...this.flowSubmissionDetails];
    //         this.updateGroupData();
    //     })
    //     .catch(error => {
    //         console.error('Failed to load broadcast members', error);
    //     })
    //     .finally(() => {
    //         this.isLoading = false;
    //     });
    // }

    updateGroupData() {
        try {
            const startIndex = (this.currentGrpPage - 1) * this.pageGrpSize;
            const endIndex = Math.min(startIndex + this.pageGrpSize, this.totalGrpItems);
            this.paginatedDetails = this.filteredDetails.slice(startIndex, endIndex);
            console.log('Paginated Details:', JSON.stringify(this.paginatedDetails));
            
        } catch (error) {
            this.showToast('Error', 'Error updating shown data', 'error');
        }
    }

    handleGrpPrevious() {
        try{
            if (this.currentGrpPage > 1) {
                this.currentGrpPage--;
                this.updateGroupData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating to previous page', 'error');
        }
    }
    
    handleGrpNext() {
        try{
            if (this.currentGrpPage < this.totalGrpPages) {
                this.currentGrpPage++;
                this.updateGroupData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
        }
    }

    handleGrpPageChange(event) {
        try{
            const selectedPage = parseInt(event.target.getAttribute('data-id'), 10);
            if (selectedPage !== this.currentGrpPage) {
                this.currentGrpPage = selectedPage;
                this.updateGroupData();
            }
        }catch(error){
            this.showToast('Error', 'Error navigating pages', 'error');
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

    showToast(title, message, varient) {
        const toastEvent = new ShowToastEvent({title: title, message: message, variant: varient});
        this.dispatchEvent(toastEvent);
    }
}