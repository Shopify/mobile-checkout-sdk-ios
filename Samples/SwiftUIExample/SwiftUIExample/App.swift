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

import SwiftUI
import ShopifyCheckoutSheetKit

@main
struct SwiftUIExampleApp: App {
	init() {
		ShopifyCheckoutSheetKit.configure {
			$0.preloading.enabled = true
			$0.logLevel = .all
		}
	}

    var body: some Scene {
        WindowGroup {
			RootTabView()
		}
    }
}

struct RootTabView: View {
	@State var isShowingCheckout = false
	@State var checkoutURL: URL?
	@ObservedObject private var cartManager = CartManager.shared

	var body: some View {
		TabView {
			CatalogView(cartManager: cartManager, checkoutURL: $checkoutURL, cart: $cartManager.cart)
				.tabItem {
					Label("Catalog", systemImage: "storefront")
				}

			NavigationView {
				CartView(cartManager: cartManager, checkoutURL: $checkoutURL, isShowingCheckout: $isShowingCheckout)
					.navigationTitle("Cart")
					.navigationBarTitleDisplayMode(.inline)
					.padding(10)
					.toolbar {
						if cartManager.cart?.lines != nil {
							ToolbarItem(placement: .navigationBarTrailing) {
								Text("Clear")
									.font(.body)
									.foregroundStyle(Color.accentColor)
									.onTapGesture {
										cartManager.resetCart()
									}
							}
						}
					}
			}
			.tabItem {
				Label("Cart", systemImage: "cart")
			}.badge(Int(cartManager.cart?.totalQuantity ?? 0))
		}
	}
}

#Preview {
	RootTabView()
}
