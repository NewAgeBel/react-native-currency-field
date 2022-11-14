package com.newagebel.RNCurrencyField

import android.os.Build
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.View.OnFocusChangeListener
import android.widget.EditText
import com.facebook.react.bridge.*
import com.facebook.react.uimanager.UIManagerModule
import java.lang.ref.WeakReference
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.text.NumberFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

fun ReadableMap.string(key: String): String? = this.getString(key)
class RNCurrencyFieldModule(private val context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {
    override fun getName() = "RNCurrencyField"

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun formatValue(value: Double, currency: String): String {
        return CurrencyMask.mask(
            value,
            currency,
            false,
            CurrencyMask.getNumberOfFractionDigits(DecimalFormat("0.##").format(value))
        )
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun extractValue(label: String, currency: String): Double {
        val (doubleValue, _ ,_) = CurrencyMask.unmask(label)
        return doubleValue
    }

    @ReactMethod
    fun initializeCurrencyField(tag: Int, options: ReadableMap) {
        // We need to use prependUIBlock instead of addUIBlock since subsequent UI operations in
        // the queue might be removing the view we're looking to update.
        context.getNativeModule(UIManagerModule::class.java)!!.prependUIBlock { nativeViewHierarchyManager ->
            // The view needs to be resolved before running on the UI thread because there's a delay before the UI queue can pick up the runnable.
            val editText = nativeViewHierarchyManager.resolveView(tag) as EditText
            context.runOnUiQueueThread {
                CurrencyTextListener.install(
                    field = editText,
                    currency = options.getString("currency") as String,
                    maxValue = options.getDouble("maxValue"),
                    selectTextOnInit = options.getBoolean("selectTextOnInit")
                )
            }
        }
    }
}

internal class CurrencyTextListener(
    field: EditText,
    currency: String,
    maxValue: Double,
    selectTextOnInit: Boolean,
    private val focusChangeListener: OnFocusChangeListener
) : CurrencyTextWatcher(
    field = field,
    currency = currency,
    maxValue = maxValue,
    selectTextOnInit = selectTextOnInit
) {
    private var previousText: String = ""
    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {
        previousText = s.toString()
        super.beforeTextChanged(s, start, count, after)
    }

    override fun onTextChanged(text: CharSequence, cursorPosition: Int, before: Int, count: Int) {
        super.onTextChanged(text, cursorPosition, before, count)
    }

    override fun onFocusChange(view: View?, hasFocus: Boolean) {
        super.onFocusChange(view, hasFocus)
        focusChangeListener.onFocusChange(view, hasFocus)
    }

    companion object {
        private const val TEXT_CHANGE_LISTENER_TAG_KEY = 123456789
        fun install(
            field: EditText,
            currency: String,
            maxValue: Double,
            selectTextOnInit: Boolean
        ) {
            if (field.getTag(TEXT_CHANGE_LISTENER_TAG_KEY) != null) {
                field.removeTextChangedListener(field.getTag(TEXT_CHANGE_LISTENER_TAG_KEY) as TextWatcher)
            }
            val listener: CurrencyTextWatcher = CurrencyTextListener(
                field = field,
                currency = currency,
                maxValue = maxValue,
                selectTextOnInit = selectTextOnInit,
                focusChangeListener = field.onFocusChangeListener
            )
            field.addTextChangedListener(listener)
            field.setOnTouchListener(listener)
            field.setOnFocusChangeListener(listener)
            field.setTag(TEXT_CHANGE_LISTENER_TAG_KEY, listener)
        }
    }
}

open class CurrencyMask {
     companion object {
         fun getNumberOfFractionDigits(string: String): Int {
             val decimalSeparator = getDecimalSeparator()

             val arr = string.split(decimalSeparator)

             if (arr.count() > 1) {
                 return arr[1].length
             }
             return 0
         }

         fun getNumbers(string: String): String {
             val decimalSeparator = getDecimalSeparator().toString()
             return "[^0-9$decimalSeparator]".toRegex().replace(string, "")
         }

         fun getIndexOfLastNumber(string: String): Int {
             val lastNumber = string.last { it.isDigit() }
             return string.lastIndexOf(lastNumber, string.length, false )
         }

         fun getIndexOfDecimalSeparator(string: String): Int {
             val decimalSeparator = getDecimalSeparator()

             return string.lastIndexOf(decimalSeparator, string.length, false )
         }

         fun getIndexOfCaretPosition(string: String): Int {
             val caretPositionAfterDecimalSeparator = getIndexOfDecimalSeparator(string) + 1
             val caretPositionAfterLastNumber = getIndexOfLastNumber(string) + 1

             if (caretPositionAfterDecimalSeparator > 0 || caretPositionAfterLastNumber > 0) {
                 return max(caretPositionAfterDecimalSeparator, caretPositionAfterLastNumber)
             }
             return string.length
         }

         fun getFormatter(currency: String): NumberFormat {
             val format: NumberFormat = NumberFormat.getCurrencyInstance()
             format.currency = Currency.getInstance(currency)
             format.maximumFractionDigits = 0
             format.minimumFractionDigits = 0
             return format
         }

         fun getDecimalSeparator(): Char {
             return DecimalFormatSymbols.getInstance().decimalSeparator
         }

         fun unmask(text: String): Triple<Double, Boolean, Int> {
             val decimalSeparator = getDecimalSeparator()

             val numbers = getNumbers(text)

             val numberOfFractionsDigits = getNumberOfFractionDigits(numbers)

             if (numbers.isNotEmpty()) {
                 val isDecimalSeparatorLastSymbol = numbers.last() == decimalSeparator

                 val formattedValue = numbers.replace(decimalSeparator.toString(), ".").toDouble()

                 return Triple(formattedValue, isDecimalSeparatorLastSymbol, numberOfFractionsDigits)
             }

             return Triple(0.0, false, 0)
         }

         fun mask(
            value: Double,
            currency: String,
            isDecimalSeparatorLastSymbol: Boolean,
            numberOfFractionsDigits: Int
         ): String {
             val decimalSeparator = getDecimalSeparator()
             val currencyFormatter = getFormatter(currency)

             currencyFormatter.maximumFractionDigits = min(numberOfFractionsDigits, 2)
             currencyFormatter.minimumFractionDigits = min(numberOfFractionsDigits, 2)

             val formattedCurrency = currencyFormatter.format(value)

             if (isDecimalSeparatorLastSymbol) {
                 val decimalSeparatorIndex = getIndexOfLastNumber(formattedCurrency) + 1
                 return formattedCurrency.substring(
                    0,
                    decimalSeparatorIndex) + decimalSeparator.toString() + formattedCurrency.substring(decimalSeparatorIndex, formattedCurrency.length
                 );
             }

             return formattedCurrency
         }
     }
}

/**
 * TextWatcher implementation.
 *
 * TextWatcher implementation, which applies masking to the user input, picking the most suitable mask for the text.
 *
 * Might be used as a decorator, which forwards TextWatcher calls to its own listener.
 */
open class CurrencyTextWatcher(
        field: EditText,
        var currency: String,
        var maxValue: Double,
        var selectTextOnInit: Boolean,
        var listener: TextWatcher? = null
) : TextWatcher, View.OnFocusChangeListener, View.OnTouchListener {

    private var previousText: String
    private var afterText: String
    private var caretPosition: Int = 0

    private val field: WeakReference<EditText> = WeakReference(field)

    init {
        previousText = field.text.toString()
        afterText = field.text.toString()
        tidyCaretPosition()

        if (selectTextOnInit == true) {
            field.selectAll()
        }
    }

    override fun afterTextChanged(edit: Editable?) {
        this.field.get()?.removeTextChangedListener(this)
        edit?.replace(0, edit.length, this.afterText)

        try {
            this.field.get()?.setSelection(this.caretPosition)
        } catch (e: IndexOutOfBoundsException) {}

        this.field.get()?.addTextChangedListener(this)
        this.listener?.afterTextChanged(edit)
    }

    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {
        previousText = s.toString()
        this.listener?.beforeTextChanged(s, start, count, after)
    }

    override fun onTextChanged(text: CharSequence, cursorPosition: Int, before: Int, count: Int) {
        try {
            val newText = text.substring(cursorPosition, cursorPosition + count)
            val oldText = previousText.substring(cursorPosition, cursorPosition + before)

            var inputText = text.toString()

            if (newText == "." || newText == "," || newText == "-") {
                val decimalSeparator = CurrencyMask.getDecimalSeparator().toString()
                inputText = inputText.replaceRange(cursorPosition, cursorPosition + count, decimalSeparator)
            }

            val (
                unmaskedValue,
                isDecimalSeparatorLastSymbol,
                numberOfFractionsDigits
            ) = CurrencyMask.unmask(inputText)

            if (!shouldAllowChange(newText, oldText, unmaskedValue)) {
                return
            }

            val maskedValue = CurrencyMask.mask(
                unmaskedValue,
                currency,
                isDecimalSeparatorLastSymbol,
                numberOfFractionsDigits
            )

            this.afterText = maskedValue
            this.caretPosition = CurrencyMask.getIndexOfCaretPosition(maskedValue)
        } catch (e: Exception) {
            this.afterText = previousText
            this.caretPosition = CurrencyMask.getIndexOfCaretPosition(previousText)
        }
    }

    fun shouldAllowChange(symbol: String, oldValue: String?, newValue: Double): Boolean {
        val decimalSeparator = CurrencyMask.getDecimalSeparator().toString()

        if (oldValue != null && oldValue.contains(decimalSeparator) && symbol == decimalSeparator)  {
            return false
        }
        if (newValue > maxValue) {
            return false
        }
        if (newValue.toString().split(".").count() > 1 && newValue.toString().split(".")[1].count() > 2) {
            return false
        }
        return true
    }

    fun tidyCaretPosition() {
        try {
            val content = field.get()?.text.toString()

            if (content?.length > 0) {
                this.caretPosition = CurrencyMask.getIndexOfCaretPosition(content)
            }

            if (this.caretPosition <= content.length) {
                this.field.get()?.setSelection(this.caretPosition)
            }
        } catch(err: Error) {}
    }

    override fun onFocusChange(view: View?, hasFocus: Boolean) {
        if (hasFocus) {
            tidyCaretPosition()
        }
    }

    override fun onTouch(v: View?, event: MotionEvent?): Boolean {
        tidyCaretPosition()
        return false
    }

    companion object {
        fun installOn(
                editText: EditText,
                currency: String,
                maxValue: Double,
                selectTextOnInit: Boolean = false,
                listener: TextWatcher? = null,
        ): CurrencyTextWatcher {
            val maskedListener = CurrencyTextWatcher(
                    editText,
                    currency,
                    maxValue,
                    selectTextOnInit,
            )
            editText.addTextChangedListener(maskedListener)
            editText.onFocusChangeListener = maskedListener
            return maskedListener
        }
    }
}
