import { LightningElement, track, api } from 'lwc';
import getAutomationById from '@salesforce/apex/AutomationConfigController.getAutomationById';
import getTemplates from "@salesforce/apex/AutomationConfigController.getTemplates";
import getEmailTemplates from "@salesforce/apex/AutomationConfigController.getEmailTemplates";
import saveAutomationPaths from '@salesforce/apex/AutomationConfigController.saveAutomationPaths';

export default class AutomationPath extends LightningElement {
    @track automationName = 'Automation';
    @track selectedButton = '';
    @track automation = {};
    @track automationPaths = {};
    @track buttonTabs = {};
    @track templates = [];
    @track emailTemplates = [];
    @api recordId;
    
    selectedTemplateId = null;
    quickReplyButtons = [];
    // isWhatsappTemplate = true;
    isFlowTemplate = false;

    connectedCallback() {
        this.getCurrentPageReference();
    }

    getCurrentPageReference() {
        let currentPageReference = window.location.href;
        let urlParams = new URLSearchParams(currentPageReference.split('?')[1]);
        this.recordId = urlParams.get('c__recordId');

        console.log('Automation Path Loaded with Record ID:', this.recordId);

        if (this.recordId) {
            this.fetchAutomationName();
            this.fetchTemplates();
            this.loadEmailTemplates();
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
                            .map(button => button.text);

                            this.quickReplyButtons.forEach(button => {
                                this.automationPaths[button] = null;
                            });
                        } catch (error) {
                            console.error("Error parsing Button_Body__c:", error);
                        }
                    }
                    this.isFlowTemplate = this.automation.templateType.toLowerCase() === 'flow';
                    this.updateDynamicTabs();
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
                    // console.log("Templates Result:", JSON.stringify(result));
                    this.templates = result;
                    this.updateDynamicTabs();
                }
            })
            .catch((error) => {
                console.error("Error fetching templates:", error);
            });
    }

    handleButtonClick(event) {
        const buttons = this.template.querySelectorAll("li");
        
        buttons.forEach(button => button.classList.remove("active"));
        
        event.target.classList.add("active");

        this.selectedButton = event.target.dataset.name;
        console.log("Selected Button:", this.selectedButton);
    }

    handleTemplateSelection(event) {
        const selectedId = event.currentTarget.dataset.id;
        console.log('Selected Template ID:', selectedId);
    
        // Remove 'active' class from all template boxes
        this.template.querySelectorAll('.template-box').forEach(item => {
            item.classList.remove('active');
        });
    
        // Add 'active' class to the selected template
        event.currentTarget.classList.add('active');
    
        this.selectedTemplateId = selectedId;
    
        if (this.selectedButton) {
            this.automationPaths[this.selectedButton] = this.selectedTemplateId;
        }
    
        console.log('Updated automationPaths:', JSON.stringify(this.automationPaths));
    }    

    getButtonClass(button) {
        return button === this.selectedButton ? 'selected' : '';
    }

    loadEmailTemplates() {
        getEmailTemplates()
            .then((data) => {
                console.log("Email Templates Result:", JSON.stringify(data));
                this.emailTemplates = data;
                this.updateDynamicTabs();
            })
            .catch((error) => {
                console.error('Error fetching Email templates:', error);
                this.emailTemplates = [];
            });
    }

    updateDynamicTabs() {
        if (this.isFlowTemplate) {
            this.dynamicTabs = [
                { id: 'create-records', label: 'Create Records', content: 'Create Records Content', isTemplateList: false }
            ];
        } else {
            this.dynamicTabs = [
                { 
                    id: 'whatsapp-template', 
                    label: 'Send WhatsApp Template', 
                    content: this.templates.map(template => ({
                        id: template.Id, 
                        name: template.MVWB__Template_Name__c
                    })), 
                    isTemplateList: true 
                },
                { 
                    id: 'email-template', 
                    label: 'Send Email Template', 
                    content: this.emailTemplates.map(template => ({
                        id: template.Id, 
                        name: template.Name
                    })), 
                    isTemplateList: true 
                }
            ];
        }
    }    

    get hasTemplates() {
        return this.templates.length > 0 || this.emailTemplates.length > 0;
    }

    handleSave() {
        const allButtonsHaveTemplates = Object.values(this.automationPaths).every(value => value !== null);

        if (!allButtonsHaveTemplates) {
            console.error('Error: All buttons must have a selected template before saving.');
            alert('Please select a template for all buttons before saving.');
            return;
        }

        const templateMap = this.templates.reduce((map, template) => {
            map[template.Id] = template.MVWB__Template_Type__c;
            return map;
        }, {});
    
        const automationPathRecords = Object.entries(this.automationPaths).map(([button, templateId]) => {
            let actionType = "Send Email";
            let actionTemplate = null;
            let actionEmailTemplate = null;
    
            if (this.isWhatsappTemplate) {
                const templateType = templateMap[templateId] || "";
                actionType = templateType.toLowerCase() === "flow" ? "Create/Edit a Record" : "Send Message";
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
                console.log('Automation Paths Saved Successfully:', result);
                alert('Automation Paths saved successfully.');
            })
            .catch((error) => {
                console.error('Error saving Automation Paths:', error);
                alert('Error saving Automation Paths. Please try again.');
            });
    }
}