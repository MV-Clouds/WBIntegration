global with sharing class SyncFlowBatchClass implements Database.Batchable<Map<String, Object>>, Database.Stateful, Database.AllowsCallouts {
    
    global List<Flow__c> flowsToInsert = new List<Flow__c>();
    global List<Flow__c> flowsToUpdate = new List<Flow__c>();
    global List<Flow__c> finalUpdateList = new List<Flow__c>();
    global List<Flow__c> flowsToDelete = new List<Flow__c>();
    global Map<String, Flow__c> existingFlows = new Map<String, Flow__c>();
    global List<Map<String, Object>> flowsToProcess;

    global SyncFlowBatchClass(List<Map<String, Object>> flowsToProcess) {
        this.flowsToProcess = flowsToProcess;
    }

    global Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        for (Flow__c f : [SELECT Id, Flow_Id__c FROM Flow__c]) {
            if (f.Flow_Id__c != null) {
                this.existingFlows.put(f.Flow_Id__c, f);
            }
        }
        System.debug('Flows to process = ' + flowsToProcess);
        return flowsToProcess;
    }

    global void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        try {
            
            for (Map<String, Object> flow : scope) {
                String action = (String) flow.get('action');
                String metaId = (String) flow.get('metaId');
                String orgFlowId = (String) flow.get('id');
    
                if (action == 'CreateInOrg') {
                    Flow__c f = new Flow__c(
                        Flow_Id__c = metaId,
                        Flow_Name__c = (String) flow.get('name'),
                        Status__c = (String) flow.get('status'),
                        Category__c = (String) flow.get('category'),
                        Flow_JSON__c = (String) flow.get('flowJson')
                    );
    
                    if (existingFlows.containsKey(metaId)) {
                        f.Id = existingFlows.get(metaId).Id;
                        this.flowsToUpdate.add(f);
                    } else {
                        this.flowsToInsert.add(f);
                    }
    
                } else if (action == 'DeleteFromOrg') {
                    if (orgFlowId != null) {
                        this.flowsToDelete.add(new Flow__c(Id = orgFlowId));
                    }
    
                } else if (action == 'CreateInMeta') {
                    String categoryStr = (String) flow.get('category');
                    List<String> categories = categoryStr != null ? categoryStr.split(';') : new List<String>();
                    if (categories.isEmpty()) categories.add('OTHER');
                    String name = (String) flow.get('name');
                    String templateType = (String) flow.get('templateType');
                    String json = (String) flow.get('flowJson');
    
                    String returnedFlowId = WhatsAppFlowController.createWhatsAppFlow(name, categories, json, templateType, false);
                    this.flowsToUpdate.add(new Flow__c(Id = orgFlowId, Flow_Id__c = returnedFlowId, Status__c = 'Draft'));
                }
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowBatchClass', 'methodName' => 'execute', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!flowsToInsert.isEmpty()) insert flowsToInsert;
        Set<Id> updateIds = new Set<Id>();
        List<Flow__c> finalUpdateList = new List<Flow__c>();
        for (Flow__c f : flowsToUpdate) {
            if (!updateIds.contains(f.Id)) {
                finalUpdateList.add(f);
                updateIds.add(f.Id);
            }
        }
        Database.update(finalUpdateList);
        if (!flowsToDelete.isEmpty()) delete flowsToDelete;
    }
}