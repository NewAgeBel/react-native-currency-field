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
    open var formatOptions: NSDictionary
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
           self.formatOptions = ["currency": currency]
           self.maxValue = maxValue
           self.selectTextOnInit = selectTextOnInit

           textView.caretPosition = CurrencyMask.getIndexOfCaretPosition(
               string: textView.text ?? "",
               formatOptions: self.formatOptions
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
                formatOptions: self.formatOptions
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
            value: updatedText,
            formatOptions: self.formatOptions
        )

        if !shouldAllowChange(symbol: string, newValue: unmaskedValue, oldValue: originalString) {
            return false
        }

        let maskedValue = CurrencyMask.mask(
            value: unmaskedValue,
            formatOptions: self.formatOptions,
            isDecimalSeparatorLastSymbol: isDecimalSeparatorLastSymbol,
            numberOfFractionsDigits: numberOfFractionsDigits
        )

        textField.text = maskedValue

        textField.caretPosition = CurrencyMask.getIndexOfCaretPosition(
            string: maskedValue,
            formatOptions: self.formatOptions
        )

        // Update JS land
        if (onChangeListener != nil) {
            onChangeListener!(textField, maskedValue)
        }

        // Tell field to let us handle text updating
        return false
    }

    open func shouldAllowChange(symbol: String, newValue: Double, oldValue: String) -> Bool {
        let decimalSeparator = CurrencyMask.getDecimalSeparator(formatOptions: self.formatOptions)

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
        formatOptions: NSDictionary
    ) -> Int {
        let decimalSeparator = getDecimalSeparator(formatOptions: formatOptions)

        let arr = string.components(separatedBy: decimalSeparator)

        if arr.count > 1 {
            return arr[1].count
        }
        return 0
    }

    static func getNumbers(
        string: String,
        formatOptions: NSDictionary
    ) -> String {
        let decimalSeparator = getDecimalSeparator(formatOptions: formatOptions)
        return string.components(separatedBy: CharacterSet(charactersIn: "0123456789\(decimalSeparator)").inverted).joined()
    }

    static func getIndexOfLastNumber(string: String) -> Int {
        return Array(string).lastIndex(where: {$0.isNumber}) ?? -1
    }

    static func getIndexOfDecimalSeparator(
        string: String,
        formatOptions: NSDictionary
    ) -> Int {
        let decimalSeparator = getDecimalSeparator(formatOptions: formatOptions)
        return Array(string).lastIndex(where: {$0.description == decimalSeparator}) ?? -1
    }

    static func getIndexOfCaretPosition(
        string: String,
        formatOptions: NSDictionary
    ) -> Int {
        let indexOfDecimalSeparator = getIndexOfDecimalSeparator(
            string: string,
            formatOptions: formatOptions
        )
        let indexOfLastNumber = getIndexOfLastNumber(string: string)

        if (indexOfDecimalSeparator >= 0 || indexOfLastNumber >= 0) {
            return max(indexOfDecimalSeparator + 1, indexOfLastNumber + 1)
        }
        return 1
    }

    static func getFormatter(formatOptions: NSDictionary) -> NumberFormatter {
        let currency = formatOptions["currency"] as! String
        let minimumFractionDigits = formatOptions["minimumFractionDigits"] as! Int?
        let maximumFractionDigits = formatOptions["maximumFractionDigits"] as! Int?
        let signEnabled = formatOptions["signEnabled"] as! Bool?

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = currency
        currencyFormatter.maximumFractionDigits = maximumFractionDigits != nil ? maximumFractionDigits! : 0
        currencyFormatter.minimumFractionDigits = minimumFractionDigits != nil ? minimumFractionDigits! : 0
        currencyFormatter.currencyDecimalSeparator = currencyFormatter.decimalSeparator
        currencyFormatter.currencyGroupingSeparator = currencyFormatter.groupingSeparator

        if (signEnabled != nil && signEnabled!) {
            currencyFormatter.positivePrefix = currencyFormatter.negativePrefix.replacingOccurrences(
                of: currencyFormatter.minusSign,
                with: currencyFormatter.plusSign
            )
        }
        return currencyFormatter
    }

    static func getDecimalSeparator(formatOptions: NSDictionary) -> String {
        let currencyFormatter = getFormatter(formatOptions: formatOptions)
        return currencyFormatter.currencyDecimalSeparator
    }

    static func unmask(
        value: String,
        formatOptions: NSDictionary
    ) -> (Double, Bool, Int) {
        let currencyFormatter = getFormatter(formatOptions: formatOptions)

        let numbers = getNumbers(
            string: value,
            formatOptions: formatOptions
        )

        let numberOfFractionsDigits = getNumberOfFractionDigits(
            string: numbers,
            formatOptions: formatOptions
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
        formatOptions: NSDictionary,
        isDecimalSeparatorLastSymbol: Bool,
        numberOfFractionsDigits: Int
    ) -> String  {
        let currencyFormatter = getFormatter(formatOptions: formatOptions)

        let minimumFractionDigits = formatOptions["minimumFractionDigits"] as! Int?
        let maximumFractionDigits = formatOptions["maximumFractionDigits"] as! Int?

        currencyFormatter.maximumFractionDigits = maximumFractionDigits != nil ? maximumFractionDigits! : max(numberOfFractionsDigits, 2)
        currencyFormatter.minimumFractionDigits = minimumFractionDigits != nil ? minimumFractionDigits! : min(numberOfFractionsDigits, 2)

        let formattedCurrency = currencyFormatter.string(from: NSNumber(value: value))

        if isDecimalSeparatorLastSymbol {
            let str = "\(formattedCurrency!)";
            let decimalSeparatorIndex = Array(str).lastIndex(where: {$0.isNumber})! + 1
            return str.prefix(decimalSeparatorIndex).description + currencyFormatter.decimalSeparator.description + str.suffix(str.count - decimalSeparatorIndex).description
        }

        return formattedCurrency ?? ""
    }
}
