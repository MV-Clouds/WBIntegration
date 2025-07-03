import { LightningElement, track } from 'lwc';
import getPLMSValidity from '@salesforce/apex/PLMSController.getPLMSValidity';
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';
import getExpirationDate from '@salesforce/apex/PLMSController.getExpirationDate';

export default class LicenseExpiredLWC extends LightningElement {
    @track isChecking = false;
    @track isOneTimeCheck = false;
    @track isPackageExpired = true; 
    @track expireddate;

    checkPackageValidity(){
        this.isChecking = true;

        getPLMSValidity({doSchedule : false})
            .then( async () => {
                this.isPackageExpired = !(await checkLicenseUsablility()); // Invert the value to show message when expired
                console.log('Package Expiration Status:', this.isPackageExpired);
            })
            .catch(error => {
                console.error('Error checking package validity:', error);
                this.isPackageExpired = true;
            })
            .finally( async () => {
                this.isChecking = false;
                console.log('in final');
                
                if(this.isPackageExpired) {
                    this.isOneTimeCheck = true;
                    await getExpirationDate()
                        .then(result => {
                            console.log('Expiration Date:', result);
                            
                            this.expireddate = result;
                        })
                        .catch(error => {
                            console.error('Error fetching expiration date:', error);
                            return null; // Handle error gracefully
                        });
                }
                if(!(this.isPackageExpired)){
                    this.dispatchEvent(new CustomEvent('packageupdate', { detail: { isPackageValid: this.isPackageExpired } }));
                }
            });
    }
}