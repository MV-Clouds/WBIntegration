/**
 * Component Name: WbPreviewTemplatePage
 * @description: Used LWC components to preview the created template in meta.
 * Date: 27/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 13/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) :  Complete functionality of mapping contact record in input field and preview content
 * Change Description :
 ********************************************************************** */

import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecordsBySObject from '@salesforce/apex/WBTemplateController.getRecordsBySObject'; 
import getDynamicObjectData from '@salesforce/apex/WBTemplateController.getDynamicObjectData';
import fetchDynamicRecordData from '@salesforce/apex/WBTemplateController.fetchDynamicRecordData';
import getCountryCodes from '@salesforce/apex/WBTemplateController.getCountryCodes';

export default class WbPreviewTemplatePage extends LightningElement {
    @track ispreviewTemplate=true;
    @track filepreview;
    @track originalHeader;
    @track originalBody;
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
    @track inputValues = {};
    @track groupedVariables=[];
    @track noContact=true;
    @track selectedCountryType = '+91';  
    @track countryType=[];
    @track filteredTableData = []; 
    searchTerm = 'None';
    @track isDropdownVisible = false;
    @track variableMapping = { header: {}, body: {} };

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
        this.fetchRecords();
        this.fetchCountries();
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

    fetchRecords() {
        try {
            getRecordsBySObject()
            .then(data => {
                // this.records = data;
                this.records = [{ Id: '', Name: 'None' }, ...data]; 
                this.filteredRecordData = [...this.records];                
            })
            .catch(error => {
                console.error('Error fetching records: ', error);
            });
        } catch (error) {
            console.error('Error fetching objects records: ', error);
        }
    }

    search(event) {
        try {
            this.searchTerm = event.target.value.toLowerCase();
            console.log('searchTerm ',this.searchTerm);
            
            this.filteredRecordData = this.records.filter((record) => {
                const isSelected = this.selectedContactId.some(contact => contact.id === record.id);
                return !isSelected && record.name.toLowerCase().includes(this.searchTerm);
            });
        } catch (error) {
            console.error('Unexpected error in search:', error);
            this.showToast('Error', 'An unexpected error occurred while searching', 'error');
        }
    }

    handleFocus(event) {
        this.isDropdownVisible = true;
    }
 
    handleBlur() {
        setTimeout(() => {
            this.isDropdownVisible = false;
        }, 200);
    }

    search(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filteredRecordData = this.records.filter(record =>
            record.Name.toLowerCase().includes(this.searchTerm)
        );
    }

    handleCountryChange(event){
        this.selectedCountryType=event.target.value;
    }

    handleRecordSelection(event) {
        try {
            const contactItem = event.target.closest('.contact-item');
            const selectedId = contactItem ? contactItem.dataset.id : null;
            console.log('selectedId ',selectedId);

            if(!selectedId){
                this.tempHeader = this.originalHeader;
                this.tempBody = this.originalBody;
                this.formatedTempBody = this.formatText(this.originalBody);
                this.searchTerm='None';
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
            
                console.log('Reset to original template');
                return;
            }
           
            const hasVariables = this.tempBody.includes('{{') || this.tempHeader.includes('{{');
            const selectedRecord = this.filteredRecordData.find(record => record.Id === selectedId);

            if (!hasVariables) {
                console.warn('No variables found in the template. Please check the template structure.');
                this.showToast('Warning!', 'No variables found in the template to replace.', 'warning');
                return; 
            }

            if (selectedRecord) {
                this.searchTerm = selectedRecord.Name;
            } else {
                console.warn('Selected record not found in filteredRecordData.');
                this.searchTerm = '';
            }

            this.selectedContactId = selectedId;
            console.log('Selected Record ID:', this.selectedContactId);    
            this.fetchContactData();
        
        } catch (err) {
            console.error('Unexpected error in handleRecordSelection:', err);
        }
    }

    fetchCountries() {
        try {
            getCountryCodes()
            .then(result => {
                this.countryType = result.map(country => {
                    return { label: `(${country.callingCode})`, value: country.callingCode };
                });
            })
            .catch(error => {
                console.error('Error fetching country data:', error);
            });
        } catch (error) {
            console.error('Something went wrong in fetching country data:', error);
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
        
            this.formatedTempBody = updatedBody;
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
            getDynamicObjectData({templateId:this.templateid})
            .then((result) => {
                if (result) {
                    if (result.isImgUrl) {
                        this.isImgSelected = true;
                        this.IsHeaderText = false;
                    } else {
                        this.isImgSelected = false;
                        this.IsHeaderText = true; 
                    }
                    
                    console.log('template data ',JSON.stringify(result));
                    
                    this.originalHeader = result.template.Header_Body__c;
                    this.originalBody = result.template.Template_Body__c;
                    const variableMappings = result.templateVariables;

                    this.tempHeader = this.originalHeader;
                    this.tempBody = this.originalBody;
                    this.formattedtempHeader = this.originalHeader;
                    this.tempFooter = result.template.Footer_Body__c;

                    const buttonLabels = result.template.Button_Label__c ? result.template.Button_Label__c.split(',') : [];
                    const buttonTypes = result.template.Button_Type__c ? result.template.Button_Type__c.split(',') : [];
        
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