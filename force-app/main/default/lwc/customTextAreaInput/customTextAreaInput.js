import { LightningElement, api } from 'lwc';
import { OmniscriptBaseMixin } from 'omnistudio/omniscriptBaseMixin';

// Letters (any language), numbers and whitespace (spaces, tabs, new lines) are allowed.
const DISALLOWED_PATTERN = /[^\p{L}\p{N}\s]/u;

export default class CustomTextAreaInput extends OmniscriptBaseMixin(LightningElement) {
    // Properties below can be set from the Custom LWC element's "Custom Lightning Web Component Properties" in the OmniScript designer
    @api label = 'Description';
    @api placeholder;
    @api maxLength;
    @api fieldName = 'textValue';
    @api errorMessage = 'Special characters are not allowed. Only letters, numbers, spaces and tabs are permitted.';
    @api requiredMessage = 'Complete this field.';

    _required = false;
    value = '';
    hasError = false;

    @api
    get required() {
        return this._required;
    }
    set required(val) {
        this._required = val === true || val === 'true';
    }

    connectedCallback() {
        // Prefill from the OmniScript data JSON if a value already exists (e.g. user navigated back)
        const existing = this.omniJsonData?.[this.fieldName];
        if (typeof existing === 'string') {
            this.value = existing;
            this.hasError = DISALLOWED_PATTERN.test(existing);
        }
    }

    handleChange(event) {
        this.value = event.target.value;
        this.validate();
    }

    handleBlur() {
        this.validate();
    }

    validate() {
        const textarea = this.template.querySelector('lightning-textarea');
        this.hasError = DISALLOWED_PATTERN.test(this.value || '');
        if (textarea) {
            textarea.setCustomValidity(this.hasError ? this.errorMessage : '');
            textarea.reportValidity();
        }
        this.pushToOmniscript();
        return !this.hasError && (!textarea || textarea.checkValidity());
    }

    pushToOmniscript() {
        // Written to the element's node in the data JSON, e.g. %customTextAreaInput:textValue% / %customTextAreaInput:hasSpecialCharError%
        this.omniUpdateDataJson({
            [this.fieldName]: this.value,
            hasSpecialCharError: this.hasError
        });
    }

    // Called by the OmniScript Step when the user clicks Next. Returning false blocks navigation.
    @api
    checkValidity() {
        return this.validate();
    }

    @api
    reportValidity() {
        return this.validate();
    }
}
