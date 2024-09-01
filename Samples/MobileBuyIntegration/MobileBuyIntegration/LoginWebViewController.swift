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
import WebKit

class LoginWebViewController: UIViewController, UIAdaptivePresentationControllerDelegate, LoginWebViewDelegate {

	func loginComplete(token: String) {
		DispatchQueue.main.async {
			print("Logged in with token \(token)")
			self.dismiss(animated: true)
		}
	}

	func loginFailed(error: String) {
		DispatchQueue.main.async {
			print("Failed to log in with error \(error)")
			self.dismiss(animated: true)
		}
	}

	internal var loginWebView: LoginWebView
	private let authData: AuthData
	private let redirectUri: String

	private lazy var closeBarButtonItem: UIBarButtonItem = {
		return UIBarButtonItem(
			barButtonSystemItem: .close, target: self, action: #selector(close)
		)
	}()

	internal var progressObserver: NSKeyValueObservation?

	public init(authData: AuthData, redirectUri: String) {
		self.authData = authData
		self.redirectUri = redirectUri

		let loginView = LoginWebView()
		loginView.setAuthData(authData: authData, redirectUri: redirectUri)
		loginView.translatesAutoresizingMaskIntoConstraints = false
		loginView.scrollView.contentInsetAdjustmentBehavior = .never
		self.loginWebView = loginView

		super.init(nibName: nil, bundle: nil)

		title = "Login" // todo

		navigationItem.rightBarButtonItem = closeBarButtonItem

		loginView.viewDelegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()

		view.addSubview(loginWebView)
		NSLayoutConstraint.activate([
			loginWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			loginWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			loginWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			loginWebView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])

		loginWebView.load(URLRequest(url: authData.authorizationUrl))
	}

	@IBAction internal func close() {
		didCancel()
	}

	public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
		didCancel()
	}

	private func didCancel() {
//		delegate?.checkoutDidCancel()
	}
}
