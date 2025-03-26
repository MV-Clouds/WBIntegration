import { LightningElement, wire, track } from 'lwc';
import getAllAutomations from '@salesforce/apex/AutomationConfigController.getAllAutomations';
import getTemplates from '@salesforce/apex/AutomationConfigController.getTemplates';
import saveAutomation from '@salesforce/apex/AutomationConfigController.saveAutomation';
import updateAutomation from '@salesforce/apex/AutomationConfigController.updateAutomation';
import deleteAutomation from '@salesforce/apex/AutomationConfigController.deleteAutomation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class AutomationConfig extends LightningElement {
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
    wiredAutomationResult;

    @wire(getAllAutomations)
    wiredAutomations(result) {
        this.wiredAutomationResult = result;
        const { data, error } = result;
        if (data) {
            this.automationData = data.map((record, index) => ({
                id: record.Id,
                srNo: index + 1,
                name: record.Name,
                description: record.Description__c,
                template: record.WB_Template__r ? record.WB_Template__r.MVWB__Template_Name__c : ''
            }));
            this.isLoading = false;
            this.originalAutomationData = [...this.automationData];
        } else if (error) {
            console.error('Error fetching automation records:', error);
            this.automationData = [];
            this.isLoading = false;
        }
    }

    @wire(getTemplates)
    wiredTemplates({ error, data }) {
        if (data) {
            console.log('data:', data);
            console.log('data.length:', data.length);
            this.templateOptions = data.map(template => ({
                label: template.MVWB__Template_Name__c,
                value: template.Id
            }));
        } else if (error) {
            console.error('Error fetching templates:', error);
        }
    }

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

    handleSave() {
        if (!this.name || !this.selectedTemplateId) {
            this.showToast('Error', 'Please fill necessary fields before saving.', 'error');
            return;
        }

        if (this.isEditMode) {
            updateAutomation({ 
                recordId: this.recordId, 
                name: this.name, 
                description: this.description, 
                templateId: this.selectedTemplateId 
            })
            .then(() => {
                this.showToast('Success', 'Automation record updated successfully.', 'success');
                this.closeModal();
                return refreshApex(this.wiredAutomationResult);
            })
            .catch(error => {
                console.error('Error updating record:', error);
                this.showToast('Error', 'Failed to update automation.', 'error');
            });
        } else {
            saveAutomation({ 
                name: this.name, 
                description: this.description, 
                templateId: this.selectedTemplateId 
            })
            .then(() => {
                this.showToast('Success', 'Automation record saved successfully.', 'success');
                this.closeModal();
                return refreshApex(this.wiredAutomationResult);
            })
            .catch(error => {
                console.error('Error saving record:', error);
                this.showToast('Error', 'Failed to save automation.', 'error');
            });
        }
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Automation' : 'New Automation';
    }

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

    handleEdit(event) {
        const recordId = event.currentTarget.dataset.id;
        const selectedRecord = this.automationData.find(auto => auto.id === recordId);

        if (selectedRecord) {
            this.isEditMode = true;
            this.isModalOpen = true;
            this.recordId = recordId;
            this.name = selectedRecord.name;
            this.description = selectedRecord.description;
            console.log('selectedRecord', selectedRecord);
            console.log('selectedRecord.template', selectedRecord.template);
            this.selectedTemplateId = this.templateOptions.find(option => option.label === selectedRecord.template)?.value || '';
        }
    }

    handleDelete(event) {
        const recordId = event.currentTarget.dataset.id;
    
        if (!recordId) return;
    
        deleteAutomation({ recordId })
        .then(() => {
            this.showToast('Success', 'Automation deleted successfully.', 'success');
            return refreshApex(this.wiredAutomationResult);
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

    columns = [
        { label: 'No.', fieldName: 'id', type: 'number', initialWidth: 50 },
        { label: 'Automation Name', fieldName: 'automationName', type: 'text' },
        { label: 'Description', fieldName: 'description', type: 'text' },
        { label: 'Template', fieldName: 'template', type: 'text' },
        { label: 'Action', type: 'button-icon', initialWidth: 100, typeAttributes: { iconName: 'utility:edit', alternativeText: 'Edit', title: 'Edit', variant: 'border-filled', name: 'edit' }},
        { type: 'button-icon', initialWidth: 100, typeAttributes: { iconName: 'utility:delete', alternativeText: 'Delete', title: 'Delete', variant: 'border-filled', name: 'delete' }}
    ];
}
