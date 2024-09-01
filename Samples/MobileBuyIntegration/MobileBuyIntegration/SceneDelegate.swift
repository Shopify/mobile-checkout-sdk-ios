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
import SwiftUI
import ShopifyCheckoutSheetKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
		guard let windowScene = (scene as? UIWindowScene) else { return }

		let tabBarController = UITabBarController()

		/// Catalog
		let catalogController = ProductViewController()
		catalogController.tabBarItem.image = UIImage(systemName: "books.vertical")
		catalogController.tabBarItem.title = "Browse"
		catalogController.navigationItem.title = "Product details"

		/// Login
		let loginController = LoginViewController()
		loginController.tabBarItem.image = UIImage(systemName: "person.2.circle")
		loginController.tabBarItem.title = "Login"
		loginController.navigationItem.title = "Login"

		/// Cart
		let cartController = CartViewController()
		cartController.tabBarItem.image = UIImage(systemName: "cart")
		cartController.tabBarItem.title = "Cart"
		cartController.navigationItem.title = "Cart"

		tabBarController.viewControllers = [
			UINavigationController(
				rootViewController: catalogController
			),
			UINavigationController(
				rootViewController: cartController
			),
			UINavigationController(
				rootViewController: loginController
			)
		]

		if #available(iOS 15.0, *) {
			let settingsController = UIHostingController(rootView: SettingsView())
			settingsController.tabBarItem.image = UIImage(systemName: "gearshape.2")
			settingsController.tabBarItem.title = "Settings"

			tabBarController.viewControllers?.append(UINavigationController(
				rootViewController: settingsController
			))
		}

		let window = UIWindow(windowScene: windowScene)
		window.rootViewController = tabBarController
		window.makeKeyAndVisible()

		NotificationCenter.default.addObserver(self, selector: #selector(colorSchemeChanged), name: .colorSchemeChanged, object: nil)

		window.overrideUserInterfaceStyle = ShopifyCheckoutSheetKit.configuration.colorScheme.userInterfaceStyle

		self.window = window
	}

	@objc func colorSchemeChanged() {
		window?.overrideUserInterfaceStyle = ShopifyCheckoutSheetKit.configuration.colorScheme.userInterfaceStyle
	}
}

extension Notification.Name {
	static let colorSchemeChanged = Notification.Name("colorSchemeChanged")
}

extension Configuration.ColorScheme {
	var userInterfaceStyle: UIUserInterfaceStyle {
		switch self {
		case .light:
			return .light
		case .dark:
			return .dark
		default:
			return .unspecified
		}
	}
}
