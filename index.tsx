import React, {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from 'react'

import {
  findNodeHandle,
  NativeModules,
  TextInput,
  TextInputProps,
} from 'react-native'

const {RNCurrencyField} = NativeModules as {RNCurrencyField: NativeExports}
export const {
  initializeCurrencyField,
  extractValue,
  formatValue,
} = RNCurrencyField

if (!RNCurrencyField) {
  throw new Error(`NativeModule: RNCurrencyField is null.
To fix this issue try these steps:
  • Rebuild and restart the app.
  • Run the packager with \`--clearCache\` flag.
  • If happening on iOS, run \`pod install\` in the \`ios\` directory and then rebuild and re-run the app.
`)
}

interface FormatOptions {
  currency: string,
  minimumFractionDigits?: number,
  maximumFractionDigits?: number,
  signEnabled?: boolean
}

type NativeExports = {
  initializeCurrencyField: (reactNode: Number, options: any) => void
  formatValue: (value: number, formatOptions: FormatOptions) => string
  extractValue: (value: string, formatOptions: FormatOptions) => number
}

type CurrencyFieldProps = Pick<TextInputProps, Exclude<keyof TextInputProps, "value" | "onChangeText">> & {
  value: number
  maxValue?: number
  currency?: string
  selectTextOnInit?: boolean
  onChangeText?: (value: number, label: string) => void
}

interface Handles {
  focus: () => void
  blur: () => void
}

const CurrencyField = forwardRef<Handles, CurrencyFieldProps>(
  ({
     value,
     maxValue = 100000000,
     currency = "USD",
     selectTextOnInit = false,
     onChangeText,
     onFocus,
     ...rest
   }, ref) => {
    // Create a default input
    const [ defaultLabel ] = useState(formatValue(value ?? 0, {currency}))

    // Keep a reference to the actual text input
    const input = useRef<TextInput>(null)
    const [rawValue, setValue] = useState<number>(value)
    const [label, setLabel] = useState<string>(defaultLabel)

    // Keep numeric prop in sync without state
    useEffect(() => {
        if (value != null && value != rawValue) {
            setValue(value)
            setLabel(formatValue(value, {currency}));
        }
    }, [value, rawValue, currency])

    // Convert TextInput to CurrencyField native type
    useEffect(() => {
      const nodeId = findNodeHandle(input.current)
      if (nodeId) {
        initializeCurrencyField(nodeId, { currency, maxValue, selectTextOnInit })
      }
    }, [currency, maxValue, selectTextOnInit])

    // Create a false ref interface
    useImperativeHandle(ref, () => ({
      focus: () => {
        input.current?.focus()
      },
      blur: () => {
        input.current?.blur()
      },
    }))

    return (
      <TextInput
        {...rest}
        ref={input}
        value={label}
        onFocus={(e: any) => {
          if (defaultLabel == "" && !rawValue) {
            setValue(0)
            setLabel(formatValue(0, {currency}));
          }
          onFocus?.(e)
        }}
        onChangeText={async (value: string) => {
          const computedValue = extractValue(value, {currency})
          setLabel(value)
          setValue(computedValue)
          onChangeText?.(computedValue, value)
        }}
        keyboardType="decimal-pad"
      />
    )
  }
)

export default CurrencyField
