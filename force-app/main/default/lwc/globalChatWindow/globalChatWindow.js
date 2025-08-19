import { LightningElement, track } from 'lwc';
import checkLicenseUsablility from '@salesforce/apex/PLMSController.checkLicenseUsablility';
import getChatsForSelectedObject from '@salesforce/apex/ChatWindowController.getChatsForSelectedObject';
import getObjectPicklistOptions from '@salesforce/apex/ChatWindowController.getObjectPicklistOptions';
import getCombinedData from '@salesforce/apex/ChatWindowController.getCombinedData';
import updateStatus from '@salesforce/apex/ChatWindowController.updateStatus';
import PROFILE from '@salesforce/resourceUrl/defaultProfile';
import { subscribe} from 'lightning/empApi';

export default class GlobalChatWindow extends LightningElement {
    @track objectOptions = [];
    @track selectedObject;
    @track contacts = [];
    @track chatSearchTerm = '';
    @track filteredContacts = [];
    @track profileUrl = PROFILE;
    @track chats = [];
    @track groupedChats = [];
    @track showSpinner = false;
    @track showLicenseError = false;
    @track recordId;
    @track phoneNumber;
    @track recordName;
    @track subscription = {};
    @track channelName = '/event/MVWB__Chat_Message__e';

    async connectedCallback(){
        try {
            await this.checkLicenseStatus();
            if (this.showLicenseError) {
                return; // Stops execution if license is expired
            }
            this.fetchObjectOptions();
            this.handleSubscribe();
        } catch (e) {
            console.error('Error in connectedCallback:::', e.message);
        }
    }

    async checkLicenseStatus() {
        try {
            const isLicenseValid = await checkLicenseUsablility();
            if (!isLicenseValid) {
                this.showLicenseError = true;
            }
        } catch (error) {
            console.error('Error checking license:', error);
        }
    }

    handlePackageUpdate(event){
        this.showLicenseError = event.detail.isPackageValid;
    }

    handleSubscribe() {
        try {
            let self = this;
            let messageCallback = function () {
                self.getChatsForSelectedObject(false);
                self.getInitialData(true);
            };
     
            subscribe(this.channelName, -1, messageCallback).then(response => {
                this.subscription = response;
            });
        } catch (error) {
            console.error('error in handleSubscribe', error);
        }
    }

    fetchObjectOptions(){
        try {
            getObjectPicklistOptions()
                .then(data => {
                    if (data && data.length > 0) {
                        this.objectOptions = data.map(obj => ({ label: obj, value: obj }));
                        this.selectedObject = this.objectOptions[0].value; // first one default
                        this.getChatsForSelectedObject(true);
                    }
                })
                .catch(error => {
                    console.error('Error fetching object options:', error);
                });
        } catch (error) {
            console.error('Error in fetchObjectOptions :: ', error);
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.chatSearchTerm = null;
        this.recordName = null;
        this.groupedChats = [];
        this.getChatsForSelectedObject(true);
    }

    getChatsForSelectedObject(showSpinner){
        try {
            if(showSpinner == true){
                this.showSpinner = true;
            }
            getChatsForSelectedObject({ objectApiName: this.selectedObject})
                .then(result => {
                    this.contacts = Object.values(result).map(item => ({
                        Id: item.Id,
                        Name: item.Name,
                        Phone: item.Phone,
                        unreadOutboundCount: item.unreadOutboundCount > 0 ? item.unreadOutboundCount : null,
                    }));
                    this.filteredContacts = [...this.contacts];
                    this.filteredContacts = this.filteredContacts.map(con => ({
                        ...con,
                        cssClass: con.Id === this.recordId ? 'contact-item active' : 'contact-item'
                    }));

                    console.log(this.filteredContacts);
                })
                .catch(error => {
                    console.error('Error fetching chat data:', error);
                })
                .finally(() => {
                    this.showSpinner = false;
                });
        } catch (error) {
            console.error('Error in getChatsForSelectedObject ::: ', error);
        }
    }

    handleContactsSearch(event) {
        const searchTerm = event.target.value.toLowerCase(); // Convert to lowercase for case-insensitive search
        this.chatSearchTerm = searchTerm;
        if (searchTerm) {
            this.filteredContacts = this.contacts.filter(con =>
                con.Name && con.Name.toLowerCase().includes(searchTerm)
            );
        } else {
            this.filteredContacts = [...this.contacts]; // Reset to original list if search term is empty
        }
        this.filteredContacts = this.filteredContacts.map(con => ({
            ...con,
            cssClass: con.Id === this.recordId ? 'contact-item active' : 'contact-item'
        }));
    }

    handleContactClick(event) {
        console.log(event);
        
        const contactId = event.currentTarget.dataset.id;
        console.log('Contact Id: ' + contactId);
        
        this.recordId = contactId;
        this.filteredContacts = this.filteredContacts.map(con => ({
            ...con,
            cssClass: con.Id === this.recordId ? 'contact-item active' : 'contact-item'
        }));
        this.getInitialData(true);
    }

    // Fetch Initial Data
    getInitialData(hideSpinner){
        console.log('in getInitdata');
        
        if(!hideSpinner || hideSpinner == false){
            this.showSpinner = true;
        }
        try {
            getCombinedData({ contactId: this.recordId, objectApiName: this.selectedObject })
                .then(combinedData => {
                    this.chats = JSON.parse(JSON.stringify(combinedData.chats));
                    this.recordName = combinedData.recordName;
                    this.showSpinner = false;
                    
                    let chatIdsToSeen = [];
                    this.chats.filter(ch => ch.MVWB__Type_of_Message__c != 'Outbound Messages').forEach(ch =>{
                        if(ch.MVWB__Message_Status__c!='Seen') chatIdsToSeen.push(ch.Id);
                    })
                    if(chatIdsToSeen?.length > 0){
                        updateStatus({messageIds: chatIdsToSeen})
                        .then(result => {
                            this.filteredContacts = this.filteredContacts.map(contact => {
                                if (contact.Id === this.recordId) {
                                    const updatedCount = contact.unreadOutboundCount - result?.length;
                                    return {
                                        ...contact,
                                        unreadOutboundCount: updatedCount > 0 ? updatedCount : null// set to null if <= 0
                                    };
                                }
                                return contact;
                            });
                            this.filteredContacts = this.filteredContacts.map(con => ({
                                ...con,
                                cssClass: con.Id === this.recordId ? 'contact-item active' : 'contact-item'
                            }));
                        })
                    }
                })
                .catch(e => {
                    this.showSpinner = false;
                    console.error('Error in getCombinedData:', e.message);
                });
        } catch (e) {
            this.showSpinner = false;
            console.error('Error in function getInitialData:::', e.message);
        }
    }
}