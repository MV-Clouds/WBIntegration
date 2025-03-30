import { LightningElement, track } from 'lwc';
import getAllAutomations from '@salesforce/apex/AutomationConfigController.getAllAutomations';
import getTemplates from '@salesforce/apex/AutomationConfigController.getTemplates';
import saveAutomations from '@salesforce/apex/AutomationConfigController.saveAutomations';
import updateAutomations from '@salesforce/apex/AutomationConfigController.updateAutomations';
import deleteAutomations from '@salesforce/apex/AutomationConfigController.deleteAutomations';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class AutomationConfig extends NavigationMixin(LightningElement) {
    @track automationData = [];
    @track originalAutomationData = [];
    @track isLoading = true;
    @track isModalOpen = false;
    @track templateOptions = [];
    @track name = '';
    @track description = '';
    @track selectedTemplateId = '';
    @track recordId = null;

    @track isEditMode = false;
    
    connectedCallback() {
        this.fetchAutomations();
        this.fetchTemplates();
    }

    /** 
    * Method Name: fetchAutomations 
    * @description: fetches all automation records to display on the UI  
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    fetchAutomations() {
        this.isLoading = true;
        getAllAutomations()
            .then(data => {
                this.automationData = data.map((record, index) => ({
                    id: record.Id,
                    srNo: index + 1,
                    name: record.Name,
                    description: record.Description__c,
                    template: record.WB_Template__r ? record.WB_Template__r.MVWB__Template_Name__c : ''
                }));
                this.originalAutomationData = [...this.automationData];
            })
            .catch(error => {
                console.error('Error fetching automation records:', error);
                this.automationData = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /** 
    * Method Name: fetchTemplates 
    * @description: fetches all templates for picklist  
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    fetchTemplates() {
        getTemplates()
            .then(data => {
                this.templateOptions = data.map(template => ({
                    label: template.MVWB__Template_Name__c,
                    value: template.Id
                }));
            })
            .catch(error => {
                console.error('Error fetching templates:', error);
            });
    }

    /**
    * Method Name: handleChange
    * @description: Updates fields based on field change
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    handleChange(event) {
        const fieldName = event.target.label;
        if (fieldName === 'Name') {
            this.name = event.target.value;
        } else if (fieldName === 'Description') {
            this.description = event.target.value || '';
        } else if (fieldName === 'Template') {
            this.selectedTemplateId = event.target.value;
        }
    }

    /**
    * Method Name: handleSave 
    * @description: Saves automation records based on create/edit mode  
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    handleSave() {
        if (!this.name || !this.selectedTemplateId) {
            this.showToast('Error', 'Please fill necessary fields before saving.', 'error');
            return;
        }

        const automationRecord = {
            Id: this.isEditMode ? this.recordId : undefined,
            Name: this.name,
            Description__c: this.description,
            WB_Template__c: this.selectedTemplateId
        };

        const apexMethod = this.isEditMode ? updateAutomations : saveAutomations;

        apexMethod({ automations: [automationRecord] })
            .then((result) => {
                this.showToast('Success', `Automation ${this.isEditMode ? 'updated' : 'saved'} successfully.`, 'success');
                this.closeModal();
                this.fetchAutomations();
            })
            .catch(error => {
                console.error(`Error ${this.isEditMode ? 'updating' : 'saving'} record:`, error);
                this.showToast('Error', `Failed to ${this.isEditMode ? 'update' : 'save'} automation.`, 'error');
            });
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Automation' : 'New Automation';
    }

    /**
    * Method Name: handleSearch 
    * @description: Searches automation records  
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    handleSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.automationData = this.originalAutomationData.filter(auto =>
            auto.name.toLowerCase().includes(searchTerm) ||
            auto.description.toLowerCase().includes(searchTerm) ||
            auto.template.toLowerCase().includes(searchTerm)
        );
    }    

    handleNew() {
        this.isModalOpen = true;
        this.name = '';
        this.description = '';
        this.selectedTemplateId = '';
        this.isEditMode = false;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isEditMode = false;
        this.recordId = null;
        this.name = '';
        this.description = '';
        this.selectedTemplateId = '';
    }

    /**
    * Method Name: handleEdit 
    * @description: Opens edit modal for selected automation record  
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    handleEdit(event) {
        const recordId = event.currentTarget.dataset.id;
        // const selectedRecord = this.automationData.find(auto => auto.id === recordId);

        // if (selectedRecord) {
        //     this.isEditMode = true;
        //     this.isModalOpen = true;
        //     this.recordId = recordId;
        //     this.name = selectedRecord.name;
        //     this.description = selectedRecord.description;
        //     this.selectedTemplateId = this.templateOptions.find(option => option.label === selectedRecord.template)?.value || '';
        // }
        console.log('Record ID:', recordId);
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Automation_Path'
            },
            state: {
                c__recordId: recordId
            }
        });
    }

    /**
    * Method Name: handleDelete 
    * @description: Deletes selected automation record
    * Date: 27/03/2025
    * Created By: Kavya Trivedi
    */
    handleDelete(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) return;
    
        deleteAutomations({ recordIds: [recordId] })
        .then(() => {
            this.showToast('Success', 'Automation deleted successfully.', 'success');
            this.fetchAutomations();
        })
        .catch(error => {
            console.error('Error deleting record:', error);
            this.showToast('Error', 'Error deleting automation.', 'error');
        });
    }    

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}