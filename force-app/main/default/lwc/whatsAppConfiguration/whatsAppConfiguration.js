import { LightningElement, track } from 'lwc';
import saveWhatsAppConfiguration from '@salesforce/apex/WhatsAppConfigurationController.saveConfiguration';
import WBConnectLogo from '@salesforce/resourceUrl/WBConnectLogo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WhatsAppConfiguration extends LightningElement {
    @track wBAccountIdValue = '';
    @track accessTokenValue = '';
    @track phoneNoIdValue = '';
    @track appIdValue = '';
    @track WBConnectLogo = WBConnectLogo;

    handleInput(event) {
        if(event.target.name == 'WBAccountId'){
            this.wBAccountIdValue = event.target.value;
            this.wBAccountIdValue = this.wBAccountIdValue.replaceAll(' ','');
        } if(event.target.name == 'AccessToken'){
            this.accessTokenValue = event.target.value;
            this.accessTokenValue = this.accessTokenValue.replaceAll(' ','');
        } if(event.target.name == 'PhoneNumberId'){
            this.phoneNoIdValue = event.target.value;
            this.phoneNoIdValue = this.phoneNoIdValue.replaceAll(' ','');
        } if(event.target.name == 'WBAppId'){
            this.appIdValue = event.target.value;
            this.appIdValue = this.appIdValue.replaceAll(' ','');
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
        console.log('Saved values:', this.wBAccountIdValue, this.accessTokenValue, this.phoneNoIdValue, this.appIdValue);
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