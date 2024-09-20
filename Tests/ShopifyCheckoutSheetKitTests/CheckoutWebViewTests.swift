/*
MIT License

Copyright 2023 - Present, Shopify Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import XCTest
import WebKit
@testable import ShopifyCheckoutSheetKit

// swiftlint:disable type_body_length
class CheckoutWebViewTests: XCTestCase {
	private var view: CheckoutWebView!
	private var recovery: CheckoutWebView!
	private var mockDelegate: MockCheckoutWebViewDelegate!
	private var url = URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!

	override func setUp() {
		ShopifyCheckoutSheetKit.configuration.preloading.enabled = true
		view = CheckoutWebView.for(checkout: url)
        mockDelegate = MockCheckoutWebViewDelegate()
        view.viewDelegate = mockDelegate
		view.checkoutBridge = MockCheckoutBridge.self
	}

	private func createRecoveryAgent() -> CheckoutWebView {
		recovery = CheckoutWebView.for(checkout: url, recovery: true)
        mockDelegate = MockCheckoutWebViewDelegate()
        recovery.viewDelegate = mockDelegate
        return recovery
	}

	func testCorrectlyConfiguresWebview() {
		XCTAssertEqual(view.configuration.applicationNameForUserAgent, CheckoutBridge.applicationName)
		XCTAssertTrue(view.configuration.allowsInlineMediaPlayback)
	}

	func testUsesRecoveryAgent() {
		let backgroundColor: UIColor = .systemRed
		ShopifyCheckoutSheetKit.configuration.backgroundColor = backgroundColor
		ShopifyCheckoutSheetKit.configuration.colorScheme = .automatic
		recovery = createRecoveryAgent()

		XCTAssertTrue(recovery.isRecovery)
		XCTAssertFalse(recovery.isBridgeAttached)
		XCTAssertFalse(recovery.isPreloadingAvailable)
		XCTAssertEqual(recovery.configuration.applicationNameForUserAgent, "ShopifyCheckoutSDK/\(ShopifyCheckoutSheetKit.version) (noconnect;automatic;standard_recovery)")
		XCTAssertTrue(recovery.configuration.allowsInlineMediaPlayback)
		XCTAssertEqual(recovery.backgroundColor, backgroundColor)
		XCTAssertFalse(recovery.isOpaque)
	}

	func testEmailContactLinkDelegation() {
		let link = URL(string: "mailto:contact@shopify.com")!

		let delegate = MockCheckoutWebViewDelegate()
		let didClickLinkExpectation = expectation(
			description: "checkoutViewDidClickLink was called"
		)
		delegate.didClickLinkExpectation = didClickLinkExpectation
		view.viewDelegate = delegate

		view.webView(view, decidePolicyFor: MockNavigationAction(url: link)) { policy in
			XCTAssertEqual(policy, .cancel)
		}

		wait(for: [didClickLinkExpectation], timeout: 1)
	}

	func testPhoneContactLinkDelegation() {
		let link = URL(string: "tel:1234567890")!

		let delegate = MockCheckoutWebViewDelegate()
		let didClickLinkExpectation = expectation(
			description: "checkoutViewDidClickLink was called"
		)
		delegate.didClickLinkExpectation = didClickLinkExpectation
		view.viewDelegate = delegate

		view.webView(view, decidePolicyFor: MockNavigationAction(url: link)) { policy in
			XCTAssertEqual(policy, .cancel)
		}

		wait(for: [didClickLinkExpectation], timeout: 1)
	}

	func testURLLinkDelegation() {
		let link = URL(string: "https://www.shopify.com/legal/privacy/app-users")!

		let delegate = MockCheckoutWebViewDelegate()
		let didClickLinkExpectation = expectation(
			description: "checkoutViewDidClickLink was called"
		)
		delegate.didClickLinkExpectation = didClickLinkExpectation
		view.viewDelegate = delegate

		view.webView(view, decidePolicyFor: MockExternalNavigationAction(url: link)) { policy in
			XCTAssertEqual(policy, .cancel)
		}

		wait(for: [didClickLinkExpectation], timeout: 1)
	}

	func testURLLinkDelegationWithExternalParam() {
		let link = URL(string: "https://www.shopify.com/legal/privacy/app-users?open_externally=true")!

		let delegate = MockCheckoutWebViewDelegate()
		let didClickLinkExpectation = expectation(
			description: "checkoutViewDidClickLink was called"
		)
		delegate.didClickLinkExpectation = didClickLinkExpectation
		view.viewDelegate = delegate

		view.webView(view, decidePolicyFor: MockExternalNavigationAction(url: link, navigationType: .other)) { policy in
			XCTAssertEqual(policy, .cancel)
		}

		wait(for: [didClickLinkExpectation], timeout: 1)
	}

	func test403responseOnCheckoutURLCodeDelegation() {
		view.load(checkout: URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!)
		let link = view.url!
		let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was called")

		mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation
		view.viewDelegate = mockDelegate

		let urlResponse = HTTPURLResponse(url: link, statusCode: 403, httpVersion: nil, headerFields: nil)!

		let policy = view.handleResponse(urlResponse)
		XCTAssertEqual(policy, .cancel)

		waitForExpectations(timeout: 5) { _ in
			switch self.mockDelegate.errorReceived {
			case .some(.checkoutUnavailable(let message, _, let recoverable)):
				XCTAssertEqual(message, "forbidden")
				XCTAssertFalse(recoverable)
			default:
				XCTFail("Unhandled error case received")
			}
		}
	}

	func testObtainsOrderIDFromQuery() {
		let urls = [
			"http://shopify1.shopify.com/checkouts/c/12345/thank-you?order_id=1234",
			"http://shopify1.shopify.com/checkouts/c/12345/thank_you?order_id=1234",
			"http://shopify1.shopify.com/checkouts/c/12345/thank_you/completed?order_id=1234"
		]

		for url in urls {
			recovery = createRecoveryAgent()
			let didCompleteCheckoutExpectation = expectation(description: "checkoutViewDidCompleteCheckout was called")

			mockDelegate.didEmitCheckoutCompletedEventExpectation = didCompleteCheckoutExpectation
			recovery.viewDelegate = mockDelegate

			recovery.load(checkout: URL(string: url)!)
			let urlResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)!

			XCTAssertEqual(recovery.handleResponse(urlResponse), .allow)

			waitForExpectations(timeout: 5) { _ in
				XCTAssertEqual(self.mockDelegate.completedEventReceived?.orderDetails.id, "1234")
			}
		}
	}

	func test401responseOnCheckoutURLCodeDelegation() {
		view.load(checkout: URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!)
		let link = view.url!
		let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was called")

		mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation
		view.viewDelegate = mockDelegate

		let urlResponse = HTTPURLResponse(url: link, statusCode: 401, httpVersion: nil, headerFields: nil)!

		let policy = view.handleResponse(urlResponse)
		XCTAssertEqual(policy, .cancel)

		waitForExpectations(timeout: 5) { _ in
			switch self.mockDelegate.errorReceived {
			case .some(.checkoutUnavailable(let message, _, let recoverable)):
				XCTAssertEqual(message, "unauthorized")
				XCTAssertFalse(recoverable)
			default:
				XCTFail("Unhandled error case received")
			}
		}
	}

	func test404responseOnCheckoutURLCodeDelegation() {
		view.load(checkout: URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!)
		let link = view.url!
		let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was called")

		mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation
		view.viewDelegate = mockDelegate

		let urlResponse = HTTPURLResponse(url: link, statusCode: 404, httpVersion: nil, headerFields: nil)!

		let policy = view.handleResponse(urlResponse)
		XCTAssertEqual(policy, .cancel)

		waitForExpectations(timeout: 5) { _ in
			switch self.mockDelegate.errorReceived {
			case .some(.checkoutUnavailable(let message, _, let recoverable)):
				XCTAssertEqual(message, "not found")
				XCTAssertFalse(recoverable)
			default:
				XCTFail("Unhandled error case received")
			}
		}
	}

	func testTreat404WithDeprecationHeader() {
		view.load(checkout: URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!)
		let link = view.url!
		let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was called")

		mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation
		view.viewDelegate = mockDelegate

		let urlResponse = HTTPURLResponse(url: link, statusCode: 404, httpVersion: nil, headerFields: ["x-shopify-api-deprecated-reason": "checkout_liquid_not_supported"])!

		let policy = view.handleResponse(urlResponse)
		XCTAssertEqual(policy, .cancel)

		waitForExpectations(timeout: 5) { _ in
			switch self.mockDelegate.errorReceived {
			case .some(.configurationError(let message, _, let recoverable)):
				XCTAssertEqual(message, "Storefronts using checkout.liquid are not supported. Please upgrade to Checkout Extensibility.")
				XCTAssertFalse(recoverable)
			default:
				XCTFail("Unhandled error case received")
			}
		}
	}

    func test410responseOnCheckoutURLCodeDelegation() {
		view.load(checkout: URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!)
		let link = view.url!
        let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was called")

        mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation
        view.viewDelegate = mockDelegate

		let urlResponse = HTTPURLResponse(url: link, statusCode: 410, httpVersion: nil, headerFields: nil)!

        let policy = view.handleResponse(urlResponse)
        XCTAssertEqual(policy, .cancel)

		waitForExpectations(timeout: 5) { _ in
			switch self.mockDelegate.errorReceived {
			case .some(.checkoutExpired(let message, _, let recoverable)):
				XCTAssertEqual(message, "Checkout has expired.")
				XCTAssertFalse(recoverable)
			default:
				XCTFail("Unhandled error case received")
			}
		}
    }

	func testTreat5XXReponsesAsRecoverable() {
		view.load(checkout: URL(string: "http://shopify1.shopify.com/checkouts/cn/123")!)
		let link = view.url!
		view.viewDelegate = mockDelegate

		for statusCode in 500...510 {
			let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was called for status code \(statusCode)")
			mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation

			let urlResponse = HTTPURLResponse(url: link, statusCode: statusCode, httpVersion: nil, headerFields: nil)!

			let policy = view.handleResponse(urlResponse)
			XCTAssertEqual(policy, .cancel, "Policy should be .cancel for status code \(statusCode)")

			waitForExpectations(timeout: 3) { error in
				if error != nil {
					XCTFail("Test timed out for status code \(statusCode)")
				}

				guard let receivedError = self.mockDelegate.errorReceived else {
					XCTFail("Expected to receive a `CheckoutError` for status code \(statusCode)")
					return
				}

				switch receivedError {
				case .checkoutUnavailable(_, _, let recoverable):
					XCTAssertTrue(recoverable, "Error should be recoverable for status code \(statusCode)")
				default:
					XCTFail("Received incorrect `CheckoutError` case for status code \(statusCode)")
				}
			}

			// Reset the delegate's expectations and error received state before the next iteration
			mockDelegate.didFailWithErrorExpectation = nil
			mockDelegate.errorReceived = nil
		}
	}

	func testNormalresponseOnNonCheckoutURLCodeDelegation() {
		let link = URL(string: "http://shopify.com/resource_url")!
        let didFailWithErrorExpectation = expectation(description: "checkoutViewDidFailWithError was not called")
		didFailWithErrorExpectation.isInverted = true

        mockDelegate.didFailWithErrorExpectation = didFailWithErrorExpectation
        view.viewDelegate = mockDelegate

        let urlResponse = HTTPURLResponse(url: link, statusCode: 410, httpVersion: nil, headerFields: nil)!

        let policy = view.handleResponse(urlResponse)
		XCTAssertEqual(policy, .allow)

		waitForExpectations(timeout: 0.5, handler: nil)
    }

	func testPreloadSendsPrefetchHeader() {
		let webView = LoadedRequestObservableWebView()

		webView.load(
			checkout: URL(string: "https://checkout-sdk.myshopify.io")!,
			isPreload: true
		)

		let secPurposeHeader = webView.lastLoadedURLRequest?.value(forHTTPHeaderField: "Sec-Purpose")
		XCTAssertEqual(secPurposeHeader, "prefetch")
	}

	func testNoPreloadDoesNotSendPrefetchHeader() {
		let webView = LoadedRequestObservableWebView()

		webView.load(
			checkout: URL(string: "https://checkout-sdk.myshopify.io")!,
			isPreload: false
		)

		let secPurposeHeader = webView.lastLoadedURLRequest?.value(forHTTPHeaderField: "Sec-Purpose")
		XCTAssertEqual(secPurposeHeader, nil)
		XCTAssertFalse(webView.isPreloadRequest)
	}

	func testInstrumentRequestWithPreloadingTag() {
		let webView = LoadedRequestObservableWebView()

		webView.load(
			checkout: URL(string: "https://checkout-sdk.myshopify.io")!,
			isPreload: true
		)

		webView.timer = Date()
		webView.webView(webView, didFinish: nil)

		XCTAssertTrue(webView.isPreloadRequest)
		XCTAssertEqual(webView.lastInstrumentationPayload?.name, "checkout_finished_loading")
		XCTAssertEqual(webView.lastInstrumentationPayload?.type, .histogram)
		XCTAssertEqual(webView.lastInstrumentationPayload?.tags, ["preloading": "true"])
	}

	func testDoesNotInstrumentRequestWithPreloadingTag() {
		let webView = LoadedRequestObservableWebView()

		webView.load(
			checkout: URL(string: "https://checkout-sdk.myshopify.io")!,
			isPreload: false
		)

		webView.timer = Date()
		webView.webView(webView, didFinish: nil)

		XCTAssertFalse(webView.isPreloadRequest)
		XCTAssertEqual(webView.lastInstrumentationPayload?.name, "checkout_finished_loading")
		XCTAssertEqual(webView.lastInstrumentationPayload?.type, .histogram)
		XCTAssertEqual(webView.lastInstrumentationPayload?.tags, ["preloading": "false"])
	}

	func testDoesNotInstrumentPreloadingTagIfDisabled() {
		let webView = LoadedRequestObservableWebView()
		ShopifyCheckoutSheetKit.configuration.preloading.enabled = false

		webView.load(
			checkout: URL(string: "https://checkout-sdk.myshopify.io")!,
			/// This is not respected if preloading is disabled at a config level
			isPreload: true
		)

		webView.timer = Date()
		webView.webView(webView, didFinish: nil)

		XCTAssertEqual(webView.lastInstrumentationPayload?.tags, ["preloading": "false"])
	}

	func testDetachBridgeCalledOnInit() {
		ShopifyCheckoutSheetKit.configuration.preloading.enabled = false
		let url = URL(string: "http://shopify1.shopify.com/checkouts/cn/123")
		let view = CheckoutWebView.for(checkout: url!)
		XCTAssertTrue(view.isBridgeAttached)
		let secondView = CheckoutWebView.for(checkout: url!)
		XCTAssertFalse(view.isBridgeAttached)
		XCTAssertTrue(secondView.isBridgeAttached)
	}

	func testCacheIsClearedOnInvalidate() {
		ShopifyCheckoutSheetKit.configuration.preloading.enabled = true
		let url = URL(string: "http://shopify1.shopify.com/checkouts/cn/123")
		let view = CheckoutWebView.for(checkout: url!)
		XCTAssertTrue(view.isBridgeAttached)
		XCTAssertTrue(CheckoutWebView.hasCacheEntry())

		ShopifyCheckoutSheetKit.invalidate()
		XCTAssertFalse(CheckoutWebView.hasCacheEntry())
		XCTAssertFalse(view.isBridgeAttached)
	}
}

class LoadedRequestObservableWebView: CheckoutWebView {
	var lastLoadedURLRequest: URLRequest?
	var lastInstrumentationPayload: InstrumentationPayload?

	override func load(_ request: URLRequest) -> WKNavigation? {
		self.lastLoadedURLRequest = request
		return nil
	}

	override internal func instrument(_ payload: InstrumentationPayload) {
		self.lastInstrumentationPayload = payload
	}
}

class MockCheckoutBridge: CheckoutBridgeProtocol {
    static var instrumentCalled = false
    static var sendMessageCalled = false

    static func instrument(_ webView: WKWebView, _ instrumentation: InstrumentationPayload) {
        instrumentCalled = true
    }

    static func sendMessage(_ webView: WKWebView, messageName: String, messageBody: String?) {
		sendMessageCalled = true
	}
}
// swiftlint:enable type_body_length
