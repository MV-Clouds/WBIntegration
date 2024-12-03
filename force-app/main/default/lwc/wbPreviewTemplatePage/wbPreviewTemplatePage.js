/**
 * Component Name: WbPreviewTemplatePage
 * @description: Used LWC components to preview the created template in meta.
 * Date: 27/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 3/11/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) :  Work functionality to get template data and store alternate text and show in preview.
 * Change Description :
 ********************************************************************** */

import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecordsBySObject from '@salesforce/apex/WBTemplateController.getRecordsBySObject'; 
import getDynamicObjectData from '@salesforce/apex/WBTemplateController.getDynamicObjectData';
import fetchDynamicRecordData from '@salesforce/apex/WBTemplateController.fetchDynamicRecordData';
import getTemplateWithReplacedValues from '@salesforce/apex/WBTemplateController.getTemplateWithReplacedValues'; 

export default class WbPreviewTemplatePage extends LightningElement {
    @track ispreviewTemplate=true;
    @api filepreview;
    @track tempHeader;
    @track tempBody;
    @track tempFooter;
    @track buttonList=[];
    @track formatedTempBody;
    @track objectNames = []; 
    @track fieldNames = [];
    @track isImgSelected = false;
    @track IsHeaderText = true;
    @track options = [
        { label: 'Contact', value: 'Contact', isSelected: true }
    ];
    @track records = [];
    @track contactDetails=[];

    get contactFields() {
        return Object.entries(this.contactDetails)
            .filter(([key, value]) => value !== null && value !== undefined)
            .map(([key, value]) => ({ label: key, value }));
    }

    get isDisabled(){
        return !(this.objectNames && this.fieldNames);
    }

    formatText(inputText) {
        let formattedText = inputText.replaceAll('\n', '<br/>');
        formattedText = formattedText.replace(/\*(.*?)\*/g, '<b>$1</b>');
        formattedText = formattedText.replace(/_(.*?)_/g, '<i>$1</i>');
        formattedText = formattedText.replace(/~(.*?)~/g, '<s>$1</s>');
        formattedText = formattedText.replace(/```(.*?)```/g, '<code>$1</code>');
        return formattedText;
    }

    connectedCallback() {
        console.log('filepreview ',this.filepreview);
        if(this.filepreview){
            this.isImgSelected = true;
            this.IsHeaderText = false;
        }
        this.fetchTemplateData();
        this.fetchRecords();
    }

    fetchRecords() {
        getRecordsBySObject()
            .then(data => {
                this.records = data;
                console.log(this.records);
                
            })
            .catch(error => {
                console.error('Error fetching records: ', error);
            });
    }


    handleRecordSelection(event) {
        try {
            const hasVariables = this.tempBody.includes('{{') || this.tempHeader.includes('{{');

            if (!hasVariables) {
                console.warn('No variables found in the template. Please check the template structure.');
                this.showToast('Warning!', 'No variables found in the template to replace.', 'warning');
                return; 
            }

            this.selectedContactId = event.target.value;
            console.log('Selected Record ID:', this.selectedContactId);    
            this.fetchContactData();
        
            getTemplateWithReplacedValues({
                recordId: this.selectedContactId,
            })
            .then(result => {
                if (result) {
                    const { header, body } = result;    
                    this.tempHeader = this.formatText(header);
                    this.formatedTempBody = this.formatText(body);
    
                    console.log('Formatted Header:', this.tempHeader);
                    console.log('Formatted Body:', this.formatedTempBody);
                } else {
                    console.warn('No template data returned.');
                }
            })
            .catch(error => {
                console.error('Error replacing template:', error);
            });
        } catch (err) {
            console.error('Unexpected error in handleRecordSelection:', err);
        }
    }

    fetchContactData() {
        fetchDynamicRecordData({
            objectName: this.objectNames[0], 
            fieldNames: this.fieldNames, 
            recordId: this.selectedContactId
        })
        .then(result => {
            if (result.queriedData) {
                this.contactDetails = result.queriedData;
                console.log('Queried Data:', this.contactDetails);
            } else {
                console.warn('No data found for the provided record ID.');
            }
        })
        .catch(error => {
            console.error('Error fetching dynamic data:', error);
        });
    }
    
    fetchTemplateData() {
        this.isLoading = true;
        getDynamicObjectData()
        .then((result) => {
            if (result) {
                this.tempHeader = result.template.Header_Body__c;
                this.tempBody = result.template.Template_Body__c;
                this.tempFooter = result.template.Footer_Body__c;

                const buttonLabels = result.template.Button_Label__c ? result.template.Button_Label__c.split(',') : [];
                this.buttonList = buttonLabels.map((label, index) => ({
                    id: index,
                    btntext: label.trim()
                }));
                console.log('wrapper data==> ',result);
                
                this.objectNames = result.objectNames;
                this.fieldNames = result.fieldNames;

                console.log('Object Names:', this.objectNames);
                console.log('Field Names:', this.fieldNames);
                
                this.formatedTempBody = this.formatText(this.tempBody);
                this.isLoading = false;
            }
        })
        .catch((error) => {
            console.error('Error fetching template data:', error);
            this.isLoading = false;
        })       
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