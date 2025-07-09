import { LightningElement, api, track } from 'lwc';
import getTemplatePreviewData from '@salesforce/apex/ChatWindowController.getTemplatePreviewData';
import NoPreviewAvailable from '@salesforce/resourceUrl/NoPreviewAvailable';

export default class TemplatePreview extends LightningElement {
    @api templateId;
    @api chatId;
    @track templateMergeDetails;
    @track templateData;
    @track isTextHeader;
    @track isImageHeader;
    @track isVideoHeader;
    @track isDocHeader;
    @track tempHeader;
    @track headerBody;
    @track templateBody;
    @track footerBody;
    @track buttonLabel;
    @track headerParams;
    @track bodyParams;
    @track isTemplateDeleted;
    @track isUpdateBody;
    @track buttonList=[];
    NoPreviewAvailableImg = NoPreviewAvailable;

    @track showSpinner = false;

    connectedCallback(){
        try{
            this.fetchInitialData();
        }catch(e){
            console.error('Error in connectedCallback:::', e.message);
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
            console.error('Error in function renderedCallback:::', e.message);
        }
    }

    fetchInitialData(){
        this.showSpinner = true;
        try {
            getTemplatePreviewData({templateId: this.templateId, chatId: this.chatId})
                .then((templateData) => {
                    if(!templateData){
                        this.isTemplateDeleted = true;
                        this.showSpinner = false;
                        return;
                    }
                    
                    this.templateData = templateData.template;
                    this.templateMergeDetails = templateData.templateMergeDetails;

                    this.isTextHeader = this.templateData?.MVWB__Header_Type__c === 'Text' ? true : false;
                    this.isImageHeader = this.templateData?.MVWB__Header_Type__c === 'Image' ? true : false;
                    this.isVideoHeader = this.templateData?.MVWB__Header_Type__c === 'Video' ? true : false;
                    this.isDocHeader = this.templateData?.MVWB__Header_Type__c === 'Document' ? true : false;
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(this.templateData?.MVWB__WBHeader_Body__c, "text/html");
                    this.headerBody = doc.documentElement.textContent;

                    if(this.templateData.MVWB__Header_Type__c=='Image'){
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(this.headerBody, "text/html");
                        this.headerBody = doc.documentElement.textContent || "";
                    } else if(this.templateData.MVWB__Header_Type__c=='Video'){
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(this.headerBody, "text/html");
                        this.headerBody = doc.documentElement.textContent || "";
                    } else if(this.templateData.MVWB__Header_Type__c=='Document'){
                        const parser = new DOMParser();
                        const doc = parser.parseFromString(this.headerBody, "text/html");
                        this.headerBody = doc.documentElement.textContent || "";
                    } else{
                        this.headerBody = this.headerBody ||'';
                    }

                    if(this.isTextHeader && this.templateMergeDetails) {
                        this.formatTemplateHeaderWithMergeFields();
                    } else if (this.isImageHeader || this.isVideoHeader || this.isDocHeader) {
                        this.setHeaderImageUrl();
                    }

                    this.templateBody = this.templateData?.MVWB__WBTemplate_Body__c;
                    if (this.templateData?.MVWB__Template_Category__c === 'Authentication') {
                        this.templateBody = '{{code}} ' + this.templateBody;
                    } else if(this.templateMergeDetails) {
                        this.formatTemplateBodyWithMergeFields();
                    } 

                    this.footerBody = this.templateData?.MVWB__WBFooter_Body__c;

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

                    this.showSpinner = false;

                    if(templateData.headerParams) this.headerParams = templateData.headerParams;
                    if(templateData.bodyParams) this.bodyParams = templateData.bodyParams;

                    this.isUpdateBody = true;
                })
                .catch(e => {
                    this.showSpinner = false;
                    console.error('Error in fetchInitialData > getTemplateData ::: ', e.message);
                })
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in function fetchInitialData:::', e.message);
        }
    }

    formatTemplateBodyWithMergeFields() {
        try {
            let updatedBody = this.templateBody;

            // Step 1: Parse outer object if it's a string
            const parsedOuter = typeof this.templateMergeDetails === 'string'
                ? JSON.parse(this.templateMergeDetails)
                : this.templateMergeDetails;

            // Step 2: Parse the inner MVWB__Sent_Template_Details__c string
            const mergeDetails = parsedOuter?.MVWB__Sent_Template_Details__c
                ? JSON.parse(parsedOuter.MVWB__Sent_Template_Details__c)
                : [];

            // Get only the body type parameters
            const bodyComponent = mergeDetails.find(comp => comp.type === 'body');
            const bodyParams = bodyComponent?.parameters || [];

            

            // Replace {{1}}, {{2}}, {{3}}... using bodyParams
            for (let i = 0; i < bodyParams.length; i++) {
                const placeholder = `{{${i + 1}}}`;
                const actualValue = bodyParams[i]?.text || '';
                updatedBody = updatedBody.replaceAll(placeholder, actualValue);
            }
            
            // Set the final result
            this.templateBody = updatedBody;
        } catch (err) {
            console.error('Error formatting template body:', err);
        }
    }

    formatTemplateHeaderWithMergeFields() {
        try {
            if (!this.isTextHeader) {
                return; // Skip if not a Text header
            }

            const parsedOuter = typeof this.templateMergeDetails === 'string'
                ? JSON.parse(this.templateMergeDetails)
                : this.templateMergeDetails;

            const mergeDetails = parsedOuter?.MVWB__Sent_Template_Details__c
                ? JSON.parse(parsedOuter.MVWB__Sent_Template_Details__c)
                : [];

            const headerComponent = mergeDetails.find(comp => comp.type === 'header');
            const headerTextValue = headerComponent?.parameters?.[0]?.text || '';

            // Replace only {{1}} in the raw header body
            let rawHeader = this.templateData?.MVWB__WBHeader_Body__c || '';
            rawHeader = rawHeader.replace('{{1}}', headerTextValue);

            // Decode HTML entities if any
            const parser = new DOMParser();
            const doc = parser.parseFromString(rawHeader, 'text/html');
            this.headerBody = doc.documentElement.textContent;

        } catch (err) {
            console.error('Error formatting text header:', err);
        }
    }

    setHeaderImageUrl() {
        try {
            const parsedOuter = typeof this.templateMergeDetails === 'string'
                ? JSON.parse(this.templateMergeDetails)
                : this.templateMergeDetails;

            const mergeDetails = parsedOuter?.MVWB__Sent_Template_Details__c
                ? JSON.parse(parsedOuter.MVWB__Sent_Template_Details__c)
                : [];

            const headerComponent = mergeDetails.find(comp => comp.type === 'header');
            if (!headerComponent) return;
            // Try to find parameter of type image/video/document
            const mediaParam = headerComponent.parameters.find(param =>
                param.type === 'image' || param.type === 'video' || param.type === 'document'
            );

            let link = '';
            if (mediaParam?.image?.link) {
                link = mediaParam.image.link;
            } else if (mediaParam?.video?.link) {
                link = mediaParam.video.link;
            } else if (mediaParam?.document?.link) {
                link = mediaParam.document.link;
            }
            

            // Assign to variable (e.g., for <img src={headerMediaUrl}>)
            this.headerMediaUrl = link;

            // Or use this.headerBody if you're rendering from that
            this.headerBody = link;
        } catch (err) {
            console.error('Error setting header image URL:', err);
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
}