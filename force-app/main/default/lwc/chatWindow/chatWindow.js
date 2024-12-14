import { LightningElement, api, track } from 'lwc';
import getCombinedData from '@salesforce/apex/ChatWindowController.getCombinedData';
import createChat from '@salesforce/apex/ChatWindowController.createChat';
import updateReaction from '@salesforce/apex/ChatWindowController.updateReaction';
import sendWhatsappMessage from '@salesforce/apex/ChatWindowController.sendWhatsappMessage';
import emojiData from '@salesforce/resourceUrl/emojis_data';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import updateThemePreference from '@salesforce/apex/ChatWindowController.updateThemePreference';
import updateStatus from '@salesforce/apex/ChatWindowController.updateStatus';
import { subscribe} from 'lightning/empApi';

export default class ChatWindow extends LightningElement {

    //Data Variables
    @api recordId;
    @api height;
    chats = [];

    recordData;
    @track groupedChats = [];
    @track isLightMode = true; // Default : Light mode (Sun)
    @track messageText = '';
    @track selectedTemplate = null;
    @track allTemplates = [];
    @track templateSearchKey = null;
    emojiCategories = [];
    @track replyToMessage = null;
    @track reactToMessage = null;
    @track noteText = '';

    //Control Variables
    @track showSpinner = false;
    @track noChatMessages = true;
    showEmojiPicker = false;
    showAttachmentOptions = false;
    // showSendOptions = false;
    scrollBottom = false;
    @track showReactEmojiPicker = false;
    @track sendOnlyTemplate = false;

    @track acceptedFormats = [];
    @track showFileUploader = false;
    @track showTemplateSelection = false;
    @track showTemplatePreview = false;
    @track uploadFileType = null;

    replyBorderColors = ['#34B7F1', '#FF9500', '#B38F00', '#ffa5c0', '#ff918b'];

    subscription = {};
    channelName = '/event/Chat_Message__e';

    //Get Variables
    get sunClass() {
        return `toggle-button sun-icon ${this.isLightMode ? "" : "hide"}`;
    }
    get moonClass() {
        return `toggle-button moon-icon ${this.isLightMode ? "hide" : "show"}`;
    }
    get showPopup(){
        return this.showFileUploader || this.showTemplateSelection || this.showTemplatePreview;
    }
    
    get displayBackDrop(){
        return this.showEmojiPicker || this.showAttachmentOptions || this.showFileUploader || this.showTemplateSelection || this.showTemplatePreview;
    }

    get uploadLabel(){
        return 'Upload '+ this.uploadFileType || 'File';
    }

    get filteredTemplate(){
        let searchedResult = (this.allTemplates?.filter(template => template.Name.toLowerCase().includes(this.templateSearchKey?.toLowerCase())));
        return this.templateSearchKey ? (searchedResult.length > 0 ? searchedResult : null) : this.allTemplates;
    }

    get recordMobileNumber(){
        return this.recordData.Phone;
    }

    get replyToTemplateId(){
        return this.allTemplates.find(t => t.Id == this.replyToMessage.Whatsapp_Template__c)?.Name || null;
    }

    connectedCallback(){
        try {
            this.configureHeight();
            this.getInitialData();
            this.generateEmojiCategories();
            this.handleSubscribe();
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

    handleSubscribe() {
        let self = this;
        let messageCallback = function (response) {
            let receivedChat = JSON.parse(response.data.payload.Chat_Data__c);
            
            let actionType = response.data.payload.Type__c;
            
            if(response.data.payload.ContactId__c !== self.recordId) return;
            console.log(actionType ,' status :: ', receivedChat.Message_Status__c ,' Chat received is :: ', receivedChat.WhatsAppMessageId__c);

            let chat = self.chats?.find(ch => ch.Id === receivedChat.Id);
            
            switch (actionType) {

                case 'new':
                    chat = receivedChat;
                    self.chats.push(chat);
                    self.processChats(true);
                    self.sendOnlyTemplate = false;
                    break;

                case 'status':
                    chat.Message_Status__c = receivedChat.Message_Status__c;
                    break;

                case 'react':
                    chat.Reaction__c = receivedChat.Reaction__c;
                    break;

                case 'update':
                    chat.Message__c = receivedChat.Message__c;
                    break;

                case 'delete':
                    self.chats = self.chats.filter(ch => ch.Id !== receivedChat.Id);
                    break;
            
                default:
                    break;
            }
            
            self.processChats();
        };
 
        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
        });
    }


// Fetch Initial Data
    getInitialData(){
        this.showSpinner = true;
        try {
            getCombinedData({ contactId: this.recordId })
            .then(combinedData => {

                if(combinedData.theme){
                    this.isLightMode = combinedData.theme == 'light';
                    if(!this.isLightMode) this.template.host.setAttribute("data-theme", combinedData.theme);
                }

                if(combinedData.record){
                    if(!combinedData.record.Phone){
                        this.showToast('Something went wrong!', 'The contact does not have a mobile number.', 'error');
                        this.showSpinner = false;
                        return;
                    }
                    combinedData.record.Phone = combinedData.record.Phone.replaceAll(' ', '').replace('+', '');
                    this.recordData = combinedData.record;
                }else{
                    this.showToast('Something went wrong!', 'Couldn\'t fetch data of contact', 'error');
                    this.showSpinner = false;
                    return;
                }

                this.allTemplates = combinedData.templates.length > 0 ? combinedData.templates : null;
                
                this.chats = JSON.parse(JSON.stringify(combinedData.chats));
                this.showSpinner = false;
                this.processChats(true);
                
                let chatIdsToSeen = [];
                this.chats.filter(ch => ch.Type_of_Message__c != 'Outbound Messages').forEach(ch =>{
                    if(ch.Message_Status__c!='Seen') chatIdsToSeen.push(ch.Id);
                })
                updateStatus({messageIds:chatIdsToSeen});
            })
            .catch(e => {
                this.showSpinner = false;
                console.error('Error in getCombinedData:', e.message);
            });
        } catch (e) {
            this.showSpinner = false;
            console.log('Error in function getInitialData:::', e.message);
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
            this.chats = this.chats?.map(ch => {
                ch.isText = ch.Message_Type__c == 'Text';
                ch.isImage = ch.Message_Type__c == 'Image';
                ch.isVideo = ch.Message_Type__c == 'Video';
                ch.isTemplate = ch.Message_Type__c == 'Template';
                ch.messageBy = ch.Type_of_Message__c == 'Outbound Messages' ? 'You' : this.recordData.Name;
                return ch;
            });

            this.showSpinner = true;
            let today = new Date();
            let yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);
            
            let options = { 
                day: '2-digit', 
                month: 'short', 
                year: 'numeric' 
            };
            let groupedChats = this.chats?.reduce((acc, ch) => {
                let createDate = new Date(ch.CreatedDate).toLocaleDateString('en-GB', options);
                let dateGroup = createDate == today.toLocaleDateString('en-GB', options) ? 'Today' : (createDate == yesterday.toLocaleDateString('en-GB', options) ? 'Yesterday' : createDate);
                let yourReaction= ch.Reaction__c?.split('<|USER|>')[0];
                let userReaction= ch.Reaction__c?.split('<|USER|>')[1];
                let chat = {
                    ...ch,
                    className: ch.Type_of_Message__c === 'Outbound Messages' ? 'sent-message' : 'received-message',
                    // isSent: ch.Message_Status__c === 'Sent',
                    // isDelivered: ch.Message_Status__c === 'Delivered',
                    // isSeen: ch.Message_Status__c === 'Seen',
                    isTick : ['Sent', 'Delivered', 'Seen'].includes(ch.Message_Status__c), 
                    isFailed: ch.Message_Status__c === 'Failed',
                    isSending: ch.Message_Status__c == null,
                    dateGroup: dateGroup,
                    yourReaction: yourReaction,
                    userReaction: userReaction,
                    isReaction: yourReaction || userReaction,
                    replyTo: this.chats?.find( chat => chat.Id === ch.Reply_to__c)
                };
                
                if (!acc[chat.dateGroup]) {
                    acc[chat.dateGroup] = [];
                }
                acc[chat.dateGroup].push(chat);
                return acc;
            }, {});
    
            this.groupedChats = Object.entries(groupedChats).map(([date, messages]) => ({
                date,
                messages
            }));
            
            this.showSpinner = false;
            if(needToScroll) this.scrollBottom = true;
            this.checkLastMessage();
        } catch (e) {
            console.log('Error in function processChats:::', e.message);
            this.showSpinner = false;
        }
    }
    
    checkLastMessage(){
        this.showSpinner = true;
        try {
            let inboundMessages = this.chats.filter(msg => msg.Type_of_Message__c === 'Inbound Messages');
            let latestInboundMessage = inboundMessages.sort((a, b) => new Date(b.Last_Interaction_Date__c) - new Date(a.Last_Interaction_Date__c))[0];

            if (latestInboundMessage) {
                let currentTime = new Date();
                let messageTime = new Date(latestInboundMessage.Last_Interaction_Date__c);
                let timeDifferenceInMilliseconds = currentTime - messageTime;
                let hoursDifference = timeDifferenceInMilliseconds / (1000 * 60 * 60);

                if (hoursDifference > 24){
                    this.sendOnlyTemplate = true;
                    this.noteText = "Only template can be sent as no messages were received from this contact in last 24 hours.";
                }
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
            this.showTemplateSelection = false;
            this.showTemplatePreview = false;
            this.acceptedFormats = [];
            this.uploadFileType = null;
            this.showEmojiPicker = false;
            this.showAttachmentOptions = false;
            this.selectedTemplate = null;
        } catch (e) {
            console.log('Error in function handleBackDropClick:::', e.message);
        }
    }
    
// Theme Toggle
    toggleTheme() {
        try{
            this.isLightMode = !this.isLightMode;
            let theme = this.isLightMode ? "light" : "dark";
            this.template.host.setAttribute("data-theme", theme);
            updateThemePreference({theme: theme})
            .then((isSuccess) => {
                if(isSuccess){
                    this.showToast('Success!',`Your theme preference has been updated to ${theme}.`, 'success');
                }else{
                    this.showToast('Error!','Failed to save preference, you can continue using theme for this session.', 'error');
                }
                console.log('Update theme completed');
                
            })
            .catch((e) => {
                console.log('Failed to update theme preference!.', e.message);
                
            });
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
            event.currentTarget.classList.toggle('show-options');
        } catch (e) {
            console.log('Error in function handleToggleActions:::', e.message);
        }
    }

    handleHideActions(event){
        try {
            event.currentTarget.classList.remove('show-options');
        } catch (e) {
            console.log('Error in function handleHideActions:::', e.message);
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
                this.showToast('Success!', 'The message text has been copied to clipboard.', 'success');
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
                chat.Reaction__c = event.target.innerText + (chat.Reaction__c ? chat.Reaction__c.slice(chat.Reaction__c.indexOf('<|USER|>')) : '<|USER|>');
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
            chat.Reaction__c = chat.Reaction__c?.slice(chat.Reaction__c.indexOf('<|USER|>'));
            this.updateMessageReaction(chat);
        } catch (e) {
            console.log('Error in function handleRemoveReaction:::', e.message);
        }
    }

    handleReplyMessageClick(event){
        try {            
            let replyTo = event.currentTarget.dataset.replyTo;

            let replyToChatEle = this.template.querySelector(`.message-full-length-div[data-id="${replyTo}"]`);
            if(!replyToChatEle){
                return;
            }
            replyToChatEle.scrollIntoView({behavior: 'smooth', block:'center'});

            let chatBlink = [
                { backgroundColor: "#a9a9a990" },
                { backgroundColor: "transparent" },
            ];
            
            let blinkTiming = {
                duration: 1000,
                iterations: 1,
            };
            let observer = new IntersectionObserver(
                (entries) => {
                    entries.forEach((entry) => {
                        if (entry.isIntersecting) {
                            replyToChatEle.animate(chatBlink, blinkTiming);
                            observer.unobserve(entry.target);
                        }
                    });
                },
                { threshold: 1 }
            );
    
            // Start observing the element
            observer.observe(replyToChatEle);
            
        } catch (e) {
            console.log('Error in function handleReplyMessageClick:::', e.message);
        }
    }
    handleToggleImagePreview(event){
        try {
            let isMobileDevice = /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent); 
            if(isMobileDevice){
                return;
            }
            let action = event.currentTarget.dataset.action;
            
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

    handleAttachmentOptionClick(event) {
        try {
            let mediaType = event.target.dataset.media;
            this.checkLastMessage();
            if(this.sendOnlyTemplate && mediaType != 'Template'){
                this.showToast(`Cannot send ${mediaType}!`, 'You don\'t have any response from contact in last 24 hours.', 'info');
                return;
            }
            
            switch (mediaType) {
                case 'Template':
                    this.showTemplatePreview = false;
                    this.showTemplateSelection = true;
                    this.replyToMessage = null;
                    break;
                case 'Image':
                    this.showFileUploader = true;
                    this.acceptedFormats = ['.jpg', '.png', '.jpeg'];
                    this.uploadFileType = 'Image';
                    break;
                default:
                    this.showToast('Something went wrong!', 'Could not process request, please try again.', 'error');
                    break;
            }
            this.closeAllPopups();
        } catch (e) {
            console.error('Error in function handleAttachmentOptionClick:::', e.message);
        }
    }

    handleUploadFinished(event){
        this.showSpinner = true;
        try {
            if(!(event.detail.files.length > 0)){
                this.showSpinner = false;
                return;
            }
            createChat({chatData: {message: event.detail.files[0].contentVersionId, templateId: this.selectedTemplate, messageType: 'Image', recordId: this.recordId, replyToChatId: this.replyToMessage?.Id || null}})
            .then(chat => {
                if(chat){
                    this.chats.push(chat);
                    this.processChats(true);
                    let imagePayload = this.createJSONBody(this.recordData.Phone, "image", this.replyToMessage?.WhatsAppMessageId__c || null, {
                        link: chat.Message__c,
                        fileName: event.detail.files[0].title
                    });
                    sendWhatsappMessage({jsonData: imagePayload, chatId: chat.Id, isReaction: false})
                    .then(ch => {
                        this.chats.find(ch => ch.Id === chat.Id).Message_Status__c = ch.Message_Status__c;
                        this.chats.find(ch => ch.Id === chat.Id).WhatsAppMessageId__c = ch.WhatsAppMessageId__c;
                        this.messageText = '';
                        this.template.querySelector('.message-input').value = '';
                        this.replyToMessage = null;
                        this.showSpinner = false;
                        this.processChats();
                        this.handleBackDropClick();
                    })
                }else{
                    this.showSpinner = false;
                    this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
                    console.log('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
                console.log('Error in handleUploadFinished > createChat :: ', e);
            })
            this.uploadFileType = null;
            this.showFileUploader = false;
            this.acceptedFormats = [];
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'The photo could not be sent, please try again.', 'error');
            console.log('Error in function handleUploadFinished:::', e.message);
        }
    }
    
    handleImageError(event){
        try {
            event.currentTarget.src = "/resource/Alt_Image";
            event.currentTarget.parentNode.classList.add('not-loaded-image');
        } catch (e) {
            console.log('Error in function handleImageError:::', e.message);
        }
    }

    handleSearchTemplate(event){
        try {
            this.templateSearchKey = event.target.value || null;
        } catch (e) {
            console.log('Error in function handleSearchTemplate:::', e.message);
        }
    }

    handleShowTemplatePreview(event){
        try {
            if(event.currentTarget.dataset.id){
                this.selectedTemplate = event.currentTarget.dataset.id;
                this.showTemplateSelection = false;
                this.showTemplatePreview = true;
            }
        } catch (e) {
            console.log('Error in function handleShowTemplatePreview:::', e.message);
        }
    }

    handleBackToList(){
        try {
            this.selectedTemplate = null;
            this.showTemplatePreview = false;
            this.showTemplateSelection = true;
        } catch (e) {
            console.log('Error in function handleBackToList:::', e.message);
        }
    }

    handleTemplateSent(event){
        try {
            this.showTemplateSelection = false;
            let chat = event.detail;
            this.chats.push(chat);
            this.handleBackDropClick();
            this.showSpinner = false;
            this.processChats(true);
        } catch (e) {
            console.log('Error in function handleTemplateSent:::', e.message);
        }
    }

    createJSONBody(to, type, replyId, data){
        try {
                let payload = `{ "messaging_product": "whatsapp", 
                                "to": "${to}",
                                "type": "${type}"`;
                if(replyId) payload += `, "context": {"message_id": "${replyId}"}`;
            
                if (type === "text") {
                    payload += `, "text": { "body": "${data.textBody.replace(/\n/g, "\\n")}" }`;
                } else if (type === "image") {
                    payload += `, "image": { "imageLink": "${data.imageLink}" }`;
                } else if (type === "reaction"){
                    payload += `, "reaction": { 
                        "message_id": "${data.reactToId}",
                        "emoji": "${data.emoji}"
                        }`;
                }
                payload += ` }`;
            
                return payload;
        } catch (e) {
            console.log('Error in function createJSONBody:::', e.message);
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
                this.showSpinner = false;
                this.processChats();
                let reactPayload = this.createJSONBody(this.recordData.Phone, "reaction", this.replyToMessage?.WhatsAppMessageId__c || null, {
                    reactToId : chat.WhatsAppMessageId__c,
                    emoji: chat.Reaction__c?.split('<|USER|>')[0]
                });
                console.log('ReactPayload :: ', reactPayload);
                
                sendWhatsappMessage({jsonData: reactPayload, chatId: chat.Id, isReaction: true})
                    .then(ch => {
                        console.log('Chat reply is :: ', chat.Id);
                        console.log('Ch :: ', ch);
                        
                        
                        this.chats.find(ch => ch.Id === chat.Id).Message_Status__c = ch.Message_Status__c;
                        this.chats.find(ch => ch.Id === chat.Id).WhatsAppMessageId__c = ch.WhatsAppMessageId__c;
                        this.processChats();
                })
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'The reaction could not be updated, please try again.', 'error');
                console.log('Error in updateMessageReaction > updateReaction :: ', e);
            })
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'The reaction could not be updated, please try again.', 'error');
            console.log('Error in function updateMessageReaction:::', e.message);
        }
    }

    handleSendMessage(){
        this.showSpinner = true;
        try {
            this.handleBackDropClick();
            this.template.querySelector('.dropdown-menu')?.classList?.add('hidden');
            this.messageText = this.template.querySelector('.message-input').value;
            this.checkLastMessage();
            if(this.sendOnlyTemplate){
                this.showToast('Cannot send text message!', 'You don\'t have any response from contact in last 24 hours.', 'info');
                return;
            }
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
                    let textPayload = this.createJSONBody(this.recordData.Phone, "text", this.replyToMessage?.WhatsAppMessageId__c || null, {
                        textBody: this.messageText
                    });
                    let textareaMessageElement = this.template.querySelector('.message-input');
                    this.chats.push(chat);
                    this.showSpinner = false;
                    this.messageText = '';
                    this.replyToMessage = null;
                    this.processChats(true);
                    textareaMessageElement.value = '';
                    textareaMessageElement.style.height = 'auto';
                    textareaMessageElement.style.height = `${textareaMessageElement.scrollHeight}px`;

                    sendWhatsappMessage({jsonData: textPayload, chatId: chat.Id, isReaction: false})
                    .then(ch => {
                        this.chats.find(ch => ch.Id === chat.Id).Message_Status__c = ch.Message_Status__c;
                        this.chats.find(ch => ch.Id === chat.Id).WhatsAppMessageId__c = ch.WhatsAppMessageId__c;
                        this.processChats();
                    })
                }else{
                    this.showSpinner = false;
                    this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
                    console.log('there was some error sending the message!');
                }
            })
            .catch((e) => {
                this.showSpinner = false;
                this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
                console.log('Error in handleSendMessage > createChat :: ', e);
            })
        } catch (e) {
            this.showSpinner = false;
            this.showToast('Something went wrong!', 'Message could not be sent, please try again.', 'error');
            console.log('Error in handleSendMessage:::', e.message);
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