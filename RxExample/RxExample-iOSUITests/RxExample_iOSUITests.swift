//
//  ExpectationsBreakRxBlockingSomehowUITests.swift
//  FreshBooks
//
//  Created by Mathew Stevenson on 2016-12-01.
//  Copyright © 2016 FreshBooks. All rights reserved.
//

import XCTest
import RxSwift
import RxBlocking

final class ExpectationsBreakRxBlockingSomehowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        XCUIApplication().launch()
    }

    override func tearDown() {
        super.tearDown()
        XCUIApplication().terminate()
    }

    private func observableToTestWith() -> Observable<String> {
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)

        return Observable.create({ (observer) -> Disposable in
            // This is normally where the Alamofire request would be made
            dispatch_async(backgroundQueue, { () -> Void in
                sleep(1)
                observer.on(.Next("my_value"))
            })
            return AnonymousDisposable { }
        })
    }


    // We can get the value from the blocking observable, despite the unfulfilled expectation
    func test_1_WorksFineWithUnfulfilledExpectationWithDescription() throws {
        let str = try observableToTestWith().toBlocking().first() ?? ""
        XCTAssertEqual("my_value", str, "Should be able to get the value")

        expectationWithDescription("desc")
        waitForExpectationsWithTimeout(2, handler: nil)

        let str2 = try observableToTestWith().toBlocking().first() ?? ""
        XCTAssertEqual("my_value", str2, "Should be able to get the value")
    }


    // We can get the value from the blocking observable, as the expectationForPredicate passes
    func test_2_ExpectationForPredicateIsGreatWhenItPasses() throws {
        let str1 = try observableToTestWith().toBlocking().first() ?? ""
        XCTAssertEqual("my_value", str1, "Should be able to get the value")

        // Not a problem, since this passes
        expectationForPredicate(NSPredicate(format: "true == true"), evaluatedWithObject: "Random Object literal", handler: nil)

        let str2 = try observableToTestWith().toBlocking().first() ?? ""
        XCTAssertEqual("my_value", str2, "Should still be able to get the value.")
    }


    // We can NOT get the value from the second blocking observable, after the expectationForPredicate that fails
    func test_3_FailingExpectationForPredicateBreaksRxBlockingSomehow() throws {

        // What breaks stuff - expectationForPredicate that fails
        let expectationThatFails = expectationForPredicate(NSPredicate(format: "true == false"), evaluatedWithObject: "Random Object literal", handler: nil)

        // Regardless of whether we wait for the expectation and fulfill it in the handler, it will still break RxBlocking
        waitForExpectationsWithTimeout(2, handler: { _ in
            expectationThatFails.fulfill()
        })

        let stringFromBlockingObservable: String = try observableToTestWith().toBlocking().first() ?? ""
        XCTAssertEqual("my_value", stringFromBlockingObservable, "Should still be able to get the value, but fails.")
    }


    // We can NOT get the value from the blocking observable, as it's run after the test that has the broken expectationForPredicate
    func test_4_ExpectationForPredicateBreaksRxBlockingAcrossTests() throws {
        let str = try observableToTestWith().toBlocking().first() ?? ""
        XCTAssertEqual("my_value", str, "Should be able to get the value, but fails.")
    }
    
}
