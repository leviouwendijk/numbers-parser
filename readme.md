# Setup

This heavily relies on environment variables:

```swift
enum Environment: String {
    case source = "NUMBERS_SOURCE"
    case destination = "NUMBERS_DESTINATION"
    case target = "NUMBERS_TARGET"
    case parsed = "NUMBERS_PARSED"
    case reparsed = "NUMBERS_REPARSED"
    case invoiceRaw = "NUMBERS_INVOICE_RAW"
    case invoice = "NUMBERS_INVOICE_OUT"
    case sheet = "NUMBERS_SHEET"
    case table = "NUMBERS_TABLE"
    case row = "NUMBERS_ROW"
    case column = "NUMBERS_COLUMN"
}
```
