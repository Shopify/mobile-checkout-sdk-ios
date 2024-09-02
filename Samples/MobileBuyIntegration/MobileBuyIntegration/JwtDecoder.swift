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

class JwtDecoder {

	internal static let shared = JwtDecoder()

	func decode(jwtToken jwt: String) -> [String: Any] {
	  let segments = jwt.components(separatedBy: ".")
	  return decodeJWTPart(segments[1]) ?? [:]
	}

	func base64UrlDecode(_ value: String) -> Data? {
	  var base64 = value
		.replacingOccurrences(of: "-", with: "+")
		.replacingOccurrences(of: "_", with: "/")

	  let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
	  let requiredLength = 4 * ceil(length / 4.0)
	  let paddingLength = requiredLength - length
	  if paddingLength > 0 {
		let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
		base64 += padding
	  }
	  return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
	}

	func decodeJWTPart(_ value: String) -> [String: Any]? {
	  guard let bodyData = base64UrlDecode(value),
		let json = try? JSONSerialization.jsonObject(with: bodyData, options: []), let payload = json as? [String: Any] else {
		  return nil
	  }

	  return payload
	}
}
