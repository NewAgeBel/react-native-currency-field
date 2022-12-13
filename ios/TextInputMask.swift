import Foundation

@objc(RNCurrencyField)
class TextInputMask: NSObject, RCTBridgeModule, CurrencyFieldListener {
    static func moduleName() -> String {
        "CurrencyField"
    }

    @objc static func requiresMainQueueSetup() -> Bool {
        true
    }

    var methodQueue: DispatchQueue {
        bridge.uiManager.methodQueue
    }

    var bridge: RCTBridge!
    var masks: [String: CurrencyFieldDelegate] = [:]
    var listeners: [String: CurrencyFieldListener] = [:]
    
    @objc(formatValue:formatOptions:)
    func formatValue(value: NSNumber, formatOptions: NSDictionary) -> String {
        let currency = formatOptions["currency"] as! String
                
        return CurrencyMask.mask(
            value: value.doubleValue,
            formatOptions: formatOptions,
            isDecimalSeparatorLastSymbol: false,
            numberOfFractionsDigits:
                CurrencyMask.getNumberOfFractionDigits(
                    string: value.description,
                    formatOptions: formatOptions
                )
        )
    }

    @objc(extractValue:formatOptions:)
    func extractValue(value: NSString, formatOptions: NSDictionary) -> NSNumber {
        let (doubleValue, _, _) = CurrencyMask.unmask(
            value: String(value),
            formatOptions: formatOptions
        )
        return NSNumber(value: doubleValue)
    }

    @objc(initializeCurrencyField:options:)
    func initializeCurrencyField(reactNode: NSNumber, options: NSDictionary) {
        bridge.uiManager.addUIBlock { (uiManager, viewRegistry) in
            DispatchQueue.main.async {
                guard let view = viewRegistry?[reactNode] as? RCTBaseTextInputView else { return }
                let textView = view.backedTextInputView as! RCTUITextField

                let currency = options["currency"] as! String
                let maxValue = options["maxValue"] as! Double
                let selectTextOnInit = options["selectTextOnInit"] as! Bool

                let maskedDelegate = CurrencyFieldDelegate(
                    currency: currency,
                    maxValue: maxValue,
                    selectTextOnInit: selectTextOnInit,
                    textView: textView
                ) { (_, value) in
                    let textField = textView as! UITextField
                    view.onChange?([
                        "text": value,
                        "target": view.reactTag,
                        "eventCount": view.nativeEventCount,
                    ])
                }
                let key = reactNode.stringValue
                self.listeners[key] = MaskedRCTBackedTextFieldDelegateAdapter(textField: textView)
                maskedDelegate.listener = self.listeners[key]
                self.masks[key] = maskedDelegate

                textView.delegate = self.masks[key]
            }
        }
    }
}

class MaskedRCTBackedTextFieldDelegateAdapter : RCTBackedTextFieldDelegateAdapter, CurrencyFieldListener {}
