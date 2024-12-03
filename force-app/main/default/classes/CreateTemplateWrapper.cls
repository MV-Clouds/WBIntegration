 /**
 * Class Name: CreateTemplateWrapper
 * Test Class: 
 * @description: Used in WBTemplateController Apex Class to create request body for template creation.
 * Date: 26/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
 MODIFICATION LOG*
 * Last Update Date : 26/11/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : 
 * Change Description : 
 ***********************************************************************/

public with sharing class CreateTemplateWrapper {
    
    // Main method to build overall payload to pass in create template
    public static Map<String, Object> buildPayload(TemplateWrapper templateWrapper) {
        try {
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('name', templateWrapper.templateName);
            payload.put('language', templateWrapper.tempLanguage);
            payload.put('category', templateWrapper.templateCategory);

            List<Map<String, Object>> components = new List<Map<String, Object>>();
            components.addAll(buildMarketingOrUtilityComponents(templateWrapper));

            if (!components.isEmpty()) {
                payload.put('components', components);
            }

            System.debug('Final Payload: ' + JSON.serialize(payload));
            return payload;

        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'buildPayload',e.getLineNumber());
            System.debug('Error in buildPayload: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return new Map<String, Object>(); 
    }

    private static List<Map<String, Object>> buildMarketingOrUtilityComponents(TemplateWrapper templateWrapper) {
        try {
            List<Map<String, Object>> components = new List<Map<String, Object>>();
            Map<String, Object> headerComponent = buildHeaderComponent(templateWrapper);
            if (!headerComponent.isEmpty()) {
                components.add(headerComponent);
            }
    
            if (templateWrapper.templateBody != null) {
                components.add(buildBodyComponent(templateWrapper));
            }
    
            if (templateWrapper.tempFooterText != null) {
                components.add(new Map<String, Object>{
                    'type' => 'FOOTER',
                    'text' => templateWrapper.tempFooterText
                });
            }
    
            List<Map<String, Object>> buttonComponents = buildButtonComponent(templateWrapper);
            if (!buttonComponents.isEmpty()) {
                components.add(new Map<String, Object>{
                    'type' => 'BUTTONS',
                    'buttons' => buttonComponents
                });
            }
            return components;

        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'buildMarketingOrUtilityComponents',e.getLineNumber());
            System.debug('Error in buildMarketingOrUtilityComponents: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return new List<Map<String, Object>>(); 
    }

    private static Map<String, Object> buildHeaderComponent(TemplateWrapper templateWrapper) {
        Map<String, Object> headerComponent = new Map<String, Object>();
        
        try {
            if (templateWrapper.tempHeaderFormat == null || templateWrapper.tempHeaderFormat=='None' ) {
                return headerComponent;
            }  
            headerComponent.put('type', 'HEADER'); 
            headerComponent.put('format', templateWrapper.tempHeaderFormat);
                      
            if (templateWrapper.tempHeaderFormat == 'Text' && templateWrapper.tempHeaderText != null) {
                headerComponent.put('text', templateWrapper.tempHeaderText);
                
                if (templateWrapper.tempHeaderExample != null && !templateWrapper.tempHeaderExample.isEmpty()) {
                    headerComponent.put('example', new Map<String, Object>{
                        'header_text' => templateWrapper.tempHeaderExample
                    });
                }
                return headerComponent;
            }            
            if (templateWrapper.tempHeaderFormat == 'Image' && templateWrapper.tempHeaderHandle != null) {
                headerComponent.put('example', new Map<String, Object>{
                    'header_handle' => templateWrapper.tempHeaderHandle
                });
                return headerComponent;
            }
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'buildHeaderComponent', e.getLineNumber());
            System.debug('Error in buildHeaderComponent: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return headerComponent;
    }
    
    private static Map<String, Object> buildBodyComponent(TemplateWrapper templateWrapper) {
        try {
            Map<String, Object> bodyComponent = new Map<String, Object>{
                'type' => 'BODY',
                'text' => templateWrapper.templateBody.replace('\\n', '\n')
            };
    
            if (templateWrapper.templateBodyText != null && templateWrapper.templateBodyText.size() > 0) {
                bodyComponent.put('example', new Map<String, Object>{
                    'body_text' => new List<List<String>>{templateWrapper.templateBodyText}
                });
            }
            return bodyComponent;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'buildBodyComponent',e.getLineNumber());
            System.debug('Error in buildBodyComponent: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return new Map<String, Object>(); 
    }

    private static List<Map<String, Object>> buildButtonComponent(TemplateWrapper templateWrapper) {
        List<Map<String, Object>> buttonComponents = new List<Map<String, Object>>();
    
        try {
            if (String.isBlank(templateWrapper.typeOfButton)) {
                return buttonComponents;
            }
    
            List<Object> untypedList;
            try {
                untypedList = (List<Object>) JSON.deserializeUntyped(templateWrapper.typeOfButton);
            } catch (Exception e) {
                throw new IllegalArgumentException('Invalid JSON format for typeOfButton: ' + e.getMessage());
            }
    
            for (Object item : untypedList) {
                Map<String, Object> button = (Map<String, Object>) item;
    
                String actionType = (String) button.get('selectedActionType');
                String customActionType = (String) button.get('selectedCustomType');
                String phoneNumber = (String) button.get('selectedCountryType') + (String) button.get('phonenum');
    
                Map<String, Object> buttonComponent = new Map<String, Object>();
                if ('PHONE_NUMBER'.equals(actionType)) {
                    buttonComponent.put('type', 'PHONE_NUMBER');
                    buttonComponent.put('text', (String) button.get('btntext'));
                    buttonComponent.put('phone_number', phoneNumber);
                } else if ('QUICK_REPLY'.equals(customActionType) || 'Marketing opt-out'.equals(customActionType)) {
                    buttonComponent.put('type', 'QUICK_REPLY');
                    buttonComponent.put('text', (String) button.get('Cbtntext'));
                } else if ('URL'.equals(actionType)) {
                    buttonComponent.put('type', 'URL');
                    buttonComponent.put('text', (String) button.get('btntext'));
                    buttonComponent.put('url', (String) button.get('webURL'));
                } else if ('COPY_CODE'.equals(actionType)) {
                    buttonComponent.put('type', 'COPY_CODE');
                    buttonComponent.put('example', (String) button.get('offercode'));
                }
    
                if (!buttonComponent.isEmpty()) {
                    buttonComponents.add(buttonComponent);
                }
            }
    
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'buildButtonComponent', e.getLineNumber());
            System.debug('Error in buildButtonComponent: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return buttonComponents;
    }
    
    // Handle response and store all in the template and template variable record.
    public static void handleSuccessResponse(HttpResponse res, Map<String, Object> payload, Map<String, Object> response, TemplateWrapper templateWrapper) {
        try {
            
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(payload));
            List<Map<String, String>> buttonDetails;

            String templateId = (String) responseMap.get('id');
            String status = (String) responseMap.get('status');
            String tempStatus = (status == 'PENDING') ? 'In-Review' : (status == 'REJECTED') ? 'Rejected' : (status == 'APPROVED') ? 'Active-Quality Pending' : '';
            String templateName = (String) payloadMap.get('name');
            String category = (String) payloadMap.get('category');
            String language = (String) payloadMap.get('language');
            String tempSubType = templateWrapper.templateType;
    
            String headerText = '';
            String bodyText = '';
            String footerText = '';
            String headerMergeText = '';
            String bodyMergeText = '';
            Integer headerMergeFieldCount = 0;
            Integer bodyMergeFieldCount = 0;
            String headerType = '';
            String buttonType;
            String buttonText;
            String buttonValue;
            String fieldName;
            String headType;
            List<Template_Variable__c> variableRecords = new List<Template_Variable__c>();

            List<Object> components = (List<Object>) payloadMap.get('components');
            List<String> headAlternateTexts = templateWrapper.headAlternateTexts; 
            List<String> varAlternateTexts = templateWrapper.varAlternateTexts;   
            Integer headerIndex = 0;                                      
            Integer variableIndex = 0; 

            for (Object comp : components) {
                if (!(comp instanceof Map<String, Object>)) {
                    System.debug('Expected component to be a Map<String, Object>, found: ' + comp);
                    continue;
                }

                Map<String, Object> component = (Map<String, Object>) comp;
                String type = (String) component.get('type');
                Map<String, Object> example = (Map<String, Object>) component.get('example');

                if (type == 'HEADER') {
                    headerType = (String) component.get('format');
                    headerText = '<p><b>' + (String) component.get('text') + '</b></p>';

                    if (example != null && example.containsKey('header_text') && example.get('header_text') instanceof List<Object>) {
                        List<Object> headerExampleObj = (List<Object>) example.get('header_text');
                        if (!headerExampleObj.isEmpty()) {
                            headerMergeText = (String) headerExampleObj[0];
                            headerMergeText = headerMergeText.replace('{{', '').replace('}}', '');
                            List<String> parts = headerMergeText.split('\\.');
                            if (parts.size() == 2) {
                                Template_Variable__c headerVariable = new Template_Variable__c(
                                    Object_Name__c = 'Contact',
                                    Field_Name__c = parts[1],
                                    Type__c = 'Header'
                                );

                                // Add alternate text if available
                                if (headerIndex < headAlternateTexts.size()) {
                                    headerVariable.Alternate_Text__c = headAlternateTexts[headerIndex];
                                }
                                headerIndex++;

                                variableRecords.add(headerVariable);
                            }
                        }
                    }
                } else if (type == 'BODY') {
                    Map<String, Object> result = handleBodyComponent(category, component, example);
                    bodyText = (String) result.get('bodyText');
                    bodyMergeText = (String) result.get('bodyMergeText');
                    List<Map<String, String>> parsedFields = (List<Map<String, String>>) result.get('parsedFields');

                    for (Map<String, String> field : parsedFields) {
                        Template_Variable__c bodyVariable = new Template_Variable__c(
                            Object_Name__c = 'Contact',
                            Field_Name__c = field.get('fieldName'),
                            Type__c = 'Body'
                        );

                        System.debug('variableIndex '+variableIndex);
                        System.debug('varAlternateTexts.size() '+varAlternateTexts.size());
                        // Add alternate text if available
                        if (variableIndex < varAlternateTexts.size()) {
                            bodyVariable.Alternate_Text__c = varAlternateTexts[variableIndex];
                        }
                        variableIndex++;

                        variableRecords.add(bodyVariable);
                    }
                } else if (type == 'FOOTER') {
                    footerText = (String) component.get('text');
                } else if (type == 'BUTTONS') { 
                    buttonDetails = handleButtonComponent(component);
                    for (Map<String, String> button : buttonDetails) {
                        buttonType = button.get('type');
                        buttonText = button.get('text');
                        buttonValue = button.get('value');
                    }
                }
            }
            String formattedBodyText = (bodyText != null) ? convertMarkdownToHtml(bodyText) : '';

            // Create template record
            Template__c whatsAppTemplate = new Template__c(
                Name = templateName,
                Template_Category__c = category,
                Template_SubCatagory__c = tempSubType,
                Language__c = language,
                Template_Id__c = templateId,
                Status__c = tempStatus,
                Header_Body__c = headerText,
                Header_Type__c = headerType,
                Template_Body__c = formattedBodyText,
                Footer_Body__c = footerText,
                Button_Type__c = buttonType,
                Button_Label__c = buttonText,
                Button_Body__c = String.isNotEmpty(buttonValue) ? buttonValue : buttonText
            );

            if (Template__c.sObjectType.getDescribe().isCreateable()) {
                insert whatsAppTemplate;
            }

            // Link variables to the template and insert them
            for (Template_Variable__c variable : variableRecords) {
                variable.Template__c = whatsAppTemplate.Id;
            }

            if (Template_Variable__c.sObjectType.getDescribe().isCreateable() && !variableRecords.isEmpty()) {
                insert variableRecords;
            }

            response.put('success', true);
        } catch (Exception e) {
            response.put('success', false);
            response.put('errorMessage', e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'handlesuccess', e.getLineNumber());
            System.debug('Error in handlesuccess: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }
    
    private static Map<String, Object> handleBodyComponent(String category, Map<String, Object> component, Map<String, Object> example) {
        Map<String, Object> result = new Map<String, Object>(); 
        try {
            String bodyText = (String) component.get('text');
            String bodyMergeText = '';  
            List<Map<String, String>> parsedFields = new List<Map<String, String>>(); 
    
            if (example != null && example.containsKey('body_text')) {
                Object bodyTextObj = example.get('body_text');
    
                if (bodyTextObj instanceof List<Object>) {
                    List<Object> outerList = (List<Object>) bodyTextObj;
    
                    if (!outerList.isEmpty() && outerList[0] instanceof List<Object>) {
                        List<Object> innerList = (List<Object>) outerList[0];
                        List<String> stringList = new List<String>();
    
                        for (Object obj : innerList) {
                            if (obj instanceof String) {
                                String fieldRef = (String) obj;
                                stringList.add(fieldRef);
    
                                if (fieldRef.contains('.')) {
                                    fieldRef = fieldRef.replace('{{', '').replace('}}', '');
                                    List<String> parts = fieldRef.split('\\.');
                                    Map<String, String> fieldMap = new Map<String, String>();
                                    fieldMap.put('fieldName', parts[1]); 
                                    parsedFields.add(fieldMap);
                                }
                            }
                        }
    
                        if (!stringList.isEmpty()) {
                            bodyMergeText = String.join(stringList, ',');
                        }
                    }
                }
            }
    
            result.put('bodyText', bodyText);
            result.put('bodyMergeText', bodyMergeText);
            result.put('parsedFields', parsedFields); 
    
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'handleBodyComponent', e.getLineNumber());
            System.debug('Error in handleBodyComponent: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
    
            result.put('bodyText', '');  
            result.put('bodyMergeText', '');
            result.put('parsedFields', new List<Map<String, String>>()); 
        }
    
        return result; 
    }

    private static List<Map<String, String>> handleButtonComponent(Map<String, Object> component) {
        List<Map<String, String>> buttonDetails = new List<Map<String, String>>();
        try {
            List<Object> buttons = (List<Object>) component.get('buttons'); 
    
            if (buttons != null) {
                for (Object buttonObj : buttons) {
                    if (buttonObj instanceof Map<String, Object>) {
                        Map<String, Object> button = (Map<String, Object>) buttonObj;
                        String buttonType = (String) button.get('type');
                        String buttonText = (String) button.get('text');
                        String buttonValue = '';
    
                        if (buttonType == 'COPY_CODE') {
                            buttonValue = (String) button.get('example'); 
                        } else if(buttonType == 'URL'){
                            buttonValue = (String) button.get('url'); 
                        } else if(buttonType == 'PHONE_NUMBER'){
                            buttonValue = (String) button.get('phone_number'); 
                        }
    
                        buttonDetails.add(new Map<String, String>{
                            'type' => buttonType,
                            'text' => buttonText,
                            'value' => buttonValue
                        });
                    } else {
                        System.debug('Expected button to be a Map<String, Object>, found: ' + buttonObj);
                    }
                }
            } else {
                System.debug('No buttons found in component: ' + component);
            }
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'CreateTemplateWrapper', 'handleButtonComponent', e.getLineNumber());
            System.debug('Error in handleButtonComponent: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
        return buttonDetails; 
    }
    
    // Used to format text
    public static String convertMarkdownToHtml(String bodyText) {
        bodyText = bodyText.replaceAll('\\*{1,2}([^*]+)\\*{1,2}', '<strong>$1</strong>');
        bodyText = bodyText.replaceAll('_([^_]+)_', '<em>$1</em>');        
        bodyText = bodyText.replaceAll('~([^~]+)~', '<s>$1</s>');        
        bodyText = bodyText.replaceAll('```([^`]+)```', '<code>$1</code>');        
        bodyText = bodyText.replaceAll('\n', '<br/>');
        
        return bodyText;
    }

    public class TemplateWrapper {      
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateCategory;
        @AuraEnabled public String templateType;
        @AuraEnabled public String tempHeaderFormat;
        @AuraEnabled public String tempHeaderHandle;
        @AuraEnabled public String tempLanguage;
        @AuraEnabled public String tempHeaderText;
        @AuraEnabled public List<String> tempHeaderExample;
        @AuraEnabled public List<String> headAlternateTexts;
        @AuraEnabled public List<String> varAlternateTexts;
        @AuraEnabled public String templateBody;
        @AuraEnabled public List<String> templateBodyText;
        @AuraEnabled public String tempFooterText;
        @AuraEnabled public String typeOfButton;
        @AuraEnabled public String buttonPhoneText;
        @AuraEnabled public String phoneNumber;
        @AuraEnabled public String buttonURLText;
        @AuraEnabled public String url;
        @AuraEnabled public String quickText;
        @AuraEnabled public String copyCode;
    }

}