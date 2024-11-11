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

import Buy
import UIKit
import ShopifyCheckoutSheetKit
import SwiftUICore
import Combine

class LoginViewController: UIViewController {

	@IBOutlet private var loginButton: UIButton!
    @IBOutlet private var logoutButton: UIButton!
    @IBOutlet private var refreshButton: UIButton!
    @IBOutlet private var logoutView: UIView!
    @IBOutlet private var loginView: UIView!

    private var bag = Set<AnyCancellable>()
    private var loginWebViewController: LoginWebViewController = LoginWebViewController()
    private var customerAccountClient: CustomerAccountClient = CustomerAccountClient()

	public init() {
		super.init(nibName: nil, bundle: nil)
        title = "Login"

        CustomerAccountClient.shared.$authenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authenticated in
                self?.authenticationUpdated(authenticated: authenticated)
            }
            .store(in: &bag)

        self.authenticationUpdated(authenticated: CustomerAccountClient.shared.authenticated)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

    @IBAction func logout() {
        loginWebViewController.logout()
        present(loginWebViewController, animated: true, completion: nil)
    }

    @IBAction func refresh() {
        loginWebViewController.refreshToken()
        present(loginWebViewController, animated: true, completion: nil)
    }

    @IBAction func login() {
        if #available(iOS 13.0, *) {
            loginWebViewController.modalPresentationStyle = .automatic
        } else {
            loginWebViewController.modalPresentationStyle = .overFullScreen
        }

        loginWebViewController.login()

		present(loginWebViewController, animated: true, completion: nil)
	}

    private func authenticationUpdated(authenticated: Bool) {
        if isViewLoaded {
            logoutView.isHidden = !authenticated
            loginView.isHidden = authenticated
        }
    }
}
