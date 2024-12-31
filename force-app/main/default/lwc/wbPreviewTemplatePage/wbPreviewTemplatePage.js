/**
 * Component Name: WbPreviewTemplatePage
 * @description: Used LWC components to preview the created template in meta.
 * Date: 27/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 23/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : Beta 10
 * Change Description :Beta 10 bug resolved
 ********************************************************************** */

import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecordsBySObject from '@salesforce/apex/WBTemplateController.getRecordsBySObject'; 
import sendPreviewTemplate from '@salesforce/apex/WBTemplateController.sendPreviewTemplate';  
import getDynamicObjectData from '@salesforce/apex/WBTemplateController.getDynamicObjectData';
import fetchDynamicRecordData from '@salesforce/apex/WBTemplateController.fetchDynamicRecordData';
import getTemplateDataWithReplacement from '@salesforce/apex/WBTemplateController.getTemplateDataWithReplacement';
import CountryJson from '@salesforce/resourceUrl/CountryJson';

export default class WbPreviewTemplatePage extends LightningElement {
    @track ispreviewTemplate=true;
    @track filepreview;
    @track originalHeader;
    @track originalBody;
    @track template;
    @track tempHeader;
    @track tempBody;
    @track tempFooter;
    @track headerParams;
    @track bodyParams;
    @track buttonList=[];
    @track formatedTempBody;
    @track phoneNumber='';
    @track objectNames = []; 
    @track fieldNames = [];
    @track isImgSelected = false;
    @track IsHeaderText = true;
    @track options = [
        { label: 'Contact', value: 'Contact', isSelected: true }
    ];
    @track contactDetails=[];
    @track inputValues = {};
    @track groupedVariables=[];
    @track noContact=true;
    @track selectedCountryType = '+91';  
    @track countryType=[];
    @track filteredTableData = []; 
    @track variableMapping = { header: {}, body: {} };
    @track isFieldDisabled=false;
    @track isSendDisabled=false;
    @track sendButtonClass;

    get contactFields() {
        return Object.entries(this.contactDetails)
            .filter(([key, value]) => value !== null && value !== undefined)
            .map(([key, value]) => ({ label: key, value }));
    }

    get isDisabled(){
        return !(this.objectNames && this.fieldNames);
    }

    formatText(inputText) {
        try {
            let formattedText = inputText.replaceAll('\n', '<br/>');
            formattedText = formattedText.replace(/\*(.*?)\*/g, '<b>$1</b>');
            formattedText = formattedText.replace(/_(.*?)_/g, '<i>$1</i>');
            formattedText = formattedText.replace(/~(.*?)~/g, '<s>$1</s>');
            formattedText = formattedText.replace(/```(.*?)```/g, '<code>$1</code>');
            return formattedText;
        } catch (error) {
            console.error('Something went wrong in formatting text.',error);  
        }
    }

    @api
    get templateid() {
        return this._templateid;
    }

    set templateid(value) {
        console.log('Template ID set:', value);
        this._templateid = value;
        if (this._templateid) {
            this.fetchTemplateData();
        }
    }

    get contactIcon() {
        return this.selectedContactId ? 'standard:contact' : ''; 
    }

    connectedCallback() {
        this.fetchCountries();
        this.fetchReplaceVariableTemplate(this.templateid,null);
    }

    getIconName(btntype) {
        switch (btntype) {
            case 'QUICK_REPLY':
                return 'utility:reply';
            case 'PHONE_NUMBER':
                return 'utility:call';
            case 'URL':
                return 'utility:new_window';
            case 'COPY_CODE':
            return 'utility:copy';
            default:
                return 'utility:question'; 
        }
    }

    handleCountryChange(event){
        this.selectedCountryType = event.target.value;
        console.log(this.selectedCountryType);
    }

    handleRecordSelection(event) {
        try {
            event.stopPropagation();        
            const selectedRecord = event.detail.selectedRecord || {};
            const selectedId = selectedRecord.Id || null;
            console.log('selectedId', selectedId);

            if(!selectedId){
                console.log('enter to if');
                
                this.tempHeader = this.originalHeader;
                this.tempBody = this.originalBody;
                this.formatedTempBody = this.formatText(this.tempBody);
                console.log('this.tempBody ',this.tempBody);
                console.log('this.formatedTempBody ',this.formatedTempBody);
                
                this.groupedVariables = this.groupedVariables.map(group => {
                    return {
                        ...group,
                        mappings: group.mappings.map(mapping => {
                            return {
                                ...mapping,
                                value: '' 
                            };
                        })
                    };
                });
                this.variableMapping = {
                    header: {},
                    body: {}
                };
                this.isFieldDisabled=false;
                console.log('Reset to original template');
                return;
            }else{
                this.isFieldDisabled=true;
            }
           
            const hasVariables = this.tempBody.includes('{{') || this.tempHeader.includes('{{');

            if (!hasVariables) {
                console.warn('No variables found in the template. Please check the template structure.');
                this.showToast('Warning!', 'No variables found in the template to replace.', 'warning');
                return; 
            }

            this.selectedContactId = selectedId;

            console.log('Selected Record ID:', this.selectedContactId);    
            this.fetchContactData();
        
        } catch (err) {
            console.error('Unexpected error in handleRecordSelection:', err);
        }
    }

    fetchCountries() {
        try{
            fetch(CountryJson)
            .then((response) => response.json())
            .then((data) => {
                this.countryType = data.map(country => {
                    return { label: `(${country.callingCode})`, value: country.callingCode,isSelected: country.callingCode === this.selectedCountryType };
                });
            })
            .catch((e) => console.log('Error fetching country data:', e));
        }catch(e){
            console.error('Something wrong while fetching country data:', e);
        }
    }

    fetchContactData() {
        try {
            fetchDynamicRecordData({
                objectName: this.objectNames[0], 
                fieldNames: this.fieldNames, 
                recordId: this.selectedContactId
            })
            .then(result => {
                console.log('fetched result ',result);
                
                if (result.queriedData) {
                    this.contactDetails = result.queriedData;
                   console.log('contactDetails ',this.contactDetails);
                   
                    this.groupedVariables = this.groupedVariables.map(group => {
                        return {
                            ...group,
                            mappings: group.mappings.map(mapping => {
                                const variableName = mapping.variable;
                                const value = this.contactDetails[mapping.fieldName] || mapping.alternateText || '';
                                if (group.type === 'Header') {
                                    this.variableMapping.header[variableName] = value;  
                                } else if (group.type === 'Body') {
                                    this.variableMapping.body[variableName] = value;  
                                }                                
                                return {
                                    ...mapping,
                                    value
                                };
                            })
                        };
                    });
                    this.updateTemplates();
                    this.fetchReplaceVariableTemplate(this.templateid,this.selectedContactId);
                    
                } else {
                    console.warn('No data found for the provided record ID.');
                }
            })
            .catch(error => {
                console.error('Error fetching dynamic data:', error);
            });
        } catch (error) {
            console.error('Something wrong in fetching dynamic data:', error);
        }
    }
    
    updateTemplates() {
        try {
            let updatedBody = this.originalBody;
            let updatedHeader = this.originalHeader;
            
            this.groupedVariables.forEach(group => {
                group.mappings.forEach(mapping => {
                    const variableToken = mapping.variable;
                
                    if (group.type === 'Header' && this.variableMapping.header[variableToken]) {  
                        updatedHeader = updatedHeader.replace(variableToken, this.variableMapping.header[variableToken]);    
                    }

                    if (group.type === 'Body' && this.variableMapping.body[variableToken]) {
                        while (updatedBody.includes(variableToken)) {
                            updatedBody = updatedBody.replace(variableToken, this.variableMapping.body[variableToken]);
                        }
                    }
                
                });
            });
        
            this.formatedTempBody = this.formatText(updatedBody);
            this.tempHeader = updatedHeader;
        } catch (error) {
            console.error('Something went wrong while updating the template.',error);   
        }
    }
    
    handleInputChange(event) {
        try {
            const {name, value } = event.target; 
            const groupType = event.target.dataset.group; 
            this.variableMapping[groupType.toLowerCase()][name] = value;
            const group = this.groupedVariables.find(group => group.type === groupType);
            const mapping = group.mappings.find(mapping => mapping.variable === name);

            if (mapping) {
                mapping.value = value;            
            }
            this.updateTemplates();  
        } catch (error) {
            console.error('Something wrong as input change.',error);
        }        
    }


    fetchTemplateData() {
        try {
            this.isLoading = true;    
            console.log('in the preview page==> ',this.templateid);
                    
            getDynamicObjectData({templateId:this.templateid})
            .then((result) => {
                if (result) {
                    this.isImgSelected = result.isImgUrl;
                    this.IsHeaderText = !result.isImgUrl;                    
                    this.originalHeader = result.template.MVWB__Header_Body__c;
                    this.originalBody = result.template.MVWB__Template_Body__c;
                    const variableMappings = result.templateVariables;

                    this.tempHeader = this.originalHeader;
                    this.tempBody = this.originalBody;
                    this.formattedtempHeader = this.originalHeader;
                    this.tempFooter = result.template.MVWB__Footer_Body__c;

                    this.isSendDisabled = result.template.MVWB__Status__c !== 'Active-Quality Pending';
                    this.sendButtonClass = this.isSendDisabled 
                    ? 'send-btn send-btn-active' 
                    : 'send-btn';
                  
                    const buttonLabels = result.template.MVWB__Button_Label__c ? result.template.MVWB__Button_Label__c.split(',') : [];
                    const buttonTypes = result.template.MVWB__Button_Type__c ? result.template.MVWB__Button_Type__c.split(',') : [];
        
                    this.buttonList = buttonLabels.map((label, index) => {
                        const type = buttonTypes[index]?.trim() || 'default';
                        return {
                            id: index,
                            btntext: label.trim(),
                            btnType: type,
                            iconName: this.getIconName(type) 
                        };
                    });

                    const grouped = variableMappings.reduce((acc, mapping) => {
                        const mappingWithValue = { 
                            ...mapping, 
                            value: '' 
                        };
                        const typeGroup = acc.find(group => group.type === mappingWithValue.type);                
                        if (typeGroup) {
                            typeGroup.mappings.push(mappingWithValue);
                        } else {
                            acc.push({ 
                                type: mappingWithValue.type, 
                                mappings: [mappingWithValue] 
                            });
                        }
                        return acc;
                    }, []);                
            
                    this.groupedVariables = grouped;
                    console.log('mapping variable ',JSON.stringify(this.groupedVariables));
                    
                    if(this.groupedVariables.length == 0){
                        this.noContact=false;
                    }

                    this.objectNames = result.objectNames;
                    this.fieldNames = result.fieldNames;
                    console.log('this.objectNames ',this.objectNames);
                    console.log('this.fieldNames ',this.fieldNames);

                    this.formatedTempBody = this.formatText(this.tempBody);
                    this.isLoading = false;
                }
            })
            .catch((error) => {
                console.error('Error fetching template data:', error);
                this.isLoading = false;
            })  
        } catch (error) {
            console.error('Something wrong in fetching template.',error);
        }     
    }

    handlePhoneChange(event){
        this.phoneNumber=event.target.value;
        console.log(this.phoneNumber);
        
    }

    fetchReplaceVariableTemplate(templateid,contactid){
        try {
            getTemplateDataWithReplacement({templateId: templateid, contactId:contactid})
            .then((templateData) => {
                if (templateData) {
                    this.template = templateData.template;
                    if(templateData.headerParams) this.headerParams = templateData.headerParams;
                    if(templateData.bodyParams) this.bodyParams = templateData.bodyParams;
                }
               
            })
            .catch(e => {
                this.isLoading = false;
                console.log('Error in fetchInitialData > getTemplateData ::: ', e.message);
            })
        } catch (e) {
            this.isLoading = false;
            console.log('Error in function fetchInitialData:::', e.message);
        }
    
    }


    sendTemplatePreview() {
        this.isLoading = true; 
    
        try {
            let phonenum = this.selectedContactId 
                ? this.contactDetails.Phone 
                : (this.selectedCountryType && this.phoneNumber && this.phoneNumber.length >= 10) 
                    ? `${this.selectedCountryType}${this.phoneNumber}`
                    : null;
    
            if (!phonenum) {
                this.showToast('Warning', 'Invalid country code or phone number', 'warning');
                this.isLoading = false;
                return;
            }
    
            const templatePayload = this.createJSONBody(phonenum, "template", {
                templateName: this.template.MVWB__Template_Name__c,
                languageCode: this.template.MVWB__Language__c,
                headerImageURL: this.template.MVWB__Header_Body__c,
                headerType:this.template.MVWB__Header_Type__c,
                headerParameters: this.headerParams,
                bodyParameters: this.bodyParams,
                buttonLabel: this.template.MVWB__Button_Label__c,
                buttonType: this.template.MVWB__Button_Type__c
            });
    
            sendPreviewTemplate({ jsonData: templatePayload })
                .then((result) => {
                    if (result) {
                        this.showToast('Error', result, 'error');
                    } else {
                        this.showToast('Success', 'Template sent successfully', 'success');
                        this.closePreview(); 
                    }
                })
                .catch((error) => {
                    console.error('Error in sending template:', error);
                    this.showToast('Error', error.body?.message || 'Failed to send template', 'error');
                })
                .finally(() => {
                    this.isLoading = false; 
                });
    
        } catch (e) {
            console.error('Error in function sendTemplatePreview:', e.message);
            this.isLoading = false; 
        }
    }    
    

    createJSONBody(to, type, data){
        try {
                let payload = `{ "messaging_product": "whatsapp", "to": "${to}", "type": "${type}"`;
                payload += `, "template": { 
                    "name": "${data.templateName}",
                    "language": { "code": "${data.languageCode}" }`;
                let components = [];
                if (data.headerParameters && data.headerParameters.length > 0) {
                    let headerParams = data.headerParameters.map(
                        (param) => `{ "type": "text", "text": "${param}" }`
                    ).join(", ");
                    components.push(`{ 
                        "type": "header", 
                        "parameters": [ ${headerParams} ] 
                    }`);
                }
                if(data.headerType=='Image' && data.headerImageURL){
                    components.push(`{ 
                        "type": "header", 
                        "parameters": [ { "type": "image", "image": { "link":"${data.headerImageURL}" } } ] 
                    }`);
                }
                if (data.bodyParameters && data.bodyParameters.length > 0) {
                    let bodyParams = data.bodyParameters.map(
                        (param) => `{ "type": "text", "text": "${param}" }`
                    ).join(", ");
                    components.push(`{ 
                        "type": "body", 
                        "parameters": [ ${bodyParams} ] 
                    }`);
                }
                // if (data.buttonLabel && data.buttonType) {
                //     components.push(`{ 
                //         "type": "button", 
                //         "sub_type": "${data.buttonType}", 
                //         "index": 0, 
                //         "parameters": [{ 
                //             "type": "text", 
                //             "text": "${data.buttonLabel}" 
                //         }] 
                //     }`);
                // }
                if (components.length > 0) {
                    payload += `, "components": [ ${components.join(", ")} ]`;
                }
                payload += ` }`; 
                payload += ` }`;
            
                return payload;
        } catch (e) {
            console.log('Error in function createJSONBody:::', e.message);
        }
    }

    closePreview() {
        this.dispatchEvent(new CustomEvent('closepopup'));
    }

    clearPreview(){
        this.tempHeader='';
        this.tempBody='';
        this.tempFooter='';
        this.buttonList=[];
        this.objectNames=[];
        this.fieldNames=[];
        this.contactDetails=[];
        this.formatedTempBody='';
    }

    showToast(title,message,variant) {
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(toastEvent);
    }
}