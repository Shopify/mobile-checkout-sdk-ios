//
//  ClientQuery.swift
//  Storefront
//
//  Created by Shopify.
//  Copyright (c) 2017 Shopify Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit
import Buy
import Pay

final class ClientQuery {

	static let maxImageDimension = Int32(UIScreen.main.bounds.width)
	
	// ----------------------------------
	//  MARK: - Customers -
	//
	static func mutationForLogin(email: String, password: String) -> Storefront.MutationQuery {
		let input = Storefront.CustomerAccessTokenCreateInput(email: email, password: password)
		return Storefront.buildMutation { $0
			.customerAccessTokenCreate(input: input) { $0
				.customerAccessToken { $0
					.accessToken()
					.expiresAt()
				}
				.customerUserErrors { $0
					.code()
					.field()
					.message()
				}
			}
		}
	}
	
	static func mutationForLogout(accessToken: String) -> Storefront.MutationQuery {
		return Storefront.buildMutation { $0
			.customerAccessTokenDelete(customerAccessToken: accessToken) { $0
				.deletedAccessToken()
				.userErrors { $0
					.field()
					.message()
				}
			}
		}
	}
	
	static func queryForCustomer(limit: Int, after cursor: String? = nil, accessToken: String) -> Storefront.QueryRootQuery {
		return Storefront.buildQuery { $0
			.customer(customerAccessToken: accessToken) { $0
				.id()
				.displayName()
				.email()
				.firstName()
				.lastName()
				.phone()
				.updatedAt()
				.orders(first: Int32(limit), after: cursor) { $0
					.fragmentForStandardOrder()
				}
			}
		}
	}
	
	// ----------------------------------
	//  MARK: - Shop -
	//
	static func queryForShopName() -> Storefront.QueryRootQuery {
		return Storefront.buildQuery { $0
			.shop { $0
				.name()
			}
		}
	}
	
	static func queryForShopURL() -> Storefront.QueryRootQuery {
		return Storefront.buildQuery { $0
			.shop { $0
				.primaryDomain { $0
					.url()
				}
			}
		}
	}
	
	// ----------------------------------
	//  MARK: - Storefront -
	//
	static func queryForCollections(limit: Int, after cursor: String? = nil, productLimit: Int = 25, productCursor: String? = nil) -> Storefront.QueryRootQuery {
		return Storefront.buildQuery { $0
			.collections(first: Int32(limit), after: cursor) { $0
				.pageInfo { $0
					.hasNextPage()
				}
				.edges { $0
					.cursor()
					.node { $0
						.id()
						.title()
						.descriptionHtml()
						.image { $0
							.url()
						}
						
						.products(first: Int32(productLimit), after: productCursor) { $0
							.fragmentForStandardProduct()
						}
					}
				}
			}
		}
	}
	
	// ----------------------------------
	//  MARK: - Checkout -
	//
	static func mutationForCreateCheckout(with cartItems: [BaseCartLine]) -> Storefront.MutationQuery {
		let lineItems = cartItems.map { item in
			let variant = item.merchandise as? Storefront.ProductVariant
			return Storefront.CheckoutLineItemInput.create(quantity: Int32(item.quantity), variantId: variant!.id)
		}
		
		let checkoutInput = Storefront.CheckoutCreateInput.create(
			lineItems: .value(lineItems),
			allowPartialAddresses: .value(true)
		)
		
		return Storefront.buildMutation { $0
			.checkoutCreate(input: checkoutInput) { $0
				.checkout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func queryForCheckout(_ id: String) -> Storefront.QueryRootQuery {
		Storefront.buildQuery { $0
			.node(id: GraphQL.ID(rawValue: id)) { $0
				.onCheckout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func mutationForUpdateCheckout(_ id: String, updatingPartialShippingAddress address: PayPostalAddress) -> Storefront.MutationQuery {
		
		let checkoutID   = GraphQL.ID(rawValue: id)
		let addressInput = Storefront.MailingAddressInput.create(
			city:     address.city.orNull,
			country:  address.country.orNull,
			province: address.province.orNull,
			zip:      address.zip.orNull
		)
		
		return Storefront.buildMutation { $0
			.checkoutShippingAddressUpdateV2(shippingAddress: addressInput, checkoutId: checkoutID) { $0
				.checkoutUserErrors { $0
					.field()
					.message()
				}
				.checkout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func mutationForUpdateCheckout(_ id: GraphQL.ID, updatingCompleteShippingAddress address: PayAddress) -> Storefront.MutationQuery {
		
		let checkoutID   = id
		let addressInput = Storefront.MailingAddressInput.create(
			address1:  address.addressLine1.orNull,
			address2:  address.addressLine2.orNull,
			city:      address.city.orNull,
			country:   address.country.orNull,
			firstName: address.firstName.orNull,
			lastName:  address.lastName.orNull,
			phone:     address.phone.orNull,
			province:  address.province.orNull,
			zip:       address.zip.orNull
		)
		
		return Storefront.buildMutation { $0
			.checkoutShippingAddressUpdateV2(shippingAddress: addressInput, checkoutId: checkoutID) { $0
				.checkoutUserErrors { $0
					.field()
					.message()
				}
				.checkout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func mutationForUpdateCheckout(_ id: GraphQL.ID, updatingShippingRate shippingRate: Storefront.ShippingRate) -> Storefront.MutationQuery {
		
		return Storefront.buildMutation { $0
			.checkoutShippingLineUpdate(checkoutId: id, shippingRateHandle: shippingRate.handle) { $0
				.checkoutUserErrors { $0
					.field()
					.message()
				}
				.checkout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func mutationForUpdateCheckout(_ id: GraphQL.ID, updatingEmail email: String) -> Storefront.MutationQuery {
		
		return Storefront.buildMutation { $0
			.checkoutEmailUpdateV2(checkoutId: id, email: email) { $0
				.checkoutUserErrors { $0
					.field()
					.message()
				}
				.checkout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func mutationForUpdateCheckout(_ checkoutID: String, associatingCustomer accessToken: String) -> Storefront.MutationQuery {
		let id = GraphQL.ID(rawValue: checkoutID)
		return Storefront.buildMutation { $0
			.checkoutCustomerAssociateV2(checkoutId: id, customerAccessToken: accessToken) { $0
				.checkoutUserErrors { $0
					.field()
					.message()
				}
				.checkout { $0
					.fragmentForCheckout()
				}
			}
		}
	}
	
	static func mutationForCompleteCheckoutUsingApplePay(_ checkout: Storefront.Checkout, billingAddress: PayAddress, token: String, idempotencyToken: String) -> Storefront.MutationQuery {
		
		let mailingAddress = Storefront.MailingAddressInput.create(
			address1:  billingAddress.addressLine1.orNull,
			address2:  billingAddress.addressLine2.orNull,
			city:      billingAddress.city.orNull,
			country:   billingAddress.country.orNull,
			firstName: billingAddress.firstName.orNull,
			lastName:  billingAddress.lastName.orNull,
			province:  billingAddress.province.orNull,
			zip:       billingAddress.zip.orNull
		)
		
		let currencyCode  = Storefront.CurrencyCode(rawValue: checkout.currencyCode.rawValue)!
		let paymentAmount = Storefront.MoneyInput(amount: checkout.paymentDue.amount, currencyCode: currencyCode)
		let paymentInput  = Storefront.TokenizedPaymentInputV3.create(
			paymentAmount:  paymentAmount,
			idempotencyKey: idempotencyToken,
			billingAddress: mailingAddress,
			paymentData:    token,
			type:           Storefront.PaymentTokenType.applePay,
			test: .value(true)
		)
		
		return Storefront.buildMutation { $0
			.checkoutCompleteWithTokenizedPaymentV3(checkoutId: checkout.id, payment: paymentInput) { $0
				.checkoutUserErrors { $0
					.field()
					.message()
				}
				.payment { $0
					.fragmentForPayment()
				}
			}
		}
	}
	
	static func queryForPayment(_ id: String) -> Storefront.QueryRootQuery {
		return Storefront.buildQuery { $0
			.node(id: GraphQL.ID(rawValue: id)) { $0
				.onPayment { $0
					.fragmentForPayment()
				}
			}
		}
	}
	
	static func queryShippingRatesForCheckout(_ id: GraphQL.ID) -> Storefront.QueryRootQuery {
		
		return Storefront.buildQuery { $0
			.node(id: id) { $0
				.onCheckout { $0
					.fragmentForCheckout()
					.availableShippingRates { $0
						.ready()
						.shippingRates { $0
							.handle()
							.price { $0
								.amount()
								.currencyCode()
							}
							.title()
						}
					}
				}
			}
		}
	}
}
