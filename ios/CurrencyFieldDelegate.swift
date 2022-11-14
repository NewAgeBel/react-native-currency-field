import Foundation
import UIKit


/**
 ### CurrencyFieldListener

 Allows clients to obtain value extracted by the mask from user input.

 Provides callbacks from listened UITextField.
 */
@objc public protocol CurrencyFieldListener: UITextFieldDelegate {

    /**
     Callback to return extracted value and to signal whether the user has complete input.
     */
    @objc optional func textField(
        _ textField: UITextField,
        didFillMandatoryCharacters complete: Bool,
        didExtractValue value: String
    )

}


/**
 ### CurrencyFieldDelegate

 UITextFieldDelegate, which applies masking to the user input.
 Might be used as a decorator, which forwards UITextFieldDelegate calls to its own listener.
 */
@IBDesignable
open class CurrencyFieldDelegate: NSObject, UITextFieldDelegate {

    open weak var listener: CurrencyFieldListener?
    open var onChangeListener: ((_ textField: UITextField, _ value: String) -> ())?
    open var currency: String
    open var maxValue: Double
    open var selectTextOnInit: Bool

    public init(
        currency: String,
        maxValue: Double,
        selectTextOnInit: Bool,
        textView: UITextField,
        onMaskedTextChangedCallback: ((_ textInput: UITextInput, _ value: String) -> ())? = nil
       ) {
           self.onChangeListener = onMaskedTextChangedCallback
           self.currency = currency
           self.maxValue = maxValue
           self.selectTextOnInit = selectTextOnInit

           textView.caretPosition = CurrencyMask.getIndexOfCaretPosition(
               string: textView.text ?? "",
               currency: self.currency
           )

           if (selectTextOnInit == true) {
               textView.becomeFirstResponder()
               textView.selectedTextRange = textView.textRange(from: textView.beginningOfDocument, to: textView.endOfDocument)
           }

           super.init()
       }


    open func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return listener?.textFieldShouldBeginEditing?(textField) ?? true
    }

    open func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            textField.caretPosition = CurrencyMask.getIndexOfCaretPosition(
                string: textField.text ?? "",
                currency: self.currency
            )
        }
        listener?.textFieldDidBeginEditing?(textField)
    }

    open func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return listener?.textFieldShouldEndEditing?(textField) ?? true
    }

    open func textFieldDidEndEditing(_ textField: UITextField) {
        listener?.textFieldDidEndEditing?(textField)
    }

    @available(iOS 10.0, *)
    open func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if listener?.textFieldDidEndEditing?(textField, reason: reason) != nil {
            listener?.textFieldDidEndEditing?(textField, reason: reason)
        } else {
            listener?.textFieldDidEndEditing?(textField)
        }
    }

    open func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let originalString = textField.text ?? ""
        let updatedText: String = replaceCharacters(inText: originalString, range: range, withCharacters: string)

        let (
            unmaskedValue,
            isDecimalSeparatorLastSymbol,
            numberOfFractionsDigits
        ) = CurrencyMask.unmask(
            input: updatedText,
            currency: self.currency
        )

        if !shouldAllowChange(symbol: string, newValue: unmaskedValue, oldValue: originalString) {
            return false
        }

        let maskedValue = CurrencyMask.mask(
            value: unmaskedValue,
            currency: self.currency,
            isDecimalSeparatorLastSymbol: isDecimalSeparatorLastSymbol,
            numberOfFractionsDigits: numberOfFractionsDigits
        )

        textField.text = maskedValue

        textField.caretPosition = CurrencyMask.getIndexOfCaretPosition(
            string: maskedValue,
            currency: self.currency
        )

        // Update JS land
        if (onChangeListener != nil) {
            onChangeListener!(textField, maskedValue)
        }

        // Tell field to let us handle text updating
        return false
    }

    open func shouldAllowChange(symbol: String, newValue: Double, oldValue: String) -> Bool {
        let decimalSeparator = CurrencyMask.getDecimalSeparator(currency: currency)

        if oldValue.contains(decimalSeparator) && symbol == decimalSeparator  {
            return false
        }
        if newValue > self.maxValue {
            return false
        }
        if String(newValue).components(separatedBy: ".")[1].count > 2 {
            return false
        }
        return true
    }

    open func replaceCharacters(inText text: String, range: NSRange, withCharacters newText: String) -> String {
        if 0 < range.length {
            let result = NSMutableString(string: text)
            result.replaceCharacters(in: range, with: newText)
            return result as String
        } else {
            let result = NSMutableString(string: text)
            result.insert(newText, at: range.location)
            return result as String
        }
    }
}

class CurrencyMask {
    static func getNumberOfFractionDigits(
        string: String,
        currency: String
    ) -> Int {
        let decimalSeparator = getDecimalSeparator(currency: currency)

        let arr = string.components(separatedBy: decimalSeparator)

        if arr.count > 1 {
            return arr[1].count
        }
        return 0
    }

    static func getNumbers(
        string: String,
        currency: String
    ) -> String {
        let decimalSeparator = getDecimalSeparator(currency: currency)
        return string.components(separatedBy: CharacterSet(charactersIn: "0123456789\(decimalSeparator)").inverted).joined()
    }

    static func getIndexOfLastNumber(string: String) -> Int {
        return Array(string).lastIndex(where: {$0.isNumber}) ?? -1
    }

    static func getIndexOfDecimalSeparator(
        string: String,
        currency: String
    ) -> Int {
        let decimalSeparator = getDecimalSeparator(currency: currency)
        return Array(string).lastIndex(where: {$0.description == decimalSeparator}) ?? -1
    }

    static func getIndexOfCaretPosition(
        string: String,
        currency: String
    ) -> Int {
        let indexOfDecimalSeparator = getIndexOfDecimalSeparator(
            string: string,
            currency: currency
        )
        let indexOfLastNumber = getIndexOfLastNumber(string: string)

        if (indexOfDecimalSeparator >= 0 || indexOfLastNumber >= 0) {
            return max(indexOfDecimalSeparator + 1, indexOfLastNumber + 1)
        }
        return 1
    }

    static func getFormatter(currency: String) -> NumberFormatter {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = currency
        currencyFormatter.maximumFractionDigits = 0
        currencyFormatter.minimumFractionDigits = 0
        currencyFormatter.currencyDecimalSeparator = currencyFormatter.decimalSeparator
        currencyFormatter.currencyGroupingSeparator = currencyFormatter.groupingSeparator
        return currencyFormatter
    }

    static func getDecimalSeparator(currency: String) -> String {
        let currencyFormatter = getFormatter(currency: currency)
        return currencyFormatter.currencyDecimalSeparator
    }

    static func unmask(
        input: String,
        currency: String
    ) -> (Double, Bool, Int) {
        let currencyFormatter = getFormatter(currency: currency)

        let numbers = getNumbers(
            string: input,
            currency: currency
        )

        let numberOfFractionsDigits = getNumberOfFractionDigits(
            string: numbers,
            currency: currency
        )

        let isDecimalSeparatorLastSymbol = numbers.last?.description == currencyFormatter.decimalSeparator

        currencyFormatter.numberStyle = .decimal
        let doubleValue = currencyFormatter.number(from: numbers)?.doubleValue ?? Double(0)

        return (
            doubleValue,
            isDecimalSeparatorLastSymbol,
            numberOfFractionsDigits
        )
    }

    static func mask(
        value: Double,
        currency: String,
        isDecimalSeparatorLastSymbol: Bool,
        numberOfFractionsDigits: Int
    ) -> String  {
        let currencyFormatter = getFormatter(currency: currency)

        currencyFormatter.maximumFractionDigits = min(numberOfFractionsDigits, 2)
        currencyFormatter.minimumFractionDigits = min(numberOfFractionsDigits, 2)

        let formattedCurrency = currencyFormatter.string(from: NSNumber(value: value))

        if isDecimalSeparatorLastSymbol {
            let str = "\(formattedCurrency!)";
            let decimalSeparatorIndex = Array(str).lastIndex(where: {$0.isNumber})! + 1
            return str.prefix(decimalSeparatorIndex).description + currencyFormatter.decimalSeparator.description + str.suffix(str.count - decimalSeparatorIndex).description
        }

        return formattedCurrency ?? ""
    }
}
