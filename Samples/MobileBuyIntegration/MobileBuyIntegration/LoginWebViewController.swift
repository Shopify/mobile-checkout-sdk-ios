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

	internal var loginWebView: LoginWebView
    internal var authenticationClient: CustomerAccountClient = CustomerAccountClient.shared

	internal var progressObserver: NSKeyValueObservation?

	public init() {
		self.loginWebView = LoginWebView()

		super.init(nibName: nil, bundle: nil)

		title = "Login"

        loginWebView.viewDelegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

    func login() {
        guard !authenticationClient.isAuthenticated() else {
            print("Customer account is already authenticated.")
            return
        }

        loginWebView.translatesAutoresizingMaskIntoConstraints = false
        loginWebView.scrollView.contentInsetAdjustmentBehavior = .never

        guard let authData = authenticationClient.buildAuthData() else {
            print("No auth data available to build authorization URL")
            return
        }

        loginWebView
            .setAuthData(
                authData: authData,
                redirectUri: authenticationClient.getRedirectUri()
            )

        loginWebView.load(URLRequest(url: authData.authorizationUrl))
    }

    func refreshToken() {
        guard authenticationClient.isAuthenticated() else {
            print("Customer account is not authenticated.")
            return
        }

        let refreshToken = authenticationClient.getRefreshToken()
        guard refreshToken != nil else {
            print("No refresh token available to build refresh token URL.")
            return
        }

        authenticationClient
            .refreshAccessToken(refreshToken: refreshToken!, callback: { token, error in
                guard let nonNilToken = token else {
                    self.loginFailed(error: error ?? "Unknown error")
                    return
                }
                self.loginComplete(token: nonNilToken)
            })
    }

    func logout() {
        guard authenticationClient.isAuthenticated() else {
            print("Customer account is not authenticated.")
            return
        }

        let idToken = authenticationClient.getIdToken()
        guard idToken != nil else {
            print("No id token available to build logout URL.")
            return
        }

        authenticationClient.logout(
            idToken: idToken!,
            callback: { success, error in
                guard success != nil else {
                    self.loginFailed(error: error ?? "Unknown error")
                    return
                }
                self.logoutComplete()
            }
        )
    }

	func loginComplete(token: String) {
		DispatchQueue.main.async {
			let idToken = CustomerAccountClient.shared.decodedIdToken()
            let sfApiAccessToken = CustomerAccountClient.shared.getSfApiAccessToken()
            let accessToken = CustomerAccountClient.shared.getAccessToken()
            let accessTokenExpiration = AccessTokenExpirationManager.shared.getExpirationDate(accessToken: accessToken!)
			let email = idToken?["email"] ?? ""
			let message = "Logged in (or was already logged in) - \(email!)\n SFP API Access Token:\(sfApiAccessToken!)\n Expiration Date:\(accessTokenExpiration!)"

			self.showAlert(title: "Login complete", message: message, completion: {
				self.dismiss(animated: true)
			})
		}
	}

    func logoutComplete() {
        DispatchQueue.main.async {
            let message = "Logged out"

            self.showAlert(title: "Logout complete", message: message, completion: {
                self.dismiss(animated: true)
            })
        }
    }

	func loginFailed(error: String) {
		DispatchQueue.main.async {
			self.showAlert(title: "Login failed", message: "Failed to log in with error \(error)", completion: {
				self.dismiss(animated: true)
			})
		}
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
	}
}

extension LoginWebViewController {
	func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
			completion?()
		}))

		self.present(alert, animated: true, completion: nil)
	}
}
