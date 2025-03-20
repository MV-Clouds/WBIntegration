import { LightningElement, track, wire } from 'lwc';
import getObjectConfigs from '@salesforce/apex/BroadcastMessageController.getObjectConfigs';
import getListViewsForObject from '@salesforce/apex/BroadcastMessageController.getListViewsForObject';
import { getListUi } from 'lightning/uiListApi';

export default class BroadcastMessage extends LightningElement {
    @track objectOptions = [];
    @track listViewOptions = [];
    @track selectedObject = '';
    @track selectedListView = '';
    @track data = [];
    @track paginatedData = [];
    @track currentPage = 1;
    @track pageSize = 10;
    @track visiblePages = 5;
    @track isLoading = false;
    @track configMap = {}; // store object -> {nameField, phoneField}


    get dynamicFieldNames() {
        if (!this.selectedObject || !this.configMap[this.selectedObject]) {
            return [];
        }
        const fields = this.configMap[this.selectedObject];
        return [
            `${this.selectedObject}.${fields.nameField}`,
            `${this.selectedObject}.${fields.phoneField}`
        ];
    }

    get showNoRecordsMessage() {
        return this.data.length === 0;
    }

    get isListViewDropdownDisabled() {
        return !this.selectedObject;
    }

    /**
     * Getter Name : totalItems
     * @description : set the totalItems count.
     */
    get totalItems() {
        return this.data.length;
    }

    /**
    * Getter Name : totalPages
    * @description : set the totalpages count.
    */
    get totalPages() {
        return Math.ceil(this.totalItems / this.pageSize);
    }

    /**
    * Getter Name : pageNumbers
    * @description : set the list for page number in pagination.
    */
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

        /**
    * Getter Name : isFirstPage
    * @description : check the current page is first.
    */
    get isFirstPage() {
        return this.currentPage === 1;
    }

    /**
    * Getter Name : isLastPage
    * @description : check the current page is last.
    */
    get isLastPage() {
        return this.currentPage === Math.ceil(this.totalItems / this.pageSize);
    }
    
    
    connectedCallback() {
        this.loadConfigs();
    }

    loadConfigs() {
        this.isLoading = true;
        getObjectConfigs()
            .then(result => {
                this.objectOptions = result.objectOptions;
                this.configMap = result.configMap;
            })
            .catch(error => {
                console.error('Error loading configs:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
    * Method Name : updateShownData
    * @description : update the shownProcessedLisitingData when pagination is applied.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
    updateShownData() {
        try {
            const startIndex = (this.currentPage - 1) * this.pageSize;
            const endIndex = Math.min(startIndex + this.pageSize, this.totalItems);
            this.paginatedData = this.data.slice(startIndex, endIndex);
            
        } catch (error) {
            console.log('Error updateShownData->' + error);
        }
    }

    /**
    * Method Name : handlePrevious
    * @description : handle the previous button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
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

    /**
    * Method Name : handleNext
    * @description : handle the next button click in the pagination.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
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

        /**
    * Method Name : handlePageChange
    * @description : handle the direct click on page number.
    * date: 20/08/2024
    * Created By:Vyom Soni
    */
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


    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedListView = '';
        this.data = [];
        this.currentPage = 1;
        this.paginatedData = [];
        this.loadListViews();
    }

    loadListViews() {
        this.isLoading = true;
        getListViewsForObject({ objectApiName: this.selectedObject })
            .then(result => {
                this.listViewOptions = result.map(lv => ({
                    label: lv.Name,
                    value: lv.Id
                }));
            })
            .catch(error => {
                console.error('Error loading list views:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleListViewChange(event) {
        this.selectedListView = event.detail.value;
    }

    @wire(getListUi, {
        objectApiName: '$selectedObject',
        listViewId: '$selectedListView',
        fields: '$dynamicFieldNames'
    })
    wiredListView({ error, data }) {
        if (!this.selectedObject || !this.selectedListView) {
            return;
        }
    
        if (data) {
            const fields = this.configMap[this.selectedObject];
            this.data = data.records.records.map((record, index) => ({
                index : index + 1,
                Id: record.id,
                name: record.fields[fields.nameField] ? record.fields[fields.nameField].value : '',
                phone: record.fields[fields.phoneField] ? record.fields[fields.phoneField].value : ''
            }));

            this.updateShownData();
        } else if (error) {
            console.error('Error loading records:', error);
        }
    }
    
}