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
import Combine
import Foundation
import ShopifyCheckoutSheetKit

var cache: Storefront.Cart?

public class CartManager: ObservableObject {
	let client: StorefrontClient = StorefrontClient()

	static let shared = CartManager()

	// MARK: Properties

	@Published
	var cart: Storefront.Cart?

	func injectRandomCartItem() {
		if cache == nil {
			getRandomProduct(onCompletionHandler: { item in
				if let variantId = item?.variants.nodes.first?.id {
					self.addItem(variant: variantId, completionHandler: { cart in
						cache = cart
						self.cart = cart
					})
				}
			})
		} else {
			cart = cache
		}
	}

	// MARK: Cart Actions

	func addItem(variant: GraphQL.ID, completionHandler: ((Storefront.Cart?) -> Void)?) {
		performCartLinesAdd(item: variant) { result in
			switch result {
			case .success(let cart):
				self.cart = cart
			case .failure(let error):
				print(error)
			}
			completionHandler?(self.cart)
		}
	}

	func updateQuantity(variant: GraphQL.ID, quantity: Int32, completionHandler: ((Storefront.Cart?) -> Void)?) {
		performCartUpdate(id: variant, quantity: quantity, handler: { result in
			switch result {
			case .success(let cart):
				self.cart = cart
			case .failure(let error):
				print(error)
			}
			completionHandler?(self.cart)
		})
	}

	func resetCart() {
		self.cart = nil
	}

	// MARK: Product actions

	func getRandomProduct(onCompletionHandler: @escaping (Storefront.Product?) -> Void) {
		let query = Storefront.buildQuery(inContext: Storefront.InContextDirective(country: Storefront.CountryCode.inferRegion())) { $0
			.products(first: 250) { $0
				.edges { $0
					.node { $0.productFragment() }
				}
			}
		}

		client.execute(query: query) { result in
			if case .success(let query) = result {
				let product = query.products.edges.randomElement()?.node
				onCompletionHandler(product)
			}
		}

	}

	typealias CartResultHandler = (Result<Storefront.Cart, Error>) -> Void

	private func performCartUpdate(id: GraphQL.ID, quantity: Int32, handler: @escaping CartResultHandler) {
		let lines = [Storefront.CartLineUpdateInput.create(id: id, quantity: Input(orNull: quantity))]

		if let cartID = cart?.id {
			let mutation = Storefront.buildMutation(inContext: Storefront.InContextDirective(country: Storefront.CountryCode.inferRegion())) { $0
				.cartLinesUpdate(cartId: cartID, lines: lines) { $0
					.cart { $0.cartManagerFragment() }
				}
			}

			client.execute(mutation: mutation) { result in
				if case .success(let mutation) = result, let cart = mutation.cartLinesUpdate?.cart {
					handler(.success(cart))
				} else {
					handler(.failure(URLError(.unknown)))
				}
			}
		} else {
			performCartCreate(items: [id], handler: handler)
		}
	}

	private func performCartLinesAdd(item: GraphQL.ID, handler: @escaping CartResultHandler) {
		if let cartID = cart?.id {
			let lines = [Storefront.CartLineInput.create(merchandiseId: item)]

			let mutation = Storefront.buildMutation(inContext: Storefront.InContextDirective(country: Storefront.CountryCode.inferRegion())) { $0
				.cartLinesAdd(lines: lines, cartId: cartID) { $0
					.cart { $0.cartManagerFragment() }
				}
			}

			client.execute(mutation: mutation) { result in
				if case .success(let mutation) = result, let cart = mutation.cartLinesAdd?.cart {
					handler(.success(cart))
				} else {
					handler(.failure(URLError(.unknown)))
				}
			}
		} else {
			performCartCreate(items: [item], handler: handler)
		}
	}

	private func performCartCreate(items: [GraphQL.ID] = [], handler: @escaping CartResultHandler) {
		let mutation = Storefront.buildMutation(inContext: Storefront.InContextDirective(country: Storefront.CountryCode.inferRegion())) { $0
			.cartCreate(input: defaultCart(items)) { $0
				.cart { $0.cartManagerFragment() }
			}
		}

		client.execute(mutation: mutation) { result in
			if case .success(let mutation) = result, let cart = mutation.cartCreate?.cart {
				handler(.success(cart))
			} else {
				handler(.failure(URLError(.unknown)))
			}
		}
	}

	private func defaultCart(_ items: [GraphQL.ID]) -> Storefront.CartInput {
		return Storefront.CartInput.create(
			lines: Input(orNull: items.map({ Storefront.CartLineInput.create(merchandiseId: $0) }))
		)
	}
}

extension Storefront.ProductQuery {
	@discardableResult
	func productFragment() -> Storefront.ProductQuery {
		self.id()
			.title()
			.description()
			.vendor()
			.availableForSale()
			.featuredImage { $0
				.url(
					transform: Storefront.ImageTransformInput(maxWidth: 932)
				)
			}
			.variants(first: 1) { $0
				.nodes { $0
					.id()
					.title()
					.price { $0
						.amount()
						.currencyCode()
					}
				}
			}
	}
}

extension Storefront.CartQuery {
	@discardableResult
	func cartManagerFragment() -> Storefront.CartQuery {
		self
			.id()
			.checkoutUrl()
			.totalQuantity()
			.lines(first: 250) { $0
				.nodes { $0
					.id()
					.quantity()
					.merchandise { $0
						.onProductVariant { $0
							.title()
							.price({ $0
								.amount()
								.currencyCode()
							})
							.product { $0
								.title()
								.vendor()
								.availableForSale()
								.featuredImage { $0
									.url(
										transform: Storefront.ImageTransformInput(maxWidth: 120)
									)
								}
							}
						}
					}
				}
			}
			.cost { $0
				.totalAmount({ $0
					.amount()
					.currencyCode()
				})
				.subtotalAmount { $0
					.amount()
					.currencyCode()
				}
			}
	}
}

extension Storefront.CountryCode {
	static func inferRegion() -> Storefront.CountryCode {
		if #available(iOS 16, *) {
			if let regionCode = Locale.current.region?.identifier {
				return Storefront.CountryCode(rawValue: regionCode) ?? .ca
			}
		}

		return .ca
	}
}

extension Storefront.MoneyV2 {
	func formattedString() -> String? {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencyCode = currencyCode.rawValue
		return formatter.string(from: NSDecimalNumber(decimal: amount))
	}
}

extension Storefront {
	func inferContext() -> Storefront.InContextDirective {
		return Storefront.InContextDirective(country: Storefront.CountryCode.inferRegion())
	}
}
