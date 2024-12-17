import { LightningElement, track } from 'lwc';
import saveWhatsAppConfiguration from '@salesforce/apex/WhatsAppConfigurationController.saveConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WhatsAppConfiguration extends LightningElement {
    @track appIdValue = '';
    @track appSecretValue = '';
    @track accessTokenValue = '';
    @track phoneNoIdValue = '';

    handleInput(event) {
        if(event.target.name == 'AppId'){
            this.appIdValue = event.target.value;
        } if(event.target.name == 'AppSecret'){
            this.appSecretValue = event.target.value;
        } if(event.target.name == 'AccessToken'){
            this.accessTokenValue = event.target.value;
        } if(event.target.name == 'PhoneNumberId'){
            this.phoneNoIdValue = event.target.value;
        }
    }

    // Similar handlers for other fields

    handleSave() {
        // Basic validation (add more as needed)
        if (!this.appIdValue || !this.appSecretValue || !this.accessTokenValue || !this.phoneNoIdValue) {
            alert('Please fill in all fields');
            return;
        }

        // Handle saving logic (e.g., API calls, data storage)
        console.log('Saved values:', this.appIdValue, this.appSecretValue, this.accessTokenValue, this.phoneNoIdValue);
        const serializedData = JSON.stringify({
            WhatsAppAppId__c: String(this.appIdValue),
            WhatsAppAppSecret__c: String(this.appSecretValue),
            AccessToken__c: String(this.accessTokenValue),
            PhoneNumberId__c: String(this.phoneNoIdValue)
        });
        saveWhatsAppConfiguration({WhatsAppAppId : this.appIdValue, WhatsAppAppSecret : this.appSecretValue, AccessToken : this.accessTokenValue, PhoneNumberId : this.phoneNoIdValue})
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Saved successfully',
                    variant: 'success'
                })
            );
        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }

    // Similar handlers for other info icons
}