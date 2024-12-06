public with sharing class ExceptionLog {
    public static void exception(String Response, String classname, String methodname,Integer exceptionLine){
        try {
            Exception_Log__c error = new Exception_Log__c();
            error.Exception_Message__c = Response;
            error.Class_Name__c = classname;
            error.Method_Name__c = methodname;
            error.Exception_Line_Numer__c = exceptionLine;
            insert error;
        } catch (Exception e) {
            System.debug('Error in ExceptionLog ..' + e.getMessage() + '\n' + e +'\n Exception line no : '+ e.getLineNumber());
        }
    }
}