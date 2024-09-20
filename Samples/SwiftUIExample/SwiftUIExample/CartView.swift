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
import SwiftUI
import ShopifyCheckoutSheetKit

struct CartView: View {
	@State var cartCompleted: Bool = false
	@State var isBusy: Bool = false

	@ObservedObject var cartManager: CartManager
	@Binding var checkoutURL: URL? {
		didSet {
			cartCompleted = false
		}
	}
	@Binding var isShowingCheckout: Bool

	var body: some View {
		if let lines = cartManager.cart?.lines.nodes {
			ScrollView {
				VStack {
					CartLines(lines: lines, isBusy: $isBusy)
				}

				Spacer()

				VStack {
					Button(action: {
						isShowingCheckout = true
					}, label: {
						Text("Checkout")
					})
					.padding()
					.frame(maxWidth: .infinity)
					.background(isBusy ? Color.gray : Color.blue)
					.foregroundColor(.white)
					.cornerRadius(10)
					.bold()
					.disabled(isBusy)
					.accessibilityIdentifier("checkoutButton")
					.sheet(isPresented: $isShowingCheckout) {
						if let url = checkoutURL {
							CheckoutSheet(checkout: url)
								/// Configuration
								.title("SwiftUI")
								.colorScheme(.automatic)
								.tintColor(UIColor(red: 0.33, green: 0.20, blue: 0.92, alpha: 1.00))
								/// Lifecycle events
								.onCancel {
									if cartCompleted {
										cartManager.resetCart()
										cartCompleted = false
									}

									isShowingCheckout = false
								}
								.onPixelEvent { event in
									switch event {
									case .alertDisplayedEvent(let event):
										print("WebPixel - (alert_displayed)", event.name!)
									case .uiExtensionErroredEvent(let event):
										print("WebPixel - (ui_extension_errored)", event.name!)
									case .standardEvent(let event):
										print("WebPixel - (standard)", event.name!)
									case .customEvent(let event):
										print("WebPixel - (custom)", event.name!)
									}
								}
								.onLinkClick { url in
									if UIApplication.shared.canOpenURL(url) {
										UIApplication.shared.open(url)
									}
								}
								.onComplete { checkout in
									print("Checkout completed - Order id: \(String(describing: checkout.orderDetails.id))")
									cartCompleted = true
								}
								.onFail { error in
									print(error)
								}
								.edgesIgnoringSafeArea(.all)
								.accessibility(identifier: "CheckoutSheet")
						}
					}
					.padding(.top, 15)
					.padding(.horizontal, 5)
				}

				Spacer()
			}
			.padding(10)
			.onAppear(
				perform: {
					if let url = checkoutURL {
						ShopifyCheckoutSheetKit.preload(checkout: url)
					}
				}
			)
		} else {
			EmptyState()
		}
	}
}

struct EmptyState: View {
	var body: some View {
		VStack(alignment: .center) {
			SwiftUI.Image(systemName: "cart")
				.resizable()
				.frame(width: 30, height: 30)
				.foregroundColor(.gray)
				.padding(.bottom, 6)
			Text("Your cart is empty.")
				.font(.caption)
		}
	}
}

struct CartLines: View {
	var lines: [BaseCartLine]
	@State var updating: GraphQL.ID? {
		didSet {
			isBusy = updating != nil
		}
	}
	@Binding var isBusy: Bool

	var body: some View {
		ForEach(lines, id: \.id) { node in
			let variant = node.merchandise as? Storefront.ProductVariant

			HStack {
				if let imageUrl = variant?.product.featuredImage?.url {
					AsyncImage(url: imageUrl) { image in
						image.image?.resizable().aspectRatio(contentMode: .fit)
					}
					.frame(width: 60, height: 120)
				}

				VStack(alignment: .leading, spacing: 10) {
					Text(variant?.product.title ?? "")
						.font(.body)
						.bold()
						.lineLimit(2)
						.truncationMode(.tail)

					Text(variant?.product.vendor ?? "")
						.font(.body)
						.foregroundColor(.blue)

					if let price = variant?.price.formattedString() {
						HStack(spacing: 80) {
							Text("\(price)")
								.foregroundColor(.gray)

						HStack(spacing: 20) {
								Button(action: {
									/// Prevent multiple simulataneous calls
									guard node.quantity > 1 && updating != node.id else {
										return
									}

									updating = node.id
									CartManager.shared.updateQuantity(variant: node.id, quantity: node.quantity - 1, completionHandler: { cart in
										CartManager.shared.cart = cart
										updating = nil

										/// Invalidate the cart cache to ensure the correct item quantity is reflected on checkout
										ShopifyCheckoutSheetKit.invalidate()
									})
								}, label: {
									HStack {
										Text("-").font(.title2)
									}.frame(width: 20)
								})

								VStack {
									if updating == node.id {
										ProgressView().progressViewStyle(CircularProgressViewStyle())
										.scaleEffect(0.8)
									} else {
										HStack {
											Text("\(node.quantity)")
										}.frame(width: 20)
									}
								}.frame(width: 20)

								Button(action: {
									/// Prevent multiple simulataneous calls
									guard updating != node.id else {
										return
									}

									updating = node.id
									CartManager.shared.updateQuantity(variant: node.id, quantity: node.quantity + 1, completionHandler: { cart in
										CartManager.shared.cart = cart
										updating = nil

										/// Invalidate the cart cache to ensure the correct item quantity is reflected on checkout
										ShopifyCheckoutSheetKit.invalidate()
									})
								}, label: {
									HStack {
										Text("+").font(.title2)
									}.frame(width: 20)
								})
							}
						}
					}
				}.padding(.leading, 5)
			}
			.padding([.leading, .trailing], 10)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

struct CartViewPreview: PreviewProvider {
	static var previews: some View {
		CartViewPreviewContent()
	}
}

struct CartViewPreviewContent: View {
	@State var isShowingCheckout = false
	@State var checkoutURL: URL?
	@State var isBusy: Bool = false
	@StateObject var cartManager = CartManager.shared

	init() {
		cartManager.injectRandomCartItem()
	}

	var body: some View {
		CartView(cartManager: CartManager.shared, checkoutURL: $checkoutURL, isShowingCheckout: $isShowingCheckout)
	}
}
