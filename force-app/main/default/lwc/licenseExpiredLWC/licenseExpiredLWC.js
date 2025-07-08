import { LightningElement, track } from 'lwc';
import getPLMSValidityCustom from '@salesforce/apex/PLMSController.getPLMSValidityCustom';

export default class LicenseExpiredLWC extends LightningElement {
    @track isChecking = false;
    @track isOneTimeCheck = false;
    @track errorMessage = false;
    @track expireddate;

    checkPackageValidity(){
        this.isChecking = true;

        getPLMSValidityCustom()
            .then( result => {
                if(result && result.message == 'Success' && result.isLicenseValid == true) {
                    this.expireddate = result.expirationDate;
                    this.dispatchEvent(new CustomEvent('packageupdate', { detail: { isPackageValid: false } })); // Keep false to indicate the package is valid
                } else if (result && result.message == 'Success' && !result.isLicenseValid) {
                    this.isOneTimeCheck = true;
                    this.expireddate = result.expirationDate;
                    this.dispatchEvent(new CustomEvent('packageupdate', { detail: { isPackageValid: true } })); // Keep true to indicate the package is expired
                } else if(result && result.message == 'Error') {
                    this.errorMessage = true;
                    this.dispatchEvent(new CustomEvent('packageupdate', { detail: { isPackageValid: true } })); // Keep true to indicate the package is expired
                } else {
                    this.errorMessage = true;
                    this.dispatchEvent(new CustomEvent('packageupdate', { detail: { isPackageValid: true } })); // Keep true to indicate the package is expired
                }
            })
            .catch(error => {
                console.error('Error checking package validity:', error);
            })
            .finally( async () => {
                this.isChecking = false;
            });
    }
}