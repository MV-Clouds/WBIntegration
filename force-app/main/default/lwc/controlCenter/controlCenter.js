import { LightningElement } from 'lwc';
import facebookSDK from '@salesforce/resourceUrl/facebookSDKResource';
import { loadScript } from 'lightning/platformResourceLoader';

export default class ControlCenter extends LightningElement {
    fbSdk;
    sessionInfo;
    sdkResponse;

    connectedCallback() {
        console.log('in connected callback');
        
        // Load Facebook SDK
        loadScript(this, facebookSDK)
            .then(() => {
                console.log('The script loaded is :', window.FB);
        
                    window.FB.init({
                        appId: '514916280628381', // Your Facebook App ID
                        autoLogAppEvents: true,
                        xfbml: true,
                        version: 'v21.0' // The Facebook Graph API version
                    });
        
                console.log('Initializing', window.FB);
                
                this.setupEventListener();
            })
            .catch((error) => {
                console.error('Error loading Facebook SDK', error);
            });
    }

    setupEventListener() {
        window.addEventListener('message', (event) => {
            if (event.origin !== "https://www.facebook.com" && event.origin !== "https://web.facebook.com") {
                return;
            }
            try {
                const data = JSON.parse(event.data);
                if (data.type === 'WA_EMBEDDED_SIGNUP') {
                    if (data.event === 'FINISH') {
                        const { phone_number_id, waba_id } = data.data;
                        this.sessionInfo = `Phone number ID: ${phone_number_id}, WABA ID: ${waba_id}`;
                    } else if (data.event === 'CANCEL') {
                        const { current_step } = data.data;
                        console.warn("Cancelled at ", current_step);
                    } else if (data.event === 'ERROR') {
                        const { error_message } = data.data;
                        console.error("Error: ", error_message);
                    }
                }
                this.sdkResponse = JSON.stringify(data, null, 2);
            } catch (error) {
                console.log('Non-JSON Response', event.data);
            }
        });
    }

    launchWhatsAppSignup() {
        console.log('Launching WhatsApp signup flow');
        // Facebook login
        window.FB.login((response) => {
            if (response.authResponse) {
                const code = response.authResponse.code;
                console.log('Facebook login successful, code:', code);
                // Perform any necessary actions with the returned code.
            }
            this.sdkResponse = JSON.stringify(response, null, 2);
        }, {
            config_id: '8971126402921271', 
            response_type: 'code', 
            override_default_response_type: true, 
            extras: {
                setup: {},
                featureType: '',
                sessionInfoVersion: '2',
            }
        })
        .then(() =>{
            console.log('SDK response success');
        })
        .catch((error) => {
            console.error('Error launching WhatsApp signup flow', error);
        });
    }
}
