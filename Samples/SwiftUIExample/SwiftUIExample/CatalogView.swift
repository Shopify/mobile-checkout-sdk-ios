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

struct CatalogView: View {
	@ObservedObject var cartManager: CartManager

	@Binding var checkoutURL: URL?
	@Binding var cart: Storefront.Cart?

	@State private var isAddingToCart = false
	@State private var isShowingCheckout = false
	@State private var isShowingCart = false
	@State private var product: Storefront.Product?

	func onAppear() {
		cartManager.getRandomProduct { [self] result in
			product = result
		}
	}

	var body: some View {
		NavigationView {
			VStack {
				if
				let product = product,
				let first = product.variants.nodes.first,
				let price = first.price.formattedString() {
					VStack {
						VStack(alignment: .leading) {
							AsyncImage(url: product.featuredImage?.url) { image in
								image.image?
									.resizable()
									.aspectRatio(contentMode: .fill)
									.background(Color(UIColor.systemGray5))
									.frame(maxHeight: 400)
									.clipped()
							}
							.frame(height: 400, alignment: .topLeading)
							.background(Color.gray)
							.padding(.bottom, 10)
						}

						VStack {
							Text(product.vendor)
								.font(.caption2)
								.bold()
								.foregroundColor(.blue)
								.multilineTextAlignment(.center)
								.padding(.top, 10)
								.padding(.bottom, 5)

							Text(product.title)
								.font(.title3)
								.bold()
								.multilineTextAlignment(.center)
								.lineLimit(2)
								.truncationMode(.tail)
								.padding(.top, 0)

							Text(product.description)
								.padding(2)
								.bold()
								.lineLimit(3)
								.foregroundColor(.gray)
						}.padding(.horizontal, 15)

						Button(action: {
							isAddingToCart = true

								if let variantId = product.variants.nodes.first?.id {
									cartManager.addItem(variant: variantId) { cart in
										isAddingToCart = false
										checkoutURL = cart?.checkoutUrl
									}
								}
							}, label: {
								if isAddingToCart {
									ProgressView()
										.progressViewStyle(CircularProgressViewStyle(tint: .white))
										.padding()
										.frame(maxWidth: 400)
										.background(Color.blue)
										.foregroundColor(.white)
										.cornerRadius(10)
								} else {
									Text(product.availableForSale ? (first.price.amount == 0 ? "Add to cart - Free" : "Add to cart - \(price)") : "Out of stock")
										.font(.headline)
										.padding()
										.frame(maxWidth: 400)
										.background(product.availableForSale ? Color.blue : Color.gray)
										.foregroundColor(.white)
										.cornerRadius(10)
								}
							})
							.disabled(!product.availableForSale)
							.accessibilityIdentifier("addToCartButton")
							.sheet(isPresented: $isShowingCart) {
								NavigationView {
									CartView(
										cartManager: cartManager,
										checkoutURL: $checkoutURL,
										isShowingCheckout: $isShowingCheckout
									)
									.toolbar {
										ToolbarItem(placement: .navigationBarTrailing) {
											SwiftUI.Image(systemName: "multiply.circle.fill")
												.resizable()
												.frame(width: 25, height: 25)
												.foregroundColor(Color(UIColor.lightGray))
												.onTapGesture {
													isShowingCart = false
												}
										}
									}
									.navigationBarTitleDisplayMode(.inline)
									.navigationTitle("Cart")
								}
							}.padding()
						}
				} else {
					ProgressView()
				}
			}.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					if #available(iOS 16.1, *) {
						Text("Plant").font(.headline).fontDesign(.monospaced)
					} else {
						Text("Plant").font(.headline)
					}
				}
				ToolbarItemGroup {
					BadgeButton(badgeCount: Int(cartManager.cart?.totalQuantity ?? 0), action: {
						isShowingCart = true
					})
					.accessibilityIdentifier("cartIcon")

					Button(action: {
						onAppear()
					}, label: {
						SwiftUI.Image(systemName: "arrow.clockwise")
					})
				}
			}
		}
		.preferredColorScheme(.light)
		.edgesIgnoringSafeArea(.bottom)
		.padding(0)
		.onAppear {
			if product != nil {
				return
			}
			onAppear()
		}
	}
}

struct BadgeButton: View {
	var badgeCount: Int
	var action: (() -> Void)?

	var body: some View {
		Button(action: action ?? {}) {
			ZStack {
				SwiftUI.Image(systemName: "cart.fill")

				if badgeCount > 0 {
					Text("\(badgeCount)")
						.foregroundColor(.white)
						.font(.system(size: 12))
						.frame(width: 20, height: 20)
						.background(Color.red)
						.clipShape(Circle())
						.offset(x: 10, y: -10)
				}
			}
		}
	}
}

struct CatalogViewPreview: PreviewProvider {
	static var previews: some View {
		CatalogViewPreviewContent()
	}
}

struct CatalogViewPreviewContent: View {
	@State var isShowingCheckout = false
	@State var checkoutURL: URL?
	@StateObject var cartManager = CartManager.shared

	var body: some View {
		CatalogView(cartManager: CartManager.shared, checkoutURL: $checkoutURL, cart: $cartManager.cart)
	}
}
