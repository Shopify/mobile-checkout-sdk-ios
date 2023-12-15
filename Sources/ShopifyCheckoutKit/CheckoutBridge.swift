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

import WebKit

enum BridgeError: Swift.Error {
	case invalidBridgeEvent(Swift.Error? = nil)
	case unencodableInstrumentation(Swift.Error? = nil)
}

enum CheckoutBridge {
	static let schemaVersion = "7.0"
	static let messageHandler = "mobileCheckoutSdk"
	static var hasInitialized = false
	static var messageBuffer = Array<() -> Void>()

	static var applicationName: String {
		let theme = ShopifyCheckoutKit.configuration.colorScheme.rawValue
		return "ShopifyCheckoutSDK/\(ShopifyCheckoutKit.version) (\(schemaVersion);\(theme);standard)"
	}

	static func instrument(_ webView: WKWebView, _ instrumentation: InstrumentationPayload) {
		if let payload = instrumentation.toBridgeEvent() {
			// This is being wrapped in a timer as such due to a bug in loading of the event listeners on latest schema version. Will be removed once bug is fixed
			let msg = "setTimeout(function() { window.MobileCheckoutSdk.dispatchMessage('instrumentation', \(payload));}, 1000 );"
			webView.evaluateJavaScript(msg)
		}
	}

	static func sendMessage(_ webView: WKWebView, message: String) {
		let script = "window.MobileCheckoutSdk.dispatchMessage('\(message)');"
		if (hasInitialized) {
			webView.evaluateJavaScript(script)
		} else {
			messageBuffer.append {
				webView.evaluateJavaScript(script)
			}
		}
	}

	static func decode(_ message: WKScriptMessage) throws -> WebEvent {
		guard let body = message.body as? String, let data = body.data(using: .utf8) else {
			throw BridgeError.invalidBridgeEvent()
		}

		do {
			return try JSONDecoder().decode(WebEvent.self, from: data)
		} catch {
			throw BridgeError.invalidBridgeEvent(error)
		}
	}

	static func reset() {
		messageBuffer.removeAll()
		hasInitialized = false
	}
}

extension CheckoutBridge {
	enum WebEvent: Decodable {
		case checkoutComplete
		case checkoutExpired
		case checkoutUnavailable
		case checkoutModalToggled(modalVisible: Bool)
		case `init`
		case unsupported(String)

		enum CodingKeys: String, CodingKey {
			case name
			case body
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			let name = try container.decode(String.self, forKey: .name)

			switch name {
			case "completed":
				self = .checkoutComplete
			case "error":
				// needs to support .checkoutUnavailable by parsing error payload on body
				self = .checkoutExpired
			case "checkoutBlockingEvent":
				let modalVisible = try container.decode(String.self, forKey: .body)
				self = .checkoutModalToggled(modalVisible: Bool(modalVisible)!)
			case "init":
				self = .`init`
				CheckoutBridge.hasInitialized = true
				CheckoutBridge.messageBuffer.forEach { delayedSend in
					delayedSend()
				}
				CheckoutBridge.messageBuffer.removeAll()
			default:
				self = .unsupported(name)
			}
		}
	}
}

struct InstrumentationPayload: Codable {
	var name: String
	var value: Int
	var type: InstrumentationType
	var tags: [String: String] = [:]
}

enum InstrumentationType: String, Codable {
	case incrementCounter
	case histogram
}

extension InstrumentationPayload {
	func toBridgeEvent() -> String? {
		SdkToWebEvent(detail: self).toJson()
	}
}

struct SdkToWebEvent<T: Codable>: Codable {
	var detail: T
}

extension SdkToWebEvent {
	func toJson() -> String? {
		do {
			let jsonData = try JSONEncoder().encode(self)
			return String(data: jsonData, encoding: .utf8)
		} catch {
			print(#function, BridgeError.unencodableInstrumentation(error))
		}

		return nil
	}

}
