import { LightningElement, track, wire } from 'lwc';
import getObjectConfigs from '@salesforce/apex/BroadcastMessageController.getObjectConfigs';
import getListViewsForObject from '@salesforce/apex/BroadcastMessageController.getListViewsForObject';
import { getListUi } from 'lightning/uiListApi';

export default class BroadcastMessage extends LightningElement {
    @track objectOptions = [];
    @track listViewOptions = [];
    @track selectedObject = '';
    @track selectedListView = '';
    @track data = [];
    @track isLoading = false;
    @track configMap = {}; // store object -> {nameField, phoneField}


    get dynamicFieldNames() {
        if (!this.selectedObject || !this.configMap[this.selectedObject]) {
            return [];
        }
        const fields = this.configMap[this.selectedObject];
        return [
            `${this.selectedObject}.${fields.nameField}`,
            `${this.selectedObject}.${fields.phoneField}`
        ];
    }

    get showNoRecordsMessage() {
        return this.data.length === 0;
    }

    get isListViewDropdownDisabled() {
        return !this.selectedObject;
    }
    
    @wire(getListUi, {
        objectApiName: '$selectedObject',
        listViewId: '$selectedListView',
        fields: '$dynamicFieldNames'
    })
    wiredListView({ error, data }) {
        if (!this.selectedObject || !this.selectedListView) {
            return;
        }
    
        if (data) {
            const fields = this.configMap[this.selectedObject];
            this.data = data.records.records.map((record, index) => ({
                index : index + 1,
                Id: record.id,
                name: record.fields[fields.nameField] ? record.fields[fields.nameField].value : '',
                phone: record.fields[fields.phoneField] ? record.fields[fields.phoneField].value : ''
            }));
        } else if (error) {
            console.error('Error loading records:', error);
        }
    }

    connectedCallback() {
        this.loadConfigs();
    }

    loadConfigs() {
        this.isLoading = true;
        getObjectConfigs()
            .then(result => {
                this.objectOptions = result.objectOptions;
                this.configMap = result.configMap;
            })
            .catch(error => {
                console.error('Error loading configs:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedListView = '';
        this.data = [];
        this.loadListViews();
    }

    loadListViews() {
        this.isLoading = true;
        getListViewsForObject({ objectApiName: this.selectedObject })
            .then(result => {
                this.listViewOptions = result.map(lv => ({
                    label: lv.Name,
                    value: lv.Id
                }));
            })
            .catch(error => {
                console.error('Error loading list views:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleListViewChange(event) {
        this.selectedListView = event.detail.value;
        
    }
    
}
