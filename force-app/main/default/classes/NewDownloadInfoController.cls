/**
 * Class Name: NewDownloadInfoController
 * Test Class: -
 * @description: Used to handle the emails and store the org data
 * ****************************************************************
 * @Note: This class isn not to be added to the package, it's for the handler org only
 * ****************************************************************
 * Created Date: 18 Dec, 2024
 * Created By: Kevin Suvagiya
 *--------------------------------------------------------------------------------
 * Last Modified By: Kevin Suvagiya
 * Last Modified Date: 18 Dec, 2024
 * Last Modification Description: Created a method to handle the emails and store the org data
 *--------------------------------------------------------------------------------
 * Modification History:
 * Date Modified - Developer Name - Description
 * 18 Dec, 2024  - Kevin Suvagiya - Created a method to handle the emails and store the org data
 **/
public with sharing class NewDownloadInfoController implements Messaging.InboundEmailHandler{
    /*
    *********************************************************
    @description     : Method is used to handle the emails and store the org data
    @param           : email - {Messaging.InboundEmail} - Data about the email to be handled
    @param           : envelope - {Messaging.InboundEnvelope} - emails of the sender and recipient
    @return          : none
    ********************************************************
    */
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        try {
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            String emailBody = email.plainTextBody;
            System.debug('emailBody '+emailBody);
            Account a = new Account();
            a.Name = envelope.fromAddress + ' - ' + System.now().toString();
            a.Description = emailBody;
            insert as User a;

            return result;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'NewDownloadInfoController', 'methodName' => 'handleInboundEmail', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
            return null;
        }

    }
}