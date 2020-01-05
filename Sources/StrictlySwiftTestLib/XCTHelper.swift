//
//  XCTHelper.swift
//
//  Created by strictlyswift on 27-May-19.
//

import Foundation
import XCTest
import Combine

public func XCTAssertEqualArrays<T>(_ first: [T],
                                    _ second: [T],
                                    file: StaticString = #file,
                                    line: UInt = #line)
    where T: Equatable {
        XCTAssertEqual(first.count, second.count)
        XCTAssert( zip(first,second).allSatisfy { $0.0 == $0.1 }, "Arrays do not match", file: file, line: line )
}


/// Compares two dictionaries of form [String:X]. X can be a further nested dictionary, or a String
/// or an Int.
public func XCTAssertEqualDictionaries(item:[String:Any],
                                       refDict:[String:Any],
                                       file: StaticString = #file,
                                       line: UInt = #line) {
    
    // Check if the number of keys in 'item' matches
    XCTAssertEqual(Set(refDict.keys), Set(item.keys), "Fields in item don't match reference", file: file, line: line)
    
    for field in item.keys {
        switch (item[field], refDict[field]) {
        case let (fieldDict, refSubDict) as ([String:Any], [String:Any]):
            XCTAssertEqualDictionaries(item: fieldDict, refDict: refSubDict, file: file, line:line)
            
        case let (fieldStr, refStr) as (String, String):
            XCTAssertEqual(fieldStr, refStr, "Item's field '\(field)' has value '\(fieldStr)', but reference '\(field)' has '\(refStr)'" , file: file, line: line)
            
        case let (fieldStr, refStr) as (Int, Int):
            XCTAssertEqual(fieldStr, refStr, "Item's field '\(field)' has value '\(fieldStr)', but reference '\(field)' has '\(refStr)'" , file: file, line: line)
            
        default:
            XCTFail("Could not compare \(item[field] ?? "nil") and \(refDict[field] ?? "nil")", file: file, line: line)
        }
    }
}

/// Get around lack of resource management in SPM
public func getTestResourceDirectory(file: StaticString = #file) -> URL {
    let fileName = file.withUTF8Buffer {
        String(decoding: $0, as: UTF8.self)
    }

    let thisSourceFile = URL(fileURLWithPath: fileName  )
    return thisSourceFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")
}

/// Function to use in tests which waits for output from a given publisher; returning the output if any before
/// the timeout.
///
///     let result = XCTWaitForPublisherResult() {
///          Dyno().createTableWaitActive(name: TEST_TABLE, partitionKeyField: ("id",.string) )
///     }
///     XCTAssertEqual(resultC1, true) // able to create table successfully
///
@available(OSX 10.15, *)
extension XCTestCase {
    public func XCTWaitForPublisherResult<T, P>(timeout: Double = 5, file: StaticString = #file, line: UInt = #line, publisher: () -> P) -> T? where P:Publisher, P.Output == T {
        let exp = XCTestExpectation(description: "expect")
        
        var result: T?
        let cancellable = publisher()
            .sink(
                receiveCompletion: { outcome in
                    switch outcome {
                    case .failure(let e):
                        self.recordFailure(withDescription: "Failed with \(e)", inFile: String("\(file)"), atLine: Int(line), expected: false)
                     //   XCTFail("Failed with \(e)", file:file, line:line)
                    case .finished:exp.fulfill()
                    } },
                receiveValue: { value in result = value })
        
        let outcome = XCTWaiter.wait(for: [exp], timeout: timeout)
        
        switch outcome {
        case .completed:
            return result
        case .timedOut:
            XCTFail("XCTWaitForPublisherResult failed to get publisher result before timeout of \(timeout) seconds", file:file, line:line)
        default:
            XCTFail("XCTWaitForPublisherResult failed with error", file:file, line:line)
        }
        
        NSLog("Cancellable is \(cancellable)")  //  ???
        
        return result
    }


    /// Similar to `XCTWaitForPublisherResult`, but expects to receive a failure in the given timeframe.
    ///
    /// Pass parameter `unexpectedSuccessMessage` to customize the XCTFail you'll get if the publisher, in fact,
    /// succeeds.
    @available(OSX 10.15, *)
    public func XCTWaitForPublisherFailure<T, P>(unexpectedSuccessMessage: String = "", timeout: Double = 5, file: StaticString = #file, line: UInt = #line, publisher: () -> P) -> P.Failure? where P:Publisher, P.Output == T {
        let exp = XCTestExpectation(description: "expect")
        
        var failure: P.Failure?
        let cancellable = publisher()
            .sink(
                receiveCompletion: { outcome in
                    switch outcome {
                    case .failure(let e):
                        failure = e
                        exp.fulfill()
                    case .finished:
                        exp.fulfill()
                    } },
                receiveValue: { _ in })
        
        let waitOutcome = XCTWaiter.wait(for: [exp], timeout: timeout)
        
        switch (waitOutcome, failure) {
        case (.completed, .none):
            XCTFail("XCTWaitForPublisherFailure unexpectedly succeeded. "+unexpectedSuccessMessage, file:file, line:line)
        case (.completed, .some(_)):
            break
        default:
            XCTFail("XCTWaitForPublisherFailure didn't get expected failure before timeout", file:file, line:line)
        }
        
        NSLog("Cancellable is \(cancellable)")  //  ???
        return failure
    }
}
