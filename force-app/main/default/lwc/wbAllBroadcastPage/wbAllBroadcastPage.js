import { LightningElement, track } from 'lwc';
import getBroadcastRecs from '@salesforce/apex/BroadcastMessageController.getBroadcastRecs';
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastGroups';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class WbAllBroadcastPage extends LightningElement {
    @track data = [];
    @track paginatedData = [];
    @track filteredData = [];
    @track broadcastGroups = [];
    @track filteredGroups = [];
    @track selectedGroupIds = [];
    currentPage = 1;
    pageSize = 10;
    visiblePages = 5;
    isLoading = false;
    showPopup = false;
    selectedObjectName = '';
    isPopupLoading = false;
    popUpFirstPage = true;
    popupHeader = 'Choose Broadcast Groups';
    isCreateBroadcast = false;
    isAllBroadcastPage = true;

    get showNoRecordsMessage() {
        return this.filteredData.length === 0;
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
            console.error('Error pageNumbers->' + error);
            return null;
        }
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }

    get isNextDisabled() {
        return this.selectedGroupIds.length === 0;
    }
    
    connectedCallback() {
        this.loadBroadcastGroups();
    }

    loadBroadcastGroups() {
        this.isLoading = true;
        getBroadcastRecs()
            .then(result => {
                console.log({result});
                this.data = result.map((item, index) => ({
                    ...item,
                    index : index + 1,
                }));

                this.filteredData = [...this.data];
                this.updateShownData();
            })
            .catch(error => {
                console.error('Error loading records:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.filteredData.slice(startIndex, endIndex);
            console.log(this.paginatedData);
        } catch (error) {
            console.error('Error updateShownData->' + error);
        }
    }

    handleSearch(event) {
        try {
            if(event.detail.value.trim().toLowerCase() != null) {
                this.filteredData = this.data.filter(item => 
                    item.Broadcast_Group__r && 
                    item.Broadcast_Group__r.Name.toLowerCase().includes(event.detail.value.trim().toLowerCase())
                );
                this.updateShownData();
            }
        } catch (error) {
            console.error('Error in search: ' + error.stack);
        }
    }
    
    handlePrevious() {
        try{
            if (this.currentPage > 1) {
                this.currentPage--;
                this.updateShownData();
            }
        }catch(error){
            console.error('handlePrevious->'+error.stack);
        }
    }
    
    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            console.error('handleNext->'+error.stack);
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
            console.error('handlePageChange->'+error.stack);
        }
    } 

    handleCreateNewGroup(){
        this.isCreateBroadcast = true;
        this.isAllBroadcastPage = false;
    }

    newBroadcast(){
        this.showPopup = true;
        this.isPopupLoading = true;

        getBroadcastGroups()
            .then(result => {
                console.log({result});
                this.broadcastGroups = result;
                this.filteredGroups = [...this.broadcastGroups];
            })
            .catch(error => {
                console.error('Error loading records:', error);
            })
            .finally(() => {
                this.isPopupLoading = false;
            });
    }

    handleSearchPopup(event) {
        this.filteredGroups = this.broadcastGroups.filter(group =>
            group.Name.toLowerCase().includes(event.target.value.trim().toLowerCase())
        );
    }

    // Handle group selection
    handleGroupSelection(event) {
        try {
            const groupId = event.target.dataset.id;
            const selectedGroup = this.broadcastGroups.find(group => group.Id === groupId);
            if (event.target.checked) {
                // Add group ID to selected list if checked
                if (!this.selectedGroupIds.some(group => group.Id === groupId)) {
                    this.selectedGroupIds = [
                        ...this.selectedGroupIds,
                        { Id: groupId, ObjName: selectedGroup.Object_Name__c } // Store both Id and Name
                    ];
                    this.selectedObjectName = this.selectedGroupIds[0].ObjName;
                }
            } else {
                // Remove group ID if unchecked
                this.selectedGroupIds = this.selectedGroupIds.filter(group => group.Id !== groupId);
            }
        } catch (error) {
            console.error('Erorr in selection : ', error);
        }
    }

    handleNextOnPopup() {
        try {
            const firstObjName = this.selectedGroupIds[0]?.ObjName;
            const allSameObjName = this.selectedGroupIds.every(group => group.ObjName === firstObjName);
            
            if(!allSameObjName){
                this.showToast('Error!', 'Please select groups with the same object name', 'error');
                return;
            }
    
            this.popupHeader = 'Choose Template'
            this.popUpFirstPage = false;
        } catch (error) {
            console.error('Error in next click: ' + error);
        }
    }

    handleCloseOnPopup(){
        this.showPopup = false;
    }

    handlePreviousOnPopup(){
        this.popupHeader = 'Choose Broadcast Groups';
        this.popUpFirstPage = true;
    }

    handleSendOnPopup(){
        this.isPopupLoading = true;
    }

    showToast(title ,message, status){
        this.dispatchEvent(new ShowToastEvent({title: title, message: message, variant: status}));
    }
}