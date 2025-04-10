import { LightningElement, api, track, wire } from 'lwc';
import getTemplateData from '@salesforce/apex/ChatWindowController.getTemplateData';
import sendWhatsappMessage from '@salesforce/apex/ChatWindowController.sendWhatsappMessage';
import createChat from '@salesforce/apex/ChatWindowController.createChat';

export default class TemplatePreview extends LightningElement {
    @api templateId;
    @api recordId;
    @api objectApiName;
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
    @track isTemplateDeleted;
    @track isUpdateBody;

    @track showSpinner = false;

    connectedCallback(){
        try{
            this.fetchInitialData();
            if(!this.showButtons){
                this.template.host.style.setProperty('--max-height-of-the-preview-div', 'fit-content');
            }
        }catch(e){
            console.log('Error in connectedCallback:::', e.message);
        }
    }

    renderedCallback(){
        try {
            let bodyText = this.template.querySelector('.body-text');
            if(bodyText && this.isUpdateBody){
                bodyText.innerHTML = this.templateBody?.replaceAll(/\*(.+?)\*/g, '<b>$1</b>')?.replaceAll(/\_(.+?)\_/g, '<i>$1</i>')?.replaceAll(/\~(.+?)\~/g, '<s>$1</s>')?.replaceAll(/\```(.+?)\```/g, '<code>$1</code>');
                this.isUpdateBody = false;
            }
        } catch (e) {
            console.log('Error in function renderedCallback:::', e.message);
        }
    }

    fetchInitialData(){
        this.showSpinner = true;
        try {
            // console.log(this.templateId, this.objectApiName, this.recordId);
            getTemplateData({templateId: this.templateId, contactId:this.recordId, objectApiName : this.objectApiName})
            .then((templateData) => {
                if(!templateData){
                    this.isTemplateDeleted = true;
                    this.showSpinner = false;
                    return;
                }
                
                this.templateData = templateData.template;
                
                this.isTextHeader = this.templateData?.MVWB__Header_Type__c === 'Text' ? true : false;
                this.isImageHeader = this.templateData?.MVWB__Header_Type__c === 'Image' ? true : false;
<<<<<<< HEAD
=======
                this.isVideoHeader = this.templateData?.MVWB__Header_Type__c === 'Video' ? true : false;
                this.isDocHeader = this.templateData?.MVWB__Header_Type__c === 'Document' ? true : false;
>>>>>>> 969c50ea056df61edd127a15cd19a04a749f125c
                const parser = new DOMParser();
                const doc = parser.parseFromString(this.templateData?.MVWB__WBHeader_Body__c, "text/html");
                this.headerBody = doc.documentElement.textContent;
                
                this.templateBody = this.templateData?.MVWB__WBTemplate_Body__c;
<<<<<<< HEAD
                this.footerBody = this.templateData?.MVWB__WBFooter_Body__c;
                this.buttonLabel = this.templateData?.MVWB__Button_Label__c;
=======
                if (this.templateData?.MVWB__Template_Category__c === 'Authentication') {
                    this.templateBody = '{{code}} ' + this.templateBody;
                }
                this.footerBody = this.templateData?.MVWB__WBFooter_Body__c;
                // this.buttonLabel = this.templateData?.MVWB__Button_Label__c;

                if(this.templateData.MVWB__Header_Type__c=='Image'){
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(this.headerBody, "text/html");
                    this.headerBody = doc.documentElement.textContent || "";
                }
                else if(this.templateData.MVWB__Header_Type__c=='Video'){
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(this.headerBody, "text/html");
                    this.headerBody = doc.documentElement.textContent || "";
                }
                else if(this.templateData.MVWB__Header_Type__c=='Document'){
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(this.headerBody, "text/html");
                    this.headerBody = doc.documentElement.textContent || "";
                }
                else{
                    this.headerBody = this.headerBody ||'';
                }

                const buttonBody = this.templateData.MVWB__WBButton_Body__c
                    ? JSON.parse(this.templateData.MVWB__WBButton_Body__c)
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

>>>>>>> 969c50ea056df61edd127a15cd19a04a749f125c
                this.showSpinner = false;

                if(templateData.headerParams) this.headerParams = templateData.headerParams;
                if(templateData.bodyParams) this.bodyParams = templateData.bodyParams;

                this.isUpdateBody = true;
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
            createChat({chatData: {message: '', templateId: this.templateId, messageType: 'template', recordId: this.recordId, replyToChatId: null, phoneNumber: this.mobileNumber}})
            .then(chat => {
                if(chat){
<<<<<<< HEAD
                    let templatePayload = this.createJSONBody(this.mobileNumber, "template", {
                        templateName: this.templateData.MVWB__Template_Name__c,
                        languageCode: this.templateData.MVWB__Language__c,
                        headerParameters: this.headerParams,
                        bodyParameters: this.bodyParams,
                        buttonLabel: this.templateData.MVWB__Button_Label__c,
                        buttonType: this.templateData.MVWB__Button_Type__c,
                        isHeaderImage: this.isImageHeader,
                        headerImageURL: this.headerBody
=======
                    const buttonValue = this.templateData.MVWB__WBButton_Body__c != undefined ? JSON.parse(this.templateData.MVWB__WBButton_Body__c) : '';
                    
                    const templatePayload = this.createJSONBody(this.mobileNumber, "template", {
                        templateName: this.templateData?.MVWB__Template_Name__c,
                        languageCode: this.templateData?.MVWB__Language__c,
                        headerImageURL: this.templateData?.MVWB__WBHeader_Body__c,
                        headerType:this.templateData?.MVWB__Header_Type__c,
                        headerParameters: this.headerParams,
                        bodyParameters: this.bodyParams || '',
                        buttonLabel: this.templateData?.MVWB__Button_Label__c || '',
                        buttonType: this.templateData?.MVWB__Button_Type__c || '',
                        buttonValue : buttonValue
>>>>>>> 969c50ea056df61edd127a15cd19a04a749f125c
                    });
                    // console.log('the Payload is :: :', templatePayload);

                    sendWhatsappMessage({jsonData: templatePayload, chatId: chat.Id, isReaction: false, reaction: null})
                    .then(result => {
                        this.dispatchEvent(new CustomEvent('message', {
                            detail: result
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
<<<<<<< HEAD
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
                if(data.isHeaderImage && data.headerImageURL){
                    components.push(`{ 
                        "type": "header", 
                        "parameters": [ { "type": "image", "image": { "link":"${data.headerImageURL}" } } ] 
                    }`);
=======
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
            } else if(this.templateData.MVWB__Template_Category__c == 'Authentication'){
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
    
>>>>>>> 969c50ea056df61edd127a15cd19a04a749f125c
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
}