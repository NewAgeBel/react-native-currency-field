<p align="center">
  <img src="https://img.shields.io/npm/v/@newagebel/react-native-currency-field" />
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-brightgreen" />
</p>

<h2 align="center">🤑 react-native-currency-field 🤑</h2>
A fully native TextInput component that supports all currencies and locales.

## Demo
| Currency: USD, Locale: en_US                                                         | Currency: EUR, Locale: de_DE                                                         | Currency: UAH, Locale: uk_UA                                                         |
|--------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| <img  src="https://media.giphy.com/media/SjReA1yR2hBJ4DaVaX/giphy.gif"> | <img  src="https://media.giphy.com/media/v0cdT4M0ILu659VYYN/giphy.gif"> | <img  src="https://media.giphy.com/media/RnnLeKsnn7gb6InlBb/giphy.gif">


## Installation

```
npm install @newagebel/react-native-currency-field
```
or
```
yarn add @newagebel/react-native-currency-field
```
### iOS Installation
```
cd ios && pod install && cd ..
```
### Android Installation
There are no extra steps 💆‍♂️

## Usage

```
import CurrencyField from '@newagebel/react-native-currency-field'

function MyComponent() {
  const [value, setValue] = useState(20);

  <CurrencyField
    value={value}
    onChangeText={setValue}
    currency={'EUR'}
    maxValue={10000}
    selectTextOnInit={false}
    style={style.inputStyle}
  />;
}
```
## Props
| Prop                   | Type     | Default                                              | Description                                                                                                                                |
| ---------------------- | -------- |------------------------------------------------------| ------------------------------------------------------------------------------------------------------------------------------------------ |
| **...TextInputProps**  |          |                                                      | Inherit all [props of `TextInput`](https://reactnative.dev/docs/textinput#props).|
| **`value`**            | number   | 0                                                    | |
| **`onChangeText`**    | function | (unmaskedValue: number, maskedValue: string) => null | |
| **`currency`**        | string   | USD                                                  | |
| **`maxValue`**        | string   | 100000000                                            | |
| **`selectTextOnInit`**        | boolean   | false                                                | Select all text on initialization

**To change the locale, you need to change the region in the phone settings.**

## License
MIT
