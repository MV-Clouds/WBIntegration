import { LightningElement, track, wire } from 'lwc';
import createWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.createWhatsAppFlow';
import publishWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.publishWhatsAppFlow';
import deleteWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deleteWhatsAppFlow';
import deprecateWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.deprecateWhatsAppFlow';
import getPreviewURLofWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.getPreviewURLofWhatsAppFlow';
import FlowIcon from '@salesforce/resourceUrl/FlowIcon';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import MonacoEditor from '@salesforce/resourceUrl/MonacoEditor';
import PublishPopupImage from '@salesforce/resourceUrl/PublishPopupImage';
import getJSONData from '@salesforce/apex/WhatsAppFlowController.getJSONData';
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';

export default class CreateFlowManagement extends LightningElement {
    @track selectedCategories = [];
    @track showLicenseError = false;

    status = 'Initialize';
    editor;
    templateType = 'Default';
    jsonString = '';
    isFlowVisible = true;
    isCreateDisabled = true;
    publishImageUrl = PublishPopupImage;
    iscreateflowvisible = true; 
    dropdownClose = true;
    showPublishPopup = false;
    showDeletePopup = false;
    showDeprecatePopup = false;
    isJsonVisible=false;
    flowName = '';
    flowId = '';
    flowPreviewURL = '';
    maxFlowNamelength = 200;
    flowIconUrl = FlowIcon;
    isLoading = false;
    flows = [];

    get TypeOptions() {
        return [
            { label: 'Sign up', value: 'SIGN_UP' },
            { label: 'Sign in', value: 'SIGN_IN' },
            { label: 'Appointment booking', value: 'APPOINTMENT_BOOKING' },
            { label: 'Lead generation', value: 'LEAD_GENERATION' },
            { label: 'Shopping', value: 'SHOPPING' },
            { label: 'Contact us', value: 'CONTACT_US' },
            { label: 'Customer support', value: 'CUSTOMER_SUPPORT' },
            { label: 'Survey', value: 'SURVEY' },
            { label: 'Other', value: 'OTHER' }
        ];
    }

    get isSaveEnabled(){
        return this.status == 'Initialize' ? true : false;
    }

    get isPublishedEnabled(){
        return this.status == 'Draft' ? true : false;
    }

    get isDeleteEnabled(){
        return this.status == 'Draft' ? true : false;
    }

    get isDeprecateEnabled(){
        return this.status == 'Published' ? true : false;
    }

    async connectedCallback(){
        try {
            this.showSpinner = true;
            await this.checkLicenseStatus();
            if (this.showLicenseError) {
                return; // Stops execution if license is expired
            }
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    async checkLicenseStatus() {
        try {
            const isLicenseValid = true;
            if (!isLicenseValid) {
                this.showLicenseError = true;
            }
        } catch (error) {
            console.error('Error checking license:', error);
        }
    }

    handleTypeChange(event) {
        this.templateType = event.target.value;
    }

    handleInputChange(event){
        try {
            this.flowName = event.target.value;  
            if (this.selectedCategories.length > 0 && this.flowName.trim()) {
                this.isCreateDisabled = false;
            } else {
                this.isCreateDisabled = true;
            }
        } catch (error) {
            console.error('Error in handleInputChange : ' , error);
        }
    }

    handleDiscard() {
        this.isFlowVisible = false;
    }
  
    handleCatagories(event) {
        try {
            const selectedCategories = event.detail.selectedValues;
            this.selectedCategories = selectedCategories;
    
            if (this.selectedCategories.length > 0 && this.flowName.trim()) {
                this.isCreateDisabled = false;
            } else {
                this.isCreateDisabled = true;
            }
        } catch (error) {
            console.error('Error in handleCategories : ' , error);
        }
    }
  
    handleCreate(){
        this.getJSONDataFromApex();
    }

    get formatDate(){
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const today = new Date();
        const day = today.getDate();
        const month = months[today.getMonth()];
        const year = today.getFullYear();
        return `Updated ${day} ${month} ${year}`;
    }

    getJSONDataFromApex(){
        try {
            this.isLoading = true;
            getJSONData({type: this.templateType})
                .then((data) => {
                    if(data){
                        this.jsonString = data;
                        this.formatJSONDataonUI();
                        // this.getFlowPreview();
                    } else {
                        console.error('Error loading JSON data:', error);
                        this.showToast('Error', 'Failed to load Flow JSON data', 'error');
                        this.isLoading = false;
                    }
                })
                .catch((error) => {
                    console.error('error in json fetch' , error);
                    this.showToast('Error', 'Failed to load Flow JSON data', 'error');
                    this.isLoading = false;
                });
        } catch (error) {
            console.error('Error loading JSON data:', error);
            this.showToast('Error', 'Failed to load Flow JSON data', 'error');
            this.isLoading = false;
        }
    }

    formatJSONDataonUI(){
        try {
            this.isLoading = true;
            this.isJsonVisible = true;
            this.iscreateflowvisible = false; 
            loadScript(this, MonacoEditor + '/min/vs/loader.js')
            .then(() => {
                require.config({ paths: { vs: MonacoEditor + '/min/vs' } });
                require(['vs/editor/editor.main'], () => {
                    this.initializeEditor();
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading Monaco Editor:', error);
                this.isLoading = false;
            })
        } catch (error) {
            console.error('Error loading Monaco Editor:', error);
            this.isLoading = false;
        }
    }
    
    initializeEditor() {
        try {
            this.editor = monaco.editor.create(this.template.querySelector('.editor'), {
                value: this.jsonString,
                language: 'json',
                theme: 'vs-light',
                automaticLayout: true,
                readOnly: false,
                minimap: { enabled: false }
            });
    
            this.editor.onDidChangeModelContent(() => {
                this.jsonString = this.editor.getValue();
            });
            this.isLoading = false;
        } catch (error) {
            console.error('Error in initializing Editor:', error);
            this.isLoading = false;
        }
    }

    getFlowPreview(){
        try {
            if(this.flowId != '') {
                this.isLoading = true;
                getPreviewURLofWhatsAppFlow({ flowId : this.flowId })
                    .then((data) => {
                        if(data != 'failed'){
                            this.flowPreviewURL = data;
                        } else {
                            console.error('Error in getting Flow Preview URL:', error);
                        }
                    })
                    .catch(error => {
                        console.error('Error in getting Flow Preview URL:', error);
                    })
                    .finally(() => {
                        this.isLoading = false;
                    });
            } else {
                console.error('Flow id not found');
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error in getting Flow Preview URL:', error);
            this.isLoading = false;
        }
    }

    onRunClick() {
        try {
            console.log('template type==> ',this.templateType);
            
            this.isLoading = true;
            this.jsonString = this.editor.getValue();
            console.log('json string in on run click==> ',this.jsonString);
            // updateJson({jsonPayload: this.jsonString});
            // Save the current JSON to the database
            // saveWhatsAppFlow({jsonPayload: this.jsonString});
            
            // Validate JSON in the editor
            const model = this.editor.getModel();
            const markers = monaco.editor.getModelMarkers({ owner: 'json' }); // Get JSON-specific markers

            const errorMarkers = markers.filter(marker => marker.severity === monaco.MarkerSeverity.Error);
            if (errorMarkers.length > 0) {
                console.log('Errors found in JSON:', errorMarkers);
                this.showToast('Error', 'Invalid JSON: Please fix the syntax errors in the editor', 'error');
                this.isLoading = false;
                return;
            }

            const previewComponent = this.template.querySelector('c-wb-flow-preview');
            if (previewComponent) {
                previewComponent.runPreview(); 
            } else {
                console.error('WbPreviewFlow component not found');
            }

            // If no errors, proceed with getting the flow preview
            console.log('No errors found in JSON');
            this.getFlowPreview();
        } catch (error) {
            console.error('Error validating JSON:', error);
            this.showToast('Error', 'Failed to validate JSON', 'error');
            this.isLoading = false;
        }
    }

    onPublishClick(){
        this.showPublishPopup = true;
    }

    // Close Popup
    closePublishPopup() {
        this.showPublishPopup = false;
    }

    // Handle Publish Button Click
    handlePublish() {
        try {
            this.isLoading = true;
            this.showPublishPopup = false;
            publishWhatsAppFlow({flowId : this.flowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.showToast('Success', 'Flow published successfully', 'success');
                        this.status='Published';
                        this.isFlowVisible = false;
                    } else {
                        console.error('Error in publishing WhatsApp Flow:', error);
                    }
                })
                .catch((error) => {
                    this.showToast('Error', 'Failed to publish flow', 'error');
                    console.error('Failed to publish flow : ' , error);
                })
                .finally(() => {
                    this.isLoading = false;
                })
        } catch (error) {
            this.showToast('Error', 'Failed to publish flow', 'error');
            console.error('Failed to publish flow : ' , error);
            this.isLoading = false;
        }
    }

    onDeleteClick(){
        this.showDeletePopup = true;
    }

    handleDelete(){
        try {
            this.isLoading = true;
            this.showDeletePopup = false;
            deleteWhatsAppFlow({flowId : this.flowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.showToast('Success', 'Flow deleted successfully', 'success');
                        this.isFlowVisible = false;
                    } else {
                        this.showToast('Error', 'Failed to delete flow', 'error');
                        console.error('Error in deleting WhatsApp Flow:', error);
                    }
                    })
                .catch((error) => {
                    this.showToast('Error', 'Failed to delete flow', 'error');
                    console.error('Failed to delete flow : ' , error);
                })
                .finally(() => {
                    this.isLoading = false;
                })
        } catch (error) {
            this.showToast('Error', 'Failed to delete flow', 'error');
            console.error('Failed to delete flow : ' , error);
            this.isLoading = false;
        }
    }

    closeDeletePopup(){
        this.showDeletePopup = false;
    }

    onDeprecateClick(){
        this.showDeprecatePopup = true;
    }

    handleDeprecate(){
        try {
            this.isLoading = true;
            this.showDeletePopup = false;
            deprecateWhatsAppFlow({flowId : this.flowId})
                .then((result) => {
                    if(!result.startsWith('Failed')){
                        this.showToast('Success', 'Flow deprecated successfully', 'success');
                        this.isFlowVisible = false;
                    } else {
                        this.showToast('Error', 'Failed to deprecate flow', 'error');
                        console.error('Error in deleting WhatsApp Flow:', error);
                    }
                })
                .catch((error) => {
                    this.showToast('Error', 'Failed to delete flow', 'error');
                    console.error('Failed to delete flow : ' , error);
                })
                .finally(() => {
                    this.isLoading = false;
                })
        } catch (error) {
            this.showToast('Error', 'Failed to delete flow', 'error');
            console.error('Failed to delete flow : ' , error);
            this.isLoading = false;
            this.closeDeletePopup();
        }
    }

    onSaveClick(){
        createWhatsAppFlow({
            flowName: this.flowName,
            categories: this.selectedCategories,
            flowJson: this.jsonString,
            templateType: this.templateType
        })
        .then(result => {
            this.flowId = result; 
            this.status = 'Draft';
            this.showToast('Success', 'Flow created successfully', 'success');
        })
        .catch(error => {
            console.error('Error creating WhatsApp Flow:', error);
            this.showToast('Error', 'Failed to create WhatsApp Flow', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    closeDeprecatePopup(){
        this.showDeletePopup = false;
    }

    onBackClick(){
        this.isFlowVisible = false;
    }

    showToast(title, message, varient) {
        const toastEvent = new ShowToastEvent({title: title, message: message, variant: varient});
        this.dispatchEvent(toastEvent);
    }
}