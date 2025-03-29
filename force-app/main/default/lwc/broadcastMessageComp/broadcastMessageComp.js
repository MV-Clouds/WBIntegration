import { LightningElement, track, wire } from 'lwc';
import getObjectConfigs from '@salesforce/apex/BroadcastMessageController.getObjectConfigs';
import getListViewsForObject from '@salesforce/apex/BroadcastMessageController.getListViewsForObject';
import { getListUi } from 'lightning/uiListApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import processBroadcastMessageWithObject from '@salesforce/apex/BroadcastMessageController.processBroadcastMessageWithObject';
export default class BroadcastMessage extends LightningElement {
    @track objectOptions = [];
    @track listViewOptions = [];
    @track selectedObject = '';
    @track selectedListView = '';
    @track data = [];
    @track filteredData = []; // filtered data based on search
    @track paginatedData = [];
    @track currentPage = 1;
    @track pageSize = 10;
    @track visiblePages = 5;
    @track isLoading = false;
    @track configMap = {}; // store object -> {nameField, phoneField}
    @track searchTerm = '';
    @track selectedRecords = new Set(); // Track selected record IDs
    @track isCreateBroadcastModalOpen = false;
    @track templateOptions = []; // Will store the processed template options
    @track templateMap = new Map(); // Store the raw Map from Apex
    @track messageText = '';
    @track selectedTemplate = '';
    @track broadcastGroupName = '';
    @track isCreateBroadcastComp = true;
    @track isAllBroadcastPage = false;


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

    /**
     * Getter for select all checkbox state
    */
    get isAllSelected() {
        return this.paginatedData.length > 0 && 
                this.paginatedData.every(record => this.selectedRecords.has(record.Id));
    }

    /**
     * Getter for indeterminate state of select all checkbox
     */
    get isIndeterminate() {
        return this.paginatedData.some(record => this.selectedRecords.has(record.Id)) && 
                !this.isAllSelected;
    }

    get showNoRecordsMessage() {
        return this.paginatedData.length === 0;
    }

    get isSearchDisabled() {
        return !this.selectedObject || !this.selectedListView;
    }

    get isListViewDropdownDisabled() {
        return !this.selectedObject;
    }

    /**
     * Getter Name : totalItems
     * @description : set the totalItems count.
     */
    get totalItems() {
        return this.filteredData.length;
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
        this.loadAllTemplates(); // Load templates on component initialization
    }

    // Load all templates once during initialization
    loadAllTemplates() {
        this.isLoading = true;
        getTemplatesByObject()
            .then(result => {
                // Convert the Apex Map to JavaScript Map
                this.templateMap = new Map(Object.entries(result));
                this.updateTemplateOptions(); // Update options based on selected object
            })
            .catch(error => {
                console.error('Error loading templates:', error);
                this.showToast('Error', 'Failed to load templates', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
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
            this.paginatedData = this.filteredData.slice(startIndex, endIndex).map(record => ({
                ...record,
                isSelected: this.selectedRecords.has(record.Id)
            }));
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


    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        const term = this.searchTerm.trim();
        this.filteredData = this.data.filter(item => {
            const name = item.name?.toLowerCase() || '';
            const phone = item.phone?.toLowerCase() || '';
            return !term || name.includes(term) || phone.includes(term);
        });
        this.currentPage = 1;
        this.updateShownData();    
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        switch(name) {
            case 'name':
                this.broadcastGroupName = value;
                break;
            case 'template':
                this.selectedTemplate = value;
                break;
            case 'message':
                this.messageText = value;
                break;
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedListView = '';
        this.data = [];
        this.filteredData = [];
        this.paginatedData = [];
        this.currentPage = 1;
        this.selectedRecords.clear(); // Clear selections
        this.loadListViews();
        this.updateTemplateOptions(); // Update template options when object changes
    }

    updateTemplateOptions() {
        if (!this.selectedObject || this.templateMap.size === 0) {
            this.templateOptions = [];
            return;
        }

        let combinedTemplates = [];

        // Add object-specific templates
        if (this.templateMap.has(this.selectedObject)) {
            combinedTemplates = [...this.templateMap.get(this.selectedObject)];
        }

        // Add Generic templates
        if (this.templateMap.has('Generic')) {
            combinedTemplates = [...combinedTemplates, ...this.templateMap.get('Generic')];
        }

        // Convert to combobox options format
        this.templateOptions = combinedTemplates.map(template => ({
            label: template.Template_Name__c,
            value: template.Id
        }));

        console.log('templateOptions ==> ', this.templateOptions);
        console.log('templateOptions ==> ', JSON.stringify(this.templateOptions));
        
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
                phone: record.fields[fields.phoneField] ? record.fields[fields.phoneField].value : '',
                isSelected: false
            }));

            this.filteredData = [...this.data];
            this.currentPage = 1;
            this.selectedRecords.clear();
            this.updateShownData();
        } else if (error) {
            console.error('Error loading records:', error);
        }
    }
    /**
     * Handle individual record selection
     */
    handleRecordSelection(event) {
        const recordId = event.target.dataset.recordId;
        const record = this.paginatedData.find(row => row.Id === recordId);
        if (record) {
            record.isSelected = event.target.checked;
            if (record.isSelected) {
                this.selectedRecords.add(recordId);
            } else {
                this.selectedRecords.delete(recordId);
            }
            this.selectedRecords = new Set(this.selectedRecords);
        }
    }

    /**
     * Handle select all records
     */
    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.paginatedData.forEach(record => {
            record.isSelected = isChecked;
            if (isChecked) {
                this.selectedRecords.add(record.Id);
            } else {
                this.selectedRecords.delete(record.Id);
            }
        });
        this.selectedRecords = new Set(this.selectedRecords);
    }

    handleModalOpen(){

        if(this.selectedRecords.size === 0){
            this.showToast('Error', 'Please select at least one record', 'error');
            return;
        }

        // Check selectedRecords for invalid phone numbers
        if (Array.from(this.selectedRecords).some(recordId => {
            const record = this.data.find(r => r.Id === recordId);
            return !record || !record.phone || record.phone.trim() === '';
        })) {
            this.showToast('Error', 'One or more selected records have invalid or missing phone numbers', 'error');
            return;
        }


        this.isCreateBroadcastModalOpen = true;
    }

    closePopUp(){
        this.selectedTemplate = '';
        this.broadcastGroupName = '';
        this.messageText = '';
        this.isCreateBroadcastModalOpen = false;

    }

    handleSave(){
        if(this.messageText.trim() === '' || this.selectedTemplate === null || this.broadcastGroupName.trim() === ''){            
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }

        const phoneNumbers = Array.from(this.selectedRecords)
        .map(recordId => {
            const record = this.data.find(r => r.Id === recordId);
            return record ? record.phone : null;
        })
        .filter(phone => phone !== null && phone !== '');
  
                
        const messageData = {
            objectApiName: this.selectedObject,
            listViewName: this.selectedListView,
            phoneNumbers: phoneNumbers,
            description: this.messageText,
            templateId: this.selectedTemplate,
            name: this.broadcastGroupName
        };

        this.isLoading = true;

        // Call the Apex method
        processBroadcastMessageWithObject({ request: messageData })
        .then(() => {
            this.showToast('Success', 'Broadcast group created successfully', 'success');
            this.closePopUp();
            this.selectedRecords.clear();
            this.updateShownData();
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Failed to process broadcast', 'error');
        })
        .finally(() => {
            this.isLoading = false;
            this.isCreateBroadcastComp = false;
            this.isAllBroadcastPage = true;
        });;
    }

    showToast(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

}