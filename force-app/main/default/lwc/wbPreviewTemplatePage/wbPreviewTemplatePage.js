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
import sendPreviewTemplate from '@salesforce/apex/WBTemplateController.sendPreviewTemplate';  
import getDynamicObjectData from '@salesforce/apex/WBTemplateController.getDynamicObjectData';
import fetchDynamicRecordData from '@salesforce/apex/WBTemplateController.fetchDynamicRecordData';
import getTemplateDataWithReplacement from '@salesforce/apex/WBTemplateController.getTemplateDataWithReplacement';
import CountryJson from '@salesforce/resourceUrl/CountryJson';
import NoPreviewAvailable from '@salesforce/resourceUrl/NoPreviewAvailable';
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';

export default class WbPreviewTemplatePage extends LightningElement {
    @track ispreviewTemplate=false;
    @track filepreview;
    @track originalHeader;
    @track originalBody;
    @track template;
    @track tempHeader ;
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
    @track isVidSelected = false;
    @track isDocSelected = false;
    @track IsHeaderText = true;
    @track options = [];
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
    @track bodyParaCode = '';
    @track NoPreviewAvailableImg = NoPreviewAvailable;
    @track headerPramsCustomList = [];
    @track bodyPramsCustomList = [];
    @track isSecurityRecommedation = false;
    @track isCodeExpiration = false;
    @track showLicenseError = false;


    get contactFields() {
        return Object.entries(this.contactDetails)
            .filter(([key, value]) => value !== null && value !== undefined)
            .map(([key, value]) => ({ label: key, value }));
    }

    get isDisabled(){
        // if(this.objectNames && this.fieldNames.length>0){
        //     return false;
        // }
        // return !(this.objectNames && this.fieldNames);
        return false;
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

    get getObjectName(){
        
        return this.objectNames[0];
    }

    @api
    get templateid() {
        return this._templateid;
    }

    set templateid(value) {
        this._templateid = value;
        if (this._templateid) {
            this.fetchTemplateData();
        }
    }

    get contactIcon() {
        return this.selectedContactId ? 'standard:contact' : ''; 
    }

    async connectedCallback(){
        try {
            this.isLoading = true;
            await this.checkLicenseStatus();
            if (this.showLicenseError) {
                return; // Stops execution if license is expired
            }
            this.fetchCountries();
            this.fetchReplaceVariableTemplate(this.templateid,null);
            this.ispreviewTemplate = true;
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }
    async checkLicenseStatus() {
        try {
            const isLicenseValid = await checkLicenseUsablility();
            if (!isLicenseValid) {
                this.showLicenseError = true;
            }
        } catch (error) {
            console.error('Error checking license:', error);
        }
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
            case 'Flow':
                return 'utility:file';
            default:
                return 'utility:question'; 
        }
    }

    handleCountryChange(event){
        this.selectedCountryType = event.target.value;
    }

    handleRecordSelection(event) {
        try {
            event.stopPropagation();        
            const selectedRecord = event.detail.selectedRecord || {};
            const selectedId = selectedRecord.Id || null;
            if(!selectedId){
                this.tempHeader = this.originalHeader;
                this.tempBody = this.originalBody;
                this.formatedTempBody = this.formatText(this.tempBody);

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
                return;
            }else{
                this.isFieldDisabled=true;
            }
            const hasVariables = this.tempBody.includes('{{') || this.tempHeader.includes('{{');

            if (!hasVariables) {
                this.showToast('Warning!', 'No variables found in the template to replace.', 'warning');
                return; 
            }

            this.selectedContactId = selectedId;
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
                this.countryType = data
                    .filter(country => country.callingCode != null && country.name != null)
                    .map(country => {
                        return {
                            label: ` (${country.callingCode}) ${country.name}`,
                            value: country.callingCode
                        };
                    });
            })
            .catch((e) => console.error('Error fetching country data:', e));
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
                if (result.queriedData) {
                    this.contactDetails = result.queriedData;
                   
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
            if(groupType == 'Header'){
                this.headerPramsCustomList.push(value)
            }
            else if(groupType == 'Body'){
                this.bodyPramsCustomList.push(value);

            }
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
            getDynamicObjectData({templateId:this.templateid})
            .then((result) => {
                if (result) {

                    
                    
                    this.IsHeaderText = !result.isImgUrl;            
                    this.originalHeader = result.template.MVWB__WBHeader_Body__c;
                    this.originalBody = result.template.MVWB__WBTemplate_Body__c;
                    const variableMappings = result.templateVariables;
                    this.isSecurityRecommedation = JSON.parse(result.template.MVWB__Template_Miscellaneous_Data__c).isSecurityRecommedation;
                    this.isCodeExpiration = JSON.parse(result.template.MVWB__Template_Miscellaneous_Data__c).isCodeExpiration;
                    this.expireTime = JSON.parse(result.template.MVWB__Template_Miscellaneous_Data__c).expireTime;
                    
                    if(result.template.MVWB__Header_Type__c=='Image'){
                        this.isImgSelected = result.isImgUrl;
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(this.originalHeader, "text/html");
                        this.tempHeader = doc.documentElement.textContent || "";
                        
                    }
                    else if(result.template.MVWB__Header_Type__c=='Video'){
                        
                        this.isVidSelected = result.isImgUrl;
                        
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(this.originalHeader, "text/html");
                        this.tempHeader = doc.documentElement.textContent || "";
                    }
                    else if(result.template.MVWB__Header_Type__c=='Document'){
                        
                        this.isDocSelected = result.isImgUrl;
                        
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(this.originalHeader, "text/html");
                        this.tempHeader = doc.documentElement.textContent || "";
                    }
                    else{
                        this.tempHeader = this.originalHeader ||'';
                    }
                    this.tempBody = this.originalBody;
                    this.formattedtempHeader = this.originalHeader;
                    this.tempFooter = result.template.MVWB__WBFooter_Body__c;

                    this.isSendDisabled = result.template.MVWB__Status__c !== 'Active-Quality Pending';
                    this.sendButtonClass = this.isSendDisabled 
                    ? 'send-btn send-btn-active' 
                    : 'send-btn';
                  
                    const buttonBody = result.template.MVWB__WBButton_Body__c
                    ? JSON.parse(result.template.MVWB__WBButton_Body__c)
                    : []
                  
                  this.buttonList = buttonBody.map((buttonLabel, index) => {
                  
                    const type = buttonLabel.type
                    return {
                      id: index,
                      btntext: buttonLabel.text.trim(),
                      btnType: type,
                      iconName: this.getIconName(type)
                    }
                  })
                  


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
                    if(this.groupedVariables.length == 0){
                        this.noContact=false;
                    }

                    this.objectNames = result.objectNames == undefined? ['Contact'] : result.objectNames;
                    this.fieldNames = result.fieldNames;

                    this.options.push({ label: this.objectNames[0], value: this.objectNames[0], isSelected: true });
                   
                    this.formatedTempBody = this.formatText(this.tempBody);
                    if(result.template.MVWB__Template_Category__c == 'Authentication'){
                        this.formatedTempBody = '{{code}} ' + this.formatedTempBody;
                        if(this.isSecurityRecommedation){
                            this.formatedTempBody += '\n For your security, do not share this code.';
                        }
                        if(this.isCodeExpiration){
                            this.tempFooter = 'This code expires in '+this.expireTime+' seconds.'
                        }
                    }
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
                this.bodyParaCode = templateData.bodyParams;
                
               
            })
            .catch(e => {
                this.isLoading = false;
                console.error('Error in fetchInitialData > getTemplateData ::: ', e.message);
            })
        } catch (e) {
            this.isLoading = false;
            console.error('Error in function fetchInitialData:::', e.message);
        }
    }


    sendTemplatePreview() {
        this.isLoading = true; 
    
        try {
          
            if((this.groupedVariables.length != (this.headerPramsCustomList.length+this.bodyPramsCustomList.length)) && this.noContact){
                this.showToast('Warning', 'Please fill all input fields', 'warning');
                return;
            }
            let phonenum = this.selectedContactId 
                ? this.contactDetails.Phone 
                : (this.selectedCountryType && this.phoneNumber) 
                    ? `${this.selectedCountryType}${this.phoneNumber}`
                    : null;
            
                   

            if (!phonenum || isNaN(Number(phonenum))) {
                this.showToast('Warning', 'Invalid country code or phone number', 'warning');
                this.isLoading = false;
                return;
            }
            
            const buttonValue = this.template.MVWB__WBButton_Body__c != undefined?JSON.parse(this.template.MVWB__WBButton_Body__c) : '';
            
            
            const templatePayload = this.createJSONBody(phonenum, "template", {
                templateName: this.template.MVWB__Template_Name__c,
                languageCode: this.template.MVWB__Language__c,
                headerImageURL: this.template.MVWB__WBHeader_Body__c,
                headerType:this.template.MVWB__Header_Type__c,
                headerParameters: this.headerPramsCustomList,
                bodyParameters: this.bodyPramsCustomList,
                buttonLabel: this.template.MVWB__Button_Label__c || '',
                buttonType: this.template.MVWB__Button_Type__c || '',
                buttonValue : buttonValue
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
                    this.showToast('Error', error.body?.message || 'Failed to send template', 'error');
                })
                .finally(() => {
                    this.isLoading = false; 
                });
    
        } catch (e) {
            console.error('Error in function sendTemplatePreview:', e.message+' --- '+e);
            this.isLoading = false; 
        }
    }    
    
    createJSONBody(to, type, data) {
        try {
            const randomCode = Math.floor(Math.random() * 900000) + 100000;
            // Convert the integer to a string
            const randomCodeStr = String(randomCode);

            let payload = {
                messaging_product: "whatsapp",
                to: to,
                type: type,
                template: {
                    name: data.templateName,
                    language: {
                        code: data.languageCode
                    }
                }
            };
    
            let components = [];
    
            // Header Parameters (Text)
            if (data.headerParameters && data.headerParameters.length > 0) {
                let headerParams = data.headerParameters.map((param) => ({
                    type: "text",
                    text: param
                }));
    
                components.push({
                    type: "header",
                    parameters: headerParams
                });
            }
    
            // Header Type (Image)
            if (data.headerType === 'Image' && data.headerImageURL) {
                components.push({
                    type: "header",
                    parameters: [
                        {
                            type: "image",
                            image: {
                                link: data.headerImageURL
                            }
                        }
                    ]
                });
            }
            else if (data.headerType === 'Document' && data.headerImageURL) {
                components.push({
                    type: "header",
                    parameters: [
                        {
                            type: "document",
                            document: {
                                link: data.headerImageURL
                            }
                        }
                    ]
                });
            }
            else if (data.headerType === 'Video' && data.headerImageURL) {
                components.push({
                    type: "header",
                    parameters: [
                        {
                            type: "video",
                            video: {
                                link: data.headerImageURL
                            }
                        }
                    ]
                });
            }
            
    
            // Body Parameters
            if (data.bodyParameters && data.bodyParameters.length > 0) {
                let bodyParams = data.bodyParameters.map((param) => ({
                    type: "text",
                    text: param
                }));
    
                components.push({
                    type: "body",
                    parameters: bodyParams
                });
            } else if(this.template.MVWB__Template_Category__c == 'Authentication'){
                components.push({
                    type: "body",
                    parameters: [
                        {
                            type: "text",
                            text: randomCodeStr
                        }
                    ]
                });
            }
    
            // Button Handling
            
            if (data.buttonValue && data.buttonValue.length > 0) {
                let buttons = data.buttonValue
                    .map((button, index) => {
                        
                        switch (button.type.toUpperCase()) {
                            case "PHONE_NUMBER":
                                components.push( {
                                    type: "button",
                                    sub_type: "voice_call",
                                    index: index,
                                    parameters: [
                                        {
                                            type: "text",
                                            text: button.phone_number
                                        }
                                    ]
                                });
                                break;
                            case "URL":
                                break;
                            case "QUICK_REPLY":
                                break;
                            case "FLOW":
                                components.push( {
                                        type: "button",
                                        sub_type: "flow",
                                        index: index,
                                        parameters: [
                                            {
                                                "type": "payload",
                                                "payload": "PAYLOAD"
                                            }
                                        ]   
                                    });
                                break;
                            case 'copy_code' :
                            case "COPY_CODE":
                            case "COUPON_CODE":
                                components.push( {
                                    type: "button",
                                    sub_type: "copy_code",
                                    index: index,
                                    parameters: [
                                        {
                                            type :'coupon_code',
                                            coupon_code : button.example
                                        }
                                    ]
                                }); 
                                break;
                            case "OTP":
                                if (button.otp_type && button.otp_type.toUpperCase() === "COPY_CODE") {
                                    components.push( {
                                        type: "button",
                                        sub_type: "url",
                                        index: index,
                                        parameters: [
                                            {
                                                type : 'text',
                                                text : randomCodeStr
                                            }
                                        ]
                                    });
                                } else {
                                    console.warn(`OTP button at index ${index} missing otp_code parameter.`);
                                    return null;
                                }
                                break;
                            default:
                                console.warn(`Unknown button type: ${button.type}`);
                                return null;
                        }
                    })
                    .filter((button) => button !== null);
    
                }
            
            // Add components if available
            if (components.length > 0) {
                payload.template.components = components;
            }
            
            // Convert the object to a JSON string
            return JSON.stringify(payload);
        } catch (e) {
            console.error('Error in function createJSONBody:::', e.message);
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