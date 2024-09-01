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
import WebKit

class LoginWebView: WKWebView {

	private var redirectUri: URLComponents?
	private var authData: AuthData?
	weak var viewDelegate: LoginWebViewDelegate?

	func setAuthData(authData: AuthData, redirectUri: String) {
		self.authData = authData
		self.redirectUri = URLComponents(string: redirectUri)!
	}

	override init(frame: CGRect = .zero, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
		super.init(frame: frame, configuration: configuration)

		#if DEBUG
			if #available(iOS 16.4, *) {
				isInspectable = true
			}
		#endif

		navigationDelegate = self
		translatesAutoresizingMaskIntoConstraints = false
		scrollView.contentInsetAdjustmentBehavior = .never
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension LoginWebView: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

		print("redirect uri \(String(describing: self.redirectUri))")
		print("auth data \(String(describing: self.authData))")

		guard let nonNullRedirectUrl = self.redirectUri, let nonNullAuthData = self.authData else {
			decisionHandler(.allow)
			return
		}

		if let url = action.request.url {
			guard url.scheme == nonNullRedirectUrl.scheme else {
				decisionHandler(.allow)
				return
			}

			guard let redirectComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
				decisionHandler(.allow)
				return
			}

			guard let host = redirectComponents.host, host == nonNullRedirectUrl.host else {
				decisionHandler(.allow)
				return
			}

			CustomerAccountClient.shared.handleAuthorizationCodeRedirect(url, authData: nonNullAuthData, callback: { token, error in
				guard let delegate = self.viewDelegate else {
					return
				}

				guard let nonNilToken = token else {
					delegate.loginFailed(error: error ?? "Unknown error")
					return
				}
				delegate.loginComplete(token: nonNilToken)
			})
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}
}

protocol LoginWebViewDelegate: AnyObject {
	func loginComplete(token: String)
	func loginFailed(error: String)
}
