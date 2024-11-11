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

import UIKit
@preconcurrency import WebKit

protocol CheckoutWebViewDelegate: AnyObject {
	func checkoutViewDidStartNavigation()
	func checkoutViewDidCompleteCheckout(event: CheckoutCompletedEvent)
	func checkoutViewDidFinishNavigation()
	func checkoutViewDidClickLink(url: URL)
	func checkoutViewDidFailWithError(error: CheckoutError)
	func checkoutViewDidToggleModal(modalVisible: Bool)
	func checkoutViewDidEmitWebPixelEvent(event: PixelEvent)
}

private let deprecatedReasonHeader = "x-shopify-api-deprecated-reason"
private let checkoutLiquidNotSupportedReason = "checkout_liquid_not_supported"

class CheckoutWebView: WKWebView {
	private static var cache: CacheEntry?
	internal var timer: Date?

	static var preloadingActivatedByClient: Bool = false

	var checkoutBridge: CheckoutBridgeProtocol.Type = CheckoutBridge.self

	/// A reference to the view is needed when preload is deactivated in order to detach the bridge
	static weak var uncacheableViewRef: CheckoutWebView?

	private var navigationObserver: NSKeyValueObservation?

	var isBridgeAttached = false

	var isRecovery = false {
		didSet {
			isBridgeAttached = false
		}
	}

	var isPreloadingAvailable: Bool {
		return !isRecovery && ShopifyCheckoutSheetKit.configuration.preloading.enabled
	}

	static func `for`(checkout url: URL, recovery: Bool = false) -> CheckoutWebView {
		OSLogger.shared.debug("Creating webview for URL: \(url.absoluteString), recovery: \(recovery)")

		if recovery {
			CheckoutWebView.invalidate()
			return CheckoutWebView(recovery: true)
		}

		let cacheKey = url.absoluteString

		guard ShopifyCheckoutSheetKit.configuration.preloading.enabled else {
			OSLogger.shared.debug("Preloading not enabled")
			return uncacheableView()
		}

		guard let cache = cache, cacheKey == cache.key, !cache.isStale else {
			let view = CheckoutWebView()
			CheckoutWebView.cache = CacheEntry(key: cacheKey, view: view)
			return view
		}

		OSLogger.shared.debug("Presenting cached entry")
		return cache.view
	}

	static func uncacheableView() -> CheckoutWebView {
		uncacheableViewRef?.detachBridge()
		let view = CheckoutWebView()
		uncacheableViewRef = view
		return view
	}

	static func invalidate(disconnect: Bool = true) {
		OSLogger.shared.debug("Invalidating cache, disconnect: \(disconnect)")
		preloadingActivatedByClient = false

		if disconnect {
			cache?.view.detachBridge()
		}

		cache = nil
	}

	/// Used only for testing
	internal static func hasCacheEntry() -> Bool {
		return cache != nil
	}

	// MARK: Properties

	weak var viewDelegate: CheckoutWebViewDelegate?
	var presentedEventDidDispatch = false
	var checkoutDidPresent: Bool = false {
		didSet {
			dispatchPresentedMessage(checkoutDidLoad, checkoutDidPresent)
		}
	}
	var checkoutDidLoad: Bool = false {
		didSet {
			dispatchPresentedMessage(checkoutDidLoad, checkoutDidPresent)
		}
	}
	var isPreloadRequest: Bool = false

	// MARK: Initializers
	init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration(), recovery: Bool = false) {
		OSLogger.shared.debug("Initializing webview, recovery: \(recovery)")
		/// Some external payment providers require ID verification which trigger the camera
		/// This configuration option prevents the camera from opening as a "Live Broadcast".
		configuration.allowsInlineMediaPlayback = true

		if recovery {
			/// Uses a non-persistent, private cookie store to avoid cross-instance pollution
			configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
			configuration.applicationNameForUserAgent = CheckoutBridge.recoveryAgent
		} else {
			/// Set the User-Agent in non-recovery view
			configuration.applicationNameForUserAgent = CheckoutBridge.applicationName
		}

		self.isRecovery = recovery
		super.init(frame: frame, configuration: configuration)

#if DEBUG
		if #available(iOS 16.4, *) {
			isInspectable = true
		}
#endif

		navigationDelegate = self
		translatesAutoresizingMaskIntoConstraints = false
		scrollView.contentInsetAdjustmentBehavior = .never

		setBackgroundColor()

		if recovery {
			observeNavigationChanges()
		} else {
			connectBridge()
		}
	}

	deinit {
		OSLogger.shared.debug("De-allocating webview")

		if isRecovery {
			navigationObserver?.invalidate()
		} else {
			detachBridge()
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func connectBridge() {
		OSLogger.shared.debug("Bridging communication to checkout")
		configuration.userContentController
			.add(MessageHandler(delegate: self), name: CheckoutBridge.messageHandler)

		isBridgeAttached = true
	}

	public func detachBridge() {
		OSLogger.shared.debug("Detaching bridge")
		configuration.userContentController
			.removeScriptMessageHandler(forName: CheckoutBridge.messageHandler)
		isBridgeAttached = false
	}

	private func setBackgroundColor() {
		isOpaque = false
		backgroundColor = ShopifyCheckoutSheetKit.configuration.backgroundColor

		if #available(iOS 15.0, *) {
			underPageBackgroundColor = ShopifyCheckoutSheetKit.configuration.backgroundColor
		}
	}

	private func observeNavigationChanges() {
		navigationObserver = observe(\.url, options: [.new]) { [weak self] (_, change) in
			guard let self = self else { return }

			if let url = change.newValue as? URL {
				if CheckoutURL(from: url).isConfirmationPage() {
					self.viewDelegate?.checkoutViewDidCompleteCheckout(event: createEmptyCheckoutCompletedEvent(id: getOrderIdFromQuery(url: url)))
					navigationObserver?.invalidate()
				}
			}
		}
	}

	internal func instrument(_ payload: InstrumentationPayload) {
		OSLogger.shared.debug("Emitting instrumentation event with payload: \(payload)")
		checkoutBridge.instrument(self, payload)
	}

	// MARK: -

	func load(checkout url: URL, isPreload: Bool = false) {
		OSLogger.shared.info("Loading checkout URL: \(url.absoluteString), isPreload: \(isPreload)")
		var request = URLRequest(url: url)

		if isPreload && isPreloadingAvailable {
			isPreloadRequest = true
			request.setValue("prefetch", forHTTPHeaderField: "Sec-Purpose")
		}

		load(request)
	}

	private func dispatchPresentedMessage(_ checkoutDidLoad: Bool, _ checkoutDidPresent: Bool) {
		if checkoutDidLoad && checkoutDidPresent && isBridgeAttached {
			OSLogger.shared.info("Emitting presented event to checkout")
			CheckoutBridge.sendMessage(self, messageName: "presented", messageBody: nil)
			presentedEventDidDispatch = true
		}
	}
}

extension CheckoutWebView: WKScriptMessageHandler {
	func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
		do {
			switch try CheckoutBridge.decode(message) {
			/// Completed event
			case let .checkoutComplete(checkoutCompletedEvent):
				OSLogger.shared.info("Checkout completed event received")
				viewDelegate?.checkoutViewDidCompleteCheckout(event: checkoutCompletedEvent)
			/// Error: Checkout unavailable
			case .checkoutUnavailable(let message, let code):
				OSLogger.shared.error("Checkout unavailable error received: \(message ?? "No message"), code: \(code)")
				viewDelegate?.checkoutViewDidFailWithError(
					error: .checkoutUnavailable(
						message: message ?? "Checkout unavailable.",
						code: CheckoutUnavailable.clientError(code: code),
						recoverable: true
					)
				)
			/// Error: Storefront not configured properly
			case .configurationError(let message, let code):
				OSLogger.shared.error("Configuration error received: \(message ?? "No message"), code: \(code)")
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutUnavailable(
					message: message ?? "Storefront configuration error.",
					code: CheckoutUnavailable.clientError(code: code),
					recoverable: false
				))
			/// Error: Checkout expired
			case .checkoutExpired(let message, let code):
				OSLogger.shared.info("Checkout expired error received: \(message ?? "No message"), code: \(code)")
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutExpired(message: message ?? "Checkout has expired.", code: code))
			/// Checkout modal toggled
			case let .checkoutModalToggled(modalVisible):
				viewDelegate?.checkoutViewDidToggleModal(modalVisible: modalVisible)
			/// Checkout web pixel event
			case let .webPixels(event):
				if let nonOptionalEvent = event {
					viewDelegate?.checkoutViewDidEmitWebPixelEvent(event: nonOptionalEvent)
				}
			default:
				()
			}
		} catch {
			OSLogger.shared.error("Error decoding bridge script message: \(error.localizedDescription)")
			viewDelegate?.checkoutViewDidFailWithError(error: .sdkError(underlying: error))
		}
	}
}

extension CheckoutWebView: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard let url = action.request.url else {
			decisionHandler(.allow)
			return
		}

		if isExternalLink(action) || CheckoutURL(from: url).isDeepLink() {
			OSLogger.shared.debug("External or deep link clicked: \(url.absoluteString) - request intercepted")
			viewDelegate?.checkoutViewDidClickLink(url: removeExternalParam(url))
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if let response = navigationResponse.response as? HTTPURLResponse {
			decisionHandler(handleResponse(response))
			return
		}
		decisionHandler(.allow)
	}

	func handleResponse(_ response: HTTPURLResponse) -> WKNavigationResponsePolicy {
		let allowRecoverable = !isRecovery
		let headers = response.allHeaderFields
		let statusCode = response.statusCode
		let errorMessageForStatusCode = HTTPURLResponse.localizedString(
			forStatusCode: statusCode
		)

		guard isCheckout(url: response.url) else {
			return .allow
		}

		if statusCode >= 400 {
			/// Invalidate cache for any sort of error
			CheckoutWebView.invalidate()

			OSLogger.shared.debug("Handling response for URL: \(response.url?.absoluteString ?? "unknown URL"), status code: \(statusCode)")

			switch statusCode {
			case 401:
				OSLogger.shared.debug("Unauthorized access (401)")
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutUnavailable(message: errorMessageForStatusCode, code: CheckoutUnavailable.httpError(statusCode: statusCode), recoverable: false))
			case 404:
				OSLogger.shared.debug("Not found (404)")
				if let reason = headers[deprecatedReasonHeader] as? String, reason.lowercased() == checkoutLiquidNotSupportedReason {
					viewDelegate?.checkoutViewDidFailWithError(error: .configurationError(message: "Storefronts using checkout.liquid are not supported. Please upgrade to Checkout Extensibility.", code: CheckoutErrorCode.checkoutLiquidNotMigrated, recoverable: false))
				} else {
					viewDelegate?.checkoutViewDidFailWithError(error: .checkoutUnavailable(
						message: errorMessageForStatusCode,
						code: CheckoutUnavailable.httpError(statusCode: statusCode),
						recoverable: false
					))
				}
			case 410:
				OSLogger.shared.debug("Gone (410)")
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutExpired(message: "Checkout has expired.", code: CheckoutErrorCode.cartExpired))
			case 500...599:
				OSLogger.shared.debug("Server error (5xx)")
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutUnavailable(
					message: errorMessageForStatusCode,
					code: CheckoutUnavailable.httpError(statusCode: statusCode),
					recoverable: allowRecoverable
				))
			default:
				OSLogger.shared.debug("\(statusCode) error received")
				viewDelegate?.checkoutViewDidFailWithError(
					error: .checkoutUnavailable(
						message: errorMessageForStatusCode,
						code: CheckoutUnavailable.httpError(statusCode: statusCode),
						recoverable: false
					))
			}

			return .cancel
		}

		return .allow
	}

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		let url = webView.url?.absoluteString ?? ""
		OSLogger.shared.info("Started provisional navigation - url:\(url)")
		timer = Date()
		viewDelegate?.checkoutViewDidStartNavigation()
	}

	/// No need to emit checkoutDidFail error here as it has been handled in handleResponse already
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		let url = webView.url?.absoluteString ?? ""
		OSLogger.shared.debug("Failed provisional navigation with error: \(error.localizedDescription) url:\(url)")
		timer = nil
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		viewDelegate?.checkoutViewDidFinishNavigation()

		if let startTime = timer {
			let endTime = Date()
			let diff = endTime.timeIntervalSince(startTime)
			let message = "Loaded checkout in \(String(format: "%.2f", diff))s"
			let preload = String(isPreloadRequest)

			ShopifyCheckoutSheetKit.configuration.logger.log(message)

			if isBridgeAttached {
				self.instrument(
					InstrumentationPayload(
						name: "checkout_finished_loading",
						value: Int(diff * 1000),
						type: .histogram,
						tags: ["preloading": preload]))
			}
		}
		checkoutDidLoad = true
		timer = nil
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		timer = nil

		let nsError = error as NSError

		OSLogger.shared.debug("WebView navigation failed with error: description:\(nsError.localizedDescription) domain:\(nsError.domain) code:\(nsError.code)")

		/// Ignore cancelled redirects
		if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
			OSLogger.shared.debug("Ignoring cancelled URL redirect. code:NSURLErrorCancelled")
			return
		}

		viewDelegate?.checkoutViewDidFailWithError(
			error: .sdkError(underlying: error, recoverable: !isRecovery)
		)
	}

	private func isExternalLink(_ action: WKNavigationAction) -> Bool {
		if action.navigationType == .linkActivated && action.targetFrame == nil {
			return true
		}

		guard let url = action.request.url else { return false }
		guard let url = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }

		guard let openExternally = url.queryItems?.first(where: { $0.name == "open_externally" })?.value else { return false }

		return openExternally.lowercased() == "true" || openExternally == "1"
	}

	private func removeExternalParam(_ url: URL) -> URL {
		guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return url
		}
		urlComponents.queryItems = urlComponents.queryItems?.filter { !($0.name == "open_externally") }
		return urlComponents.url ?? url
	}

	private func isCheckout(url: URL?) -> Bool {
		return self.url == url
	}

	private func getOrderIdFromQuery(url: URL) -> String? {
		guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
			return nil
		}

		let queryItems = urlComponents.queryItems ?? []

		for item in queryItems where item.name == "order_id" {
			return item.value
		}

		return nil
	}
}

extension CheckoutWebView {
	fileprivate struct CacheEntry {
		let key: String

		let view: CheckoutWebView

		private let timestamp = Date()

		private let timeout = TimeInterval(60 * 5)

		var isStale: Bool {
			abs(timestamp.timeIntervalSinceNow) >= timeout
		}
	}
}
