import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class WbFlowPreview extends NavigationMixin(LightningElement) {
    @api flowname;
    @api iserror;
    showPreview = false;
    screens = [];
    detailsOptions = [];
    @track detailsValue;
    previewClass = 'preview';
    @track isNight = false;
    theme = 'light';

    @track inputValues = {};
    @track inputFocus = {};
    @api selectedtheme = 'light';
    @track showMenu = false; 
    _currentscreenid;
    parsedJson = null; 

    @track screenTitle = ''; 
    @track screenChildren = []; 
    @track hasFooter = false; 
    @track footerLabel = ''; 
    @track footerAction = ''; 

    @api
    set jsonstringdata(value) {
        console.log('iserror:', this.iserror);
        if (!this.iserror) {
            this._jsonstringdata = value;
            try {
                const parsed = JSON.parse(value);
                this.screens = parsed.screens || [];
                this.detailsOptions = this.screens.map(screen => ({
                    label: screen.id,
                    value: screen.id
                }));
                this.detailsValue = this.detailsOptions.length ? this.detailsOptions[0].value : null;
                this.parsedJson = parsed; 
            } catch (e) {
                console.error('Error parsing JSON data in wbcp_flowPreview:', e); 
                this.detailsOptions = [];
                this.detailsValue = null;
                this.parsedJson = null; 
                this.screenChildren = []; 
            }
        }
    }

    get jsonstringdata() {
        return this._jsonstringdata;
    }

    get previewContainerClass() {
        return `preview-container ${this.theme}-theme`;
    }

    get modeClass() {
        return this.isNight ? 'toggle night' : 'toggle day';
    }

    @api
    get currentscreenid() {
        return this._currentscreenid;
    }
    set currentscreenid(value) {
        if (value !== this._currentscreenid) {
            this._currentscreenid = value;
            this.generatePreview(); 
        }
    }

    get isOptionSelected() {
        return !this.inputValues[this.child?.name];
    }

    get currentInputValue() {
        return this.inputValues[this.child?.name] || '';
    }


    connectedCallback() {
        window.addEventListener('click', this.handleOutsideClick.bind(this)); 
        window.addEventListener('resize', this.adjustContentHeight.bind(this)); 
        this.selectedtheme = this.theme;
    }

    disconnectedCallback() {
        window.removeEventListener('click', this.handleOutsideClick.bind(this)); 
        window.removeEventListener('resize', this.adjustContentHeight.bind(this)); 
    }

    renderedCallback() {
        const mainContainer = this.template.querySelector('.whatsapp-flow-previewer-main-container'); 
        if (mainContainer) {
            mainContainer.setAttribute('data-theme', this.selectedtheme); 
        }
        this.adjustContentHeight(); 
    }

    @api
    runPreview() {
        this.generatePreview();
        this.adjustContentHeight(); 
    }

    handlePreviewFlow() {
        this.showPreview = true;
        requestAnimationFrame(() => {
            this.previewClass = 'preview slide-up';
            this.generatePreview();
        });
    }

    get disableDetailsCombobox() {
        return !this.showPreview;
    }

    handleDetailsChange(event) {
        this.detailsValue = event.detail.value;
        this._currentscreenid = this.detailsValue;
        this.generatePreview();
    }

    handleRefreshAll() {
        this.inputFocus = {};
        this.inputValues = {};
        this.generatePreview();
        this.adjustContentHeight(); 
    }

    handleClose() {
        this.previewClass = 'preview slide-down';
        setTimeout(() => {
            this.showPreview = false;
        }, 300);
    }

    handleCloseClick() { 
        this.handleClose();
    }

    toggleMode() {
        this.isNight = !this.isNight;
        this.theme = this.isNight ? 'dark' : 'light';
        this.selectedtheme = this.theme;
    }

    adjustContentHeight() { 
        const content = this.template.querySelector('.whatsapp-flow-previewer-content'); 
        if (content) {
            const contentHeight = this.hasFooter ? '66%' : '86%'; 
            this.template.host.style.setProperty('--content-height', contentHeight); 
        }
    }

    generatePreview() { 
        if (this.parsedJson) {
            if (!this._currentscreenid) {
                this._currentscreenid = this.parsedJson.screens[0]?.id || null; 
            }

            const screen = this.parsedJson.screens.find(screen => screen.id === this._currentscreenid); 
            if (screen) {
                this.screenTitle = screen.title; 
                this.screenChildren = []; 
                this.hasFooter = false; 
                this.footerLabel = ''; 
                this.footerAction = ''; 

                const form = screen.layout.children.find(child => child.type === 'Form') || screen.layout; 

                form.children.forEach(child => { 
                    const commonProps = { 
                        name: child.name, 
                        label: child.label, 
                        text: child.text, 
                        dataSource: child['data-source'], 
                        inputClass: this.getInputClass(child.name) 
                    };

                    if (child.type === 'TextHeading') { 
                        this.screenChildren.push({ ...commonProps, isTextHeading: true }); 
                    } else if (child.type === 'TextSubheading') { 
                        this.screenChildren.push({ ...commonProps, isTextSubheading: true }); 
                    } else if (child.type === 'TextBody') { 
                        this.screenChildren.push({ ...commonProps, isTextBody: true }); 
                    } else if (child.type === 'TextInput') { 
                        this.screenChildren.push({ ...commonProps, isTextInput: true, inputType: child['input-type'] }); 
                    } else if (child.type === 'TextArea') { 
                        this.screenChildren.push({ ...commonProps, isTextArea: true }); 
                    } else if (child.type === 'RadioButtonsGroup') { 
                        const dataSourceWithOptions = (child['data-source'] || []).map(option => ({ 
                            ...option,
                            checked: this.inputValues[child.name] === option.id 
                        }));
                        this.screenChildren.push({ ...commonProps, isRadioButtonsGroup: true, dataSource: dataSourceWithOptions }); 
                    } else if (child.type === 'CheckboxGroup') { 
                        const dataSourceWithOptions = (child['data-source'] || []).map(option => ({ 
                            ...option,
                            checked: this.inputValues[child.name]?.includes(option.id) 
                        }));
                        this.screenChildren.push({ ...commonProps, isCheckboxGroup: true, dataSource: dataSourceWithOptions }); 
                    } else if (child.type === 'OptIn') { 
                        this.screenChildren.push({ 
                            ...commonProps,
                            isOptIn: true,
                            checked: this.inputValues[child.name], 
                            isTosOptin: child.name === 'tos_optin' 
                        });
                    } else if (child.type === 'Dropdown') { 
                        const dataSourceWithOptions = (child['data-source'] || []).map(option => ({ 
                            ...option,
                            selected: this.inputValues[child.name] === option.id 
                        }));
                        this.screenChildren.push({ ...commonProps, isDropdown: true, dataSource: dataSourceWithOptions }); 
                    } else if (child.type === 'Footer') { 
                        this.hasFooter = true; 
                        this.footerLabel = child.label; 
                        this.footerAction = JSON.stringify(child['on-click-action']); 
                    }
                });
                this.adjustContentHeight(); 
            }
        }
    }

    handleInputChange(event) { 
        const { name, value, type, checked } = event.target; 
        if (type === 'checkbox') { 
            const currentValues = this.inputValues[name] || []; 
            if (checked) { 
                if (!currentValues.includes(value)) { 
                    currentValues.push(value); 
                }
            } else { 
                const index = currentValues.indexOf(value); 
                if (index > -1) { 
                    currentValues.splice(index, 1); 
                }
            }
            this.inputValues = { ...this.inputValues, [name]: [...currentValues] };
        } else if (type === 'radio') { 
            this.inputValues = { ...this.inputValues, [name]: value }; 
        } else if (type === 'select-one') {
            this.inputValues = { ...this.inputValues, [name]: value }; 
            if (value) { 
                event.target.classList.add('active'); 
            } else { 
                event.target.classList.remove('active'); 
            }
        }
        else { 
            this.inputValues = { ...this.inputValues, [name]: value }; 
        }
    }

    handleInputFocus(event) { 
        const { name } = event.target; 
        this.inputFocus = { ...this.inputFocus, [name]: true }; 
        event.target.classList.add('active'); 
    }

    handleInputBlur(event) { 
        const { name, value } = event.target; 
        this.inputFocus = { ...this.inputFocus, [name]: false }; 
        if (!value.trim()) { 
            event.target.classList.remove('active'); 
        }
    }

    handleDropdownChange(event) { 
        this.handleInputChange(event); 
        const selectElement = event.target; 
        if (selectElement.value) { 
            selectElement.classList.add('active'); 
        } else { 
            selectElement.classList.remove('active'); 
        }
    }

    handleMenuClick(event) { 
        event.stopPropagation(); 
        this.showMenu = !this.showMenu; 
        this.generatePreview();
    }

    handleOutsideClick(event) { 
        const menuSection = this.template.querySelector('.whatsapp-flow-previewer-menu-section'); 
        const menuBtn = this.template.querySelector('.whatsapp-flow-previewer-menu');

        if (this.showMenu && !menuSection?.contains(event.target) && !menuBtn?.contains(event.target)) { 
            this.showMenu = false; 
        }
    }

    handleNavigateToTos(event) { 
        event.preventDefault();
        this._currentscreenid = 'TERMS_AND_CONDITIONS'; 
        this.generatePreview(); 
    }

    handleContinueClick(event) { 
        const actionString = event.target.dataset.action; 
        try { 
            const action = JSON.parse(actionString); 
            if (action.type === 'navigate' && action.next) { 
                this._currentscreenid = action.next; 
                this.generatePreview(); 
            }
        } catch (e) { 
            console.error('Invalid action JSON:', e); 
        }
    }

    getInputClass(name) { 
        return `whatsapp-flow-previewer-input ${this.inputFocus[name] || (this.inputValues[name] && this.inputValues[name] !== '') ? 'active' : ''}`; 
    }
}