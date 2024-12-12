/*
 * Component Name: WbCreateTemplatePage
 * @description: Used LWC components to show create templates in meta and store in the template record.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 2/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : closePreview
 * Change Description : Added functionality to redirect the first page as close the preview. Also remove some div as per the figma till confirmation.
 ********************************************************************** */

import { LightningElement, track, wire } from 'lwc';
import {loadStyle} from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import wbCreateTempStyle from '@salesforce/resourceUrl/wbCreateTempStyle';
import richTextZip from '@salesforce/resourceUrl/richTextZip';
import buttonIconsZip from '@salesforce/resourceUrl/buttonIconsZip';
import getCountryCodes from '@salesforce/apex/WBTemplateController.getCountryCodes';
import getLanguages from '@salesforce/apex/WBTemplateController.getLanguages';
import emojiData from '@salesforce/resourceUrl/emoji_data';
// import getEmojiData from '@salesforce/apex/EmojiDataController.getEmojiData';
import doesTemplateExist from '@salesforce/apex/WBTemplateController.doesTemplateExist';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import createWhatsappTemplate from '@salesforce/apex/WBTemplateController.createWhatsappTemplate';
import startUploadSession from '@salesforce/apex/WBTemplateController.startUploadSession';
import uploadFileChunk from '@salesforce/apex/WBTemplateController.uploadFileChunk';
import getObjectFields from '@salesforce/apex/WBTemplateController.getObjectFields';

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
    @track isDefault=true;
    @track isLoading=false;
    @track templateExists=false;
    @track showEmojis = false;
    @track isCheckboxChecked=true;   
    @track showDefaultBtn=true;
    @track templateName = '';
    @track storedTemplateName = 'your_template_name';
    @track header = '';
    @track footer = '';
    @track tempBody = 'Hello';
    // formattedText = '';
    @track formatedTempBody=this.tempBody;
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
    @track selectedObject = 'Contact';
    @track fields = [];
    @track chatMessages = [];
    @track richTextZip = richTextZip;
    @track buttonIconsZip =buttonIconsZip;
    @track toolbarButtons=[];
    @track isDropdownOpen = false;
    @track dropdownClass = 'dropdown-hidden';
    @track emojiCategories=[];
    @track templateId='';
    // @track contentdocumentId='';

    get acceptedFormats() {
        return ['png','jpeg','jpg'];
    }

    get TypeOptions() {
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

    connectedCallback() {
        console.log('default option selected==> ' + this.selectedOption);       
        this.fetchCountries();
        this.fetchLanguages();
        this.fetchFields();
        this.generateEmojiCategories();
    }
    

    renderedCallback() {
        loadStyle(this, wbCreateTempStyle).then(() => {
            console.log("Loaded Successfully")
        }).catch(error => {
            console.error("Error in loading the colors",error)
        })
    }

    @wire(getWhatsAppTemplates)
    wiredWhatsAppTemplates({ error, data }) {
        if (data) {
            console.log('Templates fetched successfully', data);
            // this.isLoading=false;
        } else if (error) {
            console.error('Error fetching templates:', error);
            // this.isLoading=false;
            this.showToastError('Failed to refresh template list');
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
    }

    fetchFields() {
        getObjectFields()
            .then((result) => {
                this.fields = result.map((field) => ({ label: field, value: field }));
            })
            .catch((error) => {
                console.error('Error fetching fields: ', error);
            });
    }


    fetchCountries() {
        getCountryCodes()
            .then(result => {
                this.countryType = result.map(country => {
                    return { label: `${country.name} (${country.callingCode})`, value: country.callingCode };
                });
            })
            .catch(error => {
                console.error('Error fetching country data:', error);
            });
    }
    fetchLanguages() {
        getLanguages()
            .then(result => {
                this.languageOptions = result.map(lang => {
                    return { label: `${lang.language}`, value: lang.code, isSelected: lang.code === this.selectedLanguage  };
                });
                  if (!this.languageOptions.some(option => option.isSelected)) {
                    this.selectedLanguage = this.languageOptions[0]?.value || '';
                    if (this.languageOptions[0]) {
                        this.languageOptions[0].isSelected = true;
                    }
                }
            })
            .catch(error => {
                console.error('Error fetching language data:', error);
            });
    }

    handleFileChange(event) {
        try {
            console.log('enter in function');
            
            const fileInput = event.target.files[0];
            if (!fileInput) {
                throw new Error('No file selected. Please choose a file.');
            }

            this.file = fileInput;
            this.fileName = fileInput.name;
            this.fileSize = fileInput.size;
            this.fileType = fileInput.type;
    
            console.log('Selected File:', fileInput);
    
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
            this.showToastError(error.message || 'An error occurred while processing the file.');
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
        this.isImgSelected=false;
        this.isVidSelected=false;
        this.isDocSelected=false;
        if(this.isImageFileUploader==true){
            this.isImageFile=true;
        }
    }

    generatePreview(file) {
        if (file.type.startsWith('image/')) {
            this.isImgSelected = true;
            this.isImageFile = false;
    
            const reader = new FileReader();
            reader.onload = () => {
                this.filePreview = reader.result; 
            };
            reader.readAsDataURL(file);
        } 
    }
    
    uploadFile() {
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
                console.log('result ',result);
                
                if (result) {
                    this.uploadSessionId = result;
                    console.log('Upload session started with ID: ', this.uploadSessionId);
    
                    this.uploadChunks();
                } else {
                    console.error('Failed to start upload session.');
                }
            })
            .catch(error=>{
                console.error('Failed upload session.', error.body);

            })
        } catch (error) {
            console.error('Error starting upload session: ', error);
        }
    }

    uploadChunks() {
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
                
                try {
                    uploadFileChunk({serializedWrapper:serializedWrapper})
                    .then(result=>{
                        console.log('result ',result);
                        if (result) {
                            let serializeResult = JSON.parse(result); 
                            this.headerHandle = serializeResult.headerHandle;
                            this.imageurl = serializeResult.imageurl;
                            console.log('headerHandle ',this.headerHandle);
                            console.log('imageurl ',this.imageurl);

                            chunkStart += this.chunkSize;
                            if (chunkStart < this.fileSize) {
                                uploadNextChunk(); 
                            } else {
                                console.log('File upload completed.');
                            }
                        } else {
                            console.error('Failed to upload file chunk.');
                        }
                    })
                    .catch(error=>{
                        console.error('Failed upload session.', error);
                        this.showToastError(error.body.message || 'An error occurred while uploading image.');
                    })
                } catch (error) {
                    console.error('Error uploading file chunk: ', error);
                }
            };

            reader.readAsDataURL(chunk); 
        };

        uploadNextChunk();
    }


    handleContentType(event) {
        this.NoFileSelected=true;
        this.isfilename=false;
        this.selectedContentType = event.target.value;
        console.log(this.selectedContentType);

        if (this.selectedContentType == 'Text') {
            this.IsHeaderText = true;
        } else {
            this.IsHeaderText = false;
        }
        if (this.selectedContentType == 'Image') {
                this.isImgSelected = false;
                this.isImageFileUploader=true;
                this.isImageFile = true;
                this.addMedia = true;
        } else {
            this.isImageFile = false;
            this.isImageFileUploader=false
            this.addMedia = false;
            this.isImgSelected = false;
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
        this.storedTemplateName = 'your_template_name';
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
                if (!this.validateUrl(value)) {
                    this.showToastError('URL should be properly formatted (e.g., https://example.com)');
                }
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
                break;
            default:
                break;
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
            doesTemplateExist({ templateName: this.templateName })
                .then(result => {
                    this.templateExists = result;
                    if (this.templateExists) {
                        console.log('Template already exists.');
                    } else {
                        console.log('Template does not exist. Proceed with creation.');
                    }
                })
                .catch(error => {
                    throw new Error(`Error checking template existence: ${error.message || 'Unknown error'}`);
                });
        } catch (error) {
            console.error(error.message);
            this.showToastError(error.message || 'An error occurred while checking template existence.');
        }
    }

    handleStoredname() {
        if (this.templateName == '') {
            this.storedTemplateName = 'your_template_name';
        } else {
            this.storedTemplateName = this.templateName;
        }
    }

    handleRemove(event) {
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
        console.log('remaining ', this.buttonList.length);
        if (this.buttonList.length == 0) {
            this.createButton = false;
        }
        this.totalButtonsCount--;
        console.log('after remove: ', this.totalButtonsCount);
        this.updateButtonDisabledState();
    }

    handleMenuSelect(event) {
        try {
            // const selectedValue = event.detail.value;
            const selectedValue = event.currentTarget.dataset.value; 
            this.menuButtonSelected = selectedValue;
            console.log('selectedValue ', selectedValue);
        
            let newButton = {
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
                    this.createCustomButton('QUICK_REPLY', 'Quick reply');
                    this.isStopMarketing = false;
                    break;
                case 'Marketing opt-out':
                    if (this.marketingOpt < 1) {
                        this.isCustom = true;
                        this.isStopMarketing = true;
                        this.createCustomButton('Marketing opt-out', 'Stop promotions');
                        this.marketingOpt++;
                    }
                    break;
                case 'PHONE_NUMBER':
                    if (this.callPhoneNumber < 1) {
                        this.createButton = true;
                        newButton.isCallPhone = true;
                        newButton.btntext = 'Call Phone Number';
                        this.btntext = 'Call Phone Number';
                        this.callPhoneNumber++;
                    }
                    break;
                case 'URL':
                    if (this.visitWebsiteCount < 2) {
                        this.createButton = true;
                        newButton.isVisitSite = true;
                        this.isVisitSite = true;
                        newButton.btntext = 'Visit Website';
                        this.btntext = 'Visit Website';
                        this.visitWebsiteCount++;
                    }
                    break;
                case 'COPY_CODE':
                    if (this.copyOfferCode < 1) {
                        this.createButton = true;
                        newButton.isOfferCode = true;
                        newButton.btntext = 'Copy Offer Code';
                        this.btntext = 'Copy Offer Code';
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
                console.log('Button added. Total buttons count:', this.totalButtonsCount);
            }
        
            this.updateButtonErrors();
            this.updateButtonDisabledState();
            console.log('newbutton ', newButton.id, newButton.selectedActionType);
            console.log('added ', this.buttonList.length);
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
            console.log('Custom button added. Total buttons count:', this.totalButtonsCount);
            this.updateButtonDisabledState();
        } catch (error) {
            console.error('Error creating custom button:', error);
        }
    }
    
    get buttonListWithDisabledState() {
        return this.customButtonList.map(button => ({
            ...button,
            isDisabled: button.selectedCustomType === 'Marketing opt-out'
        }));
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

    handleButtonClick(event) {
        const buttonId = event.currentTarget.dataset.id;
        console.log('Button ID:', buttonId);
    
        const clickedButton = this.customButtonList.find(button => button.id == buttonId);
        console.log('Clicked Button:', clickedButton);
    
        if (clickedButton) {
            if (clickedButton.isDisabled) {
                console.log('Button is already disabled.');
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
        }
    }    

    handleCustomText(event) {
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
    }
    

    handleRemoveCustom(event) {
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
    }    

    get buttonClass() {
        return this.isButtonDisabled ? 'select-button disabled' : 'select-button';
    }

    updateButtonDisabledState() {
        this.isDropdownOpen=false;
        this.isButtonDisabled = this.totalButtonsCount >= 1;
        this.buttonList.forEach(button => {
            button.isDisabled = button.selectedActionType === 'COPY_CODE';
        });
        console.log('Button disabled state:', this.isButtonDisabled);
    }

    refreshTempPreview(){
        this.customButtonList = this.customButtonList.map(button => {
            return {
                ...button,
                isDisabled: false, 
                buttonClass: 'button-label-preview' 
            };
        });
        this.chatMessages = [];
    }

    addvariable() {
        this.addVar = true;
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
        this.formatedTempBody=this.tempBody;
        console.log('this.tempBody after adding variable:', this.tempBody);
        this.updateTextarea();
        this.nextIndex++;
    }

    handleVarFieldChange(event) {
        const variableId = event.target.dataset.id;
        const fieldName = event.target.value;
        this.updateVarField(variableId, fieldName);
    }

    handleAlternateVarChange(event) {
        const variableId = event.target.dataset.id;
        const alternateText = event.target.value;
        console.log('alternateText for body ',alternateText);
        
        this.updateAlternateText(variableId, alternateText);
    }

    updateVarField(variableId, fieldName) {
        this.variables = this.variables.map(varItem =>
            varItem.id === parseInt(variableId)
                ? {
                      ...varItem,
                      field: fieldName,
                      index: `{{Contact.${fieldName}}}` 
                  }
                : varItem
        );
    }

    updateAlternateText(variableId, alternateText) {
        this.variables = this.variables.map(varItem =>
            varItem.id === parseInt(variableId)
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
        const index = event.currentTarget.dataset.index;
        const varIndexToRemove = parseInt(index, 10) + 1;
        const variableToRemove = `{{${varIndexToRemove}}}`;
        // console.log('Removing variable:', variableToRemove);
        let updatedTempBody = this.tempBody.replace(variableToRemove, '');
        // console.log('updatedTempBody after removing variable:', updatedTempBody);
        this.variables = this.variables.filter((_, i) => i !== parseInt(index));
        this.variables = this.variables.map((varItem, idx) => {
            const newIndex = idx + 1;
            return {
                ...varItem,
                id: newIndex,
                index: `{{${newIndex}}}`,
                placeholder: `Enter content for {{${newIndex}}}`
            };
        });
        let placeholders = updatedTempBody.match(/\{\{\d+\}\}/g) || [];
        placeholders.forEach((placeholder, idx) => {
            const newIndex = `{{${idx + 1}}}`;
            updatedTempBody = updatedTempBody.replace(placeholder, newIndex);
        });
        // console.log('newTempBody after re-indexing:', updatedTempBody);
        this.tempBody = updatedTempBody.trim();
        this.originalTempBody = this.tempBody;
        this.formatedTempBody=this.originalTempBody;
        // console.log('this.tempBody after re-indexing:', this.tempBody);
        this.nextIndex = this.variables.length + 1;
        if (this.variables.length === 0) {
            this.addVar = false;
            this.nextIndex = 1;
        }
        this.updateTextarea();
    }

    // Header variable add-remove functionality start here
    addheadervariable() {
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
        this.headIndex++;
        this.buttonDisabled = true;
    }

    handleFieldChange(event) {
        const variableId = event.target.dataset.id;
        const fieldName = event.target.value;
        this.updateVariableField(variableId, fieldName);
    }

    updateVariableField(variableId, fieldName) {
        this.header_variables = this.header_variables.map(varItem =>
            varItem.id === parseInt(variableId)
                ? {
                      ...varItem,
                      field: fieldName,
                      index: `{{Contact.${fieldName}}}` 
                  }
                : varItem
        );
    }

    handleAlternateTextChange(event) {
        const variableId = event.target.dataset.id;
        const alternateText = event.target.value;
        this.updateVariableAlternateText(variableId, alternateText);
    }
  
    updateVariableAlternateText(variableId, alternateText) {
        this.header_variables = this.header_variables.map(varItem =>
            varItem.id === parseInt(variableId)
                ? { ...varItem, alternateText } 
                : varItem
        );
    }
    

    handleHeaderVarRemove(event) {
        const index = event.currentTarget.dataset.index;
        const varIndexToRemove = parseInt(index, 10) + 1;
        const variableToRemove = `{{${varIndexToRemove}}}`;
        console.log('Removing variable:', variableToRemove);
        let updatedHeader = this.header.replace(variableToRemove, '');
        console.log('updatedHeader after removing variable:', updatedHeader);
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
        console.log('newTempBody after re-indexing:', updatedHeader);
        this.header = updatedHeader.trim();
        this.originalHeader = this.header;
        console.log('this.header after re-indexing:', this.header);
        this.headIndex = this.header_variables.length + 1;
        if (this.header_variables.length === 0) {
            this.addHeaderVar = false;
            this.buttonDisabled = false;
            this.headIndex = 1;
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
            .catch((e) => console.log('There was an error fetching the emoji.', e));
        }catch(e){
            console.log('Error in generateEmojiCategories', e);
            
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
        event.stopPropagation();        
        const emojiChar = event.target.textContent;    
        const textarea = this.template.querySelector('textarea');        
        const currentText = textarea.value || '';
        const cursorPos = textarea.selectionStart;
    
        const newText = currentText.slice(0, cursorPos) + emojiChar + currentText.slice(cursorPos);    
        this.tempBody = newText;
        textarea.value = newText;
    
        setTimeout(() => {
            const newCursorPos = cursorPos + emojiChar.length;    
            textarea.focus();    
            textarea.setSelectionRange(newCursorPos, newCursorPos);
        }, 0); 
    }
    
    handleFormat(event) {
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
            case 'code':
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
    }

    applyFormattingAfter(text, cursorPos, marker) {
        return text.slice(0, cursorPos) + marker + text.slice(cursorPos);
    }

    formatText(inputText) {
        inputText = inputText.replace(/(\n\s*){3,}/g, '\n\n');

        let formattedText = inputText.replaceAll('\n', '<br/>');
        formattedText = formattedText.replace(/\*(.*?)\*/g, '<b>$1</b>');
        formattedText = formattedText.replace(/_(.*?)_/g, '<i>$1</i>');
        formattedText = formattedText.replace(/~(.*?)~/g, '<s>$1</s>');
        formattedText = formattedText.replace(/```(.*?)```/g, '<code>$1</code>');

        return formattedText;
    }

    updateCursor(cursorPos) {
        const textarea = this.template.querySelector('textarea');
        textarea.value = this.tempBody;
        textarea.focus();
        textarea.selectionStart = textarea.selectionEnd = cursorPos;
    }

    get tempHeaderExample() {
        console.log('Generating header example...');
        return this.header_variables.map(varItem => `{{${varItem.object}.${varItem.field}}}`);
    }

    get templateBodyText() {
        return this.variables.map(varItem => `{{${varItem.object}.${varItem.field}}}`);
    }

    validateTemplate() {
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
                console.log('Validating URL:', button.webURL);
                if (!button.selectedUrlType || !button.webURL || !this.validateUrl(button.webURL)) {
                    this.showToastError('Please provide a valid URL and URL type for the "Visit Website" button');
                    return false;
                }
            } else if (button.isCallPhone) {
                if (!button.selectedCountryType || !button.phonenum || !this.validatePhoneNumber(button.phonenum)) {
                    this.showToastError('Please provide a valid country and phone number for the "Call Phone Number" button');
                    return false;
                }
            } else if (button.isOfferCode) {
                if (!button.offercode || button.offercode.trim() === '') {
                    this.showToastError('Please provide an offer code for the "Copy Offer Code" button');
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
    }
    
   validateUrl(value) {
        const urlPattern = new RegExp('^(https?:\\/\\/)?(www\\.)?([a-zA-Z0-9\\-]+\\.)+[a-zA-Z]{2,}.*$');
        const isValid = urlPattern.test(value);
        console.log('Is valid URL:', isValid);
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
    
        const result = (() => {
        switch (currentTemplate) {
            case 'Marketing':
                return !(this.templateName && this.tempBody && this.isCheckboxChecked && areButtonFieldsFilled && areCustomButtonFilled && !this.templateExists && !hasCustomButtonError && !hasButtonListError);    
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
            console.log('button data ',JSON.stringify(buttonData));
            const template = {
                templateName: this.templateName ? this.templateName : null,
                templateCategory: this.activeTab ? this.activeTab : null,
                templateType: this.selectedOption ? this.selectedOption : null,
                tempHeaderFormat: this.selectedContentType ? this.selectedContentType : null,
                tempHeaderHandle: this.headerHandle ? this.headerHandle : null,
                // tempContentDocId:  this.contentdocumentId ? this.contentdocumentId : null,
                tempImgUrl:this.imageurl ? this.imageurl : null,
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

            console.log('Template Wrapper:', JSON.stringify(template));
            const serializedWrapper = JSON.stringify(template);
        
            createWhatsappTemplate({ serializedWrapper: serializedWrapper })
            .then(result => {
                if (result && result.success) { 
                    console.log('Template created successfully', result);
                    this.showToastSuccess('Template successfully created');
                    this.isPreviewTemplate=true;
                    this.isLoading=false;
                    const templateId = result.templateId;  
                    this.templateId = templateId;
                    console.log('temp id==> ',this.templateId);
                    
                    // this.clearWrapper();
                } else {
                    const errorResponse = JSON.parse(result.errorMessage); 
                    const errorMsg = errorResponse.error.error_user_msg || 'Due to unknown error'; 
        
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

        } catch (error) {
            console.error('Unexpected error occurred', error);
            this.showToastError('An unexpected error occurred while submitting the template.');
            this.isLoading = false;
        }       
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

    toggleDropdown() {
        this.isDropdownOpen = !this.isDropdownOpen;
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