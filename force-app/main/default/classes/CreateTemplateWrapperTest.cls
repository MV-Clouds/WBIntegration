/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-04-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class CreateTemplateWrapperTest{
     @isTest
    static void testBuildPayload() {
        CreateTemplateWrapper.TemplateWrapper templateWrapper = new CreateTemplateWrapper.TemplateWrapper(); 
        templateWrapper.templateName = 'WB Template';
        templateWrapper.tempLanguage = 'en';
        templateWrapper.templateCategory = 'Marketing';
        templateWrapper.templateType = 'Custom';
        templateWrapper.tempHeaderFormat = 'Text';
        templateWrapper.tempHeaderHandle = 'header1';
        templateWrapper.tempHeaderText = 'Welcome to WB Template';
        templateWrapper.tempHeaderExample = new List<String>{'Header Example 1', 'Header Example 2'};
        templateWrapper.headAlternateTexts = new List<String>{'Alt Text 1', 'Alt Text 2'};
        templateWrapper.varAlternateTexts = new List<String>{'Var Text 1', 'Var Text 2'};
        templateWrapper.templateBody = 'This is a sample body';
        templateWrapper.templateBodyText = new List<String>{'Body Text 1', 'Body Text 2'};
        templateWrapper.tempFooterText = 'Footer Text';
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"PHONE_NUMBER\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';

        templateWrapper.url = 'http://example.com';
        templateWrapper.tempImgUrl = 'http://example.com/image.png';
        Map<String, Object> result = CreateTemplateWrapper.buildPayload(templateWrapper);

        templateWrapper.tempHeaderFormat = 'Image';
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedCustomType\":\"QUICK_REPLY\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"URL\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"COPY_CODE\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedCustomType\":\"Marketing opt-out\"}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"Flow\"}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{\"success\": true}');

        Map<String, Object> payload = new Map<String, Object>();

        // Adding data to the map
        payload.put('category', 'Marketing');
        payload.put('language', 'en_US');
        payload.put('name', 'test_temp_55');

        // Adding components as a list of maps
        payload.put('components', new List<Map<String, Object>> {
            new Map<String, Object> { 'format' => 'Image', 'type' => 'HEADER', 'text' => 'something \\{\\{(\\d+)\\}\\} ', 'example' => new Map<String, Object>{'header_text' => new List<Object> {'some{{1}}thing', 'something2'}, 'body_text' => new List<Object> {'some {{3}}thing', 'something2'}} },
            new Map<String, Object> { 'text' => 'HelloThis is Sample.', 'type' => 'BODY', 'bodyText' => 'Something text' },
            new Map<String, Object> {
                'buttons' => new List<Map<String, Object>> {
                    new Map<String, Object> { 'text' => 'Quick reply', 'type' => 'QUICK_REPLY' }
                },
                'type' => 'BUTTONS'
            },
            new Map<String, Object> { 'format' => 'text', 'type' => 'HEADER'}
        });

        payload.put('components', new List<Map<String, Object>>{
            new Map<String, Object>{
                'type' => 'HEADER',
                'format' => 'TEXT',
                'text' => 'Event by {{1}}',
                'example' => new Map<String, Object>{
                    'header_text' => new List<Object>{'{{Contact.Email}}'}
                }
            },
            new Map<String, Object>{
                'type' => 'BODY',
                'text' => 'Hello {{1}}, This is an invitation for the annual event for 8 years of journey. Contact us for more details: {{2}}',
                'example' => new Map<String, Object>{
                    'body_text' => new List<List<String>>{
                        new List<String>{'{{Contact.Name}}', '{{Contact.Phone}}'}
                    }
                }
            },
            new Map<String, Object>{
                'type' => 'FOOTER',
                'text' => 'MV Clouds Pvt Ltd'
            },
            new Map<String, Object>{
                'type' => 'BUTTONS',
                'buttons' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'type' => 'QUICK_REPLY',
                        'text' => 'Quick reply'
                    }
                }
            }
        });
        Map<String, Object> response = new Map<String, Object>();
        response.put('success', 'true');
        response.put('is', 'someId');
        CreateTemplateWrapper.handleSuccessResponse(res, payload, response, templateWrapper);
        System.assertNotEquals(result, null, 'there should some data.');

    }
    @isTest
    static void testBuildPayloadAuthentication() {
        CreateTemplateWrapper.TemplateWrapper templateWrapper = new CreateTemplateWrapper.TemplateWrapper(); 
        templateWrapper.templateName = 'WB Template';
        templateWrapper.tempLanguage = 'en';
        templateWrapper.templateCategory = 'Authentication';
        templateWrapper.templateType = 'One-time passcode';
        templateWrapper.tempHeaderHandle = 'header1';
        templateWrapper.varAlternateTexts = new List<String>{'Var Text 1', 'Var Text 2'};
        templateWrapper.templateBody = 'This is a sample body';
        templateWrapper.templateBodyText = new List<String>{'Body Text 1', 'Body Text 2'};
        templateWrapper.tempFooterText = 'Footer Text';
        templateWrapper.typeOfButton = '[]'; 
        templateWrapper.expireTime = 301;

        Map<String, Object> result = CreateTemplateWrapper.buildPayload(templateWrapper);

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('category', 'Authentication');
        payload.put('language', 'en_US');
        payload.put('name', 'auth_template_001');

        payload.put('components', new List<Map<String, Object>>{
            new Map<String, Object>{
                'type' => 'HEADER',
                'format' => 'TEXT',
                'text' => 'Event by {{1}}',
                'example' => new Map<String, Object>{
                    'header_text' => new List<Object>{'{{Contact.Email}}'}
                }
            },
            new Map<String, Object>{
                'type' => 'BODY',
                'text' => 'Hello {{1}}, Please use the following OTP for verification: {{2}}',
                'example' => new Map<String, Object>{
                    'body_text' => new List<List<String>>{
                        new List<String>{'{{Contact.Name}}', '{{Contact.OTP}}'}
                    }
                }
            },
            new Map<String, Object>{
                'type' => 'FOOTER',
                'text' => 'Secure Login - WB'
            },
            new Map<String, Object>{
                'type' => 'BUTTONS',
                'buttons' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'type' => 'OTP',
                        'text' => 'Verify Code',
                        'otp_type' => 'COPY_CODE'
                    }
                }
            }
        });

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{\"success\": true}');

        Map<String, Object> response = new Map<String, Object>();
        response.put('success', 'true');
        response.put('id', 'auth_template_001');

        CreateTemplateWrapper.handleSuccessResponse(res, payload, response, templateWrapper);
        System.assertNotEquals(result, null, '🔹 Payload should not be null.');
    }
}