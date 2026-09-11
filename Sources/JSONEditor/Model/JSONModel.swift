import Foundation

// MARK: - 节点模型

struct JSONNode: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case object, array, string, number, bool, null
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .object: return "对象"
            case .array: return "数组"
            case .string: return "字符串"
            case .number: return "数字"
            case .bool: return "布尔"
            case .null: return "空值"
            }
        }
    }

    var id: UUID = UUID()
    var key: String? = nil        // 仅对象子节点有 key
    var kind: Kind
    var text: String = ""         // string 内容 / number 原始字面量
    var boolValue: Bool = false
    var children: [JSONNode] = []

    var isContainer: Bool { kind == .object || kind == .array }

    init(kind: Kind, key: String? = nil, text: String = "", boolValue: Bool = false) {
        self.kind = kind
        self.key = key
        self.text = text
        self.boolValue = boolValue
    }
}

// MARK: - 解析错误

struct JSONParseError: Error, Equatable {
    let message: String
    let line: Int
    let column: Int
    let offset: Int
}

// MARK: - 保序 JSON 解析器（手写递归下降，保留对象 key 顺序，报错带行列）

struct JSONParser {
    private var scalars: [Unicode.Scalar] = []
    private var i = 0
    private var line = 1
    private var col = 1

    private static let numberPattern = try! NSRegularExpression(
        pattern: "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$"
    )

    static func isValidNumberLiteral(_ s: String) -> Bool {
        numberPattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    mutating func parse(_ text: String) throws -> JSONNode {
        scalars = Array(text.unicodeScalars)
        i = 0; line = 1; col = 1
        skipWhitespace()
        var node = try parseValue()
        node.key = nil
        skipWhitespace()
        if current != nil { throw err("JSON 结束后存在多余内容") }
        return node
    }

    private var current: Unicode.Scalar? { i < scalars.count ? scalars[i] : nil }

    private mutating func advance() {
        guard i < scalars.count else { return }
        if scalars[i] == "\n" { line += 1; col = 1 } else { col += 1 }
        i += 1
    }

    private func err(_ msg: String) -> JSONParseError {
        JSONParseError(message: msg, line: line, column: col, offset: i)
    }

    private mutating func skipWhitespace() {
        while let c = current, c == " " || c == "\t" || c == "\n" || c == "\r" || c.value == 0xFEFF { advance() }
    }

    private mutating func parseValue() throws -> JSONNode {
        guard let c = current else { throw err("内容意外结束") }
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return JSONNode(kind: .string, text: try parseString())
        case "t": try expectLiteral("true"); return JSONNode(kind: .bool, boolValue: true)
        case "f": try expectLiteral("false"); return JSONNode(kind: .bool)
        case "n": try expectLiteral("null"); return JSONNode(kind: .null)
        default:
            if c == "-" || (c >= "0" && c <= "9") { return try parseNumber() }
            throw err("无法识别的字符「\(c)」")
        }
    }

    private mutating func parseObject() throws -> JSONNode {
        advance() // {
        var node = JSONNode(kind: .object)
        skipWhitespace()
        if current == "}" { advance(); return node }
        while true {
            skipWhitespace()
            guard current == "\"" else { throw err("对象的键必须是字符串") }
            let key = try parseString()
            skipWhitespace()
            guard current == ":" else { throw err("缺少冒号 :") }
            advance()
            skipWhitespace()
            var child = try parseValue()
            child.key = key
            node.children.append(child)
            skipWhitespace()
            if current == "," { advance(); continue }
            if current == "}" { advance(); break }
            throw err("缺少逗号 , 或 }")
        }
        return node
    }

    private mutating func parseArray() throws -> JSONNode {
        advance() // [
        var node = JSONNode(kind: .array)
        skipWhitespace()
        if current == "]" { advance(); return node }
        while true {
            skipWhitespace()
            let child = try parseValue()
            node.children.append(child)
            skipWhitespace()
            if current == "," { advance(); continue }
            if current == "]" { advance(); break }
            throw err("缺少逗号 , 或 ]")
        }
        return node
    }

    private mutating func parseString() throws -> String {
        advance() // 开头的 "
        var result = String.UnicodeScalarView()
        while true {
            guard let c = current else { throw err("字符串未闭合") }
            if c == "\"" { advance(); break }
            if c == "\\" {
                advance()
                guard let e = current else { throw err("转义字符不完整") }
                switch e {
                case "\"": result.append("\""); advance()
                case "\\": result.append("\\"); advance()
                case "/": result.append("/"); advance()
                case "b": result.append("\u{08}"); advance()
                case "f": result.append("\u{0C}"); advance()
                case "n": result.append("\n"); advance()
                case "r": result.append("\r"); advance()
                case "t": result.append("\t"); advance()
                case "u":
                    advance() // u
                    var value = try readHex4()
                    if (0xD800...0xDBFF).contains(value) {
                        guard current == "\\" else { throw err("无效的 Unicode 代理对") }
                        advance()
                        guard current == "u" else { throw err("无效的 Unicode 代理对") }
                        advance()
                        let low = try readHex4()
                        guard (0xDC00...0xDFFF).contains(low) else { throw err("无效的 Unicode 代理对") }
                        value = 0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00)
                    }
                    guard let scalar = Unicode.Scalar(value) else { throw err("无效的 Unicode 码点") }
                    result.append(scalar)
                default:
                    throw err("无效的转义字符 \\\(e)")
                }
                continue
            }
            if c.value < 0x20 { throw err("字符串中包含非法控制字符") }
            result.append(c)
            advance()
        }
        return String(result)
    }

    private mutating func readHex4() throws -> UInt32 {
        var v: UInt32 = 0
        for _ in 0..<4 {
            guard let c = current, let d = hexDigit(c) else { throw err("无效的 Unicode 转义") }
            v = v * 16 + d
            advance()
        }
        return v
    }

    private func hexDigit(_ c: Unicode.Scalar) -> UInt32? {
        switch c {
        case "0"..."9": return c.value - 48
        case "a"..."f": return c.value - 87
        case "A"..."F": return c.value - 55
        default: return nil
        }
    }

    private mutating func parseNumber() throws -> JSONNode {
        let start = i
        if current == "-" { advance() }
        guard let c = current, c >= "0", c <= "9" else { throw err("无效的数字") }
        if c == "0" {
            advance()
        } else {
            while let d = current, d >= "0", d <= "9" { advance() }
        }
        if current == "." {
            advance()
            guard let d = current, d >= "0", d <= "9" else { throw err("小数点后缺少数字") }
            while let d = current, d >= "0", d <= "9" { advance() }
        }
        if current == "e" || current == "E" {
            advance()
            if current == "+" || current == "-" { advance() }
            guard let d = current, d >= "0", d <= "9" else { throw err("指数部分缺少数字") }
            while let d = current, d >= "0", d <= "9" { advance() }
        }
        let s = scalars[start..<i].reduce(into: "") { $0.unicodeScalars.append($1) }
        return JSONNode(kind: .number, text: s)
    }

    private mutating func expectLiteral(_ lit: String) throws {
        for scalar in lit.unicodeScalars {
            guard current == scalar else { throw err("无效的字面值") }
            advance()
        }
    }
}

// MARK: - 序列化

enum JSONSerializer {
    static func serialize(_ node: JSONNode, pretty: Bool) -> String {
        pretty ? prettyPrint(node, level: 0) : compact(node)
    }

    static func escape(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if c.value < 0x20 {
                    out += String(format: "\\u%04x", c.value)
                } else {
                    out.unicodeScalars.append(c)
                }
            }
        }
        out += "\""
        return out
    }

    private static func scalarString(_ node: JSONNode) -> String {
        switch node.kind {
        case .string: return escape(node.text)
        case .number: return node.text.isEmpty ? "0" : node.text
        case .bool: return node.boolValue ? "true" : "false"
        case .null: return "null"
        case .object: return "{}"
        case .array: return "[]"
        }
    }

    private static func compact(_ node: JSONNode) -> String {
        switch node.kind {
        case .object:
            return "{" + node.children.map { escape($0.key ?? "") + ":" + compact($0) }.joined(separator: ",") + "}"
        case .array:
            return "[" + node.children.map { compact($0) }.joined(separator: ",") + "]"
        default:
            return scalarString(node)
        }
    }

    private static func prettyPrint(_ node: JSONNode, level: Int) -> String {
        let indent = String(repeating: "  ", count: level)
        let childIndent = String(repeating: "  ", count: level + 1)
        switch node.kind {
        case .object:
            if node.children.isEmpty { return "{}" }
            let items = node.children.map {
                childIndent + escape($0.key ?? "") + ": " + prettyPrint($0, level: level + 1)
            }
            return "{\n" + items.joined(separator: ",\n") + "\n" + indent + "}"
        case .array:
            if node.children.isEmpty { return "[]" }
            let items = node.children.map { childIndent + prettyPrint($0, level: level + 1) }
            return "[\n" + items.joined(separator: ",\n") + "\n" + indent + "]"
        default:
            return scalarString(node)
        }
    }
}

// MARK: - 树查找与路径

enum JSONPathComponent: Equatable {
    case key(String)
    case index(Int)
}

func findNode(_ id: UUID, in node: JSONNode) -> JSONNode? {
    if node.id == id { return node }
    for c in node.children {
        if let f = findNode(id, in: c) { return f }
    }
    return nil
}

func parentNode(of id: UUID, in node: JSONNode) -> JSONNode? {
    for c in node.children {
        if c.id == id { return node }
        if let p = parentNode(of: id, in: c) { return p }
    }
    return nil
}

/// 从根到目标节点的 id 链（含根与目标）
func idPath(to id: UUID, in node: JSONNode) -> [UUID]? {
    if node.id == id { return [node.id] }
    for c in node.children {
        if var p = idPath(to: id, in: c) {
            p.insert(node.id, at: 0)
            return p
        }
    }
    return nil
}

func pathToNode(_ id: UUID, in node: JSONNode) -> [JSONPathComponent]? {
    if node.id == id { return [] }
    for (idx, c) in node.children.enumerated() {
        let comp: JSONPathComponent = node.kind == .array ? .index(idx) : .key(c.key ?? "")
        if c.id == id { return [comp] }
        if var p = pathToNode(id, in: c) {
            p.insert(comp, at: 0)
            return p
        }
    }
    return nil
}

func jsonPathString(_ comps: [JSONPathComponent]) -> String {
    var s = "$"
    for c in comps {
        switch c {
        case .index(let i):
            s += "[\(i)]"
        case .key(let k):
            let simple = !k.isEmpty && k.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" } && !(k.first?.isNumber ?? false)
            s += simple ? ".\(k)" : "[\"\(k)\"]"
        }
    }
    return s
}

func countNodes(_ n: JSONNode) -> Int {
    1 + n.children.reduce(0) { $0 + countNodes($1) }
}

func maxDepth(_ n: JSONNode) -> Int {
    n.children.isEmpty ? 1 : 1 + (n.children.map(maxDepth).max() ?? 0)
}
