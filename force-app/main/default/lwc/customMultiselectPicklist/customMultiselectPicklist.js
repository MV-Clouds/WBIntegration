import { LightningElement,api,track } from 'lwc';

export default class CustomMultiselectPicklist extends LightningElement {
        @api options = []; 
        @api selectedValues = [];
        @api isDropdownOpen = false;
        @track searchTerm = '';

        get selectedCountText() {
            const count = this.selectedValues.length;
    
            if (count == 1) {
                const selectedOption = this.options.find(option => option.value === this.selectedValues[0]);
                return selectedOption ? selectedOption.label : 'Select options';
            } else if (count > 1) {
                return `${count} options selected`;
            } else {
                return 'Select options';
            }
        }

        get filteredOptions() {
            return this.options.filter(option => {
                return option.label.toLowerCase().includes(this.searchTerm.toLowerCase());
            });
        }

        handleSearchInput(event) {
            this.searchTerm = event.target.value;
        }
    
        toggleDropdown() {          
            this.isDropdownOpen = !this.isDropdownOpen;
        }
    
        // handleOptionChange(event) {
        //     const value = event.target.name;
        //     console.log('value ',value);
            
    
        //     if (event.target.checked) {
        //         if (!this.selectedValues.includes(value)) {
        //             this.selectedValues = [...this.selectedValues, value];
        //             console.log('this.selectedValues  ',this.selectedValues );
                    
        //         }
        //     } else {
        //         this.selectedValues = this.selectedValues.filter(item => item !== value);
        //     }
    
        //     this.options = this.options.map(option => ({
        //         ...option,
        //         selected: this.selectedValues.includes(option.value)
        //     }));

        //     const selectionChangeEvent = new CustomEvent('selectionchange', {
        //         detail: { SelectedValues: [...this.selectedValues] }
        //     });
        //     this.dispatchEvent(selectionChangeEvent);
    
        // }

        handleOptionChange(event) {
            try {
                event.preventDefault();
                const value = event.target.name;
                 console.log('Option value:', value);
                let tempSelectedValues = [...this.selectedValues]; 
        
                if (event.target.checked) {
                    if (!tempSelectedValues.includes(value)) {
                        tempSelectedValues.push(value);
                        console.log('Added to selectedValues:', JSON.stringify(tempSelectedValues));
                    }
                } else {
                    tempSelectedValues = tempSelectedValues.filter(item => item !== value);
                    console.log('Removed from selectedValues:', JSON.stringify(tempSelectedValues));
                }
            
                this.selectedValues = tempSelectedValues;
                
                this.options = this.options.map(option => ({
                    ...option,
                    selected: this.selectedValues.includes(option.value),
                }));
               
                const selectionChangeEvent = new CustomEvent('selectionchange', {
                    detail: { selectedValues: [...this.selectedValues] },
                });
                this.dispatchEvent(selectionChangeEvent);
            } catch (error) {
                console.error('Error occurred:', error);
            }
           
        }
        
 
        handleBlur() {
            setTimeout(() => {
                this.isDropdownOpen = false;
            }, 200); 
        }

       
}