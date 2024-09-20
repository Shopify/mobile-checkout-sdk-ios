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

// swiftlint:disable file_length

import Foundation

public enum PixelEvent {
	case customEvent(CustomEvent)
	case standardEvent(StandardEvent)
	case alertDisplayedEvent(AlertDisplayedEvent)
	case uiExtensionErroredEvent(UIExtensionErroredEvent)
}

public struct AlertDisplayedEvent: Codable {
	public let context: Context?
	/// The ID of the customer event
	public let id: String?
	/// The name of the customer event
	public let name: String?
	/// The timestamp of when the customer event occurred, in [ISO
	/// 8601](https://en.wikipedia.org/wiki/ISO_8601) format
	public let timestamp: String?

	public let data: AlertDisplayedEventData?

	enum CodingKeys: String, CodingKey {
		case context, data, id, name, timestamp
	}
}

public struct AlertDisplayedEventData: Codable {
	public let alert: AlertDisplayedEventDataAlert?
}

public struct AlertDisplayedEventDataAlert: Codable {
	/// The part of the page the alert relates to.
	/// Follows the [Shopify Functions target format], for example "cart.deliveryGroups[0].deliveryAddress.address1".
	public let target: String?
	/// The value of the field at the time the alert was displayed or null if the error does not relate to an individual field.
	public let value: String?
	/// The type of alert that was displayed, current possible values are:
	/// The type of error that occurred, current possible values are:
	/// - `INPUT_REQUIRED` - A required field is empty.
	/// - `INPUT_INVALID` - The input provided is incorrect or improperly formatted.
	/// - `CONTACT_ERROR` - An alert related to a contact information issue was displayed.
	/// - `DELIVERY_ERROR` - An alert related to a delivery issue was displayed.
	/// - `PAYMENT_ERROR` - An alert related to a payment issue was displayed.
	/// - `DISCOUNT_ERROR` - An alert related to a discount code or gift card issue was displayed.
	/// - `INVENTORY_ERROR` - An alert related to an inventory issue was displayed.
	/// - `MERCHANDISE_ERROR` - An alert related to a merchandise issue was displayed.
	/// - `CHECKOUT_ERROR` - An alert related to a general checkout issue was displayed.
	public let type: String?
	/// The message that was displayed to the user when the alert was displayed.
	public let message: String?
}

public struct UIExtensionErroredEvent: Codable {
	public let context: Context?
	/// The ID of the customer event
	public let id: String?
	/// The name of the customer event
	public let name: String?
	/// The timestamp of when the customer event occurred, in [ISO
	/// 8601](https://en.wikipedia.org/wiki/ISO_8601) format
	public let timestamp: String?

	public let data: UIExtensionErroredEventData?

	enum CodingKeys: String, CodingKey {
		case context, data, id, name, timestamp
	}
}

public struct UIExtensionErroredEventData: Codable {
	public let error: UIExtensionErroredEventDataError?
}

public struct UIExtensionErroredEventDataError: Codable {
	/// The type of error that occurred. Current possible values:
	///  - `EXTENSION_USAGE_ERROR` - An error caused by incorrect usage of extension APIs or UI components.
	public let type: String?
	/// The unique identifier of the app that the extension belongs to.
	public let appId: String?
	///  The name of the app that the extension belongs to.
	public let appName: String?
	/// The API version used by the extension
	public let apiVersion: String?
	/// The version of the app that encountered the error.
	public let appVersion: String?
	/// The name of the extension that encountered the error.
	public let extensionName: String?
	/// The [target](https://shopify.dev/docs/api/checkout-ui-extensions/latest/targets) of the extension, for example
	/// "purchase.checkout.delivery-address.render-after".
	public let extensionTarget: String?
	/// The [placement reference](https://shopify.dev/docs/apps/build/checkout/test-checkout-ui-extensions#dynamic-targets) of the extension,
	/// only populated for dynamic targets.
	public let placementReference: String?
	/// The message associated with the error that occurred.
	public let message: String?
	/// The stack trace associated with the error that occurred.
	public let trace: String?
}

public struct StandardEvent: Codable {
	public let context: Context?
	/// The ID of the customer event
	public let id: String?
	/// The name of the customer event
	public let name: String?
	/// The timestamp of when the customer event occurred, in [ISO
	/// 8601](https://en.wikipedia.org/wiki/ISO_8601) format
	public let timestamp: String?

	public let data: StandardEventData?

	enum CodingKeys: String, CodingKey {
		case context, data, id, name, timestamp
	}
}

public struct StandardEventData: Codable {
	public let checkout: Checkout?
}

/// This event represents any custom events emitted by partners or merchants via
/// the `publish` method
public struct CustomEvent: Codable {
	public let context: Context?
	public let customData: String?
	/// The ID of the customer event
	public let id: String?
	/// The name of the customer event
	public let name: String?
	/// The timestamp of when the customer event occurred, in [ISO
	/// 8601](https://en.wikipedia.org/wiki/ISO_8601) format
	public let timestamp: String?

	enum CodingKeys: String, CodingKey {
		case context, customData, id, name, timestamp
	}
}

// MARK: - Context

/// A snapshot of various read-only properties of the browser at the time of
/// event
public struct Context: Codable {
	/// Snapshot of a subset of properties of the `document` object in the top
	/// frame of the browser
	public let document: WebPixelsDocument?
	/// Snapshot of a subset of properties of the `navigator` object in the top
	/// frame of the browser
	public let navigator: WebPixelsNavigator?
	/// Snapshot of a subset of properties of the `window` object in the top frame
	/// of the browser
	public let window: WebPixelsWindow?
}

// MARK: - WebPixelsDocument

/// A snapshot of a subset of properties of the `document` object in the top
/// frame of the browser
public struct WebPixelsDocument: Codable {
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Document),
	/// returns the character set being used by the document
	public let characterSet: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Document),
	/// returns the URI of the current document
	public let location: Location?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Document),
	/// returns the URI of the page that linked to this page
	public let referrer: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Document),
	/// returns the title of the current document
	public let title: String?
}

// MARK: - Location

/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), the
/// location, or current URL, of the window object
public struct Location: Codable {
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing a `'#'` followed by the fragment identifier of the URL
	public let hash: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing the host, that is the hostname, a `':'`, and the port of
	/// the URL
	public let host: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing the domain of the URL
	public let hostname: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing the entire URL
	public let href: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing the canonical form of the origin of the specific location
	public let origin: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing an initial `'/'` followed by the path of the URL, not
	/// including the query string or fragment
	public let pathname: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing the port number of the URL
	public let port: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing the protocol scheme of the URL, including the final `':'`
	public let locationProtocol: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Location), a
	/// string containing a `'?'` followed by the parameters or "querystring" of
	/// the URL
	public let search: String?

	enum CodingKeys: String, CodingKey {
		case hash, host, hostname, href, origin, pathname, port
		case locationProtocol = "protocol"
		case search
	}
}

// MARK: - WebPixelsNavigator

/// A snapshot of a subset of properties of the `navigator` object in the top
/// frame of the browser
public struct WebPixelsNavigator: Codable {
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Navigator),
	/// returns `false` if setting a cookie will be ignored and true otherwise
	public let cookieEnabled: Bool?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Navigator),
	/// returns a string representing the preferred language of the user, usually
	/// the language of the browser UI. The `null` value is returned when this
	/// is unknown
	public let language: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Navigator),
	/// returns an array of strings representing the languages known to the user,
	/// by order of preference
	public let languages: [String]?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Navigator),
	/// returns the user agent string for the current browser
	public let userAgent: String?
}

// MARK: - WebPixelsWindow

/// A snapshot of a subset of properties of the `window` object in the top frame
/// of the browser
public struct WebPixelsWindow: Codable {
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window),
	/// gets the height of the content area of the browser window including, if
	/// rendered, the horizontal scrollbar
	public let innerHeight: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), gets
	/// the width of the content area of the browser window including, if rendered,
	/// the vertical scrollbar
	public let innerWidth: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), the
	/// location, or current URL, of the window object
	public let location: Location?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), the
	/// global object's origin, serialized as a string
	public let origin: String?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), gets
	/// the height of the outside of the browser window
	public let outerHeight: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), gets
	/// the width of the outside of the browser window
	public let outerWidth: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), an
	/// alias for window.scrollX
	public let pageXOffset: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), an
	/// alias for window.scrollY
	public let pageYOffset: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Screen), the
	/// interface representing a screen, usually the one on which the current
	/// window is being rendered
	public let screen: Screen?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), the
	/// horizontal distance from the left border of the user's browser viewport to
	/// the left side of the screen
	public let screenX: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), the
	/// vertical distance from the top border of the user's browser viewport to the
	/// top side of the screen
	public let screenY: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), the
	/// number of pixels that the document has already been scrolled horizontally
	public let scrollX: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window), the
	/// number of pixels that the document has already been scrolled vertically
	public let scrollY: Double?
}

// MARK: - Screen

/// The interface representing a screen, usually the one on which the current
/// window is being rendered
public struct Screen: Codable {
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Screen/height),
	/// the height of the screen
	public let height: Double?
	/// Per [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Screen/width),
	/// the width of the screen
	public let width: Double?
}

// MARK: - MoneyV2

/// The monetary value with currency allocated to the transaction method.
public struct MoneyV2: Codable {
	/// The decimal money amount.
	public let amount: Double?
	/// The three-letter code that represents the currency, for example, USD.
	/// Supported codes include standard ISO 4217 codes, legacy codes, and non-
	/// standard codes.
	public let currencyCode: String?
}

// MARK: - CartLine

/// Information about the merchandise in the cart.
public struct CartLine: Codable {
	/// The cost of the merchandise that the customer will pay for at checkout. The
	/// costs are subject to change and changes will be reflected at checkout.
	public let cost: CartLineCost?
	/// The merchandise that the buyer intends to purchase.
	public let merchandise: ProductVariant?
	/// The quantity of the merchandise that the customer intends to purchase.
	public let quantity: Double?
}

// MARK: - CartLineCost

/// The cost of the merchandise line that the customer will pay at checkout.
public struct CartLineCost: Codable {
	/// The total cost of the merchandise line.
	public let totalAmount: MoneyV2?
}

// MARK: - ProductVariant

/// A product variant represents a different version of a product, such as
/// differing sizes or differing colors.
public struct ProductVariant: Codable {
	/// A globally unique identifier.
	public let id: String?
	/// Image associated with the product variant. This field falls back to the
	/// product image if no image is available.
	public let image: Image?
	/// The product variant’s price.
	public let price: MoneyV2?
	/// The product object that the product variant belongs to.
	public let product: Product?
	/// The SKU (stock keeping unit) associated with the variant.
	public let sku: String?
	/// The product variant’s title.
	public let title: String?
	/// The product variant’s untranslated title.
	public let untranslatedTitle: String?
}

// MARK: - Image

/// An image resource.
public struct Image: Codable {
	/// The location of the image as a URL.
	public let src: String?
}

// MARK: - Product

/// A product is an individual item for sale in a Shopify store.
public struct Product: Codable {
	/// The ID of the product.
	public let id: String?
	/// The product’s title.
	public let title: String?
	/// The [product
	/// type](https://help.shopify.com/en/manual/products/details/product-type)
	/// specified by the merchant.
	public let type: String?
	/// The product’s untranslated title.
	public let untranslatedTitle: String?
	/// The relative URL of the product.
	public let url: String?
	/// The product’s vendor name.
	public let vendor: String?
}

// MARK: - Checkout

/// A container for all the information required to add items to checkout and
/// pay.
public struct Checkout: Codable {
	/// A list of attributes accumulated throughout the checkout process.
	public let attributes: [Attribute]?
	/// The billing address to where the order will be charged.
	public let billingAddress: MailingAddress?
	/// Indicates whether the customer has consented to be sent marketing material via email.
	public let buyerAcceptsEmailMarketing: Bool?
	/// Indicates whether the customer has consented to be sent marketing material via SMS.
	public let buyerAcceptsSmsMarketing: Bool?
	/// The three-letter code that represents the currency, for example, USD.
	/// Supported codes include standard ISO 4217 codes, legacy codes, and non-
	/// standard codes.
	public let currencyCode: String?
	/// Represents the selected delivery options for a checkout.
	public let delivery: Delivery?
	/// A list of discount applications.
	public let discountApplications: [DiscountApplication]?
	/// The total amount of the discounts applied to the price of the checkout.
	public let discountsAmount: MoneyV2?
	/// The email attached to this checkout.
	public let email: String?
	/// A list of line item objects, each one containing information about an item
	/// in the checkout.
	public let lineItems: [CheckoutLineItem]?
	/// The total amount of the discounts applied to the price of the checkout.
	public let localization: Localization?
	/// The resulting order from a paid checkout.
	public let order: Order?
	/// A unique phone number for the customer. Formatted using E.164 standard. For
	/// example, *+16135551111*.
	public let phone: String?
	/// The shipping address to where the line items will be shipped.
	public let shippingAddress: MailingAddress?
	/// Once a shipping rate is selected by the customer it is transitioned to a
	/// `shipping_line` object.
	public let shippingLine: ShippingRate?
	/// The phone number provided by the buyer after opting in to SMS marketing.
	public let smsMarketingPhone: String?
	/// The price at checkout before duties, shipping, and taxes.
	public let subtotalPrice: MoneyV2?
	/// A unique identifier for a particular checkout.
	public let token: String?
	/// The sum of all the prices of all the items in the checkout, including
	/// duties, taxes, and discounts.
	public let totalPrice: MoneyV2?
	/// The sum of all the taxes applied to the line items and shipping lines in
	/// the checkout.
	public let totalTax: MoneyV2?
	/// A list of transactions associated with a checkout or order.
	public let transactions: [Transaction]?
}

// MARK: - Attribute

/// Custom attributes left by the customer to the merchant, either in their cart
/// or during checkout.
public struct Attribute: Codable {
	/// The key for the attribute.
	public let key: String?
	/// The value for the attribute.
	public let value: String?
}

public struct Country: Codable {
	/// The ISO-3166-1 code for this country, for example, "US".
	public let isoCode: String?
}

public struct Language: Codable {
	/// Te BCP-47 language tag. It may contain a dash followed by an
	/// ISO 3166-1 alpha-2 region code, for example, "en-US".
	public let isoCode: String?
}

public struct Market: Codable {
	/// A human-readable, shop-scoped identifier.
	public let handle: String?
	/// A globally unique identifier.
	public let id: String?
}

public struct Localization: Codable {
	/// The country of the active localized experience.
	public let country: Country?
	/// The language of the active localized experience.
	public let language: Language?
	/// The market including the country of the active localized experience.
	public let market: Market?
}

// MARK: - MailingAddress

/// A mailing address for customers and shipping.
public struct MailingAddress: Codable {
	/// The first line of the address. This is usually the street address or a P.O.
	/// Box number.
	public let address1: String?
	/// The second line of the address. This is usually an apartment, suite, or
	/// unit number.
	public let address2: String?
	/// The name of the city, district, village, or town.
	public let city: String?
	/// The name of the country.
	public let country: String?
	/// The two-letter code that represents the country, for example, US.
	/// The country codes generally follows ISO 3166-1 alpha-2 guidelines.
	public let countryCode: String?
	/// The customer’s first name.
	public let firstName: String?
	/// The customer’s last name.
	public let lastName: String?
	/// The phone number for this mailing address as entered by the customer.
	public let phone: String?
	/// The region of the address, such as the province, state, or district.
	public let province: String?
	/// The two-letter code for the region.
	/// For example, ON.
	public let provinceCode: String?
	/// The ZIP or postal code of the address.
	public let zip: String?
}

// MARK: - DiscountApplication

/// The information about the intent of the discount.
public struct DiscountApplication: Codable {
	/// The method by which the discount's value is applied to its entitled items.
	///
	/// - `ACROSS`: The value is spread across all entitled lines.
	/// - `EACH`: The value is applied onto every entitled line.
	public let allocationMethod: String?
	/// How the discount amount is distributed on the discounted lines.
	///
	/// - `ALL`: The discount is allocated onto all the lines.
	/// - `ENTITLED`: The discount is allocated onto only the lines that it's
	/// entitled for.
	/// - `EXPLICIT`: The discount is allocated onto explicitly chosen lines.
	public let targetSelection: String?
	/// The type of line (i.e. line item or shipping line) on an order that the
	/// discount is applicable towards.
	///
	/// - `LINE_ITEM`: The discount applies onto line items.
	/// - `SHIPPING_LINE`: The discount applies onto shipping lines.
	public let targetType: String?
	/// The customer-facing name of the discount. If the type of discount is
	/// a `DISCOUNT_CODE`, this `title` attribute represents the code of the
	/// discount.
	public let title: String?
	/// The type of the discount.
	///
	/// - `AUTOMATIC`: A discount automatically at checkout or in the cart without
	/// the need for a code.
	/// - `DISCOUNT_CODE`: A discount applied onto checkouts through the use of
	/// a code.
	/// - `MANUAL`: A discount that is applied to an order by a merchant or store
	/// owner manually, rather than being automatically applied by the system or
	/// through a script.
	/// - `SCRIPT`: A discount applied to a customer's order using a script
	public let type: String?
	/// The value of the discount. Fixed discounts return a `Money` Object, while
	/// Percentage discounts return a `PricingPercentageValue` object.
	public let value: Value?
}

// MARK: - Value

/// A value given to a customer when a discount is applied to an order. The
/// application of a discount with this value gives the customer the specified
/// percentage off a specified item.
public struct Value: Codable {
	/// The decimal money amount.
	public let amount: Double?
	/// The three-letter code that represents the currency, for example, USD.
	/// Supported codes include standard ISO 4217 codes, legacy codes, and non-
	/// standard codes.
	public let currencyCode: String?
	/// The percentage value of the object.
	public let percentage: Double?
}

// MARK: - CheckoutLineItem

/// A single line item in the checkout, grouped by variant and attributes.
public struct CheckoutLineItem: Codable {
	/// The discounts that have been applied to the checkout line item by a discount application.
	public let discountAllocations: [DiscountAllocation]?
	/// The combined price of all of the items in the line item after line-level discounts have been applied.
	public let finalLinePrice: MoneyV2?
	/// A globally unique identifier.
	public let id: String?
	/// The properties of the line item. A shop may add, or enable customers to add custom information to a line item.
	/// Line item propertiesof a key and value pair.
	public let properties: [Property]?
	/// The quantity of the line item.
	public let quantity: Double?
	/// The selling plan associated with the line item and the effect that each selling plan has on variants when they're purchased.
	public let sellingPlanAllocation: SellingPlanAllocation?
	/// The title of the line item. Defaults to the product's title.
	public let title: String?
	/// Product variant of the line item.
	public let variant: ProductVariant?
}

public struct Delivery: Codable {
	/// The selected delivery options for the event.
	public let selectedDeliveryOptions: [DeliveryOption]?
}

public struct DeliveryOption: Codable {
	/// The cost of the delivery option.
	public let cost: MoneyV2?

	/// The cost of the delivery option after discounts have been applied.
	public let costAfterDiscounts: MoneyV2?

	/// The description of the delivery option.
	public let description: String?

	/// The unique identifier of the delivery option.
	public let handle: String?

	/// The title of the delivery option.
	public let title: String?

	/// The type of delivery option, e.g. pickup, pickupPoint, shipping, local.
	public let type: String?
}

// MARK: - DiscountAllocation

/// The discount that has been applied to the checkout line item.
public struct DiscountAllocation: Codable {
	/// The monetary value with currency allocated to the discount.
	public let amount: MoneyV2?
	/// The information about the intent of the discount.
	public let discountApplication: DiscountApplication?
}

// MARK: - Order

/// An order is a customer’s completed request to purchase one or more products
/// from a shop. An order is created when a customer completes the checkout
/// process.
public struct Order: Codable {
	/// The customer that placed the order
	public let customer: OrderCustomer?
	/// The ID of the order.
	public let id: String?
}

public struct OrderCustomer: Codable {
	/// The ID of the customer.
	public let id: String?
}

public struct Property: Codable {
	/// The key of the property.
	public let key: String?
	/// The value of the property.
	public let value: String?
}

public struct SellingPlanAllocation: Codable {
	public let sellingPlan: SellingPlan?
}

public struct SellingPlan: Codable {
	/// A globally unique identifier.
	public let id: String?
	/// The name of the selling plan. For example, '6 weeks of prepaid granola, delivered weekly'.
	public let name: String?
}

// MARK: - ShippingRate

/// A shipping rate to be applied to a checkout.
public struct ShippingRate: Codable {
	/// Price of this shipping rate.
	public let price: MoneyV2?
}

// MARK: - Transaction

/// A transaction associated with a checkout or order.
public struct Transaction: Codable {
	/// The monetary value with currency allocated to the transaction method.
	public let amount: MoneyV2?
	/// The name of the payment provider used for the transaction.
	public let gateway: String?
	/// The payment method used for the transaction.
	public let paymentMethod: TransactionPaymentMethod?
}

public struct TransactionPaymentMethod: Codable {
	/// The name of the payment method used for the transaction. This may further specify the payment method used.
	public let name: String?

	/// The type of payment method used for the transaction.
	/// - creditCard: A vaulted or manually entered credit card.
	/// - redeemable: A redeemable payment method, such as a gift card or store credit.
	/// - deferred: A deferred payment, such as invoicing the buyer and collecting payment later.
	/// - local: A local payment method specific to the current region or market.
	/// - manualPayment: A manual payment method, such as an in-person retail transaction.
	/// - paymentOnDelivery: A payment that will be collected on delivery.
	/// - wallet: An integrated wallet, such as PayPal, Google Pay, Apple Pay, etc.
	/// - offsite: A payment processed outside of Shopify's checkout, excluding integrated wallets.
	/// - customOnSite: A custom payment method that is processed through a checkout extension with a payments app.
	/// - other: Another type of payment not defined here.
	public let type: String?
}

// MARK: PixelEventsCheckoutCompleted convenience initializers and mutators

extension AlertDisplayedEvent {
	init(from webPixelsEventBody: WebPixelsEventBody) {
		self.context = webPixelsEventBody.context
		self.id = webPixelsEventBody.id
		self.name = webPixelsEventBody.name
		self.timestamp = webPixelsEventBody.timestamp
		if let dataDict = webPixelsEventBody.data {
			self.data = AlertDisplayedEventData(from: dataDict)
		} else {
			self.data = nil
		}
	}
}

extension AlertDisplayedEventData {
	init?(from dictionary: [String: Any]) {
		guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
			  let pixelData = try? JSONDecoder().decode(AlertDisplayedEventData.self, from: jsonData) else {
			return nil
		}
		self = pixelData
	}
}

extension UIExtensionErroredEvent {
	init(from webPixelsEventBody: WebPixelsEventBody) {
		self.context = webPixelsEventBody.context
		self.id = webPixelsEventBody.id
		self.name = webPixelsEventBody.name
		self.timestamp = webPixelsEventBody.timestamp
		if let dataDict = webPixelsEventBody.data {
			self.data = UIExtensionErroredEventData(from: dataDict)
		} else {
			self.data = nil
		}
	}
}

extension UIExtensionErroredEventData {
	init?(from dictionary: [String: Any]) {
		guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
			  let pixelData = try? JSONDecoder().decode(UIExtensionErroredEventData.self, from: jsonData) else {
			return nil
		}
		self = pixelData
	}
}

extension StandardEvent {
	init(from webPixelsEventBody: WebPixelsEventBody) {
		self.context = webPixelsEventBody.context
		self.id = webPixelsEventBody.id
		self.name = webPixelsEventBody.name
		self.timestamp = webPixelsEventBody.timestamp

		if let dataDict = webPixelsEventBody.data {
			self.data = StandardEventData(from: dataDict)
		} else {
			self.data = nil
		}
	}
}

extension StandardEventData {
	init?(from dictionary: [String: Any]) {
		guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
			let pixelData = try? JSONDecoder().decode(StandardEventData.self, from: jsonData) else {
				return nil
			}
		self = pixelData
	}
}

// MARK: CustomEvent convenience initializers and mutators

extension CustomEvent {
	init(from webPixelsEventBody: WebPixelsEventBody) {
		self.context = webPixelsEventBody.context
		self.customData = webPixelsEventBody.customData
		self.id = webPixelsEventBody.id
		self.name = webPixelsEventBody.name
		self.timestamp = webPixelsEventBody.timestamp
	}
}

// MARK: - CustomData

/// A free-form object representing data specific to a custom event provided by
/// the custom event publisher
public struct CustomData: Codable {
}

// MARK: - PricingPercentageValue

/// A value given to a customer when a discount is applied to an order. The
/// application of a discount with this value gives the customer the specified
/// percentage off a specified item.
public struct PricingPercentageValue: Codable {
	/// The percentage value of the object.
	let percentage: Double?
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
	let decoder = JSONDecoder()
	if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
		decoder.dateDecodingStrategy = .iso8601
	}
	return decoder
}

func newJSONEncoder() -> JSONEncoder {
	let encoder = JSONEncoder()
	if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
		encoder.dateEncodingStrategy = .iso8601
	}
	return encoder
}

// swiftlint:enable file_length
