/**
 * Component Name: WbPreviewTemplatePage
 * @description: Used LWC components to preview the created template in meta.
 * Date: 27/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 28/11/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) :  Work with the updated UI with functionality.
 * Change Description :
 ********************************************************************** */

import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecordsBySObject from '@salesforce/apex/WBTemplateController.getRecordsBySObject'; 
import getContactDetails from '@salesforce/apex/WBTemplateController.getContactDetails';
import getTemplateWithReplacedValues from '@salesforce/apex/WBTemplateController.getTemplateWithReplacedValues'; 

export default class WbPreviewTemplatePage extends LightningElement {
    @track ispreviewTemplate=true;
    @api tempbody;
    @api tempheader;
    @api tempfooter;
    @api filepreview;
    @api buttonlist=[];
    @api custombtnlist=[];
    @track formatedTempBody;
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
        this.tempbody = this.tempbody.replaceAll('\n', '<br/>');
        this.formatedTempBody = this.formatText(this.tempbody);
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
            this.selectedContactId = event.target.value;
            console.log('Selected Record ID:', this.selectedContactId);    
            this.fetchContactDetails();
    
            const hasVariables = this.tempbody.includes('{{') || this.tempheader.includes('{{');

            if (!hasVariables) {
                console.warn('No variables found in the template. Please check the template structure.');
                this.showToast('Warning!', 'No variables found in the template to replace.', 'warning');
                return; 
            }
        
            getTemplateWithReplacedValues({
                recordId: this.selectedContactId,
            })
            .then(result => {
                if (result) {
                    const { header, body } = result;    
                    this.tempheader = this.formatText(header);
                    this.formatedTempBody = this.formatText(body);
    
                    console.log('Formatted Header:', this.tempheader);
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
    
    fetchContactDetails() {
        try {
            if (this.selectedContactId) {
                getContactDetails({ contactId: this.selectedContactId })
                    .then(result => {
                        this.contactDetails = result;
                        console.log('Fetched Contact Details:', result);
                    })
                    .catch(error => {
                        this.contactDetails = {};  
                        console.error('Error fetching contact details:', error);
                    });
            } else {
                console.warn('No Contact ID selected.');
            }
        } catch (err) {
            console.error('Unexpected error in fetchContactDetails:', err);
        }
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