trigger TemplateRestrictTrigger on Template__c (before insert, before update) {
    WBTemplateController.restrictTemplates();
}
