import Foundation
import ArgumentParser
import plate
import PDFKit
import MacActor

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
    case contacts = "NUMBERS_CONTACTS"
}

enum Script {
    case open
    case setInvoice
    case debug
    case debugCells
    case exportCSV
    case exportPDF
    case close
    case ghostty
    case responder
    case map
}

struct NumbersData {
    let sheet: String
    let table: String
    let row: String
    let column: String
    let value: String
}

struct Arguments {
    let src: String
    let dst: String
    let inv: String
    let data: NumbersData
}

struct NumbersParser: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "numbers-parser",
        abstract: "Parse contents of a numbers file",
        version: "1.0.0",
        subcommands: [Export.self, Extract.self, Parse.self, Invoice.self, Read.self, Map.self, ParseContacts.self],
        defaultSubcommand: Parse.self
    )
}

func sanitize(_ path: String) -> String {
    var sanitizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Remove trailing ":" if it exists
    if sanitizedPath.hasSuffix(":") {
        sanitizedPath.removeLast()
    }
    
    return sanitizedPath
}

func script(_ type: Script,_ arguments: Arguments) -> String {
    switch type {
        case .open:
            return """
            set numbersFilePath to POSIX file "\(arguments.src)" as alias

            tell application "Numbers"
                activate
                open numbersFilePath
            end tell
            """
        case .debug:
            return """
            tell application "Numbers"
                activate
                tell document 1
                    -- Debug: List all sheets
                    set sheetList to ""
                    repeat with i from 1 to count of sheets
                        set sheetList to sheetList & i & ": " & name of sheet i & "\\n"
                    end repeat
                    display dialog "Sheets:\\n" & sheetList
                    
                    -- Check if the requested sheet exists
                    if \(arguments.data.sheet) > (count of sheets) then
                        display dialog "Error: Sheet index \(arguments.data.sheet) is out of bounds."
                        return
                    end if
                    
                    tell sheet \(arguments.data.sheet)
                        -- Debug: List all tables in the sheet
                        set tableList to ""
                        repeat with i from 1 to count of tables
                            set tableList to tableList & i & ": " & name of table i & "\\n"
                        end repeat
                        display dialog "Tables in Sheet \(arguments.data.sheet):\\n" & tableList
                        
                        -- Verify if the requested table exists
                        set tableExists to false
                        repeat with i from 1 to count of tables
                            if name of table i is "\(arguments.data.table)" then
                                set tableExists to true
                            end if
                        end repeat
                        
                        if not tableExists then
                            display dialog "Error: Table '\(arguments.data.table)' not found in sheet \(arguments.data.sheet)."
                            return
                        end tell
                    end tell
                end tell
            end tell
            """
        case .debugCells:
            return """
            tell application "Numbers"
                activate
                tell document 1
                    tell sheet 12 -- Replace with actual sheet index if necessary
                        tell table "Invoice Selection" -- Replace with actual table name if necessary
                            set debugMsg to "Debugging Table: Invoice Selection\n"

                            try
                                set cell1 to value of cell 1 of row 1
                                set debugMsg to debugMsg & "Row 1, Column 1: " & cell1 & "\n"
                            on error
                                set debugMsg to debugMsg & "Row 1, Column 1: ERROR\n"
                            end try

                            try
                                set cell2 to value of cell 2 of row 1
                                set debugMsg to debugMsg & "Row 1, Column 2: " & cell2 & "\n"
                            on error
                                set debugMsg to debugMsg & "Row 1, Column 2: ERROR\n"
                            end try

                            display dialog debugMsg
                        end tell
                    end tell
                end tell
            end tell
            """
        case .setInvoice:
            return """
            tell application "Numbers"
                activate
                    tell document 1
                        tell sheet \(arguments.data.sheet)
                            tell table "\(arguments.data.table)"
                                set the value of cell \(arguments.data.column) of row \(arguments.data.row) to \(arguments.data.value)
                            end tell
                        end tell
                    end tell
            end tell
            """
        case .exportCSV:
            return """
            set exportFilePath to POSIX file "\(arguments.dst)"
            set exportPDFPath to POSIX file "\(arguments.inv)"

            tell application "Numbers"
                activate

                tell document 1
                    export to exportFilePath as CSV
                end tell
            end tell
            """
        case .exportPDF:
            return """
            set exportPDFPath to POSIX file "\(arguments.inv)"

            tell application "Numbers"
                activate

                tell document 1
                    export to exportPDFPath as PDF
                end tell
            end tell
            """
        case .ghostty:
            return """
            tell application "Ghostty"
                activate
            end tell
            """
        case .responder:
            return """
            tell application "Responder"
                activate
            end tell
            """
        case .close:
            return """
            tell application "Numbers"
                activate

                tell document 1
                    close
                end tell
            end tell
            """
        case .map:
            return """
            tell application "Numbers"
                activate
                tell document 1
                    set result to "Sheet and Table Overview:\n"
                    repeat with sheetIndex from 1 to count of sheets
                        set currentSheet to sheet sheetIndex
                        set sheetName to name of currentSheet
                        set result to result & "Sheet " & sheetIndex & ": " & sheetName & "\n"

                        repeat with tableIndex from 1 to count of tables of currentSheet
                            set currentTable to table tableIndex of currentSheet
                            set tableName to name of currentTable
                            set result to result & "  Table " & tableIndex & ": " & tableName & "\n"
                        end repeat
                    end repeat
                    display dialog result
                end tell
            end tell
            """
    }
}

func removeExistingCSV(_ path: String = environment(Environment.destination.rawValue)) {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: path) {
        do {
            try fileManager.removeItem(atPath: path)
            print("Deleted existing directory: \(path)")
        } catch {
            print("Failed to delete existing directory: \(error)")
        }
    }
}

func runOsascriptProcess(_ script: String) {
    let process = Process()
    process.launchPath = "/usr/bin/osascript"
    process.arguments = ["-e", script]
    
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("Failed to execute AppleScript: \(error)")
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Exports .csv from .numbers file"
    )

    @Option(name: .shortAndLong, help: "source file (.numbers) path")
    var source: String = environment(Environment.source.rawValue)

    @Option(name: .shortAndLong, help: "SMTP username")
    var destination: String = environment(Environment.destination.rawValue)

    @Option(name: .shortAndLong, help: "Raw invoice output path")
    var pdfRaw: String = environment(Environment.invoiceRaw.rawValue)

    @Option(name: .shortAndLong, help: "Close Numbers after rendering")
    var close: Bool = false

    @Flag(name: .shortAndLong, help: "Adjust the invoice id before rendering")
    var adjustBeforeExporting: Bool = false

    @Option(name: .shortAndLong, help: "Sheet to adjust (requires -a, --adjust-before-exporting)")
    var sheet: String = environment(Environment.sheet.rawValue)

    @Option(name: .shortAndLong, help: "Table to adjust (requires -a, --adjust-before-exporting)")
    var table: String = environment(Environment.table.rawValue)

    @Option(name: .shortAndLong, help: "Row of cell to adjust (requires -a, --adjust-before-exporting)")
    var row: String = environment(Environment.row.rawValue)

    @Option(name: .shortAndLong, help: "Column of cell to adjust (requires -a, --adjust-before-exporting)")
    var column: String = environment(Environment.column.rawValue)

    @Option(name: .shortAndLong, help: "Value to adjust selected cell to (requires -a, --adjust-before-exporting)")
    var value: String = ""

    @Flag(name: .shortAndLong, help: "Return to Responder instead of Ghostty")
    var responder: Bool = false

    func run() {
        print("Converting \(source) → \(destination)")
        let data = NumbersData(sheet: sheet, table: table, row: row, column: column, value: value)

        runAppleScript(source: source, destination: destination, invoice: pdfRaw, adjust: adjustBeforeExporting, data: data, close: close, returnToResponder: responder)
        print("Export complete.")

    }

    func runAppleScript(source: String, destination: String, invoice: String, adjust: Bool, data: NumbersData, close: Bool, returnToResponder: Bool) {
        let src = sanitize(source)
        let dst = sanitize(destination)
        let inv = sanitize(invoice)

        let args = Arguments(src: src, dst: dst, inv: inv, data: data)
        
        let open = script(.open, args)
        let setInvoice = script(.setInvoice, args)
        // let debug = script(.debug, args)
        // let debugCells = script(.debugCells, args)
        let csv = script(.exportCSV, args)
        let pdf = script(.exportPDF, args)
        let closeOp = script(.close, args)
        let ghostty = script(.ghostty, args)
        let responder = script(.responder, args)

        runOsascriptProcess(open)
        if adjust {
            print("adjust target hit...")

            // print()
            // print("running debug...")
            // runOsascriptProcess(debug)
            // runOsascriptProcess(debugCells)

            print("trying to set: ")
            print("    sheet: \(args.data.sheet)")
            print("    table: \(args.data.table)")
            print("    row: \(args.data.row)")
            print("    column: \(args.data.column)")
            print("    value: \(args.data.value)")
            print("script")
            print(setInvoice)

            runOsascriptProcess(setInvoice)
        }
        removeExistingCSV()
        runOsascriptProcess(csv)
        runOsascriptProcess(pdf)
        if returnToResponder {
            runOsascriptProcess(responder)
        } else {
            runOsascriptProcess(ghostty)
        }
        if close {
            runOsascriptProcess(closeOp)
        }
    }
}

struct Map: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "map",
        abstract: "List all sheets and their tables"
    )

    @Option(name: .shortAndLong, help: "Path to the .numbers source file")
    var source: String = environment(Environment.source.rawValue)

    func run() {
        let sanitizedSource = sanitize(source)
        let actor = NumbersActor()

        let vars = AppleScriptVariables(filePath: source)

        print("Activating Numbers and mapping sheets/tables...")

        _ = actor.activate()
        _ = actor.openDocument(filePath: sanitizedSource)

        let result = actor.mapSheetsAndTables(vars)

        switch result {
        case .success:
            print("Map script executed successfully.")
        case .failure(let error):
            print("Failed to map sheets/tables: \(error)")
        }
    }
}

struct Extract: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extracts values from a specific rendered .csv file"
    )
    
    @Option(name: .shortAndLong, help: "CSV file to parse")
    var csvPath: String = environment(Environment.target.rawValue)

    @Option(name: .shortAndLong, help: "Raw JSON output file path")
    var rawJsonPath: String = environment(Environment.parsed.rawValue)

    @Option(name: .shortAndLong, help: "Reparsed JSON output file path")
    var reparsedJsonPath: String = environment(Environment.reparsed.rawValue)

    func run() {
        print("Extracting data from CSV file: \(csvPath)")

        guard let sheetData = parseRawCSV(filePath: csvPath) else {
            print("Failed to parse \(csvPath)")
            return
        }

        saveJSON(data: sheetData, to: rawJsonPath)
        print("Parsed data saved to \(rawJsonPath)")

        guard let reparsedJSON = reparseJSON(filePath: rawJsonPath) else {
            print("Failed to parse \(csvPath)")
            return
        }

        saveReparsedJSON(data: reparsedJSON, to: reparsedJsonPath)
        print("Reparsed data saved to \(rawJsonPath)")
    }

    // for seeing what the table becomes in raw json (inadequate key:value pairs)
    func parseRawCSV(filePath: String) -> [[String: String]]? {
        guard let fileContents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("Failed to read CSV file: \(filePath)")
            return nil
        }

        let lines = fileContents.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let headers = lines.first?.components(separatedBy: ";") else {
            print("No headers found in \(filePath)")
            return nil
        }

        var rows: [[String: String]] = []

        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ";")
            var rowDict: [String: String] = [:]

            for (index, value) in values.enumerated() where index < headers.count {
                rowDict[headers[index]] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            rows.append(rowDict)
        }

        return rows
    }
    
    func reparseJSON(filePath: String) -> [String: [String: String]]? {
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("Failed to read JSON file: \(filePath)")
            return nil
        }

        guard let rawJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: String]] else {
            print("Failed to decode JSON structure in \(filePath)")
            return nil
        }

        var invoiceData: [String: String] = [:]

        for entry in rawJson {
            guard let keyColumn = entry["Invoice ID"],
                  let valueColumn = entry.first(where: { $0.key.hasPrefix("RN") })?.value
            else {
                continue
            }

            let cleanedKey = keyColumn.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedValue = valueColumn.trimmingCharacters(in: .whitespacesAndNewlines)

            // Directly store key-value pairs without nesting inside another dictionary
            invoiceData[cleanedKey] = cleanedValue
        }

        return ["Invoices": invoiceData]
    }

    // processing csv into key:value pairs properly
    // func reparseJSON(filePath: String) -> [String: [[String: [String: String]]]]? {
    //     guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
    //         print("Failed to read JSON file: \(filePath)")
    //         return nil
    //     }

    //     guard let rawJson = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: String]] else {
    //         print("Failed to decode JSON structure in \(filePath)")
    //         return nil
    //     }

    //     var invoiceData: [String: [[String: [String: String]]]] = ["Invoices": []]
    //     var orderedInvoices: [[String: [String: String]]] = []

    //     for (_ , entry) in rawJson.enumerated() {
    //         for (leftColumn, rightColumn) in entry {
    //             let keyValue = rightColumn.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    //             if keyValue.count == 2, !keyValue[0].isEmpty, !keyValue[1].isEmpty {
    //                 let invoiceID = leftColumn.components(separatedBy: ";").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"

    //                 let key = keyValue[0]
    //                 let value = keyValue[1]

    //                 if let index = orderedInvoices.firstIndex(where: { $0[invoiceID] != nil }) {
    //                     orderedInvoices[index][invoiceID]?[key] = value
    //                 } else {
    //                     orderedInvoices.append([invoiceID: [key: value]])
    //                 }
    //             }
    //         }
    //     }

    //     invoiceData["Invoices"] = orderedInvoices
    //     return invoiceData
    // }

    func saveJSON(data: [[String: String]], to filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
        } catch {
            print("Failed to save JSON: \(error)")
        }
    }

    func saveReparsedJSON(data: [String: [String: Any]], to filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted])
            try jsonData.write(to: fileURL)
            print("Structured JSON successfully saved to \(filePath)")
        } catch {
            print("Failed to save structured JSON: \(error)")
        }
    }

    func extractContactsTable() {
        print("Extracting Contacts table from CSV: \(csvPath)")

        guard let sheetData = parseRawCSV(filePath: csvPath) else {
            print("Failed to parse \(csvPath)")
            return
        }

        // You can adapt this filter if you only want to include rows that contain e.g., a name or email
        let filteredData = sheetData.filter { !$0.isEmpty }

        let contactsOutputPath = reparsedJsonPath.replacingOccurrences(of: ".json", with: "-contacts.json")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: filteredData, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: contactsOutputPath))
            print("Extracted contacts saved to \(contactsOutputPath)")
        } catch {
            print("Failed to save contacts JSON: \(error)")
        }
    }
}

struct Invoice: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "invoice",
        abstract: "Filters specific pages from the exported invoice PDF"
    )

    @Option(name: .shortAndLong, help: "Raw exported invoice PDF")
    var invoiceRaw: String = environment(Environment.invoiceRaw.rawValue)

    @Option(name: .shortAndLong, help: "Filtered output invoice PDF")
    var invoiceOut: String = environment(Environment.invoice.rawValue)


    func run() {
        print("Filtering specific pages from \(invoiceRaw)...")

        let selectedPages = [12, 13] // Example: Extract pages 13 & 14 (zero-based index)
        
        let rawURL = URL(fileURLWithPath: invoiceRaw)
        
        guard FileManager.default.fileExists(atPath: rawURL.path) else {
            print("Raw invoice PDF does not exist at: \(invoiceRaw)")
            return
        }

        guard let pdfDocument = PDFDocument(url: rawURL) else {
            print("Failed to open raw invoice PDF: \(invoiceRaw)")
            return
        }

        print("Loaded PDF with \(pdfDocument.pageCount) pages.")

        let newPDF = PDFDocument()
        
        for (index, pageIndex) in selectedPages.enumerated() {
            if let page = pdfDocument.page(at: pageIndex) {
                print("Adding page \(pageIndex + 1) to new PDF.")
                newPDF.insert(page, at: index)
            } else {
                print("Page \(pageIndex + 1) does not exist in the PDF.")
            }
        }

        // Save the new PDF
        if let outputData = newPDF.dataRepresentation() {
            do {
                try outputData.write(to: URL(fileURLWithPath: invoiceOut))
                print("Filtered invoice saved to \(invoiceOut)")
            } catch {
                print("Failed to write filtered PDF: \(error)")
            }
        } else {
            print("Failed to generate filtered PDF.")
        }
    }
}

struct Parse: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "parse",
        abstract: "Exports and then parses the CSV file"
    )

    @Option(name: .shortAndLong, help: "Close Numbers after rendering")
    var close: Bool = false

    @Flag(name: .shortAndLong, help: "Adjust the invoice id before rendering")
    var adjustBeforeExporting: Bool = false

    @Option(name: .shortAndLong, help: "Sheet to adjust (requires -a, --adjust-before-exporting)")
    var sheet: String = environment(Environment.sheet.rawValue)

    @Option(name: .shortAndLong, help: "Table to adjust (requires -a, --adjust-before-exporting)")
    var table: String = environment(Environment.table.rawValue)

    @Option(name: .shortAndLong, help: "Row of cell to adjust (requires -a, --adjust-before-exporting)")
    var row: String = environment(Environment.row.rawValue)

    @Option(name: .shortAndLong, help: "Column of cell to adjust (requires -a, --adjust-before-exporting)")
    var column: String = environment(Environment.column.rawValue)

    @Option(name: .shortAndLong, help: "Value to adjust selected cell to (requires -a, --adjust-before-exporting)")
    var value: String

    @Flag(name: .shortAndLong, help: "Return to Responder instead of Ghostty")
    var responder: Bool = false

    func run() {
        do {
            print("Running Export...")
            var exportArgs = ["--close", "\(close)"]

            if adjustBeforeExporting {
                exportArgs.append("--adjust-before-exporting")
                
                exportArgs.append(contentsOf: ["--sheet", sheet])
                exportArgs.append(contentsOf: ["--table", table])
                exportArgs.append(contentsOf: ["--row", row]) 
                exportArgs.append(contentsOf: ["--column", column]) 
                exportArgs.append(contentsOf: ["--value", value]) 
            }

            if responder {
                exportArgs.append("--responder")
            }

            print("Export args:")
            print(exportArgs)

            var export = try Export.parseAsRoot(exportArgs)
            try export.run()

            print("Running Invoice...")
            var invoice = try Invoice.parseAsRoot([]) 
            try invoice.run()

            print("Running Extract...")
            var extract = try Extract.parseAsRoot([])
            try extract.run()
        } catch {
            print("Error running commands: \(error)")
        }
    }
}

struct Read: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "read",
        abstract: "Read last parsed values from JSON"
    )

    func run() {
        do {
            let json = environment(Environment.reparsed.rawValue)

            let jsonData = try Data(contentsOf: URL(fileURLWithPath: json))
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])

            if let jsonString = String(data: try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted), encoding: .utf8) {
                print(jsonString)
            } else {
                print("Failed to convert JSON to string.")
            }
        } catch {
            print("Error reading JSON file: \(error)")
        }
    }
}

struct ParseContacts: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "parse-contacts",
        abstract: "Exports and then parses the 'contacts' table from Sheet 7 into JSON"
    )

    func run() throws {
        var export = try Export.parseAsRoot([])
        try export.run()

        let basePath = environment(Environment.destination.rawValue)
        let contactsCSV = basePath + "/Contacts-contacts.csv"
    
        // output
        let contactsJSONPath = environment(Environment.contacts.rawValue)

        json(contactsCSV, contactsJSONPath)
    }

    func json(_ input: String, _ output: String) {
        do {
            let csvContent = try String(contentsOfFile: input, encoding: .utf8)
            let lines = csvContent.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            guard let headerLine = lines.first else {
                print("No header found in CSV.")
                return
            }

            let headers = headerLine.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let dataRows = lines.dropFirst()

            let rows: [[String: String]] = dataRows.map { line in
                let values = line.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return Dictionary(uniqueKeysWithValues: zip(headers, values))
            }

            let jsonData = try JSONSerialization.data(withJSONObject: rows, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: output))
            print("Contacts JSON written to \(output)")
        } catch {
            print("Failed to parse contacts CSV: \(error)")
        }
    }
}

// struct Init: ParsableCommand {
//     static let configuration = CommandConfiguration(
//         commandName: "init",
//         abstract: "Initialization helper"
//     )

//     func run() {
//         do {
//         } catch {
//         }
//     }
// }

NumbersParser.main()
