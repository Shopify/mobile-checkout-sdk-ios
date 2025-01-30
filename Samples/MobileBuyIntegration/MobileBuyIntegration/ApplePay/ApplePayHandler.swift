/*
 MIT License

 Copyright 2025 - Present, Shopify Inc.

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
import PassKit
import ShopifyCheckoutSheetKit
import UIKit

typealias PaymentCompletionHandler = (Bool) -> Void

class ApplePayHandler: NSObject {
    // MARK: Properties

    /**
     * Starts as nil when no payment status has been made
     * Question: Should be reset to nil when starting a new payment process?
     */
    var paymentStatus: PKPaymentAuthorizationStatus?
    /**
     * Instantiated during `startPayment`
     * called at the end of the payment process after PaymentHandler#didAuthorizePayment
     */
    var paymentCompletionHandler: PaymentCompletionHandler?

    /**
     * Card types not present in this list will not be shown as available for ApplePay
     */
    static let SupportedNetworks: [PKPaymentNetwork] = [
        .amex,
        .discover,
        .masterCard,
        .visa
    ]

    /*
     * The merchant’s two-letter ISO 3166 country code.
     */
    static let CountryCode = "US"
    /**
     * The three-letter ISO 4217 currency code that determines the currency the payment request uses.
     */
    static let CurrencyCode = "USD"

    /**
     * This value must match one of the merchant identifiers specified by the Merchant IDs
     * Entitlement key in the app’s entitlements. For more information on adding merchant IDs,
     * see Configure Apple Pay (iOS, watchOS).*
     * @see: https://developer.apple.com/documentation/passkit_apple_pay_and_wallet/pkpaymentrequest/1619305-merchantidentifier
     */
    static let MerchantId = "merchant.com.shopify.example.MobileBuyIntegration.ApplePay"

    func startApplePayCheckout(completion: @escaping PaymentCompletionHandler) {
        paymentCompletionHandler = completion

        let paymentSummaryItems = PassKitFactory.shared.createPaymentSummaryItems()

        let paymentRequest = PassKitFactory.shared.createPaymentRequest(
            paymentSummaryItems: paymentSummaryItems
        )

        // Display the payment request.
        let paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController.delegate = self
        paymentController.present(completion: { (presented: Bool) in
            if !presented {
                debugPrint("Failed to present payment controller, falling back to CSK")
                self.paymentCompletionHandler?(false)
            }
        })
    }
}

extension ApplePayHandler: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(
        _: PKPaymentAuthorizationController,
        didSelectShippingMethod shippingMethod: PKShippingMethod
    ) async -> PKPaymentRequestShippingMethodUpdate {
        guard let identifier = shippingMethod.identifier else {
            print(CartManager.Errors.invariant(message: "Shipping method identifier is nil"))
            return PKPaymentRequestShippingMethodUpdate(
                paymentSummaryItems: PassKitFactory.shared.createPaymentSummaryItems(
                    cart: CartManager.shared.cart,
                    shippingMethod: nil
                )
            )
        }

        do {
            _ = try await CartManager.shared.performCartSelectedDeliveryOptionsUpdate(
                deliveryOptionHandle: identifier
            )

            let cart = try await CartManager.shared.performCartPrepareForCompletion()

            let paymentRequestShippingContactUpdate = PKPaymentRequestShippingMethodUpdate(
                paymentSummaryItems: PassKitFactory.shared.createPaymentSummaryItems(
                    cart: cart,
                    shippingMethod: shippingMethod
                )
            )
            return paymentRequestShippingContactUpdate
        } catch {
            print(
                CartManager.Errors.apiErrors(
                    requestName: "cartSelectedDeliveryOptionsUpdate  or cartPrepareForCompletion",
                    message:
                    "Check response from cartSelectedDeliveryOptionsUpdate or cartPrepareForCompletion \(error)"
                )
            )

            return PKPaymentRequestShippingMethodUpdate(
                paymentSummaryItems: PassKitFactory.shared.createPaymentSummaryItems(
                    cart: CartManager.shared.cart,
                    shippingMethod: nil
                )
            )
        }
    }

    func paymentAuthorizationController(
        _: PKPaymentAuthorizationController,
        didSelectShippingContact contact: PKContact
    ) async -> PKPaymentRequestShippingContactUpdate {
        do {
            _ = try await CartManager.shared.performBuyerIdentityUpdate(
                contact: contact,
                partial: true
            )

            guard let firstDeliveryGroup = CartManager.shared.cart?.deliveryGroups.nodes.first
            else {
                throw CartManager.Errors.invariant(message: "deliveryGroups empty")
            }

            let shippingMethods = PassKitFactory.shared.createShippingMethods(
                firstDeliveryGroup: firstDeliveryGroup
            )

            _ = try await CartManager.shared.performCartPrepareForCompletion()

            return PKPaymentRequestShippingContactUpdate(
                errors: [],
                paymentSummaryItems: PassKitFactory.shared.createPaymentSummaryItems(
                    cart: CartManager.shared.cart,
                    shippingMethod: nil
                ),
                shippingMethods: shippingMethods
            )
        } catch {
            print("[didSelectShippingContact] error: \(error)")
            return PKPaymentRequestShippingContactUpdate(
                errors: [error],
                paymentSummaryItems: PassKitFactory.shared.createPaymentSummaryItems(
                    cart: CartManager.shared.cart,
                    shippingMethod: nil
                ),
                shippingMethods: []
            )
        }
    }

    func paymentAuthorizationController(
        _: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment
    ) async -> PKPaymentAuthorizationResult {
        /**
         * Apply validations that make sense for your business requirements
         */
        guard payment.shippingContact?.postalAddress?.isoCountryCode == "US" else {
            paymentStatus = .failure
            return .init(
                status: .failure,
                errors: [
                    PKPaymentRequest
                        .paymentShippingAddressUnserviceableError(
                            withLocalizedDescription:
                            "Address must be in the United States to use Apple Pay in the Sample App"
                        ),
                    PKPaymentRequest.paymentShippingAddressInvalidError(
                        withKey: CNPostalAddressCountryKey,
                        localizedDescription: "Invalid country"
                    )
                ]
            )
        }

        do {
            _ = try await CartManager.shared.performCartPaymentUpdate(payment: payment)
        } catch {
            print("[didAuthorizePayment][performCartPaymentUpdate][failure] \(error)")
            paymentStatus = .failure
            return PKPaymentAuthorizationResult(status: .failure, errors: [error])
        }

        do {
            let response = try await CartManager.shared.performCartSubmitForCompletion()
            CartManager.shared.redirectUrl = response.redirectUrl
            paymentStatus = .success
            return PKPaymentAuthorizationResult(status: .success, errors: nil)
        } catch {
            print("[didAuthorizePayment][submitForCompletion][failure] \(error)")
            paymentStatus = .failure
            return PKPaymentAuthorizationResult(status: .failure, errors: [error])
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            // The payment sheet doesn't automatically dismiss once it has finished. Dismiss the payment sheet.
            DispatchQueue.main.async {
                defer {
                    // Reset state after closing sheet
                    self.paymentStatus = nil
                    self.paymentCompletionHandler = nil
                }

                guard let paymentStatus = self.paymentStatus?.rawValue as? NSNumber else {
                    return print(
                        "Unknown payment status \(String(describing: CartManager.shared.cart))"
                    )
                }

                self.paymentCompletionHandler?(Bool(truncating: paymentStatus))
            }
        }
    }
}
