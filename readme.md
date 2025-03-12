# Setup

This heavily relies on environment variables:

```swift
enum Environment: String {
    case apikey = "MAILER_API_KEY" 
    case apiURL = "MAILER_API_BASE_URL"
    case endpoint = "MAILER_API_ENDPOINT_DEFAULT"
    case from = "MAILER_FROM"
    case alias = "MAILER_ALIAS"
    case aliasInvoice = "MAILER_ALIAS_INVOICE"
    case domain = "MAILER_DOMAIN"
    case replyTo = "MAILER_REPLY_TO"
    case invoiceJSON = "MAILER_INVOICE_JSON"
    case invoicePDF = "MAILER_INVOICE_PDF"
    case testEmail = "MAILER_TEST_EMAIL"
    case automationsEmail = "MAILER_AUTOMATIONS_EMAIL"
}
```

