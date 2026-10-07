import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

// Printable ASCII (space through ~) and tabs are allowed. New lines only when allowLineBreaks is true.
// Rejects bullets, decorative symbols, emoji, smart quotes, accented/non-Latin letters, etc.
const DISALLOWED_PATTERN = /[^ -~\t]/;
const DISALLOWED_PATTERN_WITH_LINE_BREAKS = /[^ -~\t\r\n]/;

const DEFAULT_ERROR_MESSAGE = 'Use up to 1,000 characters on a single line. Emojis, line breaks and special characters (such as • or ★) are not allowed.';
const DEFAULT_REQUIRED_MESSAGE = 'Complete this field.';

export default class CustomTextArea2 extends LightningElement {
    // Properties below are set on the component in the Flow screen editor
    @api label = 'Profile';
    @api placeholder;
    @api maxLength = 1000;
    @api errorMessage;
    @api requiredMessage;

    _value = '';
    _hasError = false;
    _required = false;
    _allowLineBreaks = false;
    _restored = false;

    // Input: default value from the Flow. Output: the text the user entered.
    // Bind input and output to the same variable so the value is kept when the user clicks Previous.
    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val === undefined || val === null ? '' : String(val);
        this._hasError = this.disallowedPattern.test(this._value);
    }

    // Output only: true when the text breaks the character, line break or length rules
    @api
    get hasError() {
        return this._hasError;
    }
    set hasError(val) {
        // Set by the component itself; ignore values passed in from the Flow
    }

    @api
    get required() {
        return this._required;
    }
    set required(val) {
        this._required = val === true || val === 'true';
    }

    @api
    get allowLineBreaks() {
        return this._allowLineBreaks;
    }
    set allowLineBreaks(val) {
        this._allowLineBreaks = val === true || val === 'true';
    }

    get disallowedPattern() {
        return this._allowLineBreaks ? DISALLOWED_PATTERN_WITH_LINE_BREAKS : DISALLOWED_PATTERN;
    }

    get effectiveErrorMessage() {
        return this.errorMessage || DEFAULT_ERROR_MESSAGE;
    }

    get effectiveRequiredMessage() {
        return this.requiredMessage || DEFAULT_REQUIRED_MESSAGE;
    }

    renderedCallback() {
        // Show the field error for a default or returning value, once the textarea exists
        if (!this._restored) {
            this._restored = true;
            if (this._value) {
                this.runChecks();
                this.notifyFlow();
            }
        }
    }

    handleChange(event) {
        this._value = event.target.value;
        this.runChecks();
        this.notifyFlow();
    }

    handleBlur() {
        this.runChecks();
    }

    // Applies the rules and shows/clears the field-level error. Returns true when valid.
    runChecks() {
        const text = this._value || '';
        const tooLong = this.maxLength && text.length > Number(this.maxLength);
        this._hasError = this.disallowedPattern.test(text) || Boolean(tooLong);

        const textarea = this.template.querySelector('lightning-textarea');
        if (textarea) {
            textarea.setCustomValidity(this._hasError ? this.effectiveErrorMessage : '');
            textarea.reportValidity();
        }
        return !this._hasError && (!textarea || textarea.checkValidity());
    }

    notifyFlow() {
        this.dispatchEvent(new FlowAttributeChangeEvent('value', this._value));
        this.dispatchEvent(new FlowAttributeChangeEvent('hasError', this._hasError));
    }

    // Called by Flow when the user clicks Next. Returning isValid: false keeps the user on the screen.
    @api
    validate() {
        if (this.runChecks()) {
            return { isValid: true };
        }
        const missing = this._required && !this._value;
        return {
            isValid: false,
            errorMessage: missing ? this.effectiveRequiredMessage : this.effectiveErrorMessage
        };
    }
}
