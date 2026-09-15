import Foundation

// MARK: - XLSX解析器
class XLSXParser {
    private let archive: Archive
    private var sharedStrings: [String] = []

    init(fileURL: URL) throws {
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw NSError(domain: "XLSXParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法打开XLSX文件"])
        }
        self.archive = archive
    }

    func parse() throws -> [String: [[String]]] {
        // 1. 解析共享字符串
        sharedStrings = try parseSharedStrings()

        // 2. 解析工作簿关系
        let relationships = try parseWorkbookRelationships()

        // 3. 解析工作簿获取工作表名称和rId
        let sheets = try parseWorkbook()

        // 4. 解析每个工作表
        var result: [String: [[String]]] = [:]
        for (name, rId) in sheets {
            if let path = relationships[rId] {
                let rows = try parseWorksheet(path: path)
                result[name] = rows
            }
        }

        return result
    }

    // MARK: - 读取ZIP中的文件
    private func readFile(path: String) throws -> Data {
        let entryPath = path.hasPrefix("xl/") ? path : "xl/" + path
        guard let entry = archive[entryPath] ?? archive[path] else {
            return Data()
        }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }

    // MARK: - 解析共享字符串
    private func parseSharedStrings() throws -> [String] {
        let data = try readFile(path: "xl/sharedStrings.xml")
        guard !data.isEmpty else { return [] }

        let parser = XMLParser(data: data)
        let delegate = SharedStringsParserDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    // MARK: - 解析工作簿关系
    private func parseWorkbookRelationships() throws -> [String: String] {
        let data = try readFile(path: "xl/_rels/workbook.xml.rels")
        guard !data.isEmpty else { return [:] }

        let parser = XMLParser(data: data)
        let delegate = RelationshipsParserDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.relationships
    }

    // MARK: - 解析工作簿
    private func parseWorkbook() throws -> [(name: String, rId: String)] {
        let data = try readFile(path: "xl/workbook.xml")
        guard !data.isEmpty else { return [] }

        let parser = XMLParser(data: data)
        let delegate = WorkbookParserDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.sheets
    }

    // MARK: - 解析工作表
    private func parseWorksheet(path: String) throws -> [[String]] {
        let data = try readFile(path: path)
        guard !data.isEmpty else { return [] }

        let parser = XMLParser(data: data)
        let delegate = WorksheetParserDelegate(sharedStrings: sharedStrings)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }
}

// MARK: - XMLParser Delegates

class SharedStringsParserDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var currentString = ""
    private var inT = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "t" {
            inT = true
            currentString = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inT {
            currentString += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            inT = false
        } else if elementName == "si" {
            strings.append(currentString)
        }
    }
}

class RelationshipsParserDelegate: NSObject, XMLParserDelegate {
    var relationships: [String: String] = [:]

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "Relationship", let id = attributeDict["Id"], let target = attributeDict["Target"] {
            relationships[id] = target
        }
    }
}

class WorkbookParserDelegate: NSObject, XMLParserDelegate {
    var sheets: [(name: String, rId: String)] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "sheet", let name = attributeDict["name"], let rId = attributeDict["r:id"] ?? attributeDict["id"] {
            sheets.append((name: name, rId: rId))
        }
    }
}

class WorksheetParserDelegate: NSObject, XMLParserDelegate {
    var rows: [[String]] = []
    private var currentRow: [String: String] = [:]
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var inV = false
    private var sharedStrings: [String]

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "row" {
            currentRow = [:]
        } else if elementName == "c" {
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
        } else if elementName == "v" {
            inV = true
            currentValue = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inV {
            currentValue += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" {
            inV = false
        } else if elementName == "c" {
            let colIndex = columnIndex(from: currentCellRef)
            var cellValue = currentValue
            // 共享字符串类型
            if currentCellType == "s", let idx = Int(currentValue), idx < sharedStrings.count {
                cellValue = sharedStrings[idx]
            }
            currentRow[colIndex] = cellValue
        } else if elementName == "row" {
            // 转换为有序数组
            if let maxCol = currentRow.keys.compactMap({ Int($0) }).max() {
                var rowArray: [String] = []
                for i in 0...maxCol {
                    rowArray.append(currentRow["\(i)"] ?? "")
                }
                rows.append(rowArray)
            } else {
                rows.append([])
            }
        }
    }

    // 将列引用（如A, B, AA）转换为索引
    private func columnIndex(from ref: String) -> String {
        let letters = ref.prefix { $0.isLetter }
        var index = 0
        for char in letters {
            index = index * 26 + (Int(char.uppercased().unicodeScalars.first!.value) - 64)
        }
        return "\(index - 1)"
    }
}
