/**
* @File Name : SendWhatsAppMessage.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : June 25, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | June 25, 2025 |  Harsh Gandhi | Initial Version
**/

global without sharing class SendWhatsAppMessage {

    global static List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 
    
    global static HttpResponse sendWAMessage(String jsonBody) {
        try {
            HttpRequest httpReq = new HttpRequest();
            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = wbConfig[0].MVWB__API_Endpoint__c + '/' + wbConfig[0].MVWB__API_Version__c + '/' + wbConfig[0].MVWB__Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonBody);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            return response;
        } catch (Exception e) {
            return null;
        }
    }
}