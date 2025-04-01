import { LightningElement,track } from 'lwc';

export default class FlowPreviewModel extends LightningElement {
    @track selectedFlow = '';
    @track iframeSrc = '';

    flows = [
        { id: '1', name: 'ascdwED', publishedDate: '25 Mar 2025', url: 'https://example.com/preview1' },
        { id: '2', name: 'In Progress Lead Status Update', publishedDate: '11 Mar 2025', url: 'https://example.com/preview2' },
        { id: '3', name: 'New Lead Status Update', publishedDate: '11 Mar 2025', url: 'https://example.com/preview3' }
    ];

    get flowOptions() {
        return this.flows.map(flow => ({
            label: `${flow.name} (Published: ${flow.publishedDate})`,
            value: flow.id
        }));
    }

    handleFlowChange(event) {
        const selectedId = event.detail.value;
        const flow = this.flows.find(f => f.id === selectedId);
        if (flow) {
            this.selectedFlow = selectedId;
            this.iframeSrc = flow.url;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSubmit() {
        this.dispatchEvent(new CustomEvent('submit', { detail: this.selectedFlow }));
    }
}