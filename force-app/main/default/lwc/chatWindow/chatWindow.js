import { LightningElement, api, track } from 'lwc';
import fetchAllChats from '@salesforce/apex/ChatWindowController.fetchAllChats';
import createChat from '@salesforce/apex/ChatWindowController.createChat';
import updateReaction from '@salesforce/apex/ChatWindowController.updateReaction';
import emojiData from '@salesforce/resourceUrl/emojis_data';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

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
    @track replyToMessage = null;
    @track reactToMessage = null;
    @track noteText = '';

    //Control Variables
    @track showSpinner = false;
    @track noChatMessages = false;
    showEmojiPicker = false;
    showAttachmentOptions = false;
    // showSendOptions = false;
    scrollBottom = false;
    @track showReactEmojiPicker = false;
    @track sendOnlyTemplate = false;

    @track acceptedFormats = ['.jpg', '.png', '.jpeg'];
    @track showFileUploader = false;
    @track uploadFileType = null;

    replyBorderColors = ['#34B7F1', '#FF9500', '#B38F00', '#ffa5c0', '#ff918b'];

    //Get Variables
    get sunClass() {
        return `toggle-button sun-icon ${this.isSun ? "" : "hide"}`;
    }
    get moonClass() {
        return `toggle-button moon-icon ${this.isSun ? "hide" : "show"}`;
    }
    get showPopup(){
        return this.showFileUploader;
    }
    
    get displayBackDrop(){
        return this.showEmojiPicker || this.showAttachmentOptions || this.showFileUploader;
    }

    get uploadLabel(){
        return 'Upload '+ this.uploadFileType || 'File';
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

    renderedCallback(){
        try {
            if(this.scrollBottom){
                let chatDiv = this.template.querySelector('.chat-div');
                if(chatDiv){
                    chatDiv.scrollTop = chatDiv.scrollHeight;
                }
                this.scrollBottom = false;
            }
        } catch (e) {
            console.log('Error in function renderedCallback:::', e.message);
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
                this.processChats(true);
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

    processChats(needToScroll){
        try {
            this.noChatMessages = this.chats?.length < 1 ? true : false;
            if(this.noChatMessages) {
                this.sendOnlyTemplate = true;
                this.noteText = 'The conversation hasn\'t started yet. Begin by sending a template!';
                return;
            }
            this.showSpinner = true;
            let today = new Date();
            let yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);
            
            // Map chats to include additional properties and group them by date
            let options = { 
                day: '2-digit', 
                month: 'short', 
                year: 'numeric' 
            };
            let groupedChats = this.chats?.reduce((acc, ch) => {
                let createDate = new Date(ch.CreatedDate).toLocaleDateString('en-GB', options);
                let dateGroup = createDate == today.toLocaleDateString('en-GB', options) ? 'Today' : (createDate == yesterday.toLocaleDateString('en-GB', options) ? 'Yesterday' : createDate);
                let chat = {
                    ...ch,
                    className: ch.Type_of_Message__c === 'Outbound Messages' ? 'sent-message' : 'received-message',
                    isSent: ch.Message_Status__c === 'Sent',
                    isDelivered: ch.Message_Status__c === 'Delivered',
                    isSeen: ch.Message_Status__c === 'Seen',
                    isSending: ch.Message_Status__c == null,
                    dateGroup: dateGroup,
                    replyTo: this.chats?.find( chat => chat.Id === ch.Reply_to__c)
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
            this.checkLastMessage();

            if(needToScroll) this.scrollBottom = true;
            

        } catch (e) {
            console.log('Error in function processChats:::', e.message);
            this.showSpinner = false;
        }
    }
    
    checkLastMessage(){
        this.showSpinner = true;
        try {
            let inboundMessages = this.chats.filter(msg => msg.Type_of_Message__c === 'Inbound Messages');
            let latestInboundMessage = inboundMessages.sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate))[0];

            if (latestInboundMessage) {
                let currentTime = new Date();
                let messageTime = new Date(latestInboundMessage.CreatedDate);
                let timeDifferenceInMilliseconds = currentTime - messageTime;
                let hoursDifference = timeDifferenceInMilliseconds / (1000 * 60 * 60);

                if (hoursDifference > 24){
                     this.sendOnlyTemplate = true;
                     this.noteText = "Only template can be sent as no messages were received from this contact in last 24 hours.";
                }
            } else {
                console.log('No inbound messages found.');
            }
            this.showSpinner = false;
        } catch (e) {
            this.showSpinner = false;
            console.log('Error in function checkLastMessage:::', e.message);
        }
    }

// Setting the Height
    configureHeight(){
        try {
            if(!this.height || this.height<400) this.height = 400;
            if(this.height > 640) this.height = 640;
            this.template.host.style.setProperty("--height-of-main-chat-container", this.height + "px");

            let randomIndex = Math.floor(Math.random() * this.replyBorderColors.length);
            this.template.host.style.setProperty('--reply-to-received-border-color', this.replyBorderColors[randomIndex]);
        } catch (e) {
            console.log('Error in function configureHeight:::', e.message);
        }
    }
//Handling the Backdrop

    handleBackDropClick(){
        try {
            this.closeAllPopups();
            this.reactToMessage = null;
            this.showReactEmojiPicker = false;
            this.showFileUploader = false;
            this.uploadFileType = null;
            this.showEmojiPicker = false;
            this.showAttachmentOptions = false;
        } catch (e) {
            console.log('Error in function handleBackDropClick:::', e.message);
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

    closeAllPopups(){
        this.template.host.style.setProperty("--max-height-for-attachment-options","0rem");
        this.template.host.style.setProperty("--max-height-for-send-options","0rem");
        this.template.host.style.setProperty("--height-for-emoji","0rem");
    }

// Action Options to Message Functionalities (Reply, React, Copy)

    handleToggleActions(event){
        try {
            this.template.querySelectorAll('.show-options').forEach(ele => {if(ele != event.currentTarget) ele.classList.remove('.show-options')});
            event.currentTarget.classList.toggle('show-options');
        } catch (e) {
            console.log('Error in function handleToggleActions:::', e.message);
        }
    }

    handleChatAction(event){
        try {
            let actionType = event.currentTarget.dataset.action;
            let chatId = event.currentTarget.dataset.chat;
            if(actionType === 'reply'){
                this.replyToMessage = this.chats?.find( chat => chat.Id === chatId);
                this.template.querySelector('.message-input').focus();
            }else if(actionType === 'react'){
                this.reactToMessage = chatId;
                this.showReactEmojiPicker = true;
            }else if(actionType === 'copy'){
                navigator.clipboard.writeText(event.currentTarget.dataset.message);
            }else if(actionType === 'cancel-reply'){
                this.replyToMessage = null;
            }else if(actionType === 'cancel-react'){
                this.reactToMessage = null;
                this.showReactEmojiPicker = false;
            }
        } catch (e) {
            console.log('Error in function handleReply:::', e.message);
        }
    }

    handleReactWithEmoji(event){
        try {
            if(this.reactToMessage){
                let chat = this.chats?.find( ch => ch.Id === this.reactToMessage);
                chat.Reaction__c = event.target.innerText;
                this.reactToMessage = null;
                this.showReactEmojiPicker = false;
                this.updateMessageReaction(chat);
            }
        } catch (e) {
            console.log('Error in function handleReactWithEmoji:::', e.message);
        }
    }

    handleRemoveReaction(event){
        try {
            let chat = this.chats?.find( chat => chat.Id === event.currentTarget.dataset.chat);
            chat.Reaction__c = null;
            this.updateMessageReaction(chat);
        } catch (e) {
            console.log('Error in function handleRemoveReaction:::', e.message);
        }
    }

    handleToggleImagePreview(event){
        try {
            let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
            if(isMobileDevice){
                return;
            }
            let action = event.currentTarget.dataset.action;
            console.log('Actions is :: ', action);
            
            if(action == 'open'){
                event.currentTarget.classList.add('show-image-preview');
            }else if(action == 'close'){
                this.template.querySelector('.show-image-preview').classList.remove('show-image-preview');
                event.stopPropagation()
            }
        } catch (e) {
            console.log('Error in function handleToggleImagePreview:::', e.message);
        }
    }

// Emoji Support
    generateEmojiCategories() {
        try{
            fetch(emojiData)
            .then((response) => response.json())
            .then((data) => {
                // Group emojis by category
                let groupedEmojis = Object.values(
                    data.reduce((acc, item) => {
                        let category = item.category;
                        if (!acc[category]) {
                            acc[category] = { category, emojis: [] };
                        }
                        acc[category].emojis.push(item);
                        return acc;
                    }, {})
                );
        
                this.emojiCategories = groupedEmojis; // Assign the grouped data to this.emojis
            })
            .catch((e) => console.log('There was an error fetching the emoji.', e));
        }catch(e){
            console.log('Error in generateEmojiCategories', e);
            
        }
    }

    handleEmojiButtonClick(){
        try {
            this.showEmojiPicker = !this.showEmojiPicker;
            this.closeAllPopups();
            this.template.host.style.setProperty("--height-for-emoji",this.showEmojiPicker ? "20rem" : "0rem");
            if(this.showEmojiPicker){
                this.template.querySelector('.emoji-picker-div').scrollTop = 0;
            }
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
    handleMessageTextChange(event) {
        try {
            let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
            let textareaMessageElement = this.template.querySelector('.message-input');
            if (!isMobileDevice && event.key === 'Enter') {
                if (event.shiftKey || event.ctrlKey || event.altKey || event.metaKey) {
                    return;
                }
                event.preventDefault();
                this.handleSendMessage();
                textareaMessageElement.blur();
                return;
            }
            textareaMessageElement.style.height = 'auto';
            textareaMessageElement.style.height = `${textareaMessageElement.scrollHeight}px`;
            this.showAttachmentOptions = false;
            this.template.host.style.setProperty("--max-height-for-attachment-options","0rem");
        } catch (e) {
            console.log('Error in function handleMessageTextChange:::', e.message);
        }
    }
    
// Attachments Support
    handleAttachmentButtonClick(){
        try {
            this.showAttachmentOptions = !this.showAttachmentOptions;
            this.closeAllPopups();
            this.template.host.style.setProperty("--max-height-for-attachment-options",this.showAttachmentOptions ? "13rem" : "0rem");
        } catch (e) {
            console.log('Error in function handleAttachmentButtonClick:::', e.message);
        }
    }

    handleImageUpload() {
        try {
            if(this.sendOnlyTemplate){
                this.showToast('Cannot send photo!', 'You don\'t have any message from contact since last 24 hours.', 'info');
                return;
            }
            this.showFileUploader = true;
            this.uploadFileType = 'Image';
            this.closeAllPopups();
        } catch (e) {
            console.error('Error in function handleImageUpload:::', e.message);
        }
    }

    handleUploadFinished(event){
        this.showSpinner = true;
        try {
            console.log('The Data file is been Uploaded!!', event.detail.files);
            if(!(event.detail.files.length > 0)){
                this.showSpinner = false;
                return;
            }
            createChat({chatData: {message: event.detail.files[0].contentVersionId, templateId: this.selectedTemplate, messageType: 'Image', recordId: this.recordId, replyToChatId: this.replyToMessage?.Id || null}})
            .then(chat => {
                if(chat){
                    console.log('The New Image Message is ::: ', chat);
                    this.chats.push(chat);
                    this.messageText = '';
                    this.template.querySelector('.message-input').value = '';
                    this.replyToMessage = null;
                    this.showSpinner = false;
                    this.processChats(true);
                }else{
                    this.showSpinner = false;
                    this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
                    console.log('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
                console.log('Error in sendImmediateMessage > createChat :: ', e);
            })
            this.uploadFileType = null;
            this.showFileUploader = false;
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
            console.log('Error in function handleUploadFinished:::', e.message);
        }
    }
    
    handleImageError(event){
        try {
            console.log('The Image is Not Previewable.');
            event.target.src = "/resource/Alt_Image";
        } catch (e) {
            console.log('Error in function handleImageError:::', e.message);
        }
    }

// Sending the message
    // handleOpenSendOptions(){
    //     try {
    //         this.showSendOptions = ! this.showSendOptions;
    //         this.closeAllPopups();
    //         this.template.host.style.setProperty("--max-height-for-send-options",this.showSendOptions ? "7rem" : "0rem");
    //     } catch (e) {
    //         console.log('Error in function handleOpenSendOptions:::', e.message);
    //     }
    // }

    updateMessageReaction(chat){
        this.showSpinner = true;
        try {
            updateReaction({chatId: chat.Id, reaction:chat.Reaction__c})
            .then(ch => {
                console.log('Updated Chat is ::: ', ch);
                this.showSpinner = false;
                this.processChats();
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'The reaction could not be updated, please try again.', 'error');
                console.log('Error in updateReaction > updateReaction :: ', e);
            })
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'The reaction could not be updated, please try again.', 'error');
            console.log('Error in function updateReaction:::', e.message);
        }
    }

    handleSendMessage(){
        this.showSpinner = true;
        try {
            this.handleBackDropClick();
            this.template.querySelector('.dropdown-menu')?.classList?.add('hidden');
            this.messageText = this.template.querySelector('.message-input').value;
            if(this.messageText.trim().length < 1){
                this.showToast('Something went wrong!', 'Please enter a message to send.', 'error');
                this.showSpinner = false;
                return;
            }
            if(this.sendOnlyTemplate){
                this.showToast('Cannot send text message.', 'You don\'t have any message from contact since last 24 hours.', 'info');
                this.showSpinner = false;
                return;
            }
            createChat({chatData: {message: this.messageText, templateId: this.selectedTemplate, messageType: 'text', recordId: this.recordId, replyToChatId: this.replyToMessage?.Id || null}})
            .then(chat => {
                if(chat){
                    let textareaMessageElement = this.template.querySelector('.message-input');
                    console.log('The New Message is ::: ', chat);
                    this.chats.push(chat);
                    this.showSpinner = false;
                    this.messageText = '';
                    this.replyToMessage = null;
                    this.processChats(true);
                    textareaMessageElement.value = '';
                    textareaMessageElement.style.height = 'auto';
                    textareaMessageElement.style.height = `${textareaMessageElement.scrollHeight}px`;
                }else{
                    this.showSpinner = false;
                    this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
                    console.log('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
                console.log('Error in sendImmediateMessage > createChat :: ', e);
            })
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
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

    // Toast Notification
    showToast(title ,message, status){
        try {
            let evt = new ShowToastEvent({
                title: title,
                message: message,
                variant: status,
                mode: 'dismissible'
            });
            this.dispatchEvent(evt);
        } catch (e) {
            console.log('Error in function showToast:::', e.message);
        }
    }
}