import { LightningElement,track } from 'lwc';

export default class WbShowBroadcastMessage extends LightningElement {
    @track isBroadcastMessage=true;
    @track tempName='';
    @track delivered='';
    @track sendDate='';
    @track bgName='';
    @track readRate='';
    
}