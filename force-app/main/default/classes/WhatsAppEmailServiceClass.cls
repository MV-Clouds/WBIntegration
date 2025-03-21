/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-02-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class WhatsAppEmailServiceClass implements Messaging.InboundEmailHandler {
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        try {
            Messaging.InboundEmailResult result = new Messaging.InboundEmailresult();
            String emailBody = email.plainTextBody;
            System.debug('emailBody '+emailBody);
            Map<String,Object> jsonMap = (Map<String,Object>)JSON.deserializeUntyped(emailBody);
            System.debug(jsonMap);
    
            ContentDocumentLink contentDocumentLink = new ContentDocumentLink(
                    ContentDocumentId = jsonMap.get( 'contentDocumentId' ).toString(),
                    LinkedEntityId = jsonMap.get( 'linkedEntityId' ).toString(),
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
            insert contentDocumentLink;
            return result;
        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppEmailServiceClass', 'handleInboundEmail', e.getMessage());
            return null;
        }

    }
}