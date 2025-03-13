import { LightningElement, track, wire } from 'lwc';
import getRequiredFields from '@salesforce/apex/ObjectConfigController.getRequiredFields';
import getUserConfig from '@salesforce/apex/ObjectConfigController.getUserConfig';
import saveUserConfig from '@salesforce/apex/ObjectConfigController.saveUserConfig';

export default class ObjectConfigComp extends LightningElement {
    @track selectedObject = 'Contact'; // Default object
    @track requiredFields = [];
    @track objectOptions = [
        { label: 'Lead', value: 'Lead' },
        { label: 'Opportunity', value: 'Opportunity' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Account', value: 'Account' }
    ]

    // Fetch saved metadata on load
    connectedCallback() {
        this.loadSavedValues();
    }

    // Load previously saved configuration
    loadSavedValues() {
        getUserConfig()
            .then(data => {
                let parsedData = JSON.parse(data);
                this.selectedObject = parsedData.objectApiName || 'Contact';
                
                // Store field values in an object
                let savedFieldValues = parsedData.requiredFieds?.reduce((acc, field) => {
                    acc[field.name] = field.value;
                    return acc;
                }, {}) || {};

                this.loadRequiredFields(savedFieldValues);
            })
            .catch(error => console.error('Error fetching saved values:', error));
    }

    // Load required fields based on the selected object and prefill saved values
    loadRequiredFields(savedFieldValues = {}) {
        getRequiredFields({ objectName: this.selectedObject })
            .then(data => {
                this.requiredFields = data.map(field => ({
                    apiName: field.name,
                    label: field.label,
                    type: field.type,
                    value: savedFieldValues[field.name] || field.value || '',

                    // Add type-specific attributes
                    isString: field.type === 'STRING',
                    isNumber: field.type === 'INTEGER' || field.type === 'DOUBLE' || field.type === 'CURRENCY',
                    isDate: field.type === 'DATE' || field.type === 'DATETIME',
                    isBoolean: field.type === 'BOOLEAN',
                    isPicklist: field.type === 'PICKLIST',
                    isTextArea: field.type === 'TEXTAREA'
                }));
            })
            .catch(error => console.error('Error fetching required fields:', error));
    }

    // Handle input changes and update `requiredFields`
    handleInputChange(event) {
        const fieldName = event.target.dataset.field;
        const fieldIndex = this.requiredFields.findIndex(f => f.apiName === fieldName);
        if (fieldIndex !== -1) {
            this.requiredFields[fieldIndex].value = event.target.value;
        }
    }

    // Save the configuration
    handleSave() {
        const jsonData = JSON.stringify({
            objectApiName: this.selectedObject,
            requiredFieds: this.requiredFields.map(field => ({
                name: field.apiName,
                value: field.value
            }))
        });

        saveUserConfig({ jsonData })
            .then(response => {
                alert(response === 'Success' ? 'Configuration saved successfully' : response);
            })
            .catch(error => console.error('Error saving config:', error));
    }

    // Handle object selection change
    handleObjectChange(event) {
        this.selectedObject = event.target.value;
        this.loadRequiredFields(); // Load fields for the new object
    }
}