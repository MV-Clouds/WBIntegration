/**
 * Component Name: WbManageBroadcast
 * @description: Used LWC components to show Broadcast Groups that we created.
 * Date: 3/12/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 3/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : 
 * Change Description : 
 ********************************************************************** */

import { LightningElement,track,wire } from 'lwc';
import getBroadcastGroup from '@salesforce/apex/WBManageBroadcastController.getBroadcastGroup';
// import {loadStyle} from 'lightning/platformResourceLoader';
// import wbBroadcastStyle from '@salesforce/resourceUrl/wbBroadcastStyle';

export default class WbManageBroadcast extends LightningElement {

    @track filteredRecords = [];
    @track paginatedRecords = [];
    @track currentPage = 1;
    @track totalPages = 1;
    @track allRecords = [];
    @track pageNumber = 1;
    @track pageSize = 10;
    @track currentPage = 1;
    @track visiblePages = 3;
    @track isLoading=false;
    @track searchInput='';

    // renderedCallback() {
    //     loadStyle(this, wbBroadcastStyle).then(() => {
    //         console.log("Loaded Successfully")
    //     }).catch(error => {
    //         console.error("Error in loading the colors",error)
    //     })
    // }

    @wire(getBroadcastGroup)
    wiredBroadcastGroup({ error, data }) {
        try {
            if (data) {
                console.log('Fetched Data:', JSON.stringify(data)); // Debug fetched data
                this.allRecords = data.map(record => {
                    return {
                        ...record,
                        id: record.Id,
                        LastModifiedDate: this.formatDate(record.LastModifiedDate),
                    };
                });
                console.log('Mapped Records:', JSON.stringify(this.allRecords)); // Debug mapped records
                this.filterRecords(); // Ensure this method works as intended
            } else if (error) {
                console.error('Error fetching Broadcast Group: ', error);
            }
        } catch (err) {
            console.error('Unexpected error in wiredBroadcastGroup: ', err);
        }
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

    handleChange(event) {
        const fieldName = event.target.name; 
        const value = event.detail?.value || event.target.value; 
    
        switch (fieldName) {
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
    
    filterRecords() {
        try {
            this.filteredRecords = this.allRecords; 
            if (this.searchInput) {
                this.filteredRecords = this.filteredRecords.filter(record => record.Name.toLowerCase().includes(this.searchInput));
            }
            this.paginatedRecords = this.filteredRecords; 
            this.currentPage = 1;
            this.totalPages = Math.ceil(this.filteredRecords.length / this.pageSize);
            this.updateShownData();
        } catch (error) {
            console.error('Error in filterRecords:', error);
            this.showToastError('An error occurred while filtering the records.');
        } 
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

    formatDate(dateString) {
        if (!dateString) return '';
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return new Date(dateString).toLocaleDateString(undefined, options);
    }
}