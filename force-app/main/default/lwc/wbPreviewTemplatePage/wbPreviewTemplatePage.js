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

export default class WbPreviewTemplatePage extends LightningElement {
    @track ispreviewTemplate=true;
    @track variables = [];
    @track variableValues = {};
    @api tempbody= `Hello *User*🤝, 

Welcome this is a test template for message {{1}} testing purpose and will have different buttons {{2}} and options for testing {{3}} purpose.

Regards,
MV Clouds Pvt Ltd`;
    @track formatedTempBody;
    
    formatText(inputText) {
        let formattedText = inputText.replaceAll('\n', '<br/>');
        formattedText = formattedText.replace(/\*(.*?)\*/g, '<b>$1</b>');
        formattedText = formattedText.replace(/_(.*?)_/g, '<i>$1</i>');
        formattedText = formattedText.replace(/~(.*?)~/g, '<s>$1</s>');
        formattedText = formattedText.replace(/```(.*?)```/g, '<code>$1</code>');

        return formattedText;
    }

    connectedCallback() {
        console.log('Received tempbody:', this.tempbody);
        this.tempbody = this.tempbody.replaceAll('\n', '<br/>');
        this.formatedTempBody = this.formatText(this.tempbody);
        this.addVariablesInput(); 
    }

    addVariablesInput(){
        const variableRegex = /{{(.*?)}}/g;
        let match;
        const variables = [];
        while ((match = variableRegex.exec(this.tempbody)) !== null) {
            variables.push(match[0]);
        }
        this.variables = variables; 
        console.log('Extracted variables:', this.variables);
    }

    handleInputChange(event) {
        const variableIndex = event.target.getAttribute('data-name').replace(/[{}]/g, ''); 
        const value = event.target.value; 
        
        this.variableValues[variableIndex] = value;
        let updatedTempBody = this.tempbody;
        this.variables.forEach(variable => {
            const variableIndex = variable.replace(/[{}]/g, ''); 
            
            if (this.variableValues[variableIndex]) {
                updatedTempBody = updatedTempBody.replace(variable, this.variableValues[variableIndex]);
            }
        });
    
        this.formatedTempBody = this.formatText(updatedTempBody);
    }

    closePreview(){
        this.ispreviewTemplate=false;
    }
}