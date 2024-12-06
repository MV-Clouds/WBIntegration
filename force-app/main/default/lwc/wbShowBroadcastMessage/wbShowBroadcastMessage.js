/**
 * Component Name: WbShowBroadcastMessage
 * @description: Used LWC components to show Broadcast Message Details.
 * Date: 5/12/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
MODIFICATION LOG*
 * Last Update Date : 6/12/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : fetchBrodcastMessage
 * Change Description : Update code to get the data in expected format.
 ********************************************************************** */

import { LightningElement,track } from 'lwc';
import fetchBroadcastDetails from "@salesforce/apex/WbBroadcastController.fetchBroadcastDetails";


export default class WbShowBroadcastMessage extends LightningElement {
    @track isBroadcastMessage=true;
    @track tempName='';
    @track delivered='';
    @track sendDate='';
    @track bgName='';
    @track readRate='';
    @track broadcastId='a03C400000HkQydIAF';
    @track selectedContacts=[];
    
    connectedCallback(){
        this.fetchBrodcastMessage();
    }

    fetchBrodcastMessage() {
        try {
            fetchBroadcastDetails({ broadcastId: this.broadcastId })
            .then((data) => {
                console.log("Response Data:", JSON.stringify(data));
                if (data) {
                    this.bgName = data.broadcastGroupName || 'N/A';
                    this.tempName = data.templateName || 'N/A';
                    this.delivered = data.totalDelivered || 0;
                    this.readRate = data.totalSeen || 0;
                    this.sendDate = this.formatDateTime(data.broadcastSentDate,false) || 'N/A';
    
                    console.log(JSON.stringify(this.selectedContacts));
                    this.selectedContacts = data.members.map((member, index) => {
                        const formattedLabel = `${index + 1} | ${member.contactName || null} | ${member.mobileNumber || null} | ${member.messageStatus || null} | ${this.formatDateTime(member.sendDateTime) || null}`;
                        return {
                            id: member.contactName || null,
                            label: formattedLabel,
                            name: member.contactName || null,
                            phone: member.mobileNumber || null,
                            status: member.messageStatus || null,
                            sendDate: this.formatDateTime(member.sendDateTime) || null
                        };
                    });    
                }
            })
            .catch((error) => {
                console.error("Error:", error);
            });
        } catch (error) {
            console.error("Unexpected error in fetchBrodcastMessage:", error);
        }
     
    }
    
    formatDateTime(dateString, isTimeRequired = true) {
        try {
            const date = new Date(dateString);
            if (isNaN(date)) {
                return 'Invalid Date';
            }
        
            const day = date.getDate().toString().padStart(2, '0'); 
            const month = (date.getMonth() + 1).toString().padStart(2, '0');
            const year = date.getFullYear();
            
            const formattedDate = `${day}/${month}/${year}`;    
            if (isTimeRequired) {
                const hours = date.getHours().toString().padStart(2, '0'); 
                const minutes = date.getMinutes().toString().padStart(2, '0'); 
                const seconds = date.getSeconds().toString().padStart(2, '0'); 
        
                return `${formattedDate} ${hours}:${minutes}:${seconds}`;
            }
            return formattedDate;

        } catch (error) {
            return error;
        }
        
    }
    
}


                    