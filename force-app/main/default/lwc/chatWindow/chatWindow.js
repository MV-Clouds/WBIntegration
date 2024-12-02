import { LightningElement, api, track } from 'lwc';
import fetchAllChats from '@salesforce/apex/ChatWindowController.fetchAllChats';
import createChat from '@salesforce/apex/ChatWindowController.createChat';
import emojiData from '@salesforce/resourceUrl/emojis_data';

export default class ChatWindow extends LightningElement {

    //Data Variables
    @api recordId;
    @api height;
    chats = [];
    @track groupedChats = [];
    @track isSun = true; // Default : Light mode (Sun)
    @track messageText = '';
    @track selectedTemplate = null;
    emojiCategories = [];

    //Control Variables
    @track showSpinner = false;
    showEmojiPicker = false;
    showAttachmentOptions = false;
    showSendOptions = false;
    scrollBottom = false;
    @track replyToMessage = null;

    //Get Variables
    get sunClass() {
        return `toggle-button sun-icon ${this.isSun ? "" : "hide"}`;
    }
    get moonClass() {
        return `toggle-button moon-icon ${this.isSun ? "hide" : "show"}`;
    }

    renderedCallback(){
        try {
            if(this.scrollBottom){
                let chatDiv = this.template.querySelector('.chat-div');
                if(chatDiv){
                    chatDiv.scrollTop = chatDiv.scrollHeight;
                    if(chatDiv.scrollHeight == chatDiv.scrollTop){                        
                        this.scrollBottom = false;
                    }
                }
            }
        } catch (e) {
            console.log('Error in function renderedCallback:::', e.message);
        }
    }

    connectedCallback(){
        try {
            this.configureHeight();
            this.getAllChats();
            this.generateEmojiCategories();

        } catch (e) {
            console.log('Error in connectedCallback:::', e.message);
        }
    }
    
// Fetch Initial Data
    getAllChats(){
        this.showSpinner = true;
        try {
            fetchAllChats({ contactId: this.recordId })
            .then(chats => {
                
                this.chats = chats;
                this.showSpinner = false;
                this.processChats();
            })
            .catch(e => {
                this.showSpinner = false;
                console.error('Error in fetchAllChats:', e.message);
            });
        } catch (e) {
            this.showSpinner = false;
            console.log('Error in function getAllChats:::', e.message);
        }
    }

    processChats(){
        this.showSpinner = true;
        try {
            let today = new Date();
            let yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);
            
            // Map chats to include additional properties and group them by date
            let options = { 
                day: '2-digit', 
                month: 'short', 
                year: 'numeric' 
            };
            const groupedChats = this.chats.reduce((acc, ch) => {
                let createDate = new Date(ch.CreatedDate).toLocaleDateString('en-GB', options);
                let dateGroup = createDate == today.toLocaleDateString('en-GB', options) ? 'Today' : (createDate == yesterday.toLocaleDateString('en-GB', options) ? 'Yesterday' : createDate);
                const chat = {
                    ...ch,
                    className: ch.Type_of_Message__c === 'Outbound Messages' ? 'sent-message' : 'received-message',
                    isSent: ch.Message_Status__c === 'Sent',
                    isDelivered: ch.Message_Status__c === 'Delivered',
                    isSeen: ch.Message_Status__c === 'Seen',
                    isSending: ch.Message_Status__c == null,
                    dateGroup: dateGroup
                };
    
                if (!acc[chat.dateGroup]) {
                    acc[chat.dateGroup] = [];
                }
                acc[chat.dateGroup].push(chat);
                return acc;
            }, {});
    
            // Transform groupedChats into an array for LWC template
            this.groupedChats = Object.entries(groupedChats).map(([date, messages]) => ({
                date,
                messages
            }));
            this.showSpinner = false;

            this.scrollBottom = true;
            

        } catch (e) {
            console.log('Error in function processChats:::', e.message);
            this.showSpinner = false;
        }
    }

// Setting the Height
    configureHeight(){
        try {
            if(!this.height || this.height<400) this.height = 400;
            if(this.height > 640) this.height = 640;
            this.template.host.style.setProperty("--height-of-main-chat-container", this.height + "px");
        } catch (e) {
            console.log('Error in function configureHeight:::', e.message);
        }
    }
    
// Theme Toggle
    toggleTheme() {
        try{
            this.isSun = !this.isSun;
            let theme = this.isSun ? "light" : "dark";
            this.template.host.setAttribute("data-theme", theme);
        }catch(e){
            console.log('Error in toggleTheme:::', e.message);
        }
    }

// Action Options to Message Functionalities (Reply, React, Copy)
    handleReply(event){
        try {
            console.log('Chat id in event is ::: ', event.currentTarget.dataset.chat);
            
            this.replyToMessage = this.chats?.find( chat => chat.Id === event.currentTarget.dataset.chat);
            console.log('The Chat for reply is :: ', this.replyToMessage);
        } catch (e) {
            console.log('Error in function handleReply:::', e.message);
        }
    }

// Emoji Support
    generateEmojiCategories() {
        try{
            fetch(emojiData)
            .then((response) => response.json())
            .then((data) => {
                // Group emojis by category
                const groupedEmojis = Object.values(
                    data.reduce((acc, item) => {
                        const category = item.category;
                        if (!acc[category]) {
                            acc[category] = { category, emojis: [] };
                        }
                        acc[category].emojis.push(item);
                        return acc;
                    }, {})
                );
        
                this.emojiCategories = groupedEmojis; // Assign the grouped data to this.emojis
                console.log(this.emojiCategories);
            })
            .catch((e) => console.log('There was an error fetching the emoji.', e));
        }catch(e){
            console.log('Error in generateEmojiCategories', e);
            
        }
    }

    handleEmojiButtonClick(){
        try {
            this.showEmojiPicker = !this.showEmojiPicker;
            this.template.host.style.setProperty("--height-for-emoji",this.showEmojiPicker ? "20rem" : "0rem");
            if(this.showEmojiPicker){
                this.template.querySelector('.emoji-picker-div').scrollTop = 0;
                this.template.host.style.setProperty("--max-height-for-attachment-options","0rem");
                this.template.host.style.setProperty("--max-height-for-send-options","0rem");
                this.showAttachmentOptions = false;
                this.showSendOptions = false;
            }
            this.scrollBottom = true;
        } catch (e) {
            console.log('Error in function handleEmojiButtonClick:::', e.message);
        }
    }

    handleEmojiClick(event){
        try {
            let textareaMessageElement = this.template.querySelector('.message-input');
            let textareaMessage = textareaMessageElement.value;
            let curPos = textareaMessageElement.selectionStart;
            textareaMessageElement.value = textareaMessage.slice(0, curPos) + event.target.innerText + textareaMessage.slice(curPos);
            textareaMessageElement.focus();
            textareaMessageElement.setSelectionRange(curPos + event.target.innerText.length,curPos + event.target.innerText.length); 
        } catch (e) {
            console.log('Error in function handleEmojiClick:::', e.message);
        }
    }

    handleMessageTextChange(event){
        try {
            let textareaMessageElement = this.template.querySelector('.message-input');
            console.log('the value is ::: ',textareaMessageElement.value);
            console.log('Lines in message ::: ', textareaMessageElement.value.split('\n').length);
            let lines = textareaMessageElement.value.split('\n').length;
            // lines = lines == 1 ? lines : lines + 1;
            this.template.host.style.setProperty('--height-of-text-area', lines*18 + 'px');
        } catch (e) {
            console.log('Error in function handleMessageTextChange:::', e.message);
        }
    }
// Attachments Support
    handleAttachmentButtonClick(){
        try {
            this.showAttachmentOptions = !this.showAttachmentOptions;
            this.template.host.style.setProperty("--max-height-for-attachment-options",this.showAttachmentOptions ? "11rem" : "0rem");
            if(this.showAttachmentOptions){
                this.template.host.style.setProperty("--max-height-for-send-options","0rem");
                this.template.host.style.setProperty("--height-for-emoji","0rem");
                this.showEmojiPicker = false;
                this.showSendOptions = false;
            }
        } catch (e) {
            console.log('Error in function handleAttachmentButtonClick:::', e.message);
        }
    }

// Sending the message
    handleOpenSendOptions(){
        try {
            this.showSendOptions = ! this.showSendOptions;
            this.template.host.style.setProperty("--max-height-for-send-options",this.showSendOptions ? "7rem" : "0rem");
            if(this.showSendOptions){
                this.template.host.style.setProperty("--max-height-for-attachment-options","0rem");
                this.template.host.style.setProperty("--height-for-emoji","0rem");
                this.showAttachmentOptions = false;
                this.showEmojiPicker = false;
            }
        } catch (e) {
            console.log('Error in function handleOpenSendOptions:::', e.message);
        }
    }

    handleSendMessage(){
        this.showSpinner = true;
        try {
            this.template.querySelector('.dropdown-menu')?.classList?.add('hidden');
            this.messageText = this.template.querySelector('.message-input').value;
            createChat({message: this.messageText, templateId: this.selectedTemplate, messageType: 'text', recordId: this.recordId})
            .then(chat => {
                if(chat){
                    console.log('The New Message is ::: ', chat);
                    this.chats.push(chat);
                    this.processChats();
                    this.showSpinner = false;
                    this.messageText = '';
                    textareaMessageElement.value = '';
                }else{
                    this.showSpinner = false;
                    console.log('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                console.log('Error in sendImmediateMessage > createChat :: ', e);
            })
        } catch (e) {
            this.showSpinner = false;
            console.log('Error in sendImmediateMessage:::', e.message);
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