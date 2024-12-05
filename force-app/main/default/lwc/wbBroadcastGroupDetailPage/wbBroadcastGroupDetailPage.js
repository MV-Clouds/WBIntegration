/**
 * Component Name: WbBroadcastGroupDetailPage
 * @description: Used LWC components to show Broadcast Groups Details.
 * Date: 4/12/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 5/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : 
 * Change Description : Added the Edit functionality and code formatting.
 ********************************************************************** */

import { LightningElement,track,wire,api } from 'lwc';
import getMembersWithContactData from "@salesforce/apex/WbBroadcastController.getMembersWithContactData";
import updateBroadcastGroup from "@salesforce/apex/WbBroadcastController.updateBroadcastGroup";
import getRecordsBySObject from "@salesforce/apex/WbBroadcastController.getRecordsBySObject";
import {loadStyle} from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import BroadcastExtCSS from '@salesforce/resourceUrl/BroadcastExtCSS';

export default class WbBroadcastGroupDetailPage extends LightningElement {
    @track isDisabled=true;
    @track showBGDetail=true;
    @track bgDescription='';
    @track bgName='';
    @track isLoading = false; 
    @track selectedContacts = [];
    @track broadcastGroupId; 
    @track isExistingMembers=true;
    @track addMembers=false;
    @track tableData = []; 
    @track filteredTableData = []; 
    @track searchTerm = '';
    @track _groupId;

    @api 
    set groupid(value) {
        this._groupId = value;
        console.log('Child: groupId received via setter is', this._groupId);
        if (this._groupId) {
            this.fetchMembers();   
        }
    }

    get groupid() {
        return this._groupId;
    }

    renderedCallback() {
        loadStyle(this, BroadcastExtCSS).then(() => {
            console.log("Loaded Successfully")
        }).catch(error => {
            console.error("Error in loading the colors",error)
        })
    }

    handleInputChange(event) {
        const { name, value, dataset } = event.target;
        const index = dataset.index;

        switch (name) {
            case 'bg-name':
                this.bgName = value;
                break;
            case 'description':
                this.bgDescription = value;
                break;
            default:
                break;
        }
    }

    fetchMembers() {
        try {
            getMembersWithContactData({ broadcastGroupId: this._groupId })
                .then((data) => {
                    if (data) {
                        this.bgName = data.broadcastGroupName;
                        this.bgDescription = data.broadcastGroupDescription;
                        this.selectedContacts = data.members.map((member, index) => {
                            const formattedLabel = `${index + 1} | ${member.Contact_ID__r.Name} | ${member.Contact_ID__r.Phone}`;
                            return {
                                id: member.Contact_ID__c,
                                label: formattedLabel,
                                name: member.Contact_ID__r.Name,
                                phone: member.Contact_ID__r.Phone
                            };
                        });
                        this.fetchTableData(); 
                    } else {
                        console.error("Error: No data received for broadcast group members.");
                    }
                })
                .catch((error) => {
                    let errorMessage = 'An error occurred while fetching broadcast group members.';
                    if (error && error.body && error.body.message) {
                        errorMessage = error.body.message;
                    } else if (error && error.message) {
                        errorMessage = error.message;
                    }
                    console.error(errorMessage);
                });
        } catch (error) {
            console.error("Error in fetchMembers: ", error);
        }
    }
    
    fetchTableData() {
        try {
            getRecordsBySObject({ sObjectName: 'Contact' })
                .then((result) => {
                    const selectedContactIds = new Set(this.selectedContacts.map(contact => contact.id));
                    console.log('selectedContactIds ', selectedContactIds);
    
                    this.tableData = result
                        .filter(record => !selectedContactIds.has(record.value))
                        .map((record) => ({
                            id: record.value,
                            name: record.label,
                            phone: record.phone
                        }));
    
                    this.filteredTableData = [...this.tableData];
                    this.isLoading = false;
                })
                .catch((error) => {
                    let errorMessage = 'Error fetching table data.';
                    if (error && error.message) {
                        errorMessage = error.message;
                    }
                    console.error(errorMessage);
                    this.isLoading = false;
                });
        } catch (error) {
            console.error("Error in fetchTableData: ", error);
            this.isLoading = false; 
        }
    }    

    search(event) {
        try {
            this.searchTerm = event.target.value.toLowerCase();
    
            this.filteredTableData = this.tableData.filter((record) => {
                const isSelected = this.selectedContacts.some(contact => contact.id === record.id);
                return !isSelected && record.name.toLowerCase().includes(this.searchTerm);
            });
        } catch (error) {
            console.error('Unexpected error in search:', error);
            this.showToast('Error', 'An unexpected error occurred while searching', 'error');
        }
    }

    addToPills(event) {
        try {
            const contactId = event.currentTarget.dataset.id;
            const contactName = event.currentTarget.dataset.name;
            const contactMobile = event.currentTarget.dataset.phone;
    
            const exists = this.selectedContacts.some(contact => contact.id === contactId);
            if (!exists) {
                const formattedLabel = `${this.selectedContacts.length + 1} | ${contactName} | ${contactMobile}`;
                this.selectedContacts.push({ id: contactId, name: contactName, phone: contactMobile, label: formattedLabel });
                this.tableData = this.tableData.filter(contact => contact.id !== contactId);
                this.filteredTableData = this.filteredTableData.filter(contact => contact.id !== contactId);

                this.updateSerialNumbers();
            }
    
            this.searchTerm = '';
            this.filteredTableData = [...this.tableData];
        } catch (error) {
            console.error('Unexpected error in addToPills:', error);
            this.showToast('Error', 'An unexpected error occurred while adding a contact to the list', 'error');
        }
    }
    
    removePill(event) {
        try {
            const contactId = event.currentTarget.dataset.id;
            const removedContact = this.selectedContacts.find(contact => contact.id === contactId);
    
            // Remove contact from selectedContacts
            this.selectedContacts = this.selectedContacts.filter(contact => contact.id !== contactId);
            this.updateSerialNumbers();

            if (removedContact) {
                // Check if the contact is already in tableData or filteredTableData
                const alreadyInTable = this.tableData.some(contact => contact.id === removedContact.id);
                if (!alreadyInTable) {
                    this.tableData.push({
                        id: removedContact.id,
                        name: removedContact.name,
                        phone: removedContact.phone
                    });
        
                    this.filteredTableData.push({
                        id: removedContact.id,
                        name: removedContact.name,
                        phone: removedContact.phone
                    });
        
                    // Sort the filtered data
                    this.filteredTableData.sort((a, b) => a.name.localeCompare(b.name));
                }
            }
        } catch (error) {
            console.error('Unexpected error in removePill:', error);
            this.showToast('Error', 'An unexpected error occurred while removing a contact from the list', 'error');
        }
    }

    updateSerialNumbers() {
        this.selectedContacts = this.selectedContacts.map((contact, index) => {
            const formattedLabel = `${index + 1} | ${contact.name} | ${contact.phone}`;
            return { ...contact, label: formattedLabel };
        });
    }

    showEditBroadcast(){
        this.isDisabled=false;
        this.addMembers=true;
        this.isExistingMembers=false;
    }
   
    editBroadcastGroup() {
        try {
            const selectedContactIds = this.selectedContacts.map(contact => contact.id);
            this.isLoading = true;
    
            updateBroadcastGroup({ 
                bgGroupId: this._groupId, 
                bgName: this.bgName, 
                bgDescription: this.bgDescription, 
                contactIds: selectedContactIds 
            })
            .then((result) => {
                console.log('Success to update group');
                this.showToast('Success', 'Broadcast Group Updated successfully', 'success');
                this.addMembers = false;
                this.isExistingMembers = true;
                this.fetchMembers();
                this.isLoading = false;
            })
            .catch((error) => {
                let errorMessage = 'An unexpected error occurred during broadcast group update.';
                if (error && error.message) {
                    errorMessage = error.message;
                }
                this.showToast('Error', errorMessage, 'error');
                console.error('Error during update:', error);
                this.isLoading = false;
            });
        } catch (error) {
            console.error("Unexpected error in editBroadcastGroup: ", error);
            this.isLoading = false; 
            this.showToast('Error', 'An unexpected error occurred while updating the broadcast group.', 'error');
        }
    }
    
    cancelEditBroadcastGroup(){
        this.isLoading = true; 

        setTimeout(() => {
            this.addMembers=false;
            this.isExistingMembers=true;
            this.fetchMembers();
        }, 1000); 
        
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