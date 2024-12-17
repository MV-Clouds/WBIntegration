import { LightningElement, api, track } from 'lwc';
import getTemplateData from '@salesforce/apex/ChatWindowController.getTemplateData';
import sendWhatsappMessage from '@salesforce/apex/ChatWindowController.sendWhatsappMessage';
import createChat from '@salesforce/apex/ChatWindowController.createChat';

export default class TemplatePreview extends LightningElement {
    @api templateId;
    @api recordId;
    @api mobileNumber;
    @api showButtons;

    @track templateData;
    @track isTextHeader;
    @track isImageHeader;
    @track headerBody;
    @track templateBody;
    @track footerBody;
    @track buttonLabel;
    @track headerParams;
    @track bodyParams;

    @track showSpinner = false;

    connectedCallback(){
        try{
            this.fetchInitialData();
        }catch(e){
            console.log('Error in connectedCallback:::', e.message);
        }
    }

    fetchInitialData(){
        this.showSpinner = true;
        try {
            getTemplateData({templateId: this.templateId, contactId:this.recordId})
            .then((templateData) => {

                this.templateData = templateData.template;
                
                this.isTextHeader = this.templateData?.Header_Type__c === 'Text' ? true : false;
                this.isImageHeader = this.templateData?.Header_Type__c === 'Image' ? true : false;
                this.headerBody = this.templateData?.Header_Body__c;
                this.templateBody = this.templateData?.Template_Body__c;
                this.footerBody = this.templateData?.Footer_Body__c;
                this.buttonLabel = this.templateData?.Button_Label__c;
                this.showSpinner = false;

                if(templateData.headerParams) this.headerParams = templateData.headerParams;
                if(templateData.bodyParams) this.bodyParams = templateData.bodyParams;

                let headerText = this.template.querySelector('.header-text');
                let bodyText = this.template.querySelector('.body-text');
                if(headerText) headerText.innerHTML = this.templateBody.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
                if(bodyText) bodyText.innerHTML = this.templateBody.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
            })
            .catch(e => {
                this.showSpinner = false;
                console.log('Error in fetchInitialData > getTemplateData ::: ', e.message);
            })
        } catch (e) {
            this.showSpinner = false;
            console.log('Error in function fetchInitialData:::', e.message);
        }
    }

    handleBack(){
        try {
            this.dispatchEvent(new CustomEvent('back'));
        } catch (e) {
            console.log('Error in function handleBack:::', e.message);
        }
    }

    handleSend(){
        this.showSpinner = true;
        try {
            createChat({chatData: {message: '', templateId: this.templateId, messageType: 'template', recordId: this.recordId, replyToChatId: null}})
            .then(chat => {
                if(chat){
                    let templatePayload = this.createJSONBody(this.mobileNumber, "template", {
                        templateName: this.templateData.Name,
                        languageCode: this.templateData.Language__c,
                        headerParameters: this.headerParams,
                        bodyParameters: this.bodyParams,
                        buttonLabel: this.templateData.Button_Label__c,
                        buttonType: this.templateData.Button_Type__c
                    });
                    console.log('the Payload is :: :', templatePayload);

                    sendWhatsappMessage({jsonData: templatePayload, chatId: chat.Id, isReaction: false})
                    .then(ch => {
                        this.dispatchEvent(new CustomEvent('message', {
                            detail: ch
                        }));
                        this.showSpinner = false;
                    })
                }else{
                    this.showSpinner = false;
                    console.log('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                console.log('Error in handleSelectTemplate > createChat :: ', e);
            })
        } catch (e) {
            console.log('Error in function handleSend:::', e.message);
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
                if (data.bodyParameters && data.bodyParameters.length > 0) {
                    let bodyParams = data.bodyParameters.map(
                        (param) => `{ "type": "text", "text": "${param}" }`
                    ).join(", ");
                    components.push(`{ 
                        "type": "body", 
                        "parameters": [ ${bodyParams} ] 
                    }`);
                }
                if (data.buttonLabel && data.buttonType) {
                    components.push(`{ 
                        "type": "button", 
                        "sub_type": "${data.buttonType}", 
                        "index": 0, 
                        "parameters": [{ 
                            "type": "text", 
                            "text": "${data.buttonLabel}" 
                        }] 
                    }`);
                }
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
}