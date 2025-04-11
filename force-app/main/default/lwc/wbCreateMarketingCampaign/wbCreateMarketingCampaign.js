// import { LightningElement, track } from 'lwc';
import getTemplatesByObject from '@salesforce/apex/BroadcastMessageController.getTemplatesByObject';
import { LightningElement, wire, track } from 'lwc';
import getDateFieldsForPicklist from '@salesforce/apex/BroadcastMessageController.getDateFieldsForPicklist';
import { NavigationMixin,CurrentPageReference } from 'lightning/navigation';
import createMarketingCampaign from '@salesforce/apex/MarketingMessageController.createMarketingCampaign';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WbCreateMarketingCampaign extends NavigationMixin(LightningElement) {
    @track broadcastGroupList = ['Group1', 'Group2', 'Group3'];
    @track templateOptions = []; // Will store the processed template options
    @track templateMap = new Map(); // Store the raw Map from Apex
    
    selectedObjectName = '';
    selectedOption = 'specific';
    
    isLoading = false;
    campaignName = '';
    campaignDescription = '';
    campaignObject = '';
    isMarketingCampaign = false;
    campaignStartDate = '';
    campaignEndDate = '';
    createBrodcastPopup = false;

    // dateFieldOptions = [
    //     { label: 'Birthday', value: 'birthday' },
    //     { label: 'Anniversary', value: 'anniversary' },
    //     { label: 'Signup Date', value: 'signup' }
    // ];

    @track dateFieldOptions =[];

    @track groupNames = [];
    @track selectedTemplate = '';
    @track groupId = [];

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (currentPageReference && currentPageReference.state.c__navigationState) {
            try {
                const navigationStateString = currentPageReference.state.c__navigationState;
                const navigationState = JSON.parse(atob(navigationStateString)); // Decode the Base64 string

                // Retrieve the passed data
                this.selectedObjectName = navigationState.objectName;
                this.broadcastGroupList = navigationState.groupNames;
                this.groupId = navigationState.groupId;
                // console.log('Selected Template:', this.selectedTemplate);
                console.log('Broadcast Group List:', this.broadcastGroupList);
                this.loadAllTemplates();
                this.fetchDateFields();
            } catch (error) {
                console.error('Error decoding navigation state:', error);
            }
        }
    }
    get isSpecific() {
        return this.selectedOption === 'specific';
    }

    get isRelated() {
        return this.selectedOption === 'related';
    }

    get comboClass() {
        return this.showError ? 'slds-has-error' : '';
    }

    handleOptionChange(event) {
        this.selectedOption = event.target.value;

        // Reset errors and values when switching options
        if (this.selectedOption === 'specific') {
            this.relatedError = '';
            this.selectedDateField = '';
        } else if (this.selectedOption === 'related') {
            this.specificError = '';
            this.selectedDate = '';
        }
    }

    @track specificError = ''; // Error for the "specific" option
    @track relatedError = '';  // Error for the "related" option

    fetchDateFields() {
        getDateFieldsForPicklist({ objectApiName: this.selectedObjectName })
            .then((result) => {
                if (result) {
                    this.dateFieldOptions = result.map((field) => ({
                        label: field.label,
                        value: field.value,
                    }));
                    console.log('Date Fields:', this.dateFieldOptions);
                } else {
                    this.dateFieldOptions = [];
                    console.warn('No date fields found for the object:', this.selectedObjectName);
                }
            })
            .catch((error) => {
                this.error = error;
                console.error('Error fetching date fields:', error);
            });
    }

    handleSelectChange(event) {
        const selectedDateField = event.detail.value;
        if (this.selectedOption === 'related') {
            if (!selectedDateField) {
                // Show error if no date field is selected
                this.relatedError = 'Please select a date field.';
                this.showError = true; // Keep the global error flag
            } else {
                this.selectedDateField = selectedDateField;
                this.relatedError = ''; // Clear the related error
                this.showError = false; // Clear the global error flag
            }
        }
    }

    loadAllTemplates() {
            this.isLoading = true;
            getTemplatesByObject()
                .then(result => {
                    // Convert the Apex Map to JavaScript Map
                    console.log('REsult :::: ',result);
                    
                    this.templateMap = new Map(Object.entries(result));
                    console.log('Template Map :::: ',this.templateMap);
                    this.updateTemplateOptions(); // Update options based on selected object
                    
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load templates', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }

        
        @track emailConfigs = [
            { id: 1, template: '', daysAfter: 0, timeToSend: '' }
        ];
        @track error = '';
        nextId = 2;
    
        // get templateOptions() {
        //     return [
        //         { label: 'Welcome Email', value: 'welcome' },
        //         { label: 'Reminder Email', value: 'reminder' },
        //         { label: 'Follow-up Email', value: 'followup' }
        //     ];
        // }
    
        addRow() {
            if (this.hasDuplicates()) {
                this.error = 'Duplicate template with same send time and date is not allowed.';
                return;
            }
            this.error = '';
            this.emailConfigs = [
                ...this.emailConfigs,
                { id: this.nextId++, template: '', daysAfter: 0, timeToSend: '' }
            ];
        }
    
        handleDelete(event) {
            const index = parseInt(event.target.dataset.index, 10);
            this.emailConfigs.splice(index, 1);
            this.emailConfigs = [...this.emailConfigs];
        }
    
        handleComboboxChange(event) {
            const index = parseInt(event.target.dataset.index, 10);
            this.emailConfigs[index].template = event.detail.value;
            this.validateDuplicates();
        }
    
        handleInputChange(event) {
            const index = parseInt(event.target.dataset.index, 10);
            const field = event.target.dataset.field;
            this.emailConfigs[index][field] = event.detail.value;
            this.validateDuplicates();
        }
    
        validateDuplicates() {
            const seen = new Set();
            for (let row of this.emailConfigs) {
                if (!row.template || !row.timeToSend || row.daysAfter === '') continue;
                const key = `${row.template}-${row.daysAfter}-${row.timeToSend}`;
                if (seen.has(key)) {
                    this.error = 'Duplicate template with the same send time and date is not allowed.';
                    return;
                }
                seen.add(key);
            }
            this.error = ''; // Clear the error when no duplicates are found
        }
    
        hasDuplicates() {
            const seen = new Set();
            for (let row of this.emailConfigs) {
                if (!row.template || !row.timeToSend || row.daysAfter === '') continue;
                const key = `${row.template}-${row.daysAfter}-${row.timeToSend}`;
                if (seen.has(key)) return true;
                seen.add(key);
            }
            return false;
        }

        
    
        updateTemplateOptions() {
            if (!this.selectedObjectName || this.templateMap.size === 0) {
                this.templateOptions = [];
                
                return;
            }
            console.log(this.selectedObjectName);
    
            let combinedTemplates = [];
    
            // Add object-specific templates
            if (this.templateMap.has(this.selectedObjectName)) {
                combinedTemplates = [...this.templateMap.get(this.selectedObjectName)];
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
    
            
        }

    @track selectedDate = '';
    @track minDate = this.getTodayDate(); // Set the minimum date to today

    // connectedCallback() {
    //     // this.minDate = this.getTodayDate();       
    //     // this.loadAllTemplates(); // Load templates on component initialization

    // }

    // Get today's date in YYYY-MM-DD format
    getTodayDate() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    // Handle date change
    handleDateChange(event) {
        const selectedDate = event.target.value;
        console.log("Selected Date ::: ", selectedDate);

        if (this.selectedOption === 'specific') {
            if (!selectedDate) {
                // Handle empty or invalid date
                this.specificError = 'Please select a date.';
                this.showError = false; // Keep the global error flag
            } else if (new Date(selectedDate) <= new Date()) {
                // Show error if the selected date is not after today
                this.specificError = 'Selected date must be after today.';
                this.showError = false; // Keep the global error flag
            } else {
                // Valid date
                this.selectedDate = selectedDate;
                this.specificError = ''; // Clear the specific error
                this.showError = false; // Clear the global error flag
            }
        }
    }

    // Handle input change for time and validate duplicates
    handleInputChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        const value = event.target.value;

        // Update the emailConfigs array
        this.emailConfigs[index][field] = value;

        // Validate for duplicate time and date
        if (field === 'timeToSend' || field === 'daysAfter') {
            this.validateDuplicateSchedules();
        }
    }
    handleInputChangeModal(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.value;

        if (fieldName === 'campaignName') {
            this.campaignName = fieldValue;
        } else if (fieldName === 'campaignDescription') {
            this.campaignDescription = fieldValue;
        }
    }


    handleComboboxChange(event) {
        const index = parseInt(event.target.dataset.index, 10); // Get the index from data-index
        this.emailConfigs[index].template = event.detail.value; // Update the template value
        console.log('Updated emailConfigs:', this.emailConfigs); // Debug log
        this.validateDuplicates(); // Validate for duplicates
    }

    // Validate that no two templates have the same time and date
    validateDuplicateSchedules() {
        // Clear previous errors
        this.emailConfigs = this.emailConfigs.map(config => ({
            ...config,
            errorDaysAfter: '',
            errorTimeToSend: ''
        }));

        const scheduleSet = new Set();
        let hasError = false;

        for (const config of this.emailConfigs) {
            const scheduleKey = `${config.daysAfter}-${config.timeToSend}`;
            if (scheduleSet.has(scheduleKey)) {
                // Set specific errors for duplicate fields
                config.errorDaysAfter = 'Duplicate schedule detected.';
                config.errorTimeToSend = 'Duplicate schedule detected.';
                hasError = true;
            } else {
                scheduleSet.add(scheduleKey);
            }
        }

        if (!hasError) {
            this.error = ''; // Clear global error if no duplicates
        }

        // Trigger reactivity
        this.emailConfigs = [...this.emailConfigs];
    }

    // Show error message (you can customize this to display in the UI)
    showError(message) {
        console.error(message);
        // Optionally, set an error property to display the message in the UI
        this.error = message;
    }

    validateForm() {
        if (this.selectedOption === 'specific') {
            if (!this.selectedDate || new Date(this.selectedDate) <= new Date()) {
                this.specificError = 'Selected date must be after today.';
                return false;
            }
        } else if (this.selectedOption === 'related') {
            if (!this.selectedDateField) {
                this.relatedError = 'Please select a date field.';
                return false;
            }
        }
        this.specificError = '';
        this.relatedError = '';
        return true;
    }

    get showSpecificError() {
        return this.error && this.selectedOption === 'specific';
    }

    get showRelatedError() {
        return this.error && this.selectedOption === 'related';
    }

    validateInputs() {
        if (this.selectedOption === 'specific') {
            if (!this.selectedDate || new Date(this.selectedDate) <= new Date()) {
                this.specificError = 'Please select a valid date.';
                return false;
            } else {
                this.specificError = ''; // Clear error if valid
            }
        } else if (this.selectedOption === 'related') {
            if (!this.selectedDateField) {
                this.relatedError = 'Please select a date field.';
                return false;
            } else {
                this.relatedError = ''; // Clear error if valid
            }
        }
        return true; // Return true if all validations pass
    }

    // handleSubmit() {
    //     if (this.validateInputs()) {
    //         // Proceed with form submission
    //         console.log('Form submitted successfully!');
    //     } else {
    //         console.log('Validation failed.');
    //     }
    // }
    handlePrevclick(event){
        event.preventDefault();
        this.templateMap = [];
        this.templateOptions = [];
            // Encode the data as query parameters
            // const navigationState = {
            //     groupNames: names,
            //     objectName : this.selectedObjectName
            // };
            // const encodedNavigationState = btoa(JSON.stringify(navigationState));

            // Navigate to the wbCreateMarketingCampaign component
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Broadcast' // Replace with the API name of your Lightning Tab
                }
            });
    }

    handleOpenModal() {
        this.createBrodcastPopup = true;
    }

    handleCloseModal() {
        this.createBrodcastPopup = false;
    }

    get isSubmitDisabled() {
        // Check if any required field in emailConfigs is empty
        const hasEmptyFields = this.emailConfigs.some(config => {
            return !config.template || !config.timeToSend || config.daysAfter === '';
        });

        // Check if specific or related option validations fail
        if (this.selectedOption === 'specific') {
            return hasEmptyFields || !this.selectedDate || new Date(this.selectedDate) <= new Date();
        } else if (this.selectedOption === 'related') {
            return hasEmptyFields || !this.selectedDateField;
        }

        return hasEmptyFields;
    }

      // Handle checkbox change
      handleCheckboxChange(event) {
        this.isMarketingCampaign = event.target.checked;
    }


    createCampaign() {

        console.log('In createCampaign');
        
        const campaignData = {
            name: this.campaignName,
            description: this.campaignDescription,
            objectName: this.selectedObjectName,
            isMarketingCampaign: this.isMarketingCampaign,
            selectedOption: this.selectedOption,
            selectedDate: this.selectedDate,
            selectedDateFields: this.selectedDateField,
            emailConfigs: this.emailConfigs,
            groupIdList : this.groupId
        };
    
        console.log('Campaign Data:', JSON.stringify(campaignData));
        
        createMarketingCampaign({ campaignData: JSON.stringify(campaignData) })
            .then((campaignId) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `Marketing Campaign created successfully!`,
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}