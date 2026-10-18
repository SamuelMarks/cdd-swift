import CDDSwift
import XCTest

final class ArazzoExpressionTests: XCTestCase {
    func testEvaluateUrlMethodStatusCode() throws {
        var context = ArazzoExecutionContext()
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$url", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$method", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$statusCode", in: context))

        context.url = "https://api.example.com/v1"
        context.method = "POST"
        context.statusCode = 201

        let url = try ArazzoExpressionEvaluator.evaluate(expression: "$url", in: context)
        XCTAssertEqual(url.value as? String, "https://api.example.com/v1")

        let method = try ArazzoExpressionEvaluator.evaluate(expression: "$method", in: context)
        XCTAssertEqual(method.value as? String, "POST")

        let code = try ArazzoExpressionEvaluator.evaluate(expression: "$statusCode", in: context)
        XCTAssertEqual(code.value as? Int, 201)
    }

    func testEvaluateRequestParts() throws {
        var context = ArazzoExecutionContext()
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$request.header.Authorization", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$request.query.filter", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$request.path.userId", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$request.body", in: context))

        context.requestHeaders = ["Authorization": "Bearer token123"]
        context.requestQuery = ["filter": "active"]
        context.requestPath = ["userId": "u42"]
        context.requestBody = AnyCodable(["user": ["id": 42, "name": "Alice"]])

        let header = try ArazzoExpressionEvaluator.evaluate(expression: "$request.header.Authorization", in: context)
        XCTAssertEqual(header.value as? String, "Bearer token123")

        let query = try ArazzoExpressionEvaluator.evaluate(expression: "$request.query.filter", in: context)
        XCTAssertEqual(query.value as? String, "active")

        let path = try ArazzoExpressionEvaluator.evaluate(expression: "$request.path.userId", in: context)
        XCTAssertEqual(path.value as? String, "u42")

        let wholeBody = try ArazzoExpressionEvaluator.evaluate(expression: "$request.body", in: context)
        XCTAssertNotNil(wholeBody.value)

        let bodyWithoutHash = try ArazzoExpressionEvaluator.evaluate(expression: "$request.bodyWithoutHash", in: context)
        XCTAssertNotNil(bodyWithoutHash.value)

        let bodyPointer = try ArazzoExpressionEvaluator.evaluate(expression: "$request.body#/user/name", in: context)
        XCTAssertEqual(bodyPointer.value as? String, "Alice")

        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$request.body#/nonexistent", in: context))
    }

    func testEvaluateResponseParts() throws {
        var context = ArazzoExecutionContext()
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$response.header.ETag", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$response.body", in: context))

        context.responseHeaders = ["ETag": "w12345"]
        context.responseBody = AnyCodable(["order": ["status": "completed", "total": 99.5]])

        let header = try ArazzoExpressionEvaluator.evaluate(expression: "$response.header.ETag", in: context)
        XCTAssertEqual(header.value as? String, "w12345")

        let wholeBody = try ArazzoExpressionEvaluator.evaluate(expression: "$response.body", in: context)
        XCTAssertNotNil(wholeBody.value)

        let bodyWithoutHash = try ArazzoExpressionEvaluator.evaluate(expression: "$response.bodyWithoutHash", in: context)
        XCTAssertNotNil(bodyWithoutHash.value)

        let bodyProp = try ArazzoExpressionEvaluator.evaluate(expression: "$response.body#/order/status", in: context)
        XCTAssertEqual(bodyProp.value as? String, "completed")

        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$response.body#/order/missing", in: context))
    }

    func testEvaluateInputsOutputsStepsAndSourceDescriptions() throws {
        var context = ArazzoExecutionContext()
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$inputs.id", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$outputs.finalResult", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$steps.s1.outputs.token", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$steps.s1.bad", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$sourceDescriptions.petApi.url", in: context))
        XCTAssertThrowsError(try ArazzoExpressionEvaluator.evaluate(expression: "$sourceDescriptions.bad", in: context))

        context.inputs = ["id": AnyCodable("in-123")]
        context.outputs = ["finalResult": AnyCodable("out-456")]
        context.steps = ["s1": ["token": AnyCodable("step-tok")]]
        context.sourceDescriptions = ["petApi": "https://api.petstore.com"]

        let inVal = try ArazzoExpressionEvaluator.evaluate(expression: "$inputs.id", in: context)
        XCTAssertEqual(inVal.value as? String, "in-123")

        let outVal = try ArazzoExpressionEvaluator.evaluate(expression: "$outputs.finalResult", in: context)
        XCTAssertEqual(outVal.value as? String, "out-456")

        let stepVal = try ArazzoExpressionEvaluator.evaluate(expression: "$steps.s1.outputs.token", in: context)
        XCTAssertEqual(stepVal.value as? String, "step-tok")

        let sourceUrl = try ArazzoExpressionEvaluator.evaluate(expression: "$sourceDescriptions.petApi.url", in: context)
        XCTAssertEqual(sourceUrl.value as? String, "https://api.petstore.com")

        let literal = try ArazzoExpressionEvaluator.evaluate(expression: "literalValue", in: context)
        XCTAssertEqual(literal.value as? String, "literalValue")
    }

    func testEvaluateJsonPointer() {
        let data = AnyCodable([
            "items": [
                ["name": "item1", "val~key": "val1"],
                ["name": "item2", "slash/key": "val2"]
            ],
            "empty": ""
        ])

        XCTAssertTrue(ArazzoExpressionEvaluator.evaluateJsonPointer("", on: data)?.value is [String: Any])
        XCTAssertTrue(ArazzoExpressionEvaluator.evaluateJsonPointer("/", on: data)?.value is [String: Any])
        XCTAssertEqual(ArazzoExpressionEvaluator.evaluateJsonPointer("/items/0/name", on: data)?.value as? String, "item1")
        XCTAssertEqual(ArazzoExpressionEvaluator.evaluateJsonPointer("/items/0/val~0key", on: data)?.value as? String, "val1")
        XCTAssertEqual(ArazzoExpressionEvaluator.evaluateJsonPointer("/items/1/slash~1key", on: data)?.value as? String, "val2")
        XCTAssertNil(ArazzoExpressionEvaluator.evaluateJsonPointer("/items/99", on: data))
        XCTAssertNil(ArazzoExpressionEvaluator.evaluateJsonPointer("/items/notanint", on: data))
        XCTAssertNil(ArazzoExpressionEvaluator.evaluateJsonPointer("/items/0/name/deep", on: data))

        let anyCodableDictData = AnyCodable(["nested": AnyCodable("val")])
        XCTAssertEqual(ArazzoExpressionEvaluator.evaluateJsonPointer("/nested", on: anyCodableDictData)?.value as? String, "val")
        XCTAssertNil(ArazzoExpressionEvaluator.evaluateJsonPointer("/missing", on: anyCodableDictData))

        let anyCodableArrData = AnyCodable([AnyCodable("first"), AnyCodable("second")])
        XCTAssertEqual(ArazzoExpressionEvaluator.evaluateJsonPointer("/0", on: anyCodableArrData)?.value as? String, "first")
        XCTAssertNil(ArazzoExpressionEvaluator.evaluateJsonPointer("/99", on: anyCodableArrData))
    }

    func testEvaluateCriterion() throws {
        var context = ArazzoExecutionContext()
        context.statusCode = 200
        context.responseBody = AnyCodable([
            "status": "success",
            "count": 10,
            "rate": 4.5,
            "strNum": "42",
            "enabled": true
        ])

        let statusCrit = ArazzoCriterion(context: "$statusCode", condition: "== 200", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(statusCrit, in: context))

        let statusCritNe = ArazzoCriterion(context: "$statusCode", condition: "!= 400", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(statusCritNe, in: context))

        let countCritLte = ArazzoCriterion(context: "$response.body#/count", condition: "<= 15", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(countCritLte, in: context))

        let countCritLt = ArazzoCriterion(context: "$response.body#/count", condition: "< 20", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(countCritLt, in: context))

        let countCritGte = ArazzoCriterion(context: "$response.body#/count", condition: ">= 5", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(countCritGte, in: context))

        let countCritGt = ArazzoCriterion(context: "$response.body#/count", condition: "> 5", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(countCritGt, in: context))

        let dblCrit = ArazzoCriterion(context: "$response.body#/rate", condition: "4.5", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(dblCrit, in: context))

        let dblGtCrit = ArazzoCriterion(context: "$response.body#/rate", condition: "> 4.0", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(dblGtCrit, in: context))

        let strNumCrit = ArazzoCriterion(context: "$response.body#/strNum", condition: "> 40", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(strNumCrit, in: context))

        let strCrit = ArazzoCriterion(context: "$response.body#/status", condition: "\"success\"", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(strCrit, in: context))

        let boolCrit = ArazzoCriterion(context: "$response.body#/enabled", condition: "true", type: .simple)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(boolCrit, in: context))

        let regexCrit = ArazzoCriterion(context: "$response.body#/status", condition: "/^succ[a-z]+$/", type: .regex)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(regexCrit, in: context))

        let regexFailCrit = ArazzoCriterion(context: "$response.body#/status", condition: "^[0-9]+$", type: .regex)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(regexFailCrit, in: context))

        let badRegexCrit = ArazzoCriterion(context: "$response.body#/status", condition: "[invalid(", type: .regex)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(badRegexCrit, in: context))

        let invalidCompareCrit = ArazzoCriterion(context: "$response.body#/status", condition: "> notanumber", type: .simple)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(invalidCompareCrit, in: context))

        let invalidLtCrit = ArazzoCriterion(context: "$response.body#/status", condition: "< notanumber", type: .simple)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(invalidLtCrit, in: context))

        let invalidLteCrit = ArazzoCriterion(context: "$response.body#/status", condition: "<= notanumber", type: .simple)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(invalidLteCrit, in: context))

        let invalidGteCrit = ArazzoCriterion(context: "$response.body#/status", condition: ">= notanumber", type: .simple)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(invalidGteCrit, in: context))

        let noneTypeCrit = ArazzoCriterion(context: "$statusCode", condition: "200", type: nil)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(noneTypeCrit, in: context))

        let jsonpathCrit = ArazzoCriterion(context: "$statusCode", condition: "200", type: .jsonpath)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(jsonpathCrit, in: context))

        let xpathCrit = ArazzoCriterion(context: "$statusCode", condition: "200", type: .xpath)
        XCTAssertTrue(try ArazzoExpressionEvaluator.evaluateCriterion(xpathCrit, in: context))

        let boolNumCompareCrit = ArazzoCriterion(context: "$response.body#/enabled", condition: "> 10", type: .simple)
        XCTAssertFalse(try ArazzoExpressionEvaluator.evaluateCriterion(boolNumCompareCrit, in: context))
    }

    func testApplyReplacement() {
        let original = AnyCodable([
            "user": [
                "name": "Bob",
                "roles": ["guest", "viewer"],
                "matrix": [["a", "b"], ["c", "d"]]
            ]
        ])

        let rep1 = ArazzoPayloadReplacement(target: "#/user/name", targetSelectorType: .jsonpointer, value: AnyCodable("Robert"))
        let updated1 = ArazzoExpressionEvaluator.applyReplacement(rep1, to: original)
        let nameVal = ArazzoExpressionEvaluator.evaluateJsonPointer("/user/name", on: updated1)
        XCTAssertEqual(nameVal?.value as? String, "Robert")

        let repOutOfBounds = ArazzoPayloadReplacement(target: "/user/roles/999", targetSelectorType: .jsonpointer, value: AnyCodable("none"))
        let updatedOutOfBounds = ArazzoExpressionEvaluator.applyReplacement(repOutOfBounds, to: original)
        XCTAssertEqual((updatedOutOfBounds.value as? [String: Any]) != nil, true)

        let repNonIntOnArray = ArazzoPayloadReplacement(target: "/user/roles/notanint", targetSelectorType: .jsonpointer, value: AnyCodable("none"))
        let updatedNonInt = ArazzoExpressionEvaluator.applyReplacement(repNonIntOnArray, to: original)
        XCTAssertEqual((updatedNonInt.value as? [String: Any]) != nil, true)

        let rep2 = ArazzoPayloadReplacement(target: "/user/roles/1", targetSelectorType: .jsonpointer, value: AnyCodable("editor"))
        let updated2 = ArazzoExpressionEvaluator.applyReplacement(rep2, to: original)
        let roleVal = ArazzoExpressionEvaluator.evaluateJsonPointer("/user/roles/1", on: updated2)
        XCTAssertEqual(roleVal?.value as? String, "editor")

        let repMatrix = ArazzoPayloadReplacement(target: "/user/matrix/0/1", targetSelectorType: .jsonpointer, value: AnyCodable("z"))
        let updatedMatrix = ArazzoExpressionEvaluator.applyReplacement(repMatrix, to: original)
        let matrixVal = ArazzoExpressionEvaluator.evaluateJsonPointer("/user/matrix/0/1", on: updatedMatrix)
        XCTAssertEqual(matrixVal?.value as? String, "z")

        let repNewIntermediate = ArazzoPayloadReplacement(target: "/profile/avatar/url", targetSelectorType: .jsonpointer, value: AnyCodable("https://img.png"))
        let emptyRoot = AnyCodable([String: Any]())
        let updatedWithIntermediate = ArazzoExpressionEvaluator.applyReplacement(repNewIntermediate, to: emptyRoot)
        let avatarVal = ArazzoExpressionEvaluator.evaluateJsonPointer("/profile/avatar/url", on: updatedWithIntermediate)
        XCTAssertEqual(avatarVal?.value as? String, "https://img.png")

        let repEmpty = ArazzoPayloadReplacement(target: "", targetSelectorType: .jsonpointer, value: AnyCodable("allNew"))
        let updatedEmpty = ArazzoExpressionEvaluator.applyReplacement(repEmpty, to: original)
        XCTAssertEqual(updatedEmpty.value as? String, "allNew")

        let repInvalidType = ArazzoPayloadReplacement(target: "/primitive/key", targetSelectorType: .jsonpointer, value: AnyCodable("fallback"))
        let rootPrimitive = AnyCodable(42)
        let updatedPrimitive = ArazzoExpressionEvaluator.applyReplacement(repInvalidType, to: rootPrimitive)
        XCTAssertEqual(updatedPrimitive.value as? Int, 42)
    }
}
