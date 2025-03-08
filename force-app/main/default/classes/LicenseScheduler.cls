global class LicenseScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        LicenseChecker.checkLicense();
        LicenseConfig__c config = LicenseConfig__c.getInstance();

        if (config.Next_Callout_Date__c != null) {
            String cron = '0 0 12 ' + config.Next_Callout_Date__c.day() + ' ' + config.Next_Callout_Date__c.month() + ' ? ' + config.Next_Callout_Date__c.year();
            System.schedule('Next License Check', cron, new LicenseScheduler());
        }
    }
}