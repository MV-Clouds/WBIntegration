/*
 * Component Name: WbCreateTemplatePage
 * @description: Used LWC components to show create templates in meta and store in the template record.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 23/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : Beta 10 
 * Change Description : Beta 10 bug resolved
 ********************************************************************** */

import { LightningElement, track,api } from 'lwc';
import {loadStyle} from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import wbCreateTempStyle from '@salesforce/resourceUrl/wbCreateTempStyle';
import richTextZip from '@salesforce/resourceUrl/richTextZip';
import buttonIconsZip from '@salesforce/resourceUrl/buttonIconsZip';
import emojiData from '@salesforce/resourceUrl/emojis_data';
import CountryJson from '@salesforce/resourceUrl/CountryJson';
import LanguageJson from '@salesforce/resourceUrl/LanguageJson';
import createWhatsappTemplate from '@salesforce/apex/WBTemplateController.createWhatsappTemplate';
import editWhatsappTemplate from '@salesforce/apex/WBTemplateController.editWhatsappTemplate';
import startUploadSession from '@salesforce/apex/WBTemplateController.startUploadSession';
import uploadFileChunk from '@salesforce/apex/WBTemplateController.uploadFileChunk';
import getObjectFields from '@salesforce/apex/WBTemplateController.getObjectFields';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getDynamicObjectData from '@salesforce/apex/WBTemplateController.getDynamicObjectData';
import getObjectsWithPhoneField from '@salesforce/apex/WBTemplateController.getObjectsWithPhoneField';
export default class WbCreateTemplatePage extends LightningElement {
    maxTempNamelength = 512;
    maxShortlength = 60;
    maxTempBodyLength = 1024;
    maxWebsiteUrl = 2000;
    maxBtnTxt = 25;
    maxPhonetxt = 20;
    maxCodetxt = 15;
    maxPackTxt=224;
    maxHashTxt=11;
    @track isNewTemplate=true;
    @track isEditTemplate=false;
    @track totalButtonsCount = 0;
    @track visitWebsiteCount = 0;
    @track callPhoneNumber = 0;
    @track copyOfferCode = 0;
    @track marketingOpt = 0;
    @track isAllTemplate = false;
    @track iseditTemplatevisible = true;
    @track isPreviewTemplate = false;
    @track showReviewTemplate=false;
    @track IsHeaderText = false;
    @track addHeaderVar = false;
    @track addMedia = false;
    @track isImageFile = false;
    @track isImageFileUploader=false;
    @track isCallPhone = false;
    @track isOfferCode = false;
    @track isVisitSite = false;
    @track isCustom = false;
    @track createButton = false;
    @track isButtonDisabled = false;
    @track isStopMarketing = false;
    @track buttonDisabled = false;
    @track isRefreshEnabled = true;
    @track isDefault=true;
    @track isLoading=false;
    @track templateExists=false;
    @track showEmojis = false;
    @track isCheckboxChecked=true;   
    @track showDefaultBtn=true;
    @track templateName = '';
    @track header = '';
    @track footer = '';
    @track tempBody = 'Hello';
    @track previewBody='Hello';
    @track previewHeader='';
    @track formatedTempBody= this.tempBody;
    @track btntext = '';
    @track webURL = '';
    @track Cbtntext = '';
    @track selectedAction = '';
    @track selectedUrlType = 'Static';
    @track variables = [];
    @track header_variables = [];
    @track nextIndex = 1;
    @track headIndex = 1;
    @track selectedOption='Custom';
    @track activeTab = 'Marketing';
    @track selectedLabel = 'Add button';
    @track selectedContentType = 'None';  
    @track selectedLanguage = 'en_US';
    @track selectedActionType = '';
    @track selectedCountryType = '+91';  
    @track originalTempBody = '';
    @track placeholderMap = {};
    @track buttonList = [];
    @track customButtonList = [];  
    @track emojis;
    @track originalHeader = '';
    @track menuButtonSelected;    
    file;
    fileName = '';
    fileSize = 0;
    fileType = '';
    chunkSize = 5242880;
    uploadSessionId = '';
    @track headerHandle ='';
    @track isfilename=false;
    @track NoFileSelected=true;
    @track isImgSelected = false;
    @track filePreview='';
    @track languageOptions=[];
    @track countryType=[];
    @track availableObjects = [];
    @track selectedObject = '';
    @track fields = [];
    @track chatMessages = [];
    @track richTextZip = richTextZip;
    @track buttonIconsZip =buttonIconsZip;
    @track toolbarButtons=[];
    @track isDropdownOpen = false;
    @track dropdownClass = 'dropdown-hidden';
    @track emojiCategories=[];
    @track templateId='';
    @track metaTemplateId='';
    @track allTemplates=[];
    @track headerError='';
    @track imageurl='';
    @track contentDocumentId='';
    @track isRendered=false;

    @api
    get edittemplateid() {
        return this._edittemplateid;
    }

    set edittemplateid(value) {
        this._edittemplateid = value;
        if (this._edittemplateid) {
            this.isNewTemplate=false;
            this.isEditTemplate=true;
            this.isAllTemplate=false;
            this.fetchTemplateData();
        }
    }

    get acceptedFormats() {
        return ['png','jpeg','jpg'];
    }

    get typeOptions() {
        return [
            { label: 'None', value: 'None'},
            { label: 'Text', value: 'Text'},
            { label: 'Image', value: 'Image'},
            { label: 'Video', value: 'Video', isDisabled:true},
            { label: 'Document', value: 'Document',isDisabled:true },
            { label: 'Location', value: 'Location',isDisabled:true }
        ];
    }

    get typeactionOption() {
        return [
            { label: 'Call Phone Number', value: 'PHONE_NUMBER' },
            { label: 'Visit Website', value: 'URL' },
            { label: 'Copy Offer Code', value: 'COPY_CODE' }
        ];
    }

    get customOption() {
        return [
            { label: 'Custom', value: 'QUICK_REPLY' },
            {label: 'Marketing opt-out', value: 'Marketing opt-out'}
        ];
    }

    get urlType() {
        return [
            { label: 'Static', value: 'Static' }
        ];
    }

    get selectedLanguageLabel() {
        const selectedOption = this.languageOptions.find(option => option.value === this.selectedLanguage);
        return selectedOption ? selectedOption.label : '';
    }
 
    get hasButtons() {
        return this.buttonList.length > 0 || this.customButtonList.length > 0;
    }

    get buttonListWithDisabledState() {
        return this.customButtonList.map(button => ({
            ...button,
            isDisabled: button.selectedCustomType === 'Marketing opt-out'
        }));
    }
    get visitWebsiteDisabled() {
        return this.visitWebsiteCount >= 2;
    }

    get callPhoneNumberDisabled() {
        return this.callPhoneNumber >= 1;
    }

    get copyOfferDisabled() {
        return this.copyOfferCode >= 1;
    }

    get marketingOptDisabled() {
        return this.marketingOpt >= 1;
    }

    get buttonClass() {
        return this.isButtonDisabled ? 'select-button disabled' : 'select-button';
    }

    get tempHeaderExample() {
        return this.header_variables.map(varItem => `{{${varItem.object}.${varItem.field}}}`);
    }

    get templateBodyText() {
        return this.variables.map(varItem => `{{${varItem.object}.${varItem.field}}}`);
    }
    
    get refreshButtonClass() {
        return this.isRefreshEnabled ? 'refresh-icon refresh-disabled' : 'refresh-icon';
    }

    get computedVariables() {
        return this.variables.map((varItem) => {
            return {
                ...varItem,
                options: this.fields ? this.fields.map((field) => ({
                    ...field,
                    isSelected: field.value === varItem.field
                })) : []
            };
        });
    }

    get availableObjectsWithSelection() {
        return this.availableObjects.map(obj => ({
            ...obj,
            isSelected: obj.value === this.selectedObject
        }));
    }

    connectedCallback() {
        this.fetchCountries();
        this.fetchLanguages();
        // this.fetchFields('Lead');
        this.generateEmojiCategories();
        this.fetchUpdatedTemplates(false);
        this.fetchObjectsWithPhoneField();
    }

    fetchObjectsWithPhoneField() {
        this.isLoading = true;
        getObjectsWithPhoneField()
        .then((result) => {            
            this.availableObjects = result;
            this.selectedObject = this.availableObjects[0].value;
            this.fetchFields(this.selectedObject);
        })
        .catch((error) => {
            console.error('Error fetching objects with phone field: ', error);
            this.showToastError('Error fetching objects with phone field: '+error.message);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
    
    renderedCallback() {
        loadStyle(this, wbCreateTempStyle).then(() => {
            console.log("Loaded Successfully");
        }).catch(error => {
            console.error("Error in loading the colors",error);
        })
        if (this.isRendered) return;
        this.isRendered = true;
        let headerEls = this.template.querySelectorAll('.field-header-dd');
        if(headerEls!=null && this.addHeaderVar) {
            for(let i=0; i< this.header_variables.length; i++){
                this.header_variables.forEach((hv, i) => {
                    headerEls[i].value = hv.field;
                })
            }
            this.addHeaderVar=false;
        }
        let bodyEls = this.template.querySelectorAll('.field-body-dd');
        if(bodyEls !=null && this.addVar) {
            this.variables.forEach((bv, i) => {
                bodyEls[i].value = bv.field;
            })
            this.addVar=false;
        }
    }

    fetchTemplateData() {
        try {
            getDynamicObjectData({templateId:this.edittemplateid})
            .then((data) => {
                const { template, templateVariables } = data;
                this.templateName = template.MVWB__Template_Name__c || '';
                this.metaTemplateId = template.MVWB__Template_Id__c || '';
                const headerBody = template.MVWB__WBHeader_Body__c || '';
                
                const headerType = template.MVWB__Header_Type__c || 'None';
                
                this.footer = template.MVWB__WBFooter_Body__c || '';
                this.selectedLanguage = template.MVWB__Language__c;
                this.languageOptions = this.languageOptions.map(option => ({
                    ...option,
                    isSelected: option.value === this.selectedLanguage
                }));
                
                this.tempBody = template.MVWB__WBTemplate_Body__c || 'Hello';
                
                this.previewBody = this.tempBody ? this.formatText(this.tempBody) : 'Hello';
                // const parser = new DOMParser();
                // const doc = parser.parseFromString(template?.MVWB__WBHeader_Body__c, "text/html");
                // this.previewHeader = doc.documentElement.textContent;
                if(template.MVWB__Header_Type__c=='Image'){
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(template?.MVWB__WBHeader_Body__c, "text/html");
                    this.previewHeader = doc.documentElement.textContent||"";
                }else{
                    this.previewHeader= this.formatText(headerBody) ||'';
                }
                // this.previewHeader= this.formatText(headerBody) ||'';
                this.selectedContentType=template.MVWB__Header_Type__c || 'None';
                this.btntext = template.MVWB__Button_Label__c || '';
                
                let tvs =templateVariables.map(tv=>{
                    let temp = {
                        object:tv.objName,
                        field:tv.fieldName,
                        alternateText:tv.alternateText?tv.alternateText:'',
                        id:tv.variable.slice(2,3),
                        index:tv.variable,
                        type:tv.type
                    };
                    return temp;
                })
                
                this.variables = tvs.filter(tv=>tv.type=='Body') || [];
                this.header_variables = tvs.filter(tv=>tv.type=='Header') || [];
                this.updatePreviewContent(this.previewHeader,'header');
                this.updatePreviewContent(this.previewBody,'body');
                this.addHeaderVar=this.header_variables?.length>0?true:false;
                this.addVar=this.variables?.length>0?true:false;
                if (this.addHeaderVar) {
                    // this.isHeaderVariableLoad = true;
                    this.buttonDisabled = true;
                }                
                // if(this.addVar) this.isBodyVariableLoad=true;
                
                if(template.MVWB__Button_Type__c && template.MVWB__Button_Label__c){
                    let newButton = {
                        id: this.buttonList.length + 1,
                        selectedActionType: template.MVWB__Button_Type__c,
                        iconName: this.getButtonIcon(template.MVWB__Button_Type__c),
                        btntext: template.MVWB__Button_Label__c,
                        webURL: template.MVWB__Button_Body__c,
                        phonenum: template.MVWB__Button_Body__c?.split(' ')[1],
                        offercode: template.MVWB__Button_Body__c,
                        selectedUrlType: 'Static',
                        selectedCountryType: template.MVWB__Button_Body__c?.split(' ')[0],
                        isCallPhone: false,
                        isVisitSite: false,
                        isOfferCode: false,
                        hasError: false,  
                        errorMessage: ''   
                    };
                    
                    this.handleMenuSelect({currentTarget:{dataset:{value:template.MVWB__Button_Type__c,buttonData:newButton}}});
                }
                this.handleContentType({target:{value:template.MVWB__Header_Type__c ||'None'}});

                if(headerType.toLowerCase()=='image'){
                    this.isImageFile=true;
                    this.isfilename=true;
                    this.isImgSelected=false;
                    this.fileName=template.MVWB__File_Name__c;
                    this.filePreview=headerBody;
                    this.imageurl=template.MVWB__WBHeader_Body__c;
                    this.headerHandle=template.MVWB__WBImage_Header_Handle__c;
                    this.NoFileSelected = false;
                }else{
                    this.header = headerBody.trim().replace(/^\*\*|\*\*$/g, '');
                }
             
            })
            .catch((error) => {
                console.error('Error fetching fields: ', error);
            });
        } catch (error) {
            console.error('Error fetching template data: ', error);
        }
    }

    getIconPath(iconName) {
        return `${richTextZip}/rich-texticon/${iconName}.png`;
    }

    get toolbarButtonsWithClasses() {
        return this.toolbarButtons.map(button => ({
            ...button,
            iconUrl: this.getIconPath(button.iconName), 
            classes: `toolbar-button ${button.title.toLowerCase()}`,
            imgClasses: `custom-icon ${button.iconName.toLowerCase()}`
        }));
    }

    toolbarButtons = [
        { title: 'bold', iconName: 'bold' },
        { title: 'italic', iconName: 'italic' },
        { title: 'strikethrough', iconName: 'stike' },
        { title: 'codeIcon', iconName: 'code' }
    ];

    addOutsideClickListener() {
        document.addEventListener('click', this.handleOutsideClick.bind(this));
    }

    removeOutsideClickListener() {
        document.removeEventListener('click', this.handleOutsideClick.bind(this));
    }

    disconnectedCallback() {
        this.removeOutsideClickListener();
    }

    handleOutsideClick(event) {
        const emojiContainer = this.template.querySelector('.toolbar-button');
        const button = this.template.querySelector('button');        
        if (
            (emojiContainer && !emojiContainer.contains(event.target)) && 
            (button && !button.contains(event.target))
        ) {
            this.showEmojis = false;
            this.removeOutsideClickListener();
        }
        if (this.template.querySelector('.dropdown-container') && !this.template.querySelector('.dropdown-container').contains(event.target)) {
            if (this.isDropdownOpen) {
                this.isDropdownOpen = false;
                this.dropdownClass = 'dropdown-hidden';
            }
        }
    }

    //fetch object related fields
    fetchFields(objectName) {
        try {
            getObjectFields({objectName: objectName})
            .then((result) => {
                this.fields = result.map((field) => ({ label: field, value: field }));
            })
            .catch((error) => {
                console.error('Error fetching fields: ', error);
            });
        } catch (error) {
            console.error('Error fetching objects fields: ', error);
        }
    }

    handleFileChange(event) {
        try {            
            const fileInput = event.target.files[0];
            if (!fileInput) {
                console.error('No file selected. Please choose a file.');
            }

            this.file = fileInput;
            this.fileName = fileInput.name;
            this.fileSize = fileInput.size;
            this.fileType = fileInput.type;
        
            if (this.selectedContentType === 'Image') {
                const allowedImageTypes = ['image/jpeg', 'image/png', 'image/jpg'];
                if (!allowedImageTypes.includes(fileInput.type)) {
                    this.showToastError(`Unsupported file type. Please upload a valid file for ${this.selectedContentType}: ${this.getAllowedFileTypes(this.selectedContentType)}.`);
                    this.handleRemoveFile();
                }
                this.generatePreview(fileInput);
            }
    
            this.isfilename = true;
            this.NoFileSelected = false;
    
            this.uploadFile();
        } catch (error) {
            console.error('Error handling file change:', error);
            // this.showToastError(error.message || 'An error occurred while processing the file.');
            this.handleRemoveFile(); 
        }
    }
    
    getAllowedFileTypes(contentType) {
        switch (contentType) {
            case 'Image':
                return 'Image (PNG, JPG,JPEG)';
            default:
                return '';
        }
    }

    handleRemoveFile(){
        this.isfilename=false;
        this.NoFileSelected=true;
        this.isVidSelected=false;
        this.isDocSelected=false;
        this.filePreview = null;
        this.isImageFile=false;
        this.headerHandle='';
        if(this.isImageFileUploader==true){
            this.isImgSelected=true;
        }
    }

    generatePreview(file) {
        if (file.type.startsWith('image/')) {
            this.isImgSelected = false;
            this.isImageFile = true;

            const reader = new FileReader();
            reader.onload = () => {
                this.filePreview = reader.result; 
            };
            reader.readAsDataURL(file);
        } 
    }
    
    uploadFile() {
        this.isLoading=true;
        if (!this.file) {
            alert('Please select a file to upload.');
            return;
        }
        try {
           startUploadSession({
                fileName: this.fileName,
                fileLength: this.fileSize,
                fileType: this.fileType
            }).then(result=>{
                if (result) {
                    this.uploadSessionId = result;
                    this.uploadChunks();
                } else {
                    console.error('Failed to start upload session.');
                    this.showToastError('Failed to start upload session.');
                    this.isLoading=false;
                }
            })
            .catch(error=>{
                console.error('Failed upload session.', error.body);
                this.isLoading=false;
            })
        } catch (error) {
            console.error('Error starting upload session: ', error);
            this.isLoading=false;
        }
    }

    uploadChunks() {
        try {
            let chunkStart = 0;
            const uploadNextChunk = () => {
                const chunkEnd = Math.min(chunkStart + this.chunkSize, this.fileSize);
                const chunk = this.file.slice(chunkStart, chunkEnd);
                const reader = new FileReader();
    
                reader.onloadend = async () => {
                    const base64Data = reader.result.split(',')[1]; 
                    const fileChunkWrapper = {
                        uploadSessionId: this.uploadSessionId,
                        fileContent: base64Data,
                        chunkStart: chunkStart,
                        chunkSize: base64Data.length,
                        fileName: this.fileName,
                    };
                    const serializedWrapper = JSON.stringify(fileChunkWrapper);
                    
                        uploadFileChunk({serializedWrapper:serializedWrapper})
                        .then(result=>{
                            if (result) {
                                let serializeResult = JSON.parse(result); 
                                this.headerHandle = serializeResult.headerHandle;
                                this.imageurl = serializeResult.imageurl;
                                this.contentDocumentId =serializeResult.contentDocumentId;

                                chunkStart += this.chunkSize;
                                if (chunkStart < this.fileSize) {
                                    uploadNextChunk(); 
                                } else {
                                    this.isLoading=false;
                                    this.showToastSuccess('File upload successfully.');
                                }
                            } else {
                                console.error('Failed to upload file chunk.');
                                this.isLoading=false;
                                this.showToastError('Failed to upload file chunk.');
                            }
                        })
                        .catch(error=>{
                            console.error('Failed upload session.', error);
                            this.isLoading=false;
                            this.showToastError(error.body.message || 'An error occurred while uploading image.');
                        })
                };

                reader.readAsDataURL(chunk); 
            };

            uploadNextChunk();
        } catch (error) {
            this.isLoading=false;
            console.error('Error uploading file chunk: ', error);
        }
    }

    handleContentType(event) {
        try {
            this.NoFileSelected=true;
            this.isfilename=false;
            this.previewHeader = ''; 
            this.header='';
            this.selectedContentType = event.target.value;
            setTimeout(() => {
                this.template.querySelector('.conInput').value=this.selectedContentType;
            }, 1000)
    
            this.IsHeaderText = this.selectedContentType == 'Text' ? true : false;
            if (this.selectedContentType == 'Image') {
                    this.isImgSelected = true;
                    this.isImageFileUploader=true;
                    this.isImageFile = false;
                    this.addMedia = true;
            } else {
                this.isImageFile = false;
                this.isImageFileUploader=false
                this.addMedia = false;
                this.isImgSelected = false;
            }

        } catch (error) {
            console.error('Something wrong while selecting content type: ', JSON.stringify(error));
        }
    }

    handleNextclick() {
        this.iscreatetemplatevisible = false;
        this.iseditTemplatevisible = true;
    }

    handlePrevclick() {
        this.isAllTemplate = true;
        this.iseditTemplatevisible = false;
        this.clearEditTemplateData();
    }

    clearEditTemplateData() {
        this.templateName = ''; 
        this.selectedContentType = 'None';
        this.header = ''; 
        this.addHeaderVar = false; 
        this.content = ''; 
        this.tempBody = 'Hello';  
        this.addVar=false;
        this.footer='';
        this.buttonList = [];
        this.customButtonList = [];
        this.variables = [];
        this.header_variables = [];
        this.buttonDisabled = false;
        this.originalHeader=[];
        this.nextIndex = 1;
        this.headIndex = 1;
        this.createButton=false;
        this.IsHeaderText=false;
        this.isCustom=false;
        this.formatedTempBody=this.tempBody;
        this.visitWebsiteCount = 0;
        this.callPhoneNumber = 0;
        this.copyOfferCode = 0;
        this.marketingOpt = 0;

        const headerInput = this.template.querySelector('input[name="header"]');
        if (headerInput) {
            headerInput.value = '';  
        }
    }
 
    handlediscardclick() {
        this.isAllTemplate = true;
        this.iscreatetemplatevisible = false;
        this.iseditTemplatevisible = false;
    }

    handleCustom(event) {
        this.selectedCustomType = event.target.value;
    }

    handleInputChange(event) {
        try {
            const { name, value, checked, dataset } = event.target;
            const index = dataset.index;

            switch (name) {
                case 'templateName':
                    this.templateName = value.replace(/\s+/g, '_').toLowerCase();
                    this.checkTemplateExistence();
                    break;
                case 'language':
                    this.selectedLanguage = value;
                    this.languageOptions = this.languageOptions.map(option => ({
                        ...option,
                        isSelected: option.value === this.selectedLanguage
                    }));
                    break;
                case 'footer':
                    this.footer = value;
                    break;
                case 'tempBody':
                    this.tempBody = value.replace(/(\n\s*){3,}/g, '\n\n');
                    this.formatedTempBody = this.formatText(this.tempBody);
                    this.updatePreviewContent(this.formatedTempBody,'body');
                    break;
                case 'btntext':
                    this.updateButtonProperty(index, 'btntext', value);
                    this.validateButtonText(index, value);
                    break;
                case 'selectedUrlType':
                    this.updateButtonProperty(index, 'selectedUrlType', value);
                    break;
                case 'webURL':
                    this.updateButtonProperty(index, 'webURL', value);
                    break;
                case 'selectedCountryType':
                    this.updateButtonProperty(index, 'selectedCountryType', value);
                    this.selectedCountryType = value;
                    break;
                case 'phonenum':
                    this.updateButtonProperty(index, 'phonenum', value);
                    break;
                case 'offercode':
                    this.updateButtonProperty(index, 'offercode', value);
                    break;
                case 'isCheckboxChecked':
                    this.isCheckboxChecked = checked;
                    break;
                case 'header':
                    this.header = value;
                    const variableMatches = (value.match(/\{\{\d+\}\}/g) || []).length;
                    if (variableMatches > 1) {
                        this.headerError = 'Only one variable is allowed in the header.';
                    } else {
                        this.headerError = '';
                        this.updatePreviewContent(this.header, 'header');
                    }
                
                    // this.updatePreviewContent(this.header,'header');
                    break;
                default:
                    break;
            }
        } catch (error) {
            console.error('Something went wrong: ', error);
        }
    }
    

    validateButtonText(index, newValue) {
        const isDuplicate = this.buttonList.some((button, idx) => button.btntext === newValue && idx !== parseInt(index));
        
        if (index === 0) {
            this.buttonList[index].hasError = false;
            this.buttonList[index].errorMessage = '';
        } else {
            this.buttonList[index].hasError = isDuplicate;
            this.buttonList[index].errorMessage = isDuplicate ? 'You have entered the same text for multiple buttons.' : '';
        }

        this.btntext = newValue;  
        this.updateButtonErrors(); 
    }

    updateButtonProperty(index, property, value) {
        this.buttonList[index][property] = value;
    }

    checkTemplateExistence() {
        try {
            this.templateExists = this.allTemplates.some(
                template => template.MVWB__Template_Name__c.toLowerCase() === this.templateName.toLowerCase()
            );
        } catch (error) {
            console.error(error.message);
            this.showToastError(error.message || 'An error occurred while checking template existence.');
        }
    }

    handleRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const removedButton = this.buttonList[index];
            if (removedButton && removedButton.isVisitSite) {
                this.visitWebsiteCount--;
            } else if (removedButton && removedButton.isCallPhone) {
                this.callPhoneNumber--;
            } else if (removedButton && removedButton.isOfferCode) {
                this.copyOfferCode--;
            }
            this.buttonList = this.buttonList.filter((_, i) => i !== parseInt(index));
            if (this.buttonList.length == 0) {
                this.createButton = false;
            }
            this.totalButtonsCount--;
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error while removing button.',error);
        }
    }

    handleMenuSelect(event) {
        try {
            // const selectedValue = event.detail.value;
            const selectedValue = event.currentTarget.dataset.value; 
            this.menuButtonSelected = selectedValue;
            let buttonData=event.currentTarget.dataset.buttonData;
        
            let newButton = buttonData ? buttonData:{
                id: this.buttonList.length + 1,
                selectedActionType: selectedValue,
                iconName: this.getButtonIcon(selectedValue),
                btntext: '',
                webURL: '',
                phonenum: '',
                offercode: '',
                selectedUrlType: 'Static',
                selectedCountryType: '',
                isCallPhone: false,
                isVisitSite: false,
                isOfferCode: false,
                hasError: false,  
                errorMessage: ''   
            };
        
            switch (selectedValue) {
                case 'QUICK_REPLY':
                    this.isCustom = true;
                    const quickReplyText = buttonData && buttonData.btntext ? buttonData.btntext : 'Quick reply';
                    this.createCustomButton('QUICK_REPLY', quickReplyText);
                    this.isStopMarketing = false;
                    break;
                case 'Marketing opt-out':
                    if (this.marketingOpt < 1) {
                        this.isCustom = true;
                        this.isStopMarketing = true;
                        const stopPromoText = buttonData && buttonData.btntext ? buttonData.btntext : 'Stop promotions';
                        this.createCustomButton('Marketing opt-out', stopPromoText);
                        this.marketingOpt++;
                    }
                    break;
                case 'PHONE_NUMBER':
                    if (this.callPhoneNumber < 1) {
                        this.createButton = true;
                        newButton.isCallPhone = true;
                        newButton.btntext = buttonData?.btntext || 'Call Phone Number';
                        this.btntext = buttonData?.btntext || 'Call Phone Number';
                        this.callPhoneNumber++;
                    }
                    break;
                case 'URL':
                    if (this.visitWebsiteCount < 2) {
                        this.createButton = true;
                        newButton.isVisitSite = true;
                        this.isVisitSite = true;
                        newButton.btntext = buttonData?.btntext || 'Visit Website';
                        this.btntext = buttonData?.btntext || 'Visit Website';
                        this.visitWebsiteCount++;
                    }
                    break;
                case 'COPY_CODE':
                    if (this.copyOfferCode < 1) {
                        this.createButton = true;
                        newButton.isOfferCode = true;
                        newButton.btntext = buttonData?.btntext || 'Copy Offer Code';
                        this.btntext = buttonData?.btntext || 'Copy Offer Code';
                        this.copyOfferCode++;
                    }
                    break;
                default:
                    newButton.btntext = 'Add Button';
            }
        
            const isDuplicate = this.buttonList.some(button => button.btntext === newButton.btntext);
            if (isDuplicate) {
                newButton.hasError = true;
                newButton.errorMessage = 'You have entered same text for multiple buttons.';
            } else {
                newButton.hasError = false;
                newButton.errorMessage = '';
            }
        
            if (newButton.selectedActionType != 'QUICK_REPLY' && newButton.selectedActionType != 'Marketing opt-out') {
                this.buttonList.push(newButton);
                this.totalButtonsCount++;
            }
        
            this.updateButtonErrors();
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error handling menu selection:', error);
        }
    }
       
    updateButtonErrors(isCustom = false) {
        const buttonListToCheck = isCustom ? this.customButtonList : this.buttonList;
        const buttonTexts = buttonListToCheck.map(button => isCustom ? button.Cbtntext : button.btntext);
        
        const duplicates = {};
        buttonTexts.forEach(text => {
            duplicates[text] = (duplicates[text] || 0) + 1;
        });
    
        buttonListToCheck.forEach((button, idx) => {
            const isDuplicate = duplicates[isCustom ? button.Cbtntext : button.btntext] > 1;
    
            if (idx === 0) {
                button.hasError = false;
                button.errorMessage = '';
            } else {
                if (isDuplicate) {
                    button.hasError = true;
                    button.errorMessage = 'You have entered the same text for multiple buttons.';
                } else {
                    button.hasError = false;
                    button.errorMessage = '';
                }
            }
        });
    }
    
    createCustomButton(btnType, btnText) {
        try {
            const btnTextExists = this.customButtonList.some(button => button.Cbtntext === btnText);
    
            let newCustomButton = {
                id: this.customButtonList.length + 1,
                selectedCustomType: btnType,
                Cbtntext: btnText,
                buttonClass: 'button-label-preview',
                showFooterText: btnType === 'Marketing opt-out',
                iconName: this.getButtonIcon(btnType),
                hasError: false,  
                errorMessage: ''  
            };
    
            if (btnTextExists) {
                newCustomButton.hasError = true;
                newCustomButton.errorMessage = 'You have entered same text for multiple buttons.';
            } else {
                newCustomButton.hasError = false;
                newCustomButton.errorMessage = '';
            }
    
            this.customButtonList.push(newCustomButton);
            this.totalButtonsCount++;
    
            this.updateButtonErrors(true);
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error creating custom button:', error);
        }
    }

    getButtonIcon(type) {
        const iconMap = {
            'QUICK_REPLY': 'utility:reply',
            'Marketing opt-out': 'utility:reply',
            'PHONE_NUMBER': 'utility:call',
            'URL': 'utility:new_window',
            'COPY_CODE': 'utility:copy'
        };
        return iconMap[type] || 'utility:question'; 
    }

    handleButtonClick(event) {
        try {
            const buttonId = event.currentTarget.dataset.id;        
            const clickedButton = this.customButtonList.find(button => button.id == buttonId);
        
            if (clickedButton) {
                if (clickedButton.isDisabled) {                    
                    return; 
                }
                let replyMessage = {
                    id: Date.now(),
                    body: `${clickedButton.Cbtntext}`,
                    timestamp: new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }),
                    replyToMessage: {
                        body: this.formatedTempBody,
                    }
                };
        
                this.chatMessages = [...this.chatMessages, replyMessage];
    
                clickedButton.isDisabled = true;
                clickedButton.buttonClass = 'button-label-preview disabled'; 
    
                this.customButtonList = [...this.customButtonList];
                this.isRefreshEnabled = false;
            }
        } catch (error) {
            console.error('Error while replying to template.',error);
        }
    }    

    handleCustomText(event) {
        try {
            const index = event.currentTarget.dataset.index; 
            const newValue = event.target.value;
            this.customButtonList[index].Cbtntext = newValue;  
        
            const isDuplicate = this.customButtonList.some((button, idx) => button.Cbtntext === newValue && idx !== parseInt(index));
        
            if (index === 0) {
                this.customButtonList[index].hasError = false;  
                this.customButtonList[index].errorMessage = ''; 
            } else {
                if (isDuplicate) {
                    this.customButtonList[index].hasError = true;
                    this.customButtonList[index].errorMessage = 'You have entered the same text for multiple buttons.';
                } else {
                    this.customButtonList[index].hasError = false;
                    this.customButtonList[index].errorMessage = '';
                }
            }
        
            this.Cbtntext = newValue;  
            this.updateButtonErrors(true); 
        } catch (error) {
            console.error('Error while handling the custom text.',error);
        }
    }

    handleRemoveCustom(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const removedButton = this.customButtonList[index];
        
            if (removedButton && removedButton.showFooterText) {
                this.marketingOpt--;
            }    
            this.customButtonList = this.customButtonList.filter((_, i) => i !== parseInt(index));
            if (this.customButtonList.length === 0) {
                this.isCustom = false;
            }
        
            this.totalButtonsCount--;
        
            if (removedButton?.Cbtntext) {
                const filteredMessages = this.chatMessages.filter(message => {
                    const isReplyToRemoved = message.replyToMessage?.body === this.formatedTempBody && message.body === removedButton.Cbtntext;
                    return !isReplyToRemoved;
                });
                this.chatMessages = [...filteredMessages];
            }
        
            this.customButtonList = [...this.customButtonList];
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error while removing custom buttons.',error);
            
        }
    }    

    updateButtonDisabledState() {
        this.isDropdownOpen=false;
        this.isButtonDisabled = this.totalButtonsCount >= 1;
        this.buttonList.forEach(button => {
            button.isDisabled = button.selectedActionType === 'COPY_CODE';
        });
    }

    refreshTempPreview(){
        try {
            this.customButtonList = this.customButtonList.map(button => {
                return {
                    ...button,
                    isDisabled: false, 
                    buttonClass: 'button-label-preview' 
                };
            });
            this.chatMessages = [];
            this.isRefreshEnabled = true;
            
        } catch (error) {
            console.error('Error while refreshing the template.',error);
        }
    }

    addvariable() {
        try {
            this.addVar = true;
            const maxId = this.variables.reduce((max, variable) => {
                return Math.max(max, parseInt(variable.id)); 
            }, 0); 
            
            this.nextIndex = maxId + 1;
            const defaultField = this.fields[0].value; 
            
            const newVariable = {
                id: this.nextIndex,
                object: this.selectedObject,
                field: defaultField,
                alternateText: '',
                index: `{{${this.nextIndex}}}`,        
            };
            this.variables = [...this.variables, newVariable];

            this.tempBody = `${this.tempBody} {{${this.nextIndex}}} `;
            this.formatedTempBody=this.formatText(this.tempBody);
            this.updateTextarea();
            this.updatePreviewContent(this.formatedTempBody, 'body');
            this.nextIndex++;
        } catch (error) {
            console.error('Error in adding variables.',error); 
        } 
    }

    handleVarFieldChange(event) {
        try {
            const variableIndex = String(event.target.dataset.index);
            const fieldName = event.target.value;             
            this.variables = this.variables.map((varItem) =>                
                String(varItem.index) === variableIndex
                    ? {
                          ...varItem,
                          field: fieldName, 
                      }
                    : varItem
            );
            this.formatedTempBody = this.formatText(this.tempBody);
            this.updatePreviewContent(this.formatedTempBody, 'body');
        } catch (error) {
            console.error('Something went wrong while updating variable field.', error);
        }
    }    

    handleObjectChange(event){
        try {
            const selectedObject = event.target.value;
            this.selectedObject = selectedObject;

            // Update all object dropdowns to show the same selected value
            this.template.querySelectorAll('[data-name="objectPicklist"]').forEach(dropdown => {
                dropdown.value = selectedObject;
            });

            getObjectFields({ objectName: selectedObject })
                .then((result) => {
                    this.fields = result.map((field) => ({ label: field, value: field }));

                    // Update variables for both header and body
                    this.variables = this.variables.map(varItem => ({
                            ...varItem,
                            object: selectedObject,
                            field: this.fields[0].value
                    }));
        
                    this.header_variables = this.header_variables.map(varItem => ({
                            ...varItem,
                            object: selectedObject,
                            field: this.fields[0].value
                    }));
        
                    this.formatedTempBody = this.formatText(this.tempBody);
                    this.updateTextarea();
                    this.updatePreviewContent(this.header, 'header');
                    this.updatePreviewContent(this.formatedTempBody, 'body');
                })
                .catch((error) => {
                    console.error('Error fetching fields: ', error);
                });
        } catch (error) {
            console.error('Something went wrong while updating variable object.', error);
        }
    }

    handleAlternateVarChange(event) {
        const variableIndex = String(event.target.dataset.index);
        const alternateText = event.target.value;
        this.variables = this.variables.map(varItem =>
            String(varItem.index) === variableIndex
                ? { ...varItem, alternateText }
                : varItem
        );
    }

    updateTextarea() {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = this.tempBody;
        }
        textarea.focus();
    }

    handleVarRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const varIndexToRemove = parseInt(index, 10) + 1;
            const variableToRemove = `{{${varIndexToRemove}}}`;
            let updatedTempBody = this.tempBody.replace(variableToRemove, '');
            this.variables = this.variables.filter((_, i) => i !== parseInt(index));
            this.variables = this.variables.map((varItem, idx) => {
                const newIndex = idx + 1;
                return {
                    ...varItem,
                    id: newIndex,
                    index: `{{${newIndex}}}`
                };
            });
            
            let placeholders = updatedTempBody.match(/\{\{\d+\}\}/g) || [];
            placeholders.forEach((placeholder, idx) => {
                const newIndex = `{{${idx + 1}}}`;
                updatedTempBody = updatedTempBody.replace(placeholder, newIndex);
            });
            this.tempBody = updatedTempBody.trim();
            this.originalTempBody = this.tempBody;
            this.formatedTempBody=this.originalTempBody;
            this.updatePreviewContent(this.tempBody, 'body');
            this.nextIndex = this.variables.length + 1;
            if (this.variables.length === 0) {
                this.addVar = false;
                this.nextIndex = 1;
            }
            this.updateTextarea();
        } catch (error) {
            console.error('Something wrong while removing the variable.',error);
        }
    }
  
    // Header variable add-remove functionality start here
    addheadervariable() {
        try {
            this.addHeaderVar = true;
            const defaultField = this.fields[0].value;
            const newVariable = {
                id: this.headIndex,
                object: this.selectedObject,
                field: defaultField,
                alternateText: '',
                index: `{{${this.headIndex}}}`,        
            };

            this.header_variables = [...this.header_variables, newVariable];
            this.originalHeader = (this.originalHeader || this.header || '') + ` {{${this.headIndex}}}`;
            this.header = this.originalHeader;
            this.updatePreviewContent(this.header, 'header');
            this.headIndex++;
            this.buttonDisabled = true;
        } catch (error) {
            console.error('Error in adding header variables.',error); 
        } 
    }

    handleFieldChange(event) {
        try {
            // const variableId = event.target.dataset.id;
            const variableId = String(event.target.dataset.id); 
            const fieldName = event.target.value;
            this.header_variables = this.header_variables.map(varItem =>
            String(varItem.id) === variableId
                ? {
                        ...varItem,
                        field: fieldName,
                    }
                : varItem
            );
            this.updatePreviewContent(this.header, 'header');
        } catch (error) {
            console.error('Something wrong while header variable input.',error);
        }
    }

    handleAlternateTextChange(event) {
        const variableId = String(event.target.dataset.id); 
        const alternateText = event.target.value;
        this.header_variables = this.header_variables.map(varItem =>
            String(varItem.id) === variableId
                ? { ...varItem, alternateText } 
                : varItem
        );
    }

    updatePreviewContent(inputContent, type) {
        try {
            let updatedContent = inputContent;
            
            const variables = type === 'header' ? this.header_variables : this.variables;
            variables.forEach(varItem => {
                const variablePlaceholder = varItem.index; 
                const replacementValue = `{{${varItem.object}.${varItem.field}}}`;
    
                let index = updatedContent.indexOf(variablePlaceholder);
                while (index !== -1) {
                    updatedContent = updatedContent.slice(0, index) + replacementValue + updatedContent.slice(index + variablePlaceholder.length);
                    index = updatedContent.indexOf(variablePlaceholder, index + replacementValue.length); 
                }
            });
        
            if (type === 'header') {
                this.previewHeader = updatedContent;
            } else if (type === 'body') {
                this.previewBody = updatedContent;
            }
        } catch (error) {
            console.error('Something wrong while updating preview.',error);   
        }
    }

    handleHeaderVarRemove(event) {
        try {
            const index = event.currentTarget.dataset.index;
            const varIndexToRemove = parseInt(index, 10) + 1;
            const variableToRemove = `{{${varIndexToRemove}}}`;
            let updatedHeader = this.header.replace(variableToRemove, '');
            this.header_variables = this.header_variables.filter((_, i) => i !== parseInt(index));
            this.header_variables = this.header_variables.map((varItem, idx) => {
                const newIndex = idx + 1;
                return {
                    ...varItem,
                    id: newIndex,
                    index: `{{${newIndex}}}`,
                    placeholder: `Enter content for {{${newIndex}}}`
                };
            });
            let placeholders = updatedHeader.match(/\{\{\d+\}\}/g) || [];
            placeholders.forEach((placeholder, idx) => {
                const newIndex = `{{${idx + 1}}}`;
                updatedHeader = updatedHeader.replace(placeholder, newIndex);
            });
            this.header = updatedHeader.trim();
            this.originalHeader = this.header;
            this.updatePreviewContent(this.originalHeader, 'header');
            this.headIndex = this.header_variables.length + 1;
            if (this.header_variables.length === 0) {
                this.addHeaderVar = false;
                this.buttonDisabled = false;
                this.headIndex = 1;
            }
        } catch (error) {
            console.error('Something wrong while removing header variable.',error);   
        }
    }

    generateEmojiCategories() {
        try{
            fetch(emojiData)
            .then((response) => response.json())
            .then((data) => {
                let groupedEmojis = Object.values(
                    data.reduce((acc, item) => {
                        let category = item.category;
                        if (!acc[category]) {
                            acc[category] = { category, emojis: [] };
                        }
                        acc[category].emojis.push(item);
                        return acc;
                    }, {})
                );
        
                this.emojiCategories = groupedEmojis; 
            })
            .catch((e) => console.error('There was an error fetching the emoji.', e));
        }catch(e){
            console.error('Error in generateEmojiCategories', e);
        }
    }
    fetchCountries() {
        try{
            fetch(CountryJson)
            .then((response) => response.json())
            .then((data) => {
                this.countryType = data.map(country => {
                    return { label: `${country.name} (${country.callingCode})`, value: country.callingCode };
                });
            })
            .catch((e) => console.error('Error fetching country data:', e));
        }catch(e){
            console.error('Something wrong while fetching country data:', e);
        }
    }

    fetchLanguages() {
        try{
            fetch(LanguageJson)
            .then((response) => response.json())
            .then((data) => {
                this.languageOptions = data.map(lang => {
                    return { label: `${lang.language}`, value: lang.code, isSelected: lang.code === this.selectedLanguage  };
                });
                  if (!this.languageOptions.some(option => option.isSelected)) {
                    this.selectedLanguage = this.languageOptions[0]?.value || '';
                    if (this.languageOptions[0]) {
                        this.languageOptions[0].isSelected = true;
                    }
                }
            })
            .catch((e) => console.error('Error fetching language data:', e));
        }catch(e){
            console.error('Something wrong while fetching language data:', e);
        }
    }

    handleEmoji(event) {
        event.stopPropagation();        
        this.showEmojis = !this.showEmojis;
    
        if (this.showEmojis) {
            this.addOutsideClickListener();
        } else {
            this.removeOutsideClickListener();
        }    
    }
    
    handleEmojiSelection(event) {
        try {
            event.stopPropagation();        
            const emojiChar = event.target.textContent;    
            const textarea = this.template.querySelector('textarea');        
            const currentText = textarea.value || '';
            const cursorPos = textarea.selectionStart;
        
            const newText = currentText.slice(0, cursorPos) + emojiChar + currentText.slice(cursorPos);    
            this.tempBody = newText;
            this.formatedTempBody=this.tempBody;
            this.previewBody=this.formatedTempBody;
            textarea.value = newText;
        
            setTimeout(() => {
                const newCursorPos = cursorPos + emojiChar.length;    
                textarea.focus();    
                textarea.setSelectionRange(newCursorPos, newCursorPos);
            }, 0); 
        } catch (error) {
            console.error('Error in emoji selection.',error);
            
        }
    }
    
    handleFormat(event) {
        try {
            const button = event.target.closest('button');
            const formatType = button.dataset.format;
            
            const textarea = this.template.querySelector('textarea');
            const cursorPos = textarea.selectionStart;
            const currentText = textarea.value;
            let marker;
            let markerLength;
            switch (formatType) {
                case 'bold':
                    marker = '**';
                    markerLength = 1;
                    break;
                case 'italic':
                    marker = '__';
                    markerLength = 1;
                    break;
                case 'strikethrough':
                    marker = '~~';
                    markerLength = 1;
                    break;
                case 'codeIcon':
                    marker = '``````';
                    markerLength = 3;
                    break;
                default:
                    return;
            }
            const newText = this.applyFormattingAfter(currentText, cursorPos, marker);
            const newCursorPos = cursorPos + markerLength;
            this.tempBody = newText;
            this.updateCursor(newCursorPos);
        } catch (error) {
            console.error('Something wrong while handling rich text.',error);
        }
    }

    applyFormattingAfter(text, cursorPos, marker) {
        return text.slice(0, cursorPos) + marker + text.slice(cursorPos);
    }

    formatText(inputText) {
        try {
            inputText = inputText.replace(/(\n\s*){3,}/g, '\n\n');
            let formattedText = inputText.replaceAll('\n', '<br/>');
            formattedText = formattedText.replace(/\*(.*?)\*/g, '<b>$1</b>');
            formattedText = formattedText.replace(/_(.*?)_/g, '<i>$1</i>');
            formattedText = formattedText.replace(/~(.*?)~/g, '<s>$1</s>');
            formattedText = formattedText.replace(/```(.*?)```/g, '<code>$1</code>');
    
            return formattedText;
        } catch (error) {
            console.error('Error while returning formatted text.',error);
        }
    }

    updateCursor(cursorPos) {
        const textarea = this.template.querySelector('textarea');
        textarea.value = this.tempBody;
        textarea.focus();
        textarea.selectionStart = textarea.selectionEnd = cursorPos;
    }

    validateTemplate() {
        try {
            if (!this.templateName || this.templateName.trim() === '') {
                this.showToastError('Template Name is required');
                return false;
            }
        
            if (!this.selectedLanguage) {
                this.showToastError('Please select a language');
                return false;
            }
        
            if (!this.tempBody || this.tempBody.trim() === '') {
                this.showToastError('Template Body is required');
                return false;
            }
        
            const buttonData = [...this.buttonList, ...this.customButtonList];    
            for (let button of buttonData) {
                if (button.isVisitSite) {
                    if (!button.selectedUrlType || !button.webURL || !this.validateUrl(button.webURL)) {
                        this.showToastError('Please provide a valid URL that should be properly formatted (e.g., https://example.com)');
                        return false;
                    }
                } else if (button.isCallPhone) {
                    if (!button.selectedCountryType || !button.phonenum || !this.validatePhoneNumber(button.phonenum)) {
                        this.showToastError('Please provide a valid country and phone number for the "Call Phone Number" button');
                        return false;
                    }
                } else if (button.isOfferCode) {            
                    const alphanumericPattern = /^[a-zA-Z0-9]+$/;
                    if (!alphanumericPattern.test(button.offercode.trim())) {
                        this.showToastError('Offer code must only contain alphanumeric characters (letters and numbers)');
                        return false;
                    }
                }
        
                if (button.isCustom) {
                    if (!button.Cbtntext || button.Cbtntext.trim() === '') {
                        this.showToastError('Button text is required for the custom button');
                        return false;
                    }
                }
            }
            return true;
        } catch (error) {
            console.error('Something went wrong while validating template.',error);
            return false;
        }
       
    }
   
    validateUrl(value) {
        const urlPattern = new RegExp(
            '^(https?:\\/\\/)?(www\\.)?([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,6}($|\\/.*)$'
        );
        const isValid = urlPattern.test(value);
        return isValid;
    }    

    validatePhoneNumber(value) {
        const phonePattern = /^[0-9]{10,}$/;
        return phonePattern.test(value);
    }

    handleConfirm(){
        // this.iseditTemplatevisible=false
        this.showReviewTemplate=true;
    }
    handleCloseTemplate(){
        this.showReviewTemplate=false;
        this.iseditTemplatevisible=true;
        this.isLoading=false;
    }

    get isSubmitDisabled() {
        const currentTemplate = this.activeTab; 
    
        const areButtonFieldsFilled = this.buttonList.every(button => 
            button.btntext && (button.webURL || button.phonenum || button.offercode)
        );
        const areCustomButtonFilled = this.customButtonList.every(button => button.Cbtntext);

        const hasCustomButtonError = this.customButtonList.some(button => button.hasError);
        const hasButtonListError = this.buttonList.some(button => button.hasError);
        const headerImageNotSelected = this.selectedContentType === 'Image' && !this.headerHandle;
        const headerTextNotSelected = this.selectedContentType === 'Text' && !this.header;
        const hasHeaderError = !!this.headerError;

        const result = (() => {
        switch (currentTemplate) {
            case 'Marketing':
                return !(this.templateName && this.tempBody && this.isCheckboxChecked && areButtonFieldsFilled && areCustomButtonFilled && !this.templateExists && !hasCustomButtonError && !hasButtonListError && !headerImageNotSelected && !hasHeaderError && !headerTextNotSelected);    
            default:
                return true; 
        }
        })();
    
        return result; 
    }
     
    handleSubmit() {
        try {
            this.isLoading=true;
            this.showReviewTemplate = false;
            if (!this.validateTemplate()) {
                this.isLoading=false;

                return;
            }     
            const buttonData = [];

            if (this.buttonList && this.buttonList.length > 0) {
                buttonData.push(...this.buttonList);
            }

            if (this.customButtonList && this.customButtonList.length > 0) {
                buttonData.push(...this.customButtonList);
            }
            const template = {
                templateName: this.templateName ? this.templateName : null,
                templateCategory: this.activeTab ? this.activeTab : null,
                templateType: this.selectedOption ? this.selectedOption : null,
                tempHeaderFormat: this.selectedContentType ? this.selectedContentType : null,
                tempHeaderHandle: this.headerHandle ? this.headerHandle : null,
                tempImgUrl:this.imageurl ? this.imageurl : null,
                tempImgId:this.contentDocumentId ? this.contentDocumentId : null,
                tempImgName:this.fileName ? this.fileName : null,
                tempLanguage: this.selectedLanguage ? this.selectedLanguage : null,
                tempHeaderText: this.header ? this.header : '',
                tempHeaderExample: (this.tempHeaderExample && this.tempHeaderExample.length > 0) ? this.tempHeaderExample : null,
                headAlternateTexts: this.header_variables.map(varItem => varItem.alternateText || null),
                varAlternateTexts: this.variables.map(varItem => varItem.alternateText || null),
                templateBody: this.tempBody ? this.tempBody : '',
                templateBodyText: (this.templateBodyText && this.templateBodyText.length > 0) ? this.templateBodyText : null,
                tempFooterText: this.footer ? this.footer : null,
                typeOfButton: buttonData.length > 0 ? JSON.stringify(buttonData) : null 
            };

            const serializedWrapper = JSON.stringify(template);
            if(this.metaTemplateId){
                editWhatsappTemplate({ serializedWrapper: serializedWrapper,templateId:this.metaTemplateId })
                .then(result => {
                    if (result && result.success) { 
                        this.showToastSuccess('Template successfully edited.');
                        this.isAllTemplate=true;
                        this.iseditTemplatevisible=false;
                        this.isLoading=false;
                        const templateId = result.templateId;  
                        this.templateId = templateId;
                        this.fetchUpdatedTemplates();
                    } else {
                        const errorResponse = JSON.parse(result.errorMessage); 
                        const errorMsg = errorResponse.error.error_user_msg || 'Due to unknown error'; 
            
                        this.showToastError('Template updation failed, reason - '+errorMsg);
                        this.isLoading = false; 
                    }
                })
                .catch(error => {
                    console.error('Error creating template', error);
                    const errorTitle = 'Template creation failed: ';
                    let errorMsg;        
                    if (error.body && error.body.message) {
                        if (error.body.message.includes('Read timed out')) {
                            errorMsg = 'The request timed out. Please try again.';
                        } else {
                            errorMsg = error.body.message.error_user_title || 'An unknown error occurred';
                        }
                    } else {
                        errorMsg = 'An unknown error occurred';
                    }
                
                    this.showToastError(errorTitle, errorMsg);
                    this.isLoading = false;
                });
                
            }else{
                createWhatsappTemplate({ serializedWrapper: serializedWrapper })
                .then(result => {
                    if (result && result.success) { 
                        this.showToastSuccess('Template successfully created');
                        this.isAllTemplate=true;
                        this.iseditTemplatevisible=false;
                        this.isLoading=false;
                        const templateId = result.templateId;  
                        this.templateId = templateId;
                        this.fetchUpdatedTemplates();
                        // this.clearWrapper();
                    } else {
                        const errorResponse = JSON.parse(result.errorMessage); 
                        const errorMsg = errorResponse.error.error_user_msg || errorResponse.error.message || 'Due to unknown error'; 
            
                        this.showToastError('Template creation failed, reason - '+errorMsg);
                        this.isLoading = false; 
                    }
                })
                .catch(error => {
                    console.error('Error creating template', error);
                    const errorTitle = 'Template creation failed: ';
                    let errorMsg;        
                    if (error.body && error.body.message) {
                        if (error.body.message.includes('Read timed out')) {
                            errorMsg = 'The request timed out. Please try again.';
                        } else {
                            errorMsg = error.body.message.error_user_title || 'An unknown error occurred';
                        }
                    } else {
                        errorMsg = 'An unknown error occurred';
                    }
                
                    this.showToastError(errorTitle, errorMsg);
                    this.isLoading = false;
                });
               
            }
           

        } catch (error) {
            console.error('Unexpected error occurred', error);
            this.showToastError('An unexpected error occurred while submitting the template.');
            this.isLoading = false;
        }       
    }

    fetchUpdatedTemplates(dispatchEvent = true) {
        getWhatsAppTemplates()
            .then(data => {
                this.allTemplates = data; 
                if (dispatchEvent) {
                    const event = new CustomEvent('templateupdate', { detail: data });
                    this.dispatchEvent(event);
                }
            })
            .catch(error => {
                console.error('Error fetching templates:', error);
                this.showToastError('Failed to fetch updated templates.');
            });
    }
    
    showToastError(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
    }

    showToastSuccess(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success'
        });
        this.dispatchEvent(toastEvent);
    }
    
    closePreview() {
        this.isLoading = true;     
        setTimeout(() => {
            this.isLoading = false; 
            this.isPreviewTemplate = false;
            // this.clearWrapper();
            this.iseditTemplatevisible = false;
            this.isAllTemplate = true;
        }, 2000);
    }  

    // --------------custom dropdown-----------

    getButtonPath(iconName) {
        return `${buttonIconsZip}/button-sectionIcons/${iconName}.png`;
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
        if (this.isDropdownOpen) {
            this.addOutsideClickListener();
        } else {
            this.removeOutsideClickListener();
        }
        this.dropdownClass = this.isDropdownOpen ? 'dropdown-visible' : 'dropdown-hidden';
    }
 
    dropdownOptions = [
        { title: 'Custom', value: 'QUICK_REPLY', iconName: 'custom' },
        { title: 'Marketing Opt-Out', value: 'Marketing opt-out', iconName: 'marketing',description:'Maximum 1 button can be added' },
        { title: 'Call Phone Number', value: 'PHONE_NUMBER', iconName: 'phone', description:'Maximum 1 button can be added'},
        { title: 'Visit Website', value: 'URL', iconName: 'site',description:'Maximum 2 button can be added' },
        { title: 'Copy Offer Code', value: 'COPY_CODE', iconName: 'copy',description:'Maximum 1 button can be added' }
    ];

    get quickReplyOptions() {
        return this.dropdownOptions
            .filter(option => option.value === 'QUICK_REPLY' || option.value === 'Marketing opt-out')
            .map(option => ({
                ...option,
                iconUrl: this.getButtonPath(option.iconName), 
                classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}` 
            }));
    }
    
    get callToActionOptions() {
        return this.dropdownOptions
            .filter(option => option.value === 'PHONE_NUMBER' || option.value === 'URL' || option.value === 'COPY_CODE')
            .map(option => ({
                ...option,
                iconUrl: this.getButtonPath(option.iconName), 
                classes: `dropdown-item ${option.title.toLowerCase().replace(/\s+/g, '-')}` 
            }));
    }
    
}