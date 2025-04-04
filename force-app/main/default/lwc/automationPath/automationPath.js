import { LightningElement, track, api } from 'lwc';
import getAutomationById from '@salesforce/apex/AutomationConfigController.getAutomationById';
import getTemplates from "@salesforce/apex/AutomationConfigController.getTemplates";
import getEmailTemplates from "@salesforce/apex/AutomationConfigController.getEmailTemplates";
import saveAutomationPaths from '@salesforce/apex/AutomationConfigController.saveAutomationPaths';
import getAutomationPathsByAutomationId from '@salesforce/apex/AutomationConfigController.getAutomationPathsByAutomationId';
import getAllObjects from '@salesforce/apex/AutomationConfigController.getAllObjects';
import getRequiredFields from '@salesforce/apex/AutomationConfigController.getRequiredFields';
import getFlowFields from '@salesforce/apex/AutomationConfigController.getFlowFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class AutomationPath extends NavigationMixin(LightningElement) {
    @api recordId;
    @api templateType;

    @track selectedTemplateButtonId = '';
    @track selectedAction = '';
    @track searchTerm = '';
    @track selectedTemplateId = null;
    @track isFlowTemplate = false;
    @track isScheduled = false;
    @track selectedObject = '';

    // --- Data Properties ---
    @track automation = {};
    @track allWhatsAppTemplates = [];
    @track quickReplyButtons = [];
    @track automationPaths = {};
    @track allEmailTemplates = [];
    @track allObjects = [];
    @track requiredFields = [];
    // @track chatWindowRows = [];
    @track durationUnits = [
        { label: 'Minutes', value: 'minutes' },
        { label: 'Hours', value: 'hours' },
        { label: 'Days', value: 'days' }
    ];
    @track chatWindowRows = [
        {
            id: '1',
            selectedObject: 'First Name',
            objectOptions: [
                { label: 'First Name', value: 'First Name' },
                { label: 'Last Name', value: 'Last Name' },
                { label: 'Company Name', value: 'Company Name' }
            ],
            selectedNameField: 'Name',
            nameFieldOptions: [
                { label: 'Name', value: 'Name' },
                { label: 'Company', value: 'Company' }
            ],
            isNameFieldDisabled: false
        },
        {
            id: '2',
            selectedObject: 'Company Name',
            objectOptions: [
                { label: 'First Name', value: 'First Name' },
                { label: 'Last Name', value: 'Last Name' },
                { label: 'Company Name', value: 'Company Name' }
            ],
            selectedNameField: 'Name',
            nameFieldOptions: [
                { label: 'Name', value: 'Name' },
                { label: 'Company', value: 'Company' }
            ],
            isNameFieldDisabled: false
        }
    ];

    connectedCallback() {
        this.getCurrentPageReference();
    }

    getCurrentPageReference() {
        console.log('Automation Path Loaded with Record ID:', this.recordId);
        console.log('Automation Path Loaded with Template Type:', this.templateType);

        if (this.recordId) {
            this.isFlowTemplate = this.templateType === 'Flow';
            if (this.isFlowTemplate) {
                this.selectedAction = 'create';
            } else {
                this.selectedAction = 'whatsapp';
            }
            console.log('this.isFlowTemplate :::', this.isFlowTemplate);
            this.fetchAutomationName();
            this.fetchTemplates();
            this.loadEmailTemplates();
            this.fetchAutomationPaths();
            this.loadObjects();
            this.loadRequiredFields();
            // this.loadFlowFields();
        }
    }

    fetchAutomationName() {
        getAutomationById({ recordId: this.recordId })
            .then(result => {
                if (result) {
                    this.automation = {
                        id: result.Id,
                        name: result.Name,
                        description: result.Description__c,
                        templateName: result.WB_Template__r?.MVWB__Template_Name__c || 'N/A',
                        templateType: result.WB_Template__r?.MVWB__Template_Type__c || ''
                    };

                    console.log('this.automation =', JSON.stringify(this.automation));
                    if (result.WB_Template__r?.Button_Body__c) {  //Change to MVWB__Button_Body__c
                        try {
                            const buttons = JSON.parse(result.WB_Template__r.Button_Body__c);
                            console.log('BUTTONS =', buttons);
                            this.quickReplyButtons = buttons
                            .filter(button => button.type === "QUICK_REPLY")
                            .map(button => ({
                                id: button.text,
                                label: button.text
                            }));

                            this.quickReplyButtons.forEach(button => {
                                this.automationPaths[button.id] = null;
                            });
                        } catch (error) {
                            console.error("Error parsing MVWB__Button_Body__c:", error);
                        }
                    }
                    console.log('this.quickreplybuttons:', JSON.stringify(this.quickReplyButtons));
                }
            })
            .catch(error => {
                console.error('Error fetching automation:', error);
            });
    }

    fetchTemplates() {
        getTemplates()
            .then((result) => {
                if (result) {
                    console.log("Templates Result:", JSON.stringify(result));
                    this.allWhatsAppTemplates = result.map(template => ({
                        Id: template.Id,
                        Name: template.MVWB__Template_Name__c
                    }));
                }
            })
            .catch((error) => {
                console.error("Error fetching templates:", error);
            });
    }

    loadEmailTemplates() {
        getEmailTemplates()
            .then((data) => {
                this.allEmailTemplates = data;
            })
            .catch((error) => {
                console.error('Error fetching Email templates:', error);
                this.allEmailTemplates = [];
            });
    }

    fetchAutomationPaths() {
        if (!this.recordId) {
            return;
        }
    
        getAutomationPathsByAutomationId({ automationId: this.recordId })
            .then((result) => {
                console.log('Fetched Automation Paths:', JSON.stringify(result));
    
                // Convert the fetched records into a structured object
                const automationPathsMap = {};
                result.forEach(path => {
                    automationPathsMap[path.Button_Value__c] = {
                        templateId: path.Action_Template__c || path.Action_Email_Template__c || null,
                        templateType: path.Action_Type__c === "Send Message" ? "whatsapp" : "email"
                    };
                });
    
                // Ensure all quick reply buttons have an entry in automationPaths
                this.quickReplyButtons.forEach(button => {
                    if (!automationPathsMap[button.id]) {
                        automationPathsMap[button.id] = null;
                    }
                });
    
                this.automationPaths = automationPathsMap;
            })
            .catch((error) => {
                console.error('Error fetching automation paths:', error);
                this.automationPaths = {};
            });
    }


    // --- Getters for Dynamic UI ---

    get templateButtons() {
        return this.quickReplyButtons.map(btn => ({
            ...btn,
            computedClass: this.selectedTemplateButtonId === btn.id
                ? 'slds-button slds-button_outline-brand slds-button_stretch selected-button'
                : 'slds-button slds-button_outline-brand slds-button_stretch'
        }));
    }

    get isWhatsAppView() {
        return this.selectedAction === 'whatsapp';
    }
    get isCreateView() {
        return this.selectedAction === 'create';
    }
    get isEmailView() {
        return this.selectedAction === 'email';
    }

    get whatsappButtonVariant() {
        return this.selectedAction === 'whatsapp' ? 'brand' : 'neutral';
    }
    
    get emailButtonVariant() {
        return this.selectedAction === 'email' ? 'brand' : 'neutral';
    }
    
    get createButtonVariant() {
        return this.selectedAction === 'create' ? 'brand' : 'neutral';
    }

    get scheduleButtonVariant() {
        return this.isScheduled === true ? 'brand' : 'neutral';
    }

    get immediateButtonVariant() {
        return this.isScheduled === true ? 'neutral' : 'brand';
    }

    get filteredWhatsAppTemplates() {
        const lowerSearchTerm = this.searchTerm.toLowerCase();
    
        let filtered = [];

        if (this.isWhatsAppView) {
            filtered = this.allWhatsAppTemplates.filter(template =>
                template.Name.toLowerCase().includes(lowerSearchTerm)
            );
        } else if (this.isEmailView) {
            filtered = this.allEmailTemplates.filter(template =>
                template.Name.toLowerCase().includes(lowerSearchTerm)
            );
        }
        
        return filtered.map(template => ({
            ...template,
            computedClass: this.selectedTemplateId === template.Id
                ? 'slds-p-around_small slds-border_bottom list-item selected-item'
                : 'slds-p-around_small slds-border_bottom list-item'
        }));
    }

    get hasFilteredTemplates() {
        return this.filteredWhatsAppTemplates.length > 0;
    }


    // --- Event Handlers ---

    handleTemplateButtonClick(event) {
        this.selectedTemplateButtonId = event.target.dataset.id;
        console.log('Selected Template Button:', this.selectedTemplateButtonId);

        if (this.automationPaths[this.selectedTemplateButtonId]) {
            this.selectedTemplateId = this.automationPaths[this.selectedTemplateButtonId].templateId;
            this.selectedAction = this.automationPaths[this.selectedTemplateButtonId].templateType;
        } else {
            this.selectedTemplateId = '';
        }
    }

    handleActionChange(event) {
        this.selectedAction = event.target.value;
        console.log('Selected Action:', this.selectedAction);
        // Reset specific view states if needed when changing tabs
        this.searchTerm = '';
        this.selectedTemplateId = null;
    }

    handleSendOptionChange(event) {
        this.isScheduled = event.target.value === 'scheduled';
        console.log('Send Option:', this.isScheduled);
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleTemplateSelect(event) {
        this.selectedTemplateId = event.currentTarget.dataset.id;
        console.log('Selected WhatsApp Template:', this.selectedTemplateId);

        if (this.selectedTemplateButtonId && this.selectedAction) {
            this.automationPaths[this.selectedTemplateButtonId] = {
                templateId: this.selectedTemplateId,
                templateType: this.selectedAction,
            };    
        }
    
        console.log('Updated automationPaths:', JSON.stringify(this.automationPaths));
    }

    handleCancel() {
        this.selectedTemplateButtonId = '';
        this.selectedAction = '';
        this.searchTerm = '';
        this.selectedTemplateId = null;
        this.isFlowTemplate = false;
        this.automation = {};
        this.allWhatsAppTemplates = [];
        this.quickReplyButtons = [];
        this.automationPaths = {};
        this.allEmailTemplates = [];
        this.allObjects = [];
        console.log('Cancel clicked');

        this[NavigationMixin.Navigate]({
            type: "standard__navItemPage",
            attributes: {
                apiName: 'Automation_Configuration'
            },
        });
    }

    handleSave() {
        const allButtonsHaveTemplates = Object.values(this.automationPaths).every(value => value !== null);
        
        if (!allButtonsHaveTemplates) {
            console.error('Error: All buttons must have a selected template before saving.');
            alert('Please select a template for all buttons before saving.');
            return;
        }
    
        const automationPathRecords = Object.entries(this.automationPaths).map(([button, { templateId, templateType }]) => {
            let actionType = "Send Email";
            let actionTemplate = null;
            let actionEmailTemplate = null;
    
            if (templateType === "whatsapp") {
                actionType = "Send Message";
                actionTemplate = templateId;
            } else {
                actionEmailTemplate = templateId;
            }
    
            return {
                Automation__c: this.recordId,
                Button_Value__c: button,
                Action_Type__c: actionType,
                Action_Template__c: actionTemplate,
                Action_Email_Template__c: actionEmailTemplate
            };
        });
    
        console.log('Saving Automation Paths:', JSON.stringify(automationPathRecords));
    
        saveAutomationPaths({ automationPaths: automationPathRecords })
            .then((result) => {
                this.showToast('Success', `Automation Paths saved successfully.`, 'success');
            })
            .catch((error) => {
                this.showToast('Error', `Failed to save automation paths.`, 'error');
            });
    }

    handleObjectChange(event) {
        try {
            this.selectedObject = event.target.value;
            console.log('Selected Object:', this.selectedObject);
            this.loadRequiredFields(); // Load fields for the new object
        } catch (error) {
            console.error('Error in object change : ' , error);
        }
    }

    loadObjects() {
        getAllObjects()
            .then(data => {
                // this.allObjects = data.map(obj => ({ label: obj, value: obj }));
                this.objects = data.sort((a, b) => a.label.localeCompare(b.label));
                this.allObjects = data.map(obj => ({
                    label: obj.label,
                    value: obj.value
                }));
                console.log('this.allObjects:', JSON.stringify(this.allObjects));
            })
            .catch(error => console.error('Error fetching objects:', error));

        console.log('this.allObjects =', JSON.stringify(this.allObjects));
    }

    loadRequiredFields(savedFieldValues = {}) {
        try {
            this.isLoading = true;
            if (!this.selectedObject) {
                console.log('No object selected');
                return;
            }
            getRequiredFields({ objectName: this.selectedObject })
                .then(data => {
                    // this.textFields = data[0]?.textFields;

                    // this.phoneFields = data[0]?.phoneFields.map(field => {
                    //     return {
                    //         ...field,
                    //         isSelected: false
                    //     };
                    // });
                    // this.selectedPhoneFieldVal = this.phoneFields.find(field => field.value === 'Phone')?.value || this.phoneFields[0]?.value || '';
                    // const selectedField = this.phoneFields.find(field => field.value === 'Phone') || this.phoneFields[0] || null;
                    // if (selectedField) {
                    //     this.selectedPhoneFieldVal = selectedField.value;
                    //     this.selectedPhoneFieldLabel = selectedField.label;
                    //     // Update isSelected based on selectedPhoneFieldVal
                    //     this.phoneFields = this.phoneFields.map(field => {
                    //         return {
                    //             ...field,
                    //             isSelected: field.value === this.selectedPhoneFieldVal
                    //         };
                    //     });
                    // } else {
                    //     this.selectedPhoneFieldVal = '';
                    //     this.selectedPhoneFieldLabel = '';
                    // }
                    // this.phoneFieldsForChatConfig = [...this.phoneFields];

                    this.requiredFields = data[0]?.requiredFields.map(field => ({
                        apiName: field.name,
                        label: field.label,
                        type: this.capitalizeFirstLetter(field.type),
                        value: field.type === 'BOOLEAN' 
                                ? (savedFieldValues[field.name] !== undefined ? savedFieldValues[field.name] : false)
                                : field.type === 'DATE' 
                                    ? (savedFieldValues[field.name] || field.value || new Date().toISOString().split('T')[0])
                                    : field.type === 'DATETIME' 
                                        ? (savedFieldValues[field.name] || field.value || new Date().toISOString())
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
                    console.log('this.requiredFields:', JSON.stringify(this.requiredFields));
                    // this.populateReferenceNames();
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}
    // handleObjectChange(event) {
    //     this.selectedObject = event.detail.value;
    //     getObjectFields({ objectName: this.selectedObject })
    //         .then(data => {
    //             this.fields = Object.keys(data).map(field => ({
    //                 label: field,
    //                 value: field,
    //                 type: data[field]
    //             }));
    //         })
    //         .catch(error => console.error('Error fetching fields:', error));
    // }

    // loadFlowFields() {
    //     getFlowFields({ chatRecordId: this.recordId })
    //         .then(data => {
    //             this.flowFields = data.map(key => ({ label: key, value: key }));
    //         })
    //         .catch(error => console.error('Error fetching Flow fields:', error));
    // }

    // handleFieldMapping(event) {
    //     const flowField = event.target.dataset.flowfield;
    //     this.selectedFlowFields[flowField] = event.detail.value;
    // }