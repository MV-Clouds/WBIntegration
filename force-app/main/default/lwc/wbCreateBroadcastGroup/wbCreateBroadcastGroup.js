import { LightningElement,track } from 'lwc';
import getRecordsBySObject from "@salesforce/apex/WbBroadcastController.getRecordsBySObject";
import createBroadcastGroup from "@salesforce/apex/WbBroadcastController.createBroadcastGroup";
import {loadStyle} from 'lightning/platformResourceLoader';
import BroadcastExtCSS from '@salesforce/resourceUrl/BroadcastExtCSS';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WbCreateBroadcastGroup extends LightningElement {
    @track tableData = []; 
    @track filteredTableData = []; 
    searchTerm = '';
    @track selectedContacts = []; 
    @track bgDescription='';
    @track bgName='';
    @track isLoading = false;  
    @track isNewBroadcast=true;
    @track isAllBroadcast=false;   

    connectedCallback() {
        this.fetchTableData();
    }

    renderedCallback() {
        loadStyle(this, BroadcastExtCSS).then(() => {
            console.log("Loaded Successfully")
        }).catch(error => {
            console.error("Error in loading the colors",error)
        })
    }

    fetchTableData() {
        getRecordsBySObject({sObjectName:'Contact'})
            .then((result) => {
                this.tableData = result.map((record) => ({
                    id: record.value,
                    name: record.label,
                    phone: record.phone
                }));
                this.filteredTableData = [...this.tableData]; 
                this.isLoading = false;
            })
            .catch((error) => {
                console.error('Error fetching table data:', error);
                this.isLoading = false;
            });
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

    search(event) {
        this.searchTerm = event.target.value.toLowerCase();

        this.filteredTableData = this.tableData.filter((record) => {
            const isSelected = this.selectedContacts.some(contact => contact.id === record.id);
            return !isSelected && record.name.toLowerCase().includes(this.searchTerm);
        });
        
    }

    addToPills(event) {
        const contactId = event.currentTarget.dataset.id;
        const contactName = event.currentTarget.dataset.name;
        const contactMobile = event.currentTarget.dataset.phone;
    
        const exists = this.selectedContacts.some(contact => contact.id === contactId);
        if (!exists) {
            const formattedLabel = `${this.selectedContacts.length + 1} | ${contactName} | ${contactMobile}`;
            this.selectedContacts.push({ id: contactId, name: contactName, phone: contactMobile, label: formattedLabel });    
            this.tableData = this.tableData.filter(contact => contact.id !== contactId);    
            this.filteredTableData = this.filteredTableData.filter(contact => contact.id !== contactId);
        }
    
        this.searchTerm = '';
        this.filteredTableData = [...this.tableData];
    }
    

    removePill(event) {
        const contactId = event.currentTarget.dataset.id;    
        const removedContact = this.selectedContacts.find(contact => contact.id === contactId);
        
        this.selectedContacts = this.selectedContacts.filter(contact => contact.id !== contactId);
    
        if (removedContact) {
            this.filteredTableData.push({
                id: removedContact.id,
                name: removedContact.name,
                phone: removedContact.phone
            });
    
            this.filteredTableData.sort((a, b) => a.name.localeCompare(b.name));
        }
    }

    createBroadcastGroup(){
        const selectedContactIds = this.selectedContacts.map(contact => contact.id);
        this.isLoading=true;
        createBroadcastGroup({bgName:this.bgName, bgDescription:this.bgDescription,contactIds:selectedContactIds})
        .then((result) => {
            console.log('sucess to create group');
            this.showToast('Success', 'Broadcast Group Created successfully', 'success');
            this.clearInputs();
            this.fetchTableData();
            this.isLoading = false;
        })
        .catch((error) => {
            let errorMessage = 'An unexpected error occurred';
            if (error && error.message) {
                errorMessage = error.message;
            }
            this.showToast('Error', errorMessage, 'error');
            console.error('Unexpected error:', error);
            this.isLoading = false;
        });
    }

    clearInputs(){
        this.selectedContacts=[];
        this.bgDescription='';
        this.bgName='';
        this.searchTerm='';
        this.updateTextarea();
        // this.resetMembers();
    }

    resetMembers(){
        this.filteredTableData = this.tableData.filter((record) =>
            record.name.toLowerCase().includes(this.searchTerm)
        );
    }

    updateTextarea() {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.value = this.bgDescription;
        }
        textarea.focus();
    }

    cancelBroadcastGroup(){
         this.isLoading = true; 
    
        setTimeout(() => {
            this.clearInputs();
            this.isAllBroadcast=true;
            this.isNewBroadcast=false;
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