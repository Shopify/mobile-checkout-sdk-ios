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

import Foundation

struct WebPixelsEvent: Decodable {
	let name: String
	let event: WebPixelsEventBody
}

struct WebPixelsEventBody: Decodable {
	let id: String
	let name: String
	let timestamp: String
	let type: String
	let customData: String?
	let data: [String: Any]?
	let context: Context?

	enum CodingKeys: String, CodingKey {
		case id
		case name
		case timestamp
		case type
		case customData
		case data
		case context
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		id = try container.decode(String.self, forKey: .id)
		name = try container.decode(String.self, forKey: .name)
		timestamp = try container.decode(String.self, forKey: .timestamp)
		type = try container.decode(String.self, forKey: .type)
		context = try container.decode(Context.self, forKey: .context)

		switch type {
		case "standard", "extended-standard":
			data = try container.decodeIfPresent([String: Any].self, forKey: .data)
			customData = nil
		case "custom":
			let customDataValue = try container.decode([String: Any].self, forKey: .customData)
			let jsonData = try JSONSerialization.data(withJSONObject: customDataValue)
			customData = String(data: jsonData, encoding: .utf8)!
			data = nil
		default:
			customData = nil
			data = nil
		}

	}
}

class WebPixelsEventDecoder {
	enum WebPixelsCodingKeys: String, CodingKey {
		case name
		case event
	}

	func decode(from container: KeyedDecodingContainer<CheckoutBridge.WebEvent.CodingKeys>, using decoder: Decoder) throws -> PixelEvent? {
		let messageBody = try container.decode(String.self, forKey: .body)

		guard let data = messageBody.data(using: .utf8) else {
			return nil
		}

		let webPixelsEvent = try JSONDecoder().decode(WebPixelsEvent.self, from: data)

		switch webPixelsEvent.event.type {
		case "standard", "extended-standard":
			if webPixelsEvent.event.name == "alert_displayed" {
				let alertDisplayed = AlertDisplayedEvent(from: webPixelsEvent.event)
				return .alertDisplayedEvent(alertDisplayed)
			} else if webPixelsEvent.name == "ui_extension_errored" {
				let uiExtensionError = UIExtensionErroredEvent(from: webPixelsEvent.event)
				return .uiExtensionErroredEvent(uiExtensionError)
			}
			let standardEvent = StandardEvent(from: webPixelsEvent.event)
			return .standardEvent(standardEvent)
		case "custom":
			let customEvent = CustomEvent(from: webPixelsEvent.event)
			return .customEvent(customEvent)
		default:
			return nil
		}
	}
}
