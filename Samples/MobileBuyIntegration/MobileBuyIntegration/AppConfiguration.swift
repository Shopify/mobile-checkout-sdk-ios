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
import ShopifyCheckoutSheetKit

public final class AppConfiguration: ObservableObject {
    public var storefrontDomain: String = InfoDictionary.shared.domain

    @Published public var universalLinks = UniversalLinks()

    /// Prefill buyer information
    @Published public var useVaultedState: Bool = false

    /// Logger to retain Web Pixel events
    let webPixelsLogger = FileLogger("analytics.txt")

    // Displays the Checkout with ApplePay button
    @Published var applePayEnabled: Bool = true
}

public var appConfiguration = AppConfiguration() {
    didSet {
        CartManager.shared.resetCart()
    }
}

public struct UniversalLinks {
    public var checkout: Bool = true
    public var cart: Bool = true
    public var products: Bool = true

    public var handleAllURLsInApp: Bool = true {
        didSet {
            if handleAllURLsInApp {
                enableAllURLs()
            }
        }
    }

    private mutating func enableAllURLs() {
        checkout = true
        products = true
        cart = true
    }
}
