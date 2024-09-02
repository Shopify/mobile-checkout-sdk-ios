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
import CommonCrypto

class CustomerAccountClient {

	static let shared = CustomerAccountClient()

	// OAuth
	static let customerAccountsAudience = "30243aa5-17c1-465a-8493-944bcc4e88aa"
	static let authorizationCodeGrantType = "authorization_code"
	static let tokenExchangeGrantType = "urn:ietf:params:oauth:grant-type:token-exchange"
	static let accessTokenSubjectTokenType = "urn:ietf:params:oauth:token-type:access_token"
	static let customerAPIScope = "https://api.customers.com/auth/customer.graphql"

	// Content Types
	static let json = "application/json"
	static let formUrlEncoded = "application/x-www-form-urlencoded"

	private let shopId: String
	private let clientId: String
	private let redirectUri: String
	private let customerAccountsBaseUrl: String
	private let jsonDecoder: JSONDecoder = JSONDecoder()

	// Note: store tokens in Keychain in any production app
	internal var refreshToken: String?
	internal var idToken: String?
	internal var accessToken: String?
	internal var sfApiAccessToken: String?

	init() {
		guard
			let infoPlist = Bundle.main.infoDictionary,
			let shopId = infoPlist["ShopId"] as? String,
			let clientId = infoPlist["CustomerAccountsClientId"] as? String,
			let redirectUri = infoPlist["CustomerAccountsRedirectUri"] as? String?
		else {
			fatalError("unable to load storefront configuration")
		}

		self.shopId = shopId
		self.clientId = clientId
		self.redirectUri = redirectUri ?? "shop.\(shopId).app://callback"
		self.customerAccountsBaseUrl = "https://shopify.com/\(shopId)"
	}

	func getRedirectUri() -> String {
		return self.redirectUri
	}

	func buildAuthData() -> AuthData? {
		guard var components = URLComponents(string: "\(customerAccountsBaseUrl)/auth/oauth/authorize") else {
			print("Couldn't build login page URL")
			return nil
		}

		let codeVerifier = self.createCodeVerifier()
		let codeChallenge = self.codeChallenge(for: codeVerifier)
		let state = randomString(length: 36)

		components.queryItems = [
			URLQueryItem(name: "scope", value: "openid email \(CustomerAccountClient.customerAPIScope)"),
			URLQueryItem(name: "client_id", value: clientId),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "redirect_uri", value: redirectUri),
			URLQueryItem(name: "state", value: state),
			URLQueryItem(name: "code_challenge", value: codeChallenge),
			URLQueryItem(name: "code_challenge_method", value: "S256"),
			URLQueryItem(name: "ui_locales", value: regionCode())
		]

		return AuthData(
			authorizationUrl: components.url!,
			codeVerifier: codeVerifier,
			state: state
		)
	}

	func decodedIdToken() -> [String: Any?]? {
		guard let idToken = CustomerAccountClient.shared.idToken else {
			return nil
		}
		return JwtDecoder.shared.decode(jwtToken: idToken)
	}

	/// Handles authorization code redirect, by extracting the code param, and requesting an access token with that code
	/// and the associated code verifier
	func handleAuthorizationCodeRedirect(_ url: URL, authData: AuthData, callback: @escaping (String?, String?) -> Void) {
		let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
		guard let state = queryItems?.first(where: { $0.name == "state"})?.value else {
			callback(nil, "No state param found")
			return
		}

		if authData.state != state {
			callback(nil, "State param does not match")
			return
		}

		if let code = queryItems?.first(where: { $0.name == "code" })?.value {
			requestAccessToken(code: code, codeVerifier: authData.codeVerifier, callback: callback)
		}
	}

	/// Requests accessToken with the authorization code and code verifier
	private func requestAccessToken(code: String, codeVerifier: String, callback: @escaping (String?, String?) -> Void) {
		guard let url = URL(string: "\(self.customerAccountsBaseUrl)/auth/oauth/token") else {
			return
		}

		let params = [
			"client_id": clientId,
			"grant_type": CustomerAccountClient.authorizationCodeGrantType,
			"code": code,
			"redirect_uri": redirectUri,
			"code_verifier": codeVerifier
		]

		executeRequest(
			url: url,
			headers: [
				"Content-Type": CustomerAccountClient.formUrlEncoded
			],
			body: encodeToFormURLEncoded(parameters: params),
			completionHandler: { data, _, _ in
				guard let tokenResponse = self.jsonDecoder.decodeOrNil(CustomerAccountAccessTokenResponse.self, from: data!) else {
					print("Couldn't decode access token response")
					return
				}

				self.idToken = tokenResponse.idToken
				self.refreshToken = tokenResponse.refreshToken
				self.performTokenExchange(accessToken: tokenResponse.accessToken, callback: callback)
			}
		)
	}

	/// Exchanges access token for a new token that can be used to access Customer Accounts API resources
	private func performTokenExchange(accessToken: String, callback: @escaping (String?, String?) -> Void) {
		guard let url = URL(string: "\(self.customerAccountsBaseUrl)/auth/oauth/token") else {
			callback(nil, "Couldn't build token exchange URL")
			return
		}

		let params = [
			"grant_type": CustomerAccountClient.tokenExchangeGrantType,
			"client_id": self.clientId,
			"audience": CustomerAccountClient.customerAccountsAudience,
			"subject_token": accessToken,
			"subject_token_type": CustomerAccountClient.accessTokenSubjectTokenType,
			"scopes": "https://api.customers.com/auth/customer.graphql"
		]

		executeRequest(
			url: url,
			headers: [
				"Content-Type": CustomerAccountClient.formUrlEncoded
			],
			body: encodeToFormURLEncoded(parameters: params),
			completionHandler: { data, _, _ in
				guard let tokenResponse = self.jsonDecoder.decodeOrNil(CustomerAccountExchangeTokenResponse.self, from: data!) else {
					callback(nil, "Couldn't decode token exchange response")
					return
				}
				self.accessToken = tokenResponse.accessToken
				self.exchangeForStorefrontCustomerAccessToken(customerAccessToken: tokenResponse.accessToken, callback: callback)
			}
		)
	}

	/// Exchanges a Customer Accounts API access token for a Storefront API customer access token that can be used in Storefront API (and cart mutations)
	private func exchangeForStorefrontCustomerAccessToken(customerAccessToken: String, callback: @escaping (String?, String?) -> Void) {
		guard let url = URL(string: "\(customerAccountsBaseUrl)/account/customer/api/2024-07/graphql") else {
			return
		}

		let mutation = """
			mutation {
				storefrontCustomerAccessTokenCreate {
					customerAccessToken
					userErrors {
						field
						message
					}
				}
			}
		"""

		do {
			let body = try JSONEncoder().encode(
				[
					"operationName": "storefrontCustomerAccessTokenCreate",
					"query": mutation
				]
			)

			executeRequest(
				url: url,
				headers: [
					"Content-Type": CustomerAccountClient.json,
					"Authorization": customerAccessToken
				],
				body: body,
				completionHandler: { data, _, _ in
					guard let storefrontCustomerAccessToken = self.jsonDecoder.decodeOrNil(MutationRoot.self, from: data!) else {
						callback(nil, "Couldn't decode storefront access token response")
						return
					}

					let storefrontToken = storefrontCustomerAccessToken.data.storefrontCustomerAccessTokenCreate.customerAccessToken
					callback(storefrontToken, nil)
				}
			)
		} catch {
			callback(nil, error.localizedDescription)
		}
	}

	private func encodeToFormURLEncoded(parameters: [String: String]) -> Data? {
		var components = URLComponents()
		components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
		return components.query?.data(using: .utf8)
	}

	private func createCodeVerifier() -> String {
		var buffer = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
		return base64Encode(Data(buffer))
	}

	private func codeChallenge(for verifier: String) -> String {
		guard let data = verifier.data(using: .utf8) else { fatalError() }
		var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
		data.withUnsafeBytes { bytes in
			_ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
		}
		return base64Encode(Data(digest))
	}

	private func randomString(length: Int) -> String {
	  let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	  return String((0..<length).map { _ in letters.randomElement()! })
	}

	private func base64Encode(_ input: Data) -> String {
		return input.base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
			.trimmingCharacters(in: .whitespaces)
	}

	private func executeRequest(
		url: URL,
		headers: [String: String],
		body: Data?,
		completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
	) {
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		for (key, value) in headers {
			request.setValue(value, forHTTPHeaderField: key)
		}
		request.httpBody = body

		let session = URLSession.shared
		let task = session.dataTask(with: request) { data, response, error in
			completionHandler(data, response, error)
		}
		task.resume()
	}
}

struct AuthData {
	let authorizationUrl: URL
	let codeVerifier: String
	let state: String
}

struct CustomerAccountAccessTokenResponse: Codable {
	let accessToken: String
	let expiresIn: Int
	let idToken: String
	let refreshToken: String
	let scope: String
	let tokenType: String

	enum CodingKeys: String, CodingKey {
		case accessToken = "access_token"
		case expiresIn = "expires_in"
		case idToken = "id_token"
		case refreshToken = "refresh_token"
		case scope = "scope"
		case tokenType = "token_type"
	}
}

struct CustomerAccountExchangeTokenResponse: Codable {
	let accessToken: String
	let expiresIn: Int
	let tokenType: String
	let scope: String
	let issuedTokenType: String

	enum CodingKeys: String, CodingKey {
		case accessToken = "access_token"
		case expiresIn = "expires_in"
		case tokenType = "token_type"
		case scope = "scope"
		case issuedTokenType = "issued_token_type"
	}
}

struct MutationRoot: Codable {
	let data: MutationName
}

struct MutationName: Codable {
	let storefrontCustomerAccessTokenCreate: StorefrontCustomerAccessTokenResponse
}

struct StorefrontCustomerAccessTokenResponse: Codable {
	let customerAccessToken: String
}

extension JSONDecoder {
	func decodeOrNil<T>(_ type: T.Type, from data: Data) -> T? where T: Decodable {
		do {
			return try self.decode(T.self, from: data)
		} catch {
			print("Couldn't decode data \(data)")
			return nil
		}
	}
}
