import { LightningElement, track, api } from 'lwc';
import getAutomationById from '@salesforce/apex/AutomationConfigController.getAutomationById';
import getTemplates from "@salesforce/apex/AutomationConfigController.getTemplates";
import getEmailTemplates from "@salesforce/apex/AutomationConfigController.getEmailTemplates";
import saveAutomationPaths from '@salesforce/apex/AutomationConfigController.saveAutomationPaths';
import getAvailableObjects from '@salesforce/apex/AutomationConfigController.getAvailableObjects';
import getObjectFields from '@salesforce/apex/AutomationConfigController.getObjectFields';
import getFlowFields from '@salesforce/apex/AutomationConfigController.getFlowFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AutomationPath extends LightningElement {
    @api recordId;
    @api templateType;

    @track selectedTemplateButtonId = '';
    @track selectedAction = '';
    @track searchTerm = '';
    @track selectedTemplateId = null;
    @track isFlowTemplate = false;

    // --- Data Properties ---
    @track automation = {};
    @track allWhatsAppTemplates = [];
    @track quickReplyButtons = [];
    @track automationPaths = {};
    @track allEmailTemplates = [];


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
            // this.loadObjects();
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

                    if (result.WB_Template__r?.Button_Body__c) {
                        try {
                            const buttons = JSON.parse(result.WB_Template__r.Button_Body__c);
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
                            console.error("Error parsing Button_Body__c:", error);
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
    }

    handleActionChange(event) {
        this.selectedAction = event.target.value;
        console.log('Selected Action:', this.selectedAction);
        // Reset specific view states if needed when changing tabs
        this.searchTerm = '';
        this.selectedTemplateId = null;
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
                templateType: this.selectedAction
            };    
        }
    
        console.log('Updated automationPaths:', JSON.stringify(this.automationPaths));
    }

    handleCancel() {
        console.log('Cancel clicked');
        // Add navigation logic or reset form logic
        // Example reset:
        // this.selectedTemplateButtonId = 'btn1';
        // this.selectedAction = 'whatsapp';
        // this.dateValue = new Date().toISOString().slice(0, 10);
        // this.searchTerm = '';
        // this.selectValue = 'None';
        // this.selectedTemplateId = null;
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}

    // loadObjects() {
    //     getAvailableObjects()
    //         .then(data => {
    //             this.objects = data.map(obj => ({ label: obj, value: obj }));
    //         })
    //         .catch(error => console.error('Error fetching objects:', error));
    // }

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