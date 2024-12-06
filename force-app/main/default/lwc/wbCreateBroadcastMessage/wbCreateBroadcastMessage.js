/**
 * Component Name: WbCreateBroadcastMessage
 * @description: Used LWC components to Send Broadcast Message by selecting templates and groups.
 * Date: 5/12/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 5/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : 
 * Change Description : 
 ********************************************************************** */

import { LightningElement, track } from 'lwc';
import getWhatsAppTemplates from '@salesforce/apex/WBTemplateController.getWhatsAppTemplates';
import getBroadcastGroup from '@salesforce/apex/WbBroadcastController.getBroadcastGroup';
import getMembersWithContactData from '@salesforce/apex/WbBroadcastController.getMembersWithContactData';

export default class WbCreateBroadcastMessage extends LightningElement {
    @track pickListOrdered;
    @track bgPicklist;
    @track searchResults = [];
    @track selectedSearchResult;
    @track bgsearchResults = [];
    @track bgselectedSearchResult;
    @track isNewBroadcastMessage = true;
    @track isAllBroadcast = false;
    @track tempHeader;
    @track tempBody;
    @track tempFooter;
    @track buttonList=[];
    @track selectedContacts=[];
    @track groupId;
    @track isLoading = false; 

    get selectedValue() {
        return this.selectedSearchResult ? this.selectedSearchResult.label : '';
    }
    get bgSelectedValue() {
        return this.bgselectedSearchResult ? this.bgselectedSearchResult.label : '';
    }

    connectedCallback() {
        this.fetchTemplateRecords();
        this.fetchBroadcastGroup();
    }

    renderedCallback() {
        window.addEventListener("click", (event) => {
            this.hideDropdown(event);
        });
    }

    hideDropdown(event) {
        const cmpName = this.template.host.tagName;
        const clickedElementSrcName = event.target.tagName;
        const isClickedOutside = cmpName !== clickedElementSrcName;

        if (this.searchResults && !isClickedOutside) {
            this.searchResults=[];
        }
        if (this.bgsearchResults && !isClickedOutside) {
            this.bgsearchResults=[];
        }
    }

    fetchMembers() {
        try {
            getMembersWithContactData({ broadcastGroupId: this.groupId })
                .then((data) => {
                    if (data) {
                        this.selectedContacts = data.members.map((member, index) => {
                            const formattedLabel = `${index + 1} | ${member.Contact_ID__r.Name} | ${member.Contact_ID__r.Phone}`;
                            return {
                                id: member.Contact_ID__c,
                                label: formattedLabel,
                                name: member.Contact_ID__r.Name,
                                phone: member.Contact_ID__r.Phone
                            };
                        });
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

    fetchTemplateRecords(){
        try {
            getWhatsAppTemplates()
            .then((result) => {
                console.log('Fetched templates:', result); 

                this.pickListOrdered = result
                    .filter((item) => item && item.Name) 
                    .sort((a, b) => a.Name.localeCompare(b.Name));   
            })
            .catch((error) => {
                console.error('Error fetching records:', error);
            });
        } catch (error) {
            console.error("Error in fetching template records: ", error);
        }
        
    }

    // Search method to filter pickListOrdered based on input
    search(event) {
        try {
            const searchTerm = event.target.value.toLowerCase();
            this.searchResults = this.pickListOrdered.filter(item =>
                item.Name.toLowerCase().includes(searchTerm)
            ).map(item => ({
                label: item.Name,  
                value: item.Id    
            }));
        } catch (error) {
            console.error("Error in searching templates: ", error);
        }
    }

    // Method to handle selecting a template from the dropdown
    selectSearchResult(event) {
        try {
            const selectedValue = event.currentTarget.dataset.value;         
            const selectedItem = this.searchResults.find(item => item.value === selectedValue);
            this.selectedSearchResult = selectedItem;
            this.searchResults = [];  

            if (this.selectedSearchResult) {
                const template = this.pickListOrdered.find(item => item.Id === this.selectedSearchResult.value);
                this.tempHeader = template.Header_Body__c || '';
                this.tempBody = template.Template_Body__c || '';
                this.tempFooter = template.Footer_Body__c || '';
                const buttonLabels = template.Button_Label__c ? template.Button_Label__c.split(',') : [];
                this.buttonList = buttonLabels.map((label, index) => ({
                    id: index,
                    btntext: label.trim()
                }));
            }
        } catch (error) {
            console.error("Error in selecting templates: ", error);
        }

    }
    
    // Method to keep dropdown visible when input is focused (optional)
    showPickListOptions() {
        try {
            if (!this.selectedSearchResult) {
                this.searchResults = this.pickListOrdered.map(item => ({
                    label: item.Name,
                    value: item.Id
                }));
            }
        } catch (error) {
            console.error("Something went wrong");
        }
       
    }

    // Show Broacast group and search functionality
    fetchBroadcastGroup(){
        try {
            getBroadcastGroup()
            .then((result) => {
                console.log('Fetched templates:', result); 

                this.bgPicklist = result
                    .filter((item) => item && item.Name) 
                    .sort((a, b) => a.Name.localeCompare(b.Name));   
            })
            .catch((error) => {
                console.error('Error fetching broadcast records:', error);
            });
        } catch (error) {
            console.error('Error fetching broadcast records:', error);
        }
        
    }

     // Method to keep dropdown visible when input is focused (optional)
    showBroadcastOption() {
        try {
            if (!this.bgselectedSearchResult) {
                this.bgsearchResults = this.bgPicklist.map(item => ({
                    label: item.Name,
                    value: item.Id
                }));
            }
        } catch (error) {
            console.error("Something went wrong");
        }
       
    }

    // Search method to filter bgPicklist based on input
    searchGroup(event) {
        try {
            const searchTerm = event.target.value.toLowerCase();
            this.bgsearchResults = this.bgPicklist.filter(item =>
                item.Name.toLowerCase().includes(searchTerm)
            ).map(item => ({
                label: item.Name,  
                value: item.Id    
            }));
        } catch (error) {
            console.error("Something went wrong in searching group.");
        }
        
    }

    // Method to handle selecting a template from the dropdown
    selectbgSearchResult(event) {
        try {
            const recordId = event.currentTarget.dataset.recordId;    
            const selectedItem = this.bgsearchResults.find(item => item.value === recordId);
            
            if (selectedItem) {
                this.bgselectedSearchResult = selectedItem; 
                console.log('Selected Record ID:', recordId); 
                this.groupId=recordId;
            } else {
                console.error('No matching item found for Record ID:', recordId);
            }
    
            this.fetchMembers();
            this.bgsearchResults = []; 
        } catch (error) {
            console.error('Error while selecting the groups.');
        }
       
    }

    cancelBroadcastMessage(){
        this.isLoading = true; 
    
        setTimeout(() => {
            this.isAllBroadcast=true;
            this.isNewBroadcastMessage=false;
            this.isLoading = false; 
        }, 1000); 
        
    }
}
