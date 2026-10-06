import { LightningElement, api } from 'lwc';
import { OmniscriptBaseMixin } from 'omnistudio/omniscriptBaseMixin';

// Printable ASCII (space through ~) and tabs are allowed. New lines only when allowLineBreaks is true.
// Rejects bullets, decorative symbols, emoji, smart quotes, accented/non-Latin letters, etc.
const DISALLOWED_PATTERN = /[^ -~\t]/;
const DISALLOWED_PATTERN_WITH_LINE_BREAKS = /[^ -~\t\r\n]/;

export default class CustomTextAreaInput extends OmniscriptBaseMixin(LightningElement) {
    // Properties below can be set from the Custom LWC element's "Custom Lightning Web Component Properties" in the OmniScript designer
    @api label = 'Profile';
    @api placeholder;
    @api maxLength = 1000;
    @api fieldName = 'textValue';
    @api errorMessage = 'Use up to 1,000 characters on a single line. Emojis, line breaks and special characters (such as • or ★) are not allowed.';
    @api requiredMessage = 'Complete this field.';
    // Static text or a merge field, e.g. %Prefill:Description%. Only used when the user hasn't entered a value yet.
    @api defaultValue;

    _allowLineBreaks = false;
    _required = true;
    value = '';
    hasError = false;
    _restored = false;

    @api
    get allowLineBreaks() {
        return this._allowLineBreaks;
    }
    set allowLineBreaks(val) {
        this._allowLineBreaks = val === true || val === 'true';
    }

    @api
    get required() {
        return this._required;
    }
    set required(val) {
        this._required = val === true || val === 'true';
    }

    connectedCallback() {
        // Restore the value when the user navigates back to this step
        let existing = this.omniGetSaveState ? this.omniGetSaveState(this.stateKey) : undefined;
        if (typeof existing !== 'string') {
            // Fallback: omniUpdateDataJson stores data under the element's name, e.g. CustomTextArea1.textValue
            existing = this.omniJsonData?.[this.elementName]?.[this.fieldName];
        }
        if (typeof existing !== 'string' && this.hasDefaultValue) {
            existing = String(this.defaultValue);
        }
        if (typeof existing === 'string') {
            this.value = existing;
            this.hasError = this.disallowedPattern.test(existing);
        }
    }

    renderedCallback() {
        // Re-show the field error after navigating back, once the textarea exists
        if (!this._restored && this.value) {
            this._restored = true;
            this.validate();
        }
    }

    get disallowedPattern() {
        return this._allowLineBreaks ? DISALLOWED_PATTERN_WITH_LINE_BREAKS : DISALLOWED_PATTERN;
    }

    get hasDefaultValue() {
        const val = this.defaultValue;
        // Ignore empty values and merge fields OmniScript couldn't resolve (left as literal %Node:Field%)
        return val !== undefined && val !== null && val !== '' && !/^%[^%]+%$/.test(String(val));
    }

    get elementName() {
        return this.omniJsonDef?.name;
    }

    get stateKey() {
        return `${this.elementName || 'customTextAreaInput'}_${this.fieldName}`;
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
        this.hasError = this.disallowedPattern.test(this.value || '');
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
        if (this.omniSaveState) {
            this.omniSaveState(this.value, this.stateKey, true);
        }
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
