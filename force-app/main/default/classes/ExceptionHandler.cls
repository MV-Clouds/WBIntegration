/**
* Class Name: ExceptionHandler
* Test Class: Not Needed
* @description: Used for logging the exceptions occurs withing the WBI app
* Created Date: 22 Nov, 2024
* Created By: Kevin Suvagiya
*--------------------------------------------------------------------------------
* Last Modified By: Kevin Suvagiya
* Last Modified Date: 27 Nov, 2024
* Last Modification Description: Added a method to create exception for the API and salesforce catch blocks.
*--------------------------------------------------------------------------------
* Modification History:
* Date Modified - Developer Name - Description
* 25 Nov, 2024  - Kevin Suvagiya - Added a method to link the chat record with the exception
* 27 Nov, 2024  - Kevin Suvagiya - Added a method to create exception for the API and salesforce catch blocks
**/
public with sharing class ExceptionHandler {

    // /*
    // *********************************************************
    // @description     : Method is used to create a exception log record without Chat id
    // @param           : e - {Exception} - the actual exception data
    // @return          : none
    // ********************************************************
    // */
    // public static void logException(Exception e) {
    //     try{
    //         createException(e, null);
    //     } 
    //     catch (Exception err) {
    //         System.debug('There is some error logException' + err.getMessage());
    //         // logException(error, 'ExceptionHandler', 'logException');
    //     }
    // } 
    
    // /*
    // *********************************************************
    // @description     : Method is used to create a exception log record with Chat id
    // @param           : e - {Exception} - the actual exception
    // @param           : chatId - {String} - Id of the chat
    // @return          : none
    // ********************************************************
    // */
    // public static void logException(Exception e, String chatId) {
    //     //Your Code
    //     try{
    //         createException(e, chatId);
    //     } 
    //     catch (Exception err) {
    //         System.debug('There is some error logException' + err.getMessage());
    //         // logException(error, 'ExceptionHandler', 'logException');
    //     }
    // }

    // /*
    // *********************************************************
    // @description     : Method is used to create a exception log record
    // @param           : e - {Exception} - the actual exception
    // @param           : chatId - {String} - Id of the chat, null if not specified
    // @return          : none
    // ********************************************************
    // */
    // public static void createException(Exception e, String chatId) {
    //     try{
    //         Exception_Log__c exc = new Exception_Log__c();
    //         String[] traceLines = e.getStackTraceString().split('\n');
    //         String className = '';
    //         String methodName = '';
    //         if (!traceLines.isEmpty() && traceLines[0].contains('.')) {
    //             String firstLine = traceLines[0].substringAfter('.').substringBefore(':');
    //             className = firstLine.substringBefore('.');
    //             methodName = firstLine.substringAfter(className+'.');
    //         }

    //         //Governer Limit of executingQuery 
    //         String queryLimit = '1. SOQL Queries used / SOQL Queries allowed: ' + Limits.getQueries() + '/' + Limits.getLimitQueries();
    //         String dMLimit = '2. Number of records queried so far /  Number allowed: ' + Limits.getDmlRows() + '/' + Limits.getLimitDmlRows();
    //         String dMLState = '3. Number of DML statements used so far / Number allowed: ' +  Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements();   
    //         String cPUTime = '4. Amount of CPU time (in ms) used so far / CPU usage time (in ms) allowed: ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime();
    //         String calloutLimit = '5. Number of callouts used so far / Number allowed: ' + Limits.getCallouts() + '/' + Limits.getLimitCallouts();
    //         String heapSize = '6. Amount of Heap size used so far / Heap usage allowed:' + Limits.getHeapSize() + '/' + Limits.getLimitHeapSize();
        
    //         exc.Governor_Limit_Used__c = String.format('{0}\n{1}\n{2}\n{3}\n{4}\n{5}',new List<string>{queryLimit, dMLimit,dMLState,cPUTime,calloutLimit,heapSize});
    //         exc.Exception_Message__c = e.getMessage();
    //         exc.Exception_Type__c = e.getTypeName();
    //         exc.Exception_Line_Number__c = e.getLineNumber();
    //         exc.Exception_Stack_Trace__c = e.getStackTraceString();
    //         exc.Class_Name__c = className;
    //         exc.Method_Name__c = methodName;
    //         exc.WB_Chat__c = chatId;
    //         insert as user exc;
    //     } 
    //     catch (Exception err) {
    //         System.debug('There is some error createException' + err.getMessage());
    //         // logException(error, 'ExceptionHandler', 'logException');
    //     }
    // } 

        // Method to create an exception log using wrapper data
        public static void createExceptionLog(ExceptionWrapper exceptionData) {
            try {
                Exception_Log__c exc = new Exception_Log__c();
                exc.Class_Name__c = exceptionData.className;
                exc.Method_Name__c = exceptionData.methodName;
                exc.WB_Chat__c = exceptionData.chatId;
                exc.Is_API_Exception__c = exceptionData.isApiException != null ? exceptionData.isApiException : false;
                exc.Status_Code__c = exceptionData.statusCode;

                Exception e = exceptionData.exceptionObj;
                if(e != null){
                    String queryLimit = '1. SOQL Queries used / SOQL Queries allowed: ' + Limits.getQueries() + '/' + Limits.getLimitQueries();
                    String dMLimit = '2. Number of records queried so far /  Number allowed: ' + Limits.getDmlRows() + '/' + Limits.getLimitDmlRows();
                    String dMLState = '3. Number of DML statements used so far / Number allowed: ' +  Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements();   
                    String cPUTime = '4. Amount of CPU time (in ms) used so far / CPU usage time (in ms) allowed: ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime();
                    String calloutLimit = '5. Number of callouts used so far / Number allowed: ' + Limits.getCallouts() + '/' + Limits.getLimitCallouts();
                    String heapSize = '6. Amount of Heap size used so far / Heap usage allowed:' + Limits.getHeapSize() + '/' + Limits.getLimitHeapSize();
                
                    exc.Governor_Limit_Used__c = String.format('{0}\n{1}\n{2}\n{3}\n{4}\n{5}',new List<string>{queryLimit, dMLimit,dMLState,cPUTime,calloutLimit,heapSize});
                    exc.Exception_Message__c = e.getMessage();
                    exc.Exception_Type__c = e.getTypeName();
                    exc.Exception_Line_Number__c = e.getLineNumber();
                    exc.Exception_Stack_Trace__c = e.getStackTraceString();
                }
                exc.More_Detail__c = exceptionData.moreDetails;
                exc.Response__c = exceptionData.apiResponse;
    
                insert as user exc;
            } catch (Exception e) {
                System.debug('Error in createExceptionLog: ' + e.getMessage());
            }
        }
    
        // Wrapper class to represent structured exception data
        public class ExceptionWrapper {
            public String className { get; set; } 
            public String methodName { get; set; }
            public Exception exceptionObj { get; set; }
            public Boolean isApiException { get; set; }
            public Integer statusCode { get; set; }
            public String chatId { get; set; }
            public String moreDetails { get; set; }
            public String apiResponse { get; set; }
        }
}