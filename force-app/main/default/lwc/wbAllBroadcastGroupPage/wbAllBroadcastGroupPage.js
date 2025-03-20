import { LightningElement, track } from 'lwc';
import getBroadcastGroups from '@salesforce/apex/BroadcastMessageController.getBroadcastGroups';

export default class WbAllBroadcastGroupPage extends LightningElement {
    @track data = [];
    @track filteredData = [];
    @track paginatedData = [];
    @track currentPage = 1;
    @track pageSize = 10;
    @track visiblePages = 5;
    @track isLoading = false;
    @track showPopup = false;

    get showNoRecordsMessage() {
        return this.data.length === 0;
    }

    get totalItems() {
        return this.data.length;
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
            console.log('Error pageNumbers->' + error);
            return null;
        }
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }
    
    connectedCallback() {
        this.loadBroadcastGroups();
    }

    loadBroadcastGroups() {
        this.isLoading = true;
        getBroadcastGroups()
            .then(result => {
                console.log({result});
                this.data = result.map((item, index) => ({
                    ...item,
                    index : index + 1,
                }));
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
            this.paginatedData = this.data.slice(startIndex, endIndex);
            console.log(this.paginatedData);
        } catch (error) {
            console.log('Error updateShownData->' + error);
        }
    }

    handleSearch(event) {
        try {
            this.data = this.data.filter(item => 
                item.Broadcast_Group__r && 
                item.Broadcast_Group__r.Name.toLowerCase().includes(event.detail.value.toLowerCase())
            );
            this.updateShownData();
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
            console.log('handlePrevious->'+error.stack);
        }
    }
    
    handleNext() {
        try{
            if (this.currentPage < this.totalPages) {
                this.currentPage++;
                this.updateShownData();
            }
        }catch(error){
            console.log('handleNext->'+error.stack);
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
            console.log('handlePageChange->'+error.stack);
        }
    } 

    newBroadcastGroup(){
        this.showPopup = true;
    }

    closePopUp(){
        this.showPopup = false;
    }
}