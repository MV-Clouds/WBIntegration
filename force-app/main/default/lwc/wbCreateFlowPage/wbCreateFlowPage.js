import { LightningElement,track,wire } from 'lwc';
import flowBG from '@salesforce/resourceUrl/wbiTemplateBg';
import createWhatsAppFlow from '@salesforce/apex/WhatsAppFlowController.createWhatsAppFlow';
import getJSONData from '@salesforce/apex/WhatsAppFlowController.getJSONData';

export default class WbCreateFlowPage extends LightningElement {
    @track isFlowVisible = false;
    @track iscreateflowvisible = true; 
    @track dropdownClose = true;
    @track isJsonVisible=false;
    @track value = 'default';
    @track flowName = '';
    @track selectedCatagories = [];
    backgroundImage = flowBG;
    maxFlowNamelength = 200;
    // flowIconUrl = FlowIcon;
    @track jsonString = ``;    
    jsonLines = [];
    @track dataMap={};
    @track isLoading=false;

    @wire(getJSONData)
    wiredData({ error, data }) {
        if (data) {
            console.log('Data from Apex:', data);

            data.forEach(item => {                
                if (item.name && item.data) {
                    this.dataMap[item.name] = item.data;
                } else {
                    console.warn('Item missing name or data:', item);
                }
            });

            if (this.dataMap['default']) {
                this.initializeJsonDisplay('default');
            }
        } else if (error) {
            console.error('Error loading JSON data:', error);
        }
    }
    
    initializeJsonDisplay(option) {
        this.jsonString = JSON.stringify(this.dataMap[option], null, 2);
        this.formatJsonWithLineNumbers();
    }
    
    formatJsonWithLineNumbers() {
        try {
            const parsedJson = JSON.parse(this.jsonString); 
            const jsonString = JSON.stringify(parsedJson, null, 2);
            const lines = jsonString.split('\n'); 
            
            this.jsonLines = lines.map((line, index) => ({
                lineNumber: index + 1,
                text: line
            }));
        } catch (error) {
            console.error('Error parsing JSON in formatJsonWithLineNumbers:', error);
        }
    }

    get TypeOptions() {
        return [
            { label: 'Sign up', value: 'SIGN_UP' },
            { label: 'Sign in', value: 'SIGN_IN' },
            { label: 'Appointment booking', value: 'APPOINTMENT_BOOKING' },
            { label: 'Lead generation', value: 'LEAD_GENERATION' },
            { label: 'Shopping', value: 'SHOPPING' },
            { label: 'Contact us', value: 'CONTACT_US' },
            { label: 'Customer support', value: 'CUSTOMER_SUPPORT' },
            { label: 'Survey', value: 'SURVEY' },
            { label: 'Other', value: 'OTHER' }
        ];
    }
    get backgroundImageStyle() {
        return `background-image:url(${flowBG}); background-size: cover; background-position: center;`;
    }

    handleChange(event) {
        this.value = event.target.value;
        console.log('value ',this.value);
        
        if (this.dataMap && this.dataMap[this.value]) {
            console.log('enter in if');
            
            this.jsonString = JSON.stringify(this.dataMap[this.value], null, 2); 
            console.log('this.jsonString:', this.jsonString);
            this.formatJsonWithLineNumbers();
        } else {
            console.log('No matching data found for:', this.value);
            this.jsonString = '';
            this.jsonLines = [];
        }
    }

    handleInputChange(event){
        this.flowName = event.target.value;        
    }

    handleDiscard() {
        this.isFlowVisible = true;
        this.iscreateflowvisible = false;    
    }
  
    handleCatagories(event) {
        const selectedCategories = event.detail.selectedValues;
        this.selectedCatagories = selectedCategories; 
        console.log('Selected Categories from child:', JSON.stringify(this.selectedCatagories));

    }
  
    handleCreate(){
        // this.isJsonVisible=true;
        // this.iscreateflowvisible = false; 
        this.isLoading=true;
        const catagories1 = Array.from(this.selectedCategories);  
        console.log('Converted Array:', catagories1);
        const catagories2 = JSON.stringify(this.selectedCatagories);
        console.log(catagories2);
        
        createWhatsAppFlow({ flowName: this.flowName, category:  catagories1 })
            .then( (result) => {
                if (result) {
                    console.log('Flows created Successfully!!',"success");
                    this.isJsonVisible=true;
                    this.iscreateflowvisible = false; 
                    this.isLoading=false;
                } else {
                    console.log
                    ('Error in creating Flows!!',"error");
                    this.isLoading=false;
                }
             
            }).catch( error => {
                // this.toast(error, "error");
                this.isLoading=false;
            })
    }
}