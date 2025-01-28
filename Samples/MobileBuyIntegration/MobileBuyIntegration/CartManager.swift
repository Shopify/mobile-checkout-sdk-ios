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

enum CartApiError: Error {
    case apiErrors(String)
}

class CartManager: ObservableObject {
    static let shared = CartManager(client: .shared)
    private static let ContextDirective = Storefront.InContextDirective(
        country: Storefront.CountryCode.inferRegion()
    )

    // MARK: Properties

    @Published var cart: Storefront.Cart?
    @Published var isDirty: Bool = false
    private let client: StorefrontClient
    private let vaultedContactInfo: InfoDictionary = .shared

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

    func addItem(
        variant: GraphQL.ID,
        handler completion: @escaping (_: Storefront.Cart?) -> Void
    ) {
        performCartLinesAdd(item: variant) { result in
            switch result {
            case let .success(cart):
                self.cart = cart
                completion(self.cart)
            case let .failure(error):
                print("addItem error \(error)")
                completion(nil)
            }
        }
    }

    func updateQuantity(
        variant: GraphQL.ID,
        quantity: Int32,
        completionHandler: ((Storefront.Cart?) -> Void)?
    ) {
        performCartUpdate(id: variant, quantity: quantity) { result in
            switch result {
            case let .success(cart):
                self.cart = cart
                completionHandler?(self.cart)
            case let .failure(error):
                print("updateQuantity error \(error)")
                completionHandler?(nil)
            }
        }
    }

    enum AddressType {
        case postal, billing
    }

    private func mapCNPostalAddress(
        contact: PKContact
    ) throws -> Storefront.MailingAddressInput {
        guard let address = contact.postalAddress else {
            throw CartManager.Errors.missingPostalAddress
        }

        return Storefront.MailingAddressInput.create(
            address1: Input(orNull: address.street),
            address2: Input(orNull: address.subLocality),
            city: Input(orNull: address.city),
            country: Input(orNull: address.country),
            firstName: Input(orNull: contact.name?.givenName ?? ""),
            lastName: Input(orNull: contact.name?.familyName ?? ""),
            phone: Input(orNull: contact.phoneNumber?.stringValue ?? ""),
            province: Input(orNull: address.state),
            zip: Input(orNull: address.postalCode)
        )
    }

    // TODO: Rename to selectDeliveryAddress
    func updateDeliveryAddress(
        contact: PKContact,
        partial _: Bool,
        completionHandler: ((Storefront.Cart?) -> Void)?
    ) throws {
        do {
            let shippingAddress = try mapCNPostalAddress(contact: contact)

            performCartDeliveryAddressUpdate(shippingAddress: shippingAddress) {
                switch $0 {
                case let .success(cart):
                    self.cart = cart
                case let .failure(error):
                    print("performCartDeliveryAddressUpdate: \(error)")
                }
                completionHandler?(self.cart)
            }
        } catch {
            print("Failed to update delivery address with error: \(error)")
        }
    }

    func selectShippingMethodUpdate(
        deliveryOptionHandle: String,
        handler completion: @escaping CartResultHandler
    ) {
        guard let deliveryGroupId = cart?.deliveryGroups.nodes.first?.id else {
            return print("No delivery group selected")
        }

        performCartShippingMethodUpdate(
            deliveryGroupId: deliveryGroupId,
            deliveryOptionHandle: deliveryOptionHandle
        ) { result in
            switch result {
            case let .success(result):
                self.cart = result
                completion(.success(result))
            case let .failure(error):
                /**
                 * if cartPrepareForCompletion returns errors/usererrors
                 * then deliveryGroups are invalidated resulting in throws here
                 */
                completion(.failure(error))
            }
        }
    }

    func resetCart() {
        cart = nil
        isDirty = false
    }

    typealias CartResultHandler = (Result<Storefront.Cart, Error>) -> Void

    /**
     * Creates cart if no cart.id present, or adds line items to pre-existing cart
     * Non-idempotent - subsequent calls for existing cartLine items will increase quantity by 1
     */
    private func performCartLinesAdd(
        item: GraphQL.ID,
        handler: @escaping CartResultHandler
    ) {
        guard let cartId = cart?.id else {
            return performCartCreate(items: [item], handler: handler)
        }

        let lines = [Storefront.CartLineInput.create(merchandiseId: item)]

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartLinesAdd(cartId: cartId, lines: lines) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        client.execute(mutation: mutation) { result in
            #warning("accessing cart in this if could throw")

            if case let .success(result) = result,
               let cart = result.cartLinesAdd?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
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

    private func performCartCreate(
        items: [GraphQL.ID] = [],
        handler: @escaping CartResultHandler
    ) {
        let input =
            appConfiguration.useVaultedState
                ? createVaultedCartInput(items)
                : createDefaultCartInput(items)

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartCreate(input: input) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        client.execute(mutation: mutation) { result in
            #warning("accessing cart in this if could throw")

            if case let .success(mutation) = result,
               let cart = mutation.cartCreate?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    private func performCartUpdate(
        id: GraphQL.ID,
        quantity: Int32,
        handler: @escaping CartResultHandler
    ) {
        guard let cartId = cart?.id else {
            return performCartCreate(items: [id], handler: handler)
        }

        let lines = [
            Storefront.CartLineUpdateInput.create(
                id: id, quantity: Input(orNull: quantity)
            )
        ]

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartLinesUpdate(cartId: cartId, lines: lines) {
                $0.cart { $0.cartManagerFragment() }
            }
        }

        client.execute(mutation: mutation) { result in
            #warning("accessing cart in this if could throw")

            if case let .success(result) = result,
               let cart = result.cartLinesUpdate?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    private func performCartDeliveryAddressUpdate(
        shippingAddress: Storefront.MailingAddressInput,
        handler: @escaping CartResultHandler
    ) {
        guard let cartId = cart?.id else {
            return print("no cart")
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

        client.execute(mutation: mutation) { result in
            #warning("accessing cart in this if could throw")

            if case let .success(mutationResult) = result,
               let cart = mutationResult.cartBuyerIdentityUpdate?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    func performCartPrepareForCompletion(
        handler: @escaping (Result<Storefront.Cart, Error>) -> Void
    ) {
        guard let cartId = cart?.id else {
            return print("[Fail][performCartPrepareForCompletion]: cart is nil")
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

        client.execute(mutation: mutation) { result in
            #warning("accessing cart in this if could throw")
            if
                case let .success(mutationResult) = result,
                let result = mutationResult.cartPrepareForCompletion?.result
                as? Storefront.CartStatusReady,
                let cart = result.cart
            {
                self.cart = cart
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    private func performCartShippingMethodUpdate(
        deliveryGroupId: GraphQL.ID,
        deliveryOptionHandle: String,
        handler: @escaping (Result<Storefront.Cart, Error>) -> Void
    ) {
        guard let cartId = cart?.id else {
            return print("performCartShippingMethodUpdate: Cart isn't created")
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

        client.execute(mutation: mutation) { result in
            if case let .success(mutationResult) = result,
               let cart = mutationResult.cartSelectedDeliveryOptionsUpdate?
               .cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    // TODO: Rename to selectCartPaymentMethod
    func updateCartPaymentMethod(
        payment: PKPayment, // REFACTOR: this method should just receive the decoded payment token
        completion: @escaping (Result<Storefront.Cart, Error>) -> Void
    ) {
        guard
            let cartId = cart?.id,
            let billingContact = payment.billingContact,
            let totalAmount = cart?.cost.totalAmount
        else {
            fatalError("updateCartPaymentMethod: Pre-requisites not met")
        }

        var paymentData: PaymentData?
        do {
            paymentData = try JSONDecoder().decode(
                PaymentData.self,
                from: payment.token.paymentData
            )
        } catch {
            fatalError("error decoding payment data: \(error)")
        }

        guard let paymentData else {
            print(
                "Decoding failed: .paymentData = \(payment.token)"
            )
            return completion(.failure(CartManager.Errors.invalidPaymentData))
        }

        let header = Storefront.ApplePayWalletHeaderInput.create(
            ephemeralPublicKey: paymentData.header
                .ephemeralPublicKey,
            publicKeyHash: paymentData.header.publicKeyHash,
            transactionId: paymentData.header.transactionId
            // TODO: Is it required to send applicationData, useful to send cart checkout url?
            //            applicationData: Input(
            //                orNull: paymentData.header.applicationData
            //            )
        )

        let billingAddress = try? mapCNPostalAddress(contact: billingContact)
        guard let billingAddress else {
            print(
                "Invalid Billing Address: .billingAddress = \(String(describing: billingContact.postalAddress))"
            )
            return completion(.failure(CartManager.Errors.invalidBillingAddress))
        }

        let applePayWalletContent = Storefront.ApplePayWalletContentInput
            .create(
                billingAddress: billingAddress,
                data: paymentData.data,
                header: header,
                signature: paymentData.signature,
                version: paymentData.version,
                lastDigits: Input(
                    orNull: payment
                        .token
                        .paymentMethod
                        .displayName?
                        .components(separatedBy: " ")
                        .last
                )
            )

        let walletPaymentMethod = Storefront.CartWalletPaymentMethodInput
            .create(
                applePayWalletContent: Input(orNull: applePayWalletContent)
            )

        let payment = Storefront
            .CartPaymentInput
            .create(
                amount: Storefront.MoneyInput.create(
                    amount: totalAmount.amount,
                    currencyCode: totalAmount.currencyCode
                ),
                walletPaymentMethod: Input(orNull: walletPaymentMethod)
            )

        let mutation = Storefront.buildMutation(
            inContext: CartManager.ContextDirective
        ) {
            $0.cartPaymentUpdate(cartId: cartId, payment: payment) {
                $0.cart {
                    $0.cartManagerFragment()
                }
            }
        }

        client.execute(mutation: mutation) {
            guard
                case let .success(result) = $0,
                let _cart = result.cartPaymentUpdate?.cart
            else {
                return completion(.failure(URLError(.unknown)))
            }

            completion(.success(_cart))
        }
    }

    func submitForCompletion(
        completion: @escaping (Result<Storefront.SubmitSuccess, Error>) -> Void
    ) {
        guard let cartId = cart?.id else {
            fatalError("[invariant_violation][submitForCompletion]: cart id is null")
        }

        let mutation = Storefront.buildMutation(inContext: CartManager.ContextDirective) {
            $0.cartSubmitForCompletion(cartId: cartId, attemptToken: UUID().uuidString) {
                $0.result {
                    $0
                        .onSubmitSuccess { $0.attemptId() }
                        .onSubmitFailed { $0.checkoutUrl() }
                        .onSubmitAlreadyAccepted { $0.attemptId() }
                        .onSubmitThrottled { $0.pollAfter() }
                }
            }
        }
        client.execute(mutation: mutation) {
            result in
            switch result {
            case let .success(result):
                /**
                 * TODO: how to handle the union type of success response
                 * CartUserError  SubmitSuccess etc.
                 */
                if let result = result.cartSubmitForCompletion?.result as? Storefront.CartUserError {
                    do {
                        let jsonString = try JSONSerialization.data(withJSONObject: result.rawValue)
                        let json =
                            try JSONSerialization.jsonObject(with: jsonString) as? [String: Any]

                        guard
                            let json = json,
                            let userErrors = json["userErrors"] as? [String: Any],
                            let userErrors = try? JSONSerialization.data(
                                withJSONObject: userErrors),
                            let error = String(data: userErrors, encoding: .utf8)
                        else {
                            return completion(
                                .failure(CartApiError.apiErrors("Unknown encountered"))
                            )
                        }

                        let err = CartApiError.apiErrors(error)
                        return completion(.failure(err))
                    } catch {
                        return completion(
                            .failure(CartApiError.apiErrors("Failed to stringify cart error"))
                        )
                    }
                }

                guard
                    let result = result.cartSubmitForCompletion?.result as? Storefront.SubmitSuccess
                else {
                    return completion(.failure(CartApiError.apiErrors("No result")))
                }
                //                print("[CartManager][submitForCompletion] Success \(result)")
                completion(.success(result))
                self.cart = nil
            case let .failure(error):
                print("[CartManager][submitForCompletion] error \(error)")
                return completion(.failure(URLError(.unknown)))
            }
        }
    }

    private func createDefaultCartInput(_ items: [GraphQL.ID])
        -> Storefront.CartInput
    {
        return Storefront.CartInput.create(
            lines: Input(
                orNull: items.map {
                    Storefront.CartLineInput.create(merchandiseId: $0)
                }
            )
        )
    }

    private func createVaultedCartInput(_ items: [GraphQL.ID] = [])
        -> Storefront.CartInput
    {
        let deliveryAddress = Storefront.MailingAddressInput.create(
            address1: Input(orNull: vaultedContactInfo.address1),
            address2: Input(orNull: vaultedContactInfo.address2),
            city: Input(orNull: vaultedContactInfo.city),
            company: Input(orNull: ""),
            country: Input(orNull: vaultedContactInfo.country),
            firstName: Input(orNull: vaultedContactInfo.firstName),
            lastName: Input(orNull: vaultedContactInfo.lastName),
            phone: Input(orNull: vaultedContactInfo.phone),
            province: Input(orNull: vaultedContactInfo.province),
            zip: Input(orNull: vaultedContactInfo.zip)
        )

        let deliveryAddressPreferences = [
            Storefront.DeliveryAddressInput.create(
                deliveryAddress: Input(orNull: deliveryAddress))
        ]

        return Storefront.CartInput.create(
            lines: Input(
                orNull: items.map {
                    Storefront.CartLineInput.create(merchandiseId: $0)
                }),
            buyerIdentity: Input(
                orNull: Storefront.CartBuyerIdentityInput.create(
                    email: Input(orNull: vaultedContactInfo.email),
                    deliveryAddressPreferences: Input(
                        orNull: deliveryAddressPreferences)
                ))
        )
    }
}

extension CartManager {
    enum Errors: LocalizedError {
        case missingPostalAddress, invalidPaymentData,
             invalidBillingAddress

        var failureReason: String? {
            switch self {
            case .missingPostalAddress:
                return "Postal Address is nil"
            case .invalidPaymentData:
                return "Invalid Payment Data"
            case .invalidBillingAddress:
                return "Mapping billing address failed"
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
            }
        }
    }
}
