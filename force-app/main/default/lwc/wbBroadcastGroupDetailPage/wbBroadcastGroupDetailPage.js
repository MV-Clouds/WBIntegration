import { LightningElement,track,wire,api } from 'lwc';
import getMembersWithContactData from "@salesforce/apex/WbBroadcastController.getMembersWithContactData";

export default class WbBroadcastGroupDetailPage extends LightningElement {
    @track isDisabled=true;
    @track showBGDetail=true;
    @track bgDescription='';
    @track bgName='';
    @track isLoading = false; 
    @api groupid;
    @track selectedContacts = [];
    @track broadcastGroupId; 

    @wire(getMembersWithContactData, { broadcastGroupId: this.groupid })
    wiredMembers({ data, error }) {
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
        } else if (error) {
            console.error("Error fetching broadcast group members: ", error);
        }
    }
}