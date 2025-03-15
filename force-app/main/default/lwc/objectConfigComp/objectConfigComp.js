import { LightningElement, track, wire } from 'lwc';
import getRequiredFields from '@salesforce/apex/ObjectConfigController.getRequiredFields';
import getUserConfig from '@salesforce/apex/ObjectConfigController.getUserConfig';
import saveUserConfig from '@salesforce/apex/ObjectConfigController.saveUserConfig';
import getObjectsWithPhoneField from '@salesforce/apex/ObjectConfigController.getObjectsWithPhoneField';
import getRecordName from '@salesforce/apex/ObjectConfigController.getRecordName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ObjectConfigComp extends LightningElement {
    @track selectedObject = 'Contact';
    @track requiredFields = [];
    @track objectOptions = [];
    @track isEditPage = false;
    @track isLoading = false;

    // Fetch saved metadata on load
    connectedCallback() {
        this.loadSavedValues();
        // this.fetchObjects();
    }

    // Load previously saved configuration
    loadSavedValues() {
        try {
            this.isLoading = true;
            getUserConfig()
                .then(data => {
                    if(data != '{}'){
                        this.isEditPage = false;
                        let parsedData = JSON.parse(data);
                        this.selectedObject = this.capitalizeFirstLetter(parsedData.objectApiName) || 'Contact';
                        
                        // Store field values in an object
                        let savedFieldValues = parsedData.requiredFieds?.reduce((acc, field) => {
                            acc[field.name] = field.value;
                            return acc;
                        }, {}) || {};
        
                        this.loadRequiredFields(savedFieldValues);
                    } else {
                        this.isEditPage = true;
                    }
                })
                .catch(error => {
                    console.error('Error fetching saved values:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                    if(this.objectOptions.length <= 0){
                        this.fetchObjects();
                    }
                });
        } catch (error) {
            console.error('Exception in loading saved values : ' , error);
        }
    }

    fetchObjects() {
        try {
            getObjectsWithPhoneField()
                .then(data => {
                    console.log({data});
                    this.objectOptions = data.map(obj => ({
                        label: obj.label,  // Show friendly name
                        value: obj.value   // API name
                    }));
                    if(this.requiredFields.length <= 0){
                        this.loadRequiredFields();
                    }
                })
                .catch(error => {
                    console.error('Error fetching objects:', error);
                });
        } catch (error) {
            console.error('Exception in fetching objects : ' , error);
        }
    }

    // Load required fields based on the selected object and prefill saved values
    loadRequiredFields(savedFieldValues = {}) {
        try {
            this.isLoading = true;
            getRequiredFields({ objectName: this.selectedObject })
                .then(data => {
                    this.requiredFields = data.map(field => ({
                        apiName: field.name,
                        label: field.label,
                        type: this.capitalizeFirstLetter(field.type),
                        value: field.type === 'BOOLEAN' 
                                ? (savedFieldValues[field.name] !== undefined ? savedFieldValues[field.name] : false)
                                : field.type === 'DATE' 
                                    ? (savedFieldValues[field.name] || field.value || today)
                                    : field.type === 'DATETIME' 
                                        ? (savedFieldValues[field.name] || field.value || now)
                                        : field.type === 'INTEGER' || field.type === 'DOUBLE' || field.type === 'CURRENCY'
                                            ? (savedFieldValues[field.name] || field.value || 0) 
                                            : (savedFieldValues[field.name] || field.value || ''),
                        picklistValues: field?.picklistValues,
                        relatedObject: field?.relatedObject,
                        relatedRecordName: field?.relatedRecordName,
                        isString: field.type === 'STRING',
                        isNumber: field.type === 'INTEGER' || field.type === 'DOUBLE' || field.type === 'CURRENCY',
                        isDate: field.type === 'DATE',
                        isDateTime: field.type === 'DATETIME',
                        isBoolean: field.type === 'BOOLEAN',
                        isPicklist: field.type === 'PICKLIST',
                        isReference: field.type === 'REFERENCE',
                        isTextArea: field.type === 'TEXTAREA'
                    }));
                    console.log(this.requiredFields);
                    this.populateReferenceNames();
                })
                .catch(error => {
                    console.error('Error fetching required fields:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Exception in loading required fields : ' , error);
        }
    }

    capitalizeFirstLetter(str) {
        if (!str) return str; // Handle null or undefined
        return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
    }

    // Handle object selection change
    handleObjectChange(event) {
        try {
            this.selectedObject = event.target.value;
            this.loadRequiredFields(); // Load fields for the new object
        } catch (error) {
            console.error('Error in object change : ' , error);
        }
    }

    populateReferenceNames() {
        try {
            const referenceFields = this.requiredFields.filter(field => 
                field.isReference && field.value && field.relatedObject
            );
    
            const namePromises = referenceFields.map(field =>
                getRecordName({ recordId: field.value, objectApiName: field.relatedObject })
                    .then(name => ({ apiName: field.apiName, name }))
                    .catch(error => {
                        console.error(`Error fetching name for ${field.apiName}:`, error);
                        return { apiName: field.apiName, name: '' }; // Default to empty on error
                    })
            );
    
            Promise.all(namePromises)
                .then(results => {
                    this.requiredFields = this.requiredFields.map(field => {
                        const result = results.find(r => r.apiName === field.apiName);
                        return result && field.isReference && !field.relatedRecordName
                            ? { ...field, relatedRecordName: result.name }
                            : field;
                    });
                })
                .catch(error => {
                    console.error('Error in Promise.all:', error);
                });
        } catch (error) {
            console.error('Exception in populating reference names:', error);
        }
    }

    // Handle input changes and update `requiredFields`
    handleInputChange(event) {
        try {
            const fieldName = event.target.dataset.field;
            const fieldIndex = this.requiredFields.findIndex(f => f.apiName === fieldName);
            if (fieldIndex !== -1) {
                this.requiredFields[fieldIndex].value = event.target.value;
            }
        } catch (error) {
            console.error('Error in input : ' , error);
        }
    }

    handleCheckboxChange(event) {
        try {
            const fieldName = event.target.dataset.field;
            const fieldIndex = this.requiredFields.findIndex(f => f.apiName === fieldName);
    
            if (fieldIndex !== -1) {
                this.requiredFields[fieldIndex].value = event.target.checked;
            }
        } catch (error) {
            console.error('Error in checkbox value change : ', error);
        }
    }

    handleRecordSelection(event){
        try {
            const fieldName = event.target.dataset.field;
            const selectedRecord = event.detail;

            if (selectedRecord?.recordId != null) {
                this.requiredFields = this.requiredFields.map(field =>
                    field.apiName === fieldName
                        ? { ...field, value: selectedRecord?.recordId }
                        : field
                );
            } else {
                this.requiredFields = this.requiredFields.map(field =>
                    field.apiName === fieldName
                        ? { ...field, value: '', relatedRecordName: '' }
                        : field
                );
            }
        } catch (error) {
            console.log('Error in record selection : ' ,  error);
        }
    }

    handleEdit(){
        this.isEditPage = true;
    }

    handleCancel(){
        this.isLoading = true;
        this.loadSavedValues();
        this.isEditPage = false;
    }

    handleSave() {
        try {
            const invalidFields = this.requiredFields.filter(field => 
                !field.isBoolean &&
                (field.isString || field.isNumber || field.isDate || field.isDateTime || field.isPicklist || field.isReference || field.isTextArea) &&
                (field.value === '' || field.value === null || field.value === undefined)
            );
    
            if (invalidFields.length > 0) {
                const fieldNames = invalidFields.map(field => field.apiName).join(', ');
                this.showToast('Error', `Please fill all required fields: ${fieldNames}`, 'error');
                return;
            }
    
            this.isLoading = true;
            const jsonData = JSON.stringify({
                objectApiName: this.selectedObject,
                requiredFieds: this.requiredFields.map(field => ({
                    name: field.apiName,
                    value: field.value
                }))
            });
    
            saveUserConfig({ jsonData })
                .then(response => {
                    if(response == 'sucess'){
                        this.showToast('Success', 'Configuration saved successfully', 'success');
                        this.populateReferenceNames();
                        this.isEditPage = false;
                    } else {
                        this.showToast('Error', response, 'error');
                    }
                })
                .catch(error => {
                    console.error('Error saving config:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Exception in saving configuration: ', error);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({title, message, variant}));
    }
}