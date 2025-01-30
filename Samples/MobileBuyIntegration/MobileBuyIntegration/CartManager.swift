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
import PassKit
import ShopifyCheckoutSheetKit

class CartManager: ObservableObject {
    static let shared = CartManager(client: .shared)
    private static let ContextDirective = Storefront.InContextDirective(
        country: Storefront.CountryCode.inferRegion()
    )

    // MARK: Properties

    private let client: StorefrontClient
    private let vaultedContactInfo: InfoDictionary = .shared
    public var redirectUrl: URL?

    @Published var cart: Storefront.Cart?
    @Published var isDirty: Bool = false

    // MARK: Initializers

    init(client: StorefrontClient) {
        self.client = client
    }

    public func preloadCheckout() {
        /// Only preload checkout if cart is dirty, meaning it has changes since checkout was last preloaded
        if let url = cart?.checkoutUrl, isDirty {
            ShopifyCheckoutSheetKit.preload(checkout: url)
            markCartAsReady()
        }
    }

    /// The cart is "ready" when ShopifyCheckoutSheetKit.preload(checkoutUrl) has been called
    /// The dirty state will be set to false to prevent  preloading again
    func markCartAsReady() {
        isDirty = false
    }

    // MARK: Cart Actions

    /**
     * Creates cart if no cart.id present, or adds line items to pre-existing cart
     * Non-idempotent - subsequent calls for existing cartLine items will increase quantity by 1
     */
    func performCartLinesAdd(variant: GraphQL.ID) async throws -> Storefront.Cart {
        guard let cartId = cart?.id else {
            return try await performCartCreate(items: [variant])
        }

        let lines = [Storefront.CartLineInput.create(merchandiseId: variant)]

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartLinesAdd(cartId: cartId, lines: lines) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        do {
            let response = try await client.executeAsync(mutation: mutation)
            guard let cart = response.cartLinesAdd?.cart else {
                throw Errors.invariant(message: "cart returned nil")
            }
            DispatchQueue.main.async {
                self.cart = cart
            }
            return cart
        } catch {
            throw Errors.apiErrors(requestName: "cartLinesAdd", message: "\(error)")
        }
    }

    func performCartLinesUpdate(id: GraphQL.ID, quantity: Int32) async throws -> Storefront.Cart {
        guard let cartId = cart?.id else {
            return try await performCartCreate(items: [id])
        }

        let lines = [
            Storefront.CartLineUpdateInput.create(id: id, quantity: Input(orNull: quantity))
        ]

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartLinesUpdate(cartId: cartId, lines: lines) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        do {
            let response = try await client.executeAsync(mutation: mutation)
            guard let cart = response.cartLinesUpdate?.cart else {
                throw Errors.invariant(message: "cart returned nil")
            }
            self.cart = cart
            return cart
        } catch {
            throw Errors.apiErrors(requestName: "cartLinesUpdate", message: "\(error)")
        }
    }

    func performBuyerIdentityUpdate(
        contact: PKContact,
        partial _: Bool
    ) async throws -> Storefront.Cart {
        guard let address = contact.postalAddress else {
            throw Errors.invariant(message: "contact.postalAddress is nil")
        }

        let shippingAddress = StorefrontInputFactory.shared.createMailingAddressInput(
            contact: contact,
            address: address
        )

        guard let cartId = cart?.id else {
            throw Errors.invariant(message: "cart.id must not be nil")
        }

        let deliveryAddressPreferencesInput = Input(
            orNull: [
                Storefront.DeliveryAddressInput.create(
                    deliveryAddress: Input(orNull: shippingAddress))
            ]
        )

        let buyerIdentityInput = Storefront.CartBuyerIdentityInput.create(
            email: Input(orNull: vaultedContactInfo.email),
            deliveryAddressPreferences: deliveryAddressPreferencesInput
        )

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartBuyerIdentityUpdate(
                cartId: cartId,
                buyerIdentity: buyerIdentityInput
            ) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        do {
            let response = try await client.executeAsync(mutation: mutation)
            guard let cart = response.cartBuyerIdentityUpdate?.cart else {
                throw Errors.apiErrors(
                    requestName: "cartBuyerIdentityUpdate",
                    message: "returned cart is nil"
                )
            }
            DispatchQueue.main.async {
                self.cart = cart
            }
            return cart
        } catch {
            throw Errors.apiErrors(requestName: "cartBuyerIdentityUpdate", message: "\(error)")
        }
    }

    // TODO: Move this to a DI param for CartManager - Cart shouldn't know about vaulted
    private func getCountryCode() -> Storefront.CountryCode {
        if appConfiguration.useVaultedState {
            let code = Storefront.CountryCode(
                rawValue: vaultedContactInfo.country
            )
            return code ?? .ca
        }

        return Storefront.CountryCode.inferRegion()
    }

    private func performCartCreate(items: [GraphQL.ID] = []) async throws -> Storefront.Cart {
        let input =
            appConfiguration.useVaultedState
                ? StorefrontInputFactory.shared.createVaultedCartInput(items)
                : StorefrontInputFactory.shared.createDefaultCartInput(items)

        let mutation = Storefront.buildMutation(inContext: CartManager.ContextDirective) {
            $0.cartCreate(input: input) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        do {
            let response = try await client.executeAsync(mutation: mutation)
            guard let cart = response.cartCreate?.cart else {
                throw Errors.invariant(message: "cart returned nil")
            }
            self.cart = cart
            return cart
        } catch {
            throw Errors.apiErrors(requestName: "cartCreate", message: "\(error)")
        }
    }

    func performCartSelectedDeliveryOptionsUpdate(deliveryOptionHandle: String) async throws
        -> Storefront.Cart
    {
        guard let deliveryGroupId = cart?.deliveryGroups.nodes.first?.id else {
            throw Errors.invariant(message: "No deliveryGroups")
        }
        guard let cartId = cart?.id else {
            throw Errors.invariant(message: "cart is nil")
        }

        let cartSelectedDeliveryOptionInput =
            Storefront.CartSelectedDeliveryOptionInput(
                deliveryGroupId: deliveryGroupId,
                deliveryOptionHandle: deliveryOptionHandle
            )

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartSelectedDeliveryOptionsUpdate(
                cartId: cartId,
                selectedDeliveryOptions: [cartSelectedDeliveryOptionInput]
            ) {
                $0.cart { $0.cartManagerFragment() }
                    .userErrors {
                        $0.code().message()
                    }
            }
        }

        do {
            let response = try await client.executeAsync(mutation: mutation)
            guard let cart = response.cartSelectedDeliveryOptionsUpdate?.cart else {
                throw Errors.invariant(message: "cart returned nil")
            }

            DispatchQueue.main.async {
                self.cart = cart
            }

            return cart
        } catch {
            throw Errors.apiErrors(
                requestName: "cartSelectedDeliveryOptionsUpdate",
                message: "\(error)"
            )
        }
    }

    func performCartPaymentUpdate(
        payment: PKPayment // REFACTOR: this method should just receive the decoded payment token
    ) async throws -> Storefront.Cart {
        guard let cartId = cart?.id else {
            throw Errors.invariant(message: "cartId is nil")
        }

        guard
            let billingContact = payment.billingContact,
            let billingPostalAddress = billingContact.postalAddress
        else {
            throw Errors.invariant(message: "billingContact is nil")
        }

        guard let totalAmount = cart?.cost.totalAmount else {
            throw Errors.invariant(message: "cart?.cost.totalAmount is nil")
        }

        guard let paymentData = decodePaymentData(payment: payment) else {
            throw Errors.invalidPaymentData
        }

        let paymentInput = StorefrontInputFactory.shared.createPaymentInput(
            payment: payment,
            paymentData: paymentData,
            totalAmount: totalAmount,
            billingContact: billingContact,
            billingPostalAddress: billingPostalAddress
        )

        let mutation = Storefront.buildMutation(inContext: CartManager.ContextDirective) {
            $0.cartPaymentUpdate(cartId: cartId, payment: paymentInput) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        do {
            let response = try await client.executeAsync(mutation: mutation)
            guard let cart = response.cartPaymentUpdate?.cart else {
                throw Errors.invariant(message: "cart returned nil")
            }
            return cart
        } catch {
            throw Errors.apiErrors(requestName: "cartPaymentUpdate", message: "\(error)")
        }
    }

    func performCartPrepareForCompletion() async throws -> Storefront.Cart {
        guard let cartId = cart?.id else {
            throw Errors.invariant(message: "cartId is nil")
        }

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartPrepareForCompletion(cartId: cartId) {
                $0.result {
                    $0.onCartStatusReady { $0.cart { $0.cartManagerFragment() } }
                    $0.onCartThrottled { $0.pollAfter() }
                    $0.onCartStatusReady { $0.cart { $0.cartManagerFragment() } }
                    $0.onCartStatusNotReady {
                        $0.cart { $0.cartManagerFragment() }
                            .errors { $0.code().message() }
                    }
                }
            }
        }

        let response = try await client.executeAsync(mutation: mutation)

        if let result = response.cartPrepareForCompletion?.result as? Storefront.CartStatusReady,
           let cart = result.cart
        {
            DispatchQueue.main.async {
                self.cart = cart
            }
            return cart
        } else {
            throw Errors.apiErrors(
                requestName: "cartPrepareForCompletion",
                message: ""
            )
        }
    }

    func performCartSubmitForCompletion() async throws -> Storefront.SubmitSuccess {
        guard let cartId = cart?.id else {
            fatalError("[invariant_violation][submitForCompletion]: cart id is null")
        }

        let mutation = Storefront.buildMutation(inContext: CartManager.ContextDirective) {
            $0.cartSubmitForCompletion(cartId: cartId, attemptToken: UUID().uuidString) {
                $0.result {
                    $0.onSubmitSuccess { $0.attemptId() }
                        .onSubmitFailed { $0.checkoutUrl() }
                        .onSubmitAlreadyAccepted { $0.attemptId() }
                        .onSubmitThrottled { $0.pollAfter() }
                }
            }
        }

        do {
            let result = try await client.executeAsync(mutation: mutation)
            guard
                let submissionResult = result.cartSubmitForCompletion?.result
                as? Storefront.SubmitSuccess
            else {
                throw Errors.apiErrors(
                    requestName: "cartSubmitForCompletion",
                    message: "No result"
                )
            }
            DispatchQueue.main.async {
                self.cart = nil
            }
            return submissionResult
        } catch {
            print("[CartManager][submitForCompletion] error \(error)")
            throw error
        }
    }

    func resetCart() {
        cart = nil
        isDirty = false
    }
}

extension CartManager {
    enum Errors: LocalizedError {
        case missingPostalAddress, invalidPaymentData,
             invalidBillingAddress
        case apiErrors(requestName: String, message: String)
        case invariant(message: String)

        var failureReason: String? {
            switch self {
            case .missingPostalAddress:
                return "Postal Address is nil"
            case .invalidPaymentData:
                return "Invalid Payment Data"
            case .invalidBillingAddress:
                return "Mapping billing address failed"
            case let .apiErrors(requestName, message):
                return "Request: \(requestName) Failed. Message: \(message)"
            case let .invariant(message):
                return "invariant failed: \(message)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .missingPostalAddress:
                return "Check `PKContact.postalAddress`"
            case .invalidPaymentData:
                return "Decoding failed - check the PKPayment"
            case .invalidBillingAddress:
                return "Ensure `billingContact.postalAddress` is not nil"
            case let .apiErrors(requestName, _):
                return "Check the API response for more details: \(requestName)"
            case .invariant:
                return "Resolve preconditions before continuing"
            }
        }
    }
}
