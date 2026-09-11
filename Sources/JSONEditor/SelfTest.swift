import Foundation

/// 通过 `JSONEditor --selftest` 运行的核心逻辑自测
enum SelfTest {
    static func run() {
        var failures = 0

        func check(_ name: String, _ cond: Bool) {
            if cond {
                print("PASS  \(name)")
            } else {
                print("FAIL  \(name)")
                failures += 1
            }
        }

        // 1. 解析 + 序列化往返
        let sample = """
        {
          "name": "JSON Editor",
          "tags": ["a", "b"],
          "nested": { "x": 1, "y": [true, false, null] },
          "num": -1.5e+3
        }
        """
        do {
            var parser = JSONParser()
            let root = try parser.parse(sample)
            let pretty = JSONSerializer.serialize(root, pretty: true)
            var parser2 = JSONParser()
            let root2 = try parser2.parse(pretty)
            check("往返序列化一致", JSONSerializer.serialize(root2, pretty: true) == pretty)
            check("节点计数", countNodes(root) == countNodes(root2))
        } catch {
            check("解析示例成功", false)
        }

        // 2. 对象 key 顺序保留
        do {
            var parser = JSONParser()
            let root = try parser.parse("{\"z\":1,\"a\":2,\"m\":3}")
            check("key 顺序保留", JSONSerializer.serialize(root, pretty: false) == "{\"z\":1,\"a\":2,\"m\":3}")
        } catch {
            check("key 顺序保留", false)
        }

        // 3. 错误定位
        do {
            var parser = JSONParser()
            _ = try parser.parse("{\n  \"a\": 1,\n}")
            check("非法 JSON 应报错", false)
        } catch let e as JSONParseError {
            check("错误带行号 (line=3)", e.line == 3)
        } catch {
            check("错误类型为 JSONParseError", false)
        }

        // 4. 数字字面量校验
        check("数字 01 非法", !JSONParser.isValidNumberLiteral("01"))
        check("数字 -1.5e+3 合法", JSONParser.isValidNumberLiteral("-1.5e+3"))
        check("数字 0 合法", JSONParser.isValidNumberLiteral("0"))
        check("数字 1. 非法", !JSONParser.isValidNumberLiteral("1."))

        // 5. Unicode 转义（含代理对）
        do {
            var parser = JSONParser()
            let root = try parser.parse("\"\\u0041\\uD83D\\uDE00\"")
            check("Unicode 转义", root.text == "A\u{1F600}")
        } catch {
            check("Unicode 转义", false)
        }

        // 6. 转义字符往返
        do {
            var parser = JSONParser()
            let root = try parser.parse("\"a\\nb\\t\\\"c\\\\d\"")
            let out = JSONSerializer.serialize(root, pretty: false)
            check("转义字符往返", out == "\"a\\nb\\t\\\"c\\\\d\"")
        } catch {
            check("转义字符往返", false)
        }

        // 7. 路径生成
        do {
            var parser = JSONParser()
            let root = try parser.parse("{\"user\":{\"list\":[{\"id\":7}]}}")
            if let target = findNodeByText(root, "7"),
               let comps = pathToNode(target.id, in: root) {
                check("JSONPath 生成", jsonPathString(comps) == "$.user.list[0].id")
            } else {
                check("JSONPath 生成", false)
            }
        } catch {
            check("JSONPath 生成", false)
        }

        if failures > 0 {
            print("\(failures) 项自测失败")
            exit(1)
        }
        print("SELFTEST OK")
    }

    private static func findNodeByText(_ node: JSONNode, _ text: String) -> JSONNode? {
        if node.text == text && node.kind == .number { return node }
        for c in node.children {
            if let f = findNodeByText(c, text) { return f }
        }
        return nil
    }
}
