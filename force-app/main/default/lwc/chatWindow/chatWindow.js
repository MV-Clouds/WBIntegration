import { LightningElement, api, track } from 'lwc';
import fetchAllChats from '@salesforce/apex/ChatWindowController.fetchAllChats';

export default class ChatWindow extends LightningElement {

    @api recordId;
    @track chats = [];
    @track isSun = true; // Default : Light mode (Sun)


    get sunClass() {
        return `toggle-button sun-icon ${this.isSun ? "" : "hide"}`;
    }
    get moonClass() {
        return `toggle-button moon-icon ${this.isSun ? "hide" : "show"}`;
    }

    connectedCallback(){
        try {
            fetchAllChats({contactId: this.recordId})
            .then(chats => {
                this.chats = chats;
            })
            .catch(e => {
                console.log('Error in connectedCallback > fetchAllChats:::', e.message);
            })
        } catch (e) {
            console.log('Error in connectedCallback:::', e.message);
        }
    }

    toggleTheme() {
        try{
            this.isSun = !this.isSun;
            let theme = this.isSun ? "light" : "dark";
            this.template.host.setAttribute("data-theme", theme);
            this.template.host.setProperty("--chat-bg-color", theme === "light" ? "white" : "black");
        }catch(e){
            console.log('Error in toggleTheme:::', e.message);
        }
    }

    handleOpenSendOptions(){
        try {
            this.template.querySelector('.dropdown-menu').classList.toggle('hidden');
        } catch (e) {
            console.log('Error in function handleOpenSendOptions:::', e.message);
        }
    }

    handleSendMessage(event){
        try {
            this.template.querySelector('.dropdown-menu').classList.add('hidden');
        } catch (e) {
            console.log('Error in function sendImmediateMessage:::', e.message);
        }
    }
    
    handleScheduleMessage(event){
        try {
            this.template.querySelector('.dropdown-menu').classList.add('hidden');
        } catch (e) {
            console.log('Error in function handleScheduleMessage:::', e.message);
        }
    }

}