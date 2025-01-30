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

import OSLog
import ShopifyCheckoutSheetKit
import UIKit

class CheckoutController: UIViewController {
    var window: UIWindow?
    var root: UIViewController?
    let paymentHandler = ApplePayHandler()

    init(window: UIWindow?) {
        self.window = window
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public static var shared: CheckoutController?

    public func present(checkout url: URL) {
        if let rootViewController = window?.topMostViewController() {
            ShopifyCheckoutSheetKit.present(checkout: url, from: rootViewController, delegate: self)
            root = rootViewController
        }
    }

    public func preload() {
        CartManager.shared.preloadCheckout()
    }

    public func payWithApplePay() {
        paymentHandler.startApplePayCheckout { success in
            print("success: \(success)")
            if !success, let checkoutUrl = CartManager.shared.cart?.checkoutUrl {
                // If payment fails, decelerate into CSK checkout to complete payment
                self.present(checkout: checkoutUrl)
            }

            guard let redirectUrl = CartManager.shared.redirectUrl else { return }
            // Present thank you page
            self.present(checkout: redirectUrl)
        }
    }
}

extension CheckoutController: CheckoutDelegate {
    func checkoutDidComplete(event: CheckoutCompletedEvent) {
        OSLogger.shared.debug(
            "[CheckoutDelegate] Checkout completed. Order ID: \(event.orderDetails.id)")
        CartManager.shared.resetCart()
    }

    func checkoutDidCancel() {
        OSLogger.shared.debug("[CheckoutDelegate] Checkout cancelled.")
        root?.dismiss(animated: true, completion: nil)
    }

    func checkoutDidFail(error: ShopifyCheckoutSheetKit.CheckoutError) {
        OSLogger.shared.debug("[CheckoutDelegate] Checkout failed: \(error.localizedDescription)")
    }

    func checkoutDidEmitWebPixelEvent(event: ShopifyCheckoutSheetKit.PixelEvent) {
        var eventName: String?

        switch event {
        case let .standardEvent(event):
            eventName = event.name
        case let .customEvent(event):
            eventName = event.name
        }

        OSLogger.shared.debug("[CheckoutDelegate] Pixel event: \(eventName ?? "")")
    }
}
