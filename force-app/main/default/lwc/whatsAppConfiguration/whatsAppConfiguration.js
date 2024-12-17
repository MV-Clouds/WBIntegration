import { LightningElement, track } from 'lwc';
import saveWhatsAppConfiguration from '@salesforce/apex/WhatsAppConfigurationController.saveConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WhatsAppConfiguration extends LightningElement {
    @track wBAccountIdValue = '';
    @track accessTokenValue = '';
    @track phoneNoIdValue = '';
    @track appIdValue = '';

    handleInput(event) {
        if(event.target.name == 'WBAccountId'){
            this.wBAccountIdValue = event.target.value;
        } if(event.target.name == 'AccessToken'){
            this.accessTokenValue = event.target.value;
        } if(event.target.name == 'PhoneNumberId'){
            this.phoneNoIdValue = event.target.value;
        } if(event.target.name == 'WBAppId'){
            this.appIdValue = event.target.value;
        }
    }

    // Similar handlers for other fields

    handleSave() {
        // Basic validation (add more as needed)
        if (!this.wBAccountIdValue || !this.accessTokenValue || !this.phoneNoIdValue) {
            alert('Please fill in all fields');
            return;
        }

        // Handle saving logic (e.g., API calls, data storage)
        console.log('Saved values:', this.wBAccountIdValue, this.accessTokenValue, this.phoneNoIdValue);
        saveWhatsAppConfiguration({WBAccountId : this.wBAccountIdValue, AppId : this.appIdValue , AccessToken : this.accessTokenValue, PhoneNumberId : this.phoneNoIdValue})
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