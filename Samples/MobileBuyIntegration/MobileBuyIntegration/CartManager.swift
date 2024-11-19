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

class CartManager {

    static let shared = CartManager(client: .shared)

    // MARK: Properties

    @Published
    var cart: Storefront.Cart?

    private let client: StorefrontClient
    private let address1: String
    private let address2: String
    private let city: String
    private let country: String
    private let firstName: String
    private let lastName: String
    private let province: String
    private let zip: String
    private let email: String
    private let phone: String

    // MARK: Initializers
    init(client: StorefrontClient) {
        self.client = client
        guard
            let infoPlist = Bundle.main.infoDictionary,
            let address1 = infoPlist["Address1"] as? String,
            let address2 = infoPlist["Address2"] as? String,
            let city = infoPlist["City"] as? String,
            let country = infoPlist["Country"] as? String,
            let firstName = infoPlist["FirstName"] as? String,
            let lastName = infoPlist["LastName"] as? String,
            let province = infoPlist["Province"] as? String,
            let zip = infoPlist["Zip"] as? String,
            let email = infoPlist["Email"] as? String,
            let phone = infoPlist["Phone"] as? String
        else {
            fatalError("unable to load storefront configuration")
        }

        self.address1 = address1
        self.address2 = address2
        self.city = city
        self.country = country
        self.firstName = firstName
        self.lastName = lastName
        self.province = province
        self.zip = zip
        self.email = email
        self.phone = phone
    }

    // MARK: Cart Actions

    func addItem(variant: GraphQL.ID, completionHandler: (() -> Void)?) {
        performCartLinesAdd(item: variant) { result in
            switch result {
            case .success(let cart):
                self.cart = cart
            case .failure(let error):
                print(error)
            }
            completionHandler?()
        }
    }

    func updateQuantity(
        variant: GraphQL.ID, quantity: Int32,
        completionHandler: ((Storefront.Cart?) -> Void)?
    ) {
        performCartUpdate(
            id: variant, quantity: quantity,
            handler: { result in
                switch result {
                case .success(let cart):
                    self.cart = cart
                case .failure(let error):
                    print(error)
                }
                completionHandler?(self.cart)
            })
    }

    func updateDeliveryAddress(
        contact: PKContact, partial: Bool,
        completionHandler: ((Storefront.Cart?) -> Void)?
    ) {
        let postalAddress = contact.postalAddress
        if partial {
            guard
                let city = postalAddress?.city,
                let country = postalAddress?.country,
                let province = postalAddress?.state,
                let zip = postalAddress?.postalCode
            else {
                print("Missing required fields for partial delivery address")
                return
            }
        } else {
            // TODO: figure out the correct sources of the fields
            // see: https://github.com/Shopify/portable-wallets/blob/518103cc7699c7ec2e379062a2e1df74a9442514/src/components/ApplePayButton/helpers/map-to-address.ts#L30
            guard
                let address1 = postalAddress?.street,
                let address2 = postalAddress?.subLocality,
                let city = postalAddress?.city,
                let country = postalAddress?.country,
                let firstName = contact.name?.givenName,
                let lastName = contact.name?.familyName,
                let province = postalAddress?.state,
                let zip = postalAddress?.postalCode,
                let email = contact.emailAddress,
                let phone = contact.phoneNumber
            else {
                print("Missing required fields for full delivery address")
                return
            }
        }

        let shippingAddress = Storefront.MailingAddressInput.create(
            address1: Input(orNull: address1),
            address2: Input(orNull: address2),
            city: Input(orNull: city),
            company: Input(orNull: ""),
            country: Input(orNull: country),
            firstName: Input(orNull: firstName),
            lastName: Input(orNull: lastName),
            phone: Input(orNull: phone),
            province: Input(orNull: province),
            zip: Input(orNull: zip)
        )

        performCartDeliveryAddressUpdate(
            shippingAddress: shippingAddress,
            handler: { result in
                switch result {
                case .success(let cart):
                    self.cart = cart
                case .failure(let error):
                    print(error)
                }
                completionHandler?(self.cart)
            })
    }

    func selectShippingMethodUpdate(deliveryOptionHandle: String, completionHandler: ((Storefront.Cart?) -> Void)?) {
        guard let deliveryGroupId = cart?.deliveryGroups.nodes.first?.id else {
            print("No delivery group selected")
            return
        }
        performCartShippingMethodUpdate(deliveryGroupId: deliveryGroupId, deliveryOptionHandle: deliveryOptionHandle) { result in
            switch result {
            case .success(let cart):
                self.cart = cart
                print("Waitings for cart to reload")
                self.waitAndReloadCart()
                print("Cart reloaded")
            case .failure(let error):
                print(error)
            }
            completionHandler?(self.cart)
        }
    }

    func resetCart() {
        self.cart = nil
    }

    typealias CartResultHandler = (Result<Storefront.Cart, Error>) -> Void

    private func performCartLinesAdd(
        item: GraphQL.ID, handler: @escaping CartResultHandler
    ) {
        if let cartID = cart?.id {
            let lines = [Storefront.CartLineInput.create(merchandiseId: item)]

            let mutation = Storefront.buildMutation(
                inContext: Storefront.InContextDirective(
                    country: Storefront.CountryCode.inferRegion())
            ) {
                $0
                    .cartLinesAdd(lines: lines, cartId: cartID) {
                        $0
                            .cart { $0.cartManagerFragment() }
                    }
            }

            client.execute(mutation: mutation) { result in
                if case .success(let mutation) = result,
                    let cart = mutation.cartLinesAdd?.cart
                {
                    handler(.success(cart))
                } else {
                    handler(.failure(URLError(.unknown)))
                }
            }
        } else {
            performCartCreate(items: [item], handler: handler)
        }
    }

    private func performCartCreate(
        items: [GraphQL.ID] = [], handler: @escaping CartResultHandler
    ) {
        let input =
            (appConfiguration.useVaultedState)
            ? vaultedStateCart(items) : defaultCart(items)

        let countryCode: Storefront.CountryCode =
            appConfiguration.useVaultedState
            ? ((Storefront.CountryCode(
                rawValue: Bundle.main.infoDictionary?["Country"] as? String
                    ?? "")) ?? .ca)
            : Storefront.CountryCode.inferRegion()

        let mutation = Storefront.buildMutation(
            inContext: Storefront.InContextDirective(country: countryCode)
        ) {
            $0
                .cartCreate(input: input) {
                    $0
                        .cart { $0.cartManagerFragment() }
                }
        }

        client.execute(mutation: mutation) { result in
            if case .success(let mutation) = result,
                let cart = mutation.cartCreate?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    private func performCartUpdate(
        id: GraphQL.ID, quantity: Int32, handler: @escaping CartResultHandler
    ) {
        let lines = [
            Storefront.CartLineUpdateInput.create(
                id: id, quantity: Input(orNull: quantity))
        ]

        if let cartID = cart?.id {
            let mutation = Storefront.buildMutation(
                inContext: Storefront.InContextDirective(
                    country: Storefront.CountryCode.inferRegion())
            ) {
                $0
                    .cartLinesUpdate(cartId: cartID, lines: lines) {
                        $0
                            .cart { $0.cartManagerFragment() }
                    }
            }

            client.execute(mutation: mutation) { result in
                if case .success(let mutation) = result,
                    let cart = mutation.cartLinesUpdate?.cart
                {
                    handler(.success(cart))
                } else {
                    handler(.failure(URLError(.unknown)))
                }
            }
        } else {
            performCartCreate(items: [id], handler: handler)
        }
    }

    private func performCartDeliveryAddressUpdate(
        shippingAddress: Storefront.MailingAddressInput,
        handler: @escaping CartResultHandler
    ) {
        let deliveryAddressPreferences = [
            Storefront.DeliveryAddressInput.create(
                deliveryAddress: Input(orNull: shippingAddress))
        ]

        let buyerIdentityInput = Storefront.CartBuyerIdentityInput.create(
            email: Input(orNull: email),
            deliveryAddressPreferences: Input(
                orNull: deliveryAddressPreferences
            )
        )

        guard let cartID = cart?.id else {
            return print()
        }

        let mutation = Storefront.buildMutation(
            inContext: Storefront.InContextDirective(
                country: Storefront.CountryCode.inferRegion())
        ) {
            $0
                .cartBuyerIdentityUpdate(cartId: cartID, buyerIdentity: buyerIdentityInput) {
                    $0
                        .cart { $0.cartManagerFragment() }
                }
        }

        client.execute(mutation: mutation) { result in
            if case .success(let mutationResult) = result,
                let cart = mutationResult.cartBuyerIdentityUpdate?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    private func performCartShippingMethodUpdate(
        deliveryGroupId: GraphQL.ID,
        deliveryOptionHandle: String,
        handler: @escaping CartResultHandler
    ) {
        let cartSelectedDeliveryOptionInput = Storefront.CartSelectedDeliveryOptionInput(
            deliveryGroupId: deliveryGroupId,
            deliveryOptionHandle: deliveryOptionHandle
        )

        guard let cartID = cart?.id else {
            return print()
        }

        let mutation = Storefront.buildMutation(
            inContext: Storefront.InContextDirective(
                country: Storefront.CountryCode.inferRegion())
        ) {
            $0
                .cartSelectedDeliveryOptionsUpdate(cartId: cartID, selectedDeliveryOptions: [cartSelectedDeliveryOptionInput]) {
                    $0
                        .cart { $0.cartManagerFragment() }
                }
        }

        client.execute(mutation: mutation) { result in
            if case .success(let mutationResult) = result,
                let cart = mutationResult.cartSelectedDeliveryOptionsUpdate?.cart
            {
                handler(.success(cart))
            } else {
                handler(.failure(URLError(.unknown)))
            }
        }
    }

    private func waitAndReloadCart(delayInSeconds: UInt32 = 1) {
        guard let cartId = cart?.id else { return }

        let context = Storefront.InContextDirective(country: Storefront.CountryCode.inferRegion())
        let query = Storefront.buildQuery(inContext: context) { $0
            .cart(id: cartId) { $0.cartManagerFragment() }
        }

        sleep(delayInSeconds)

        client.execute(query: query) { result in
            if case .success(let queryResult) = result {
                self.cart = queryResult.cart
            }
        }
    }

    private func defaultCart(_ items: [GraphQL.ID]) -> Storefront.CartInput {
        return Storefront.CartInput.create(
            lines: Input(
                orNull: items.map({
                    Storefront.CartLineInput.create(merchandiseId: $0)
                }))
        )
    }

    private func vaultedStateCart(_ items: [GraphQL.ID] = [])
        -> Storefront.CartInput
    {
        let deliveryAddress = Storefront.MailingAddressInput.create(
            address1: Input(orNull: address1),
            address2: Input(orNull: address2),
            city: Input(orNull: city),
            company: Input(orNull: ""),
            country: Input(orNull: country),
            firstName: Input(orNull: firstName),
            lastName: Input(orNull: lastName),
            phone: Input(orNull: phone),
            province: Input(orNull: province),
            zip: Input(orNull: zip))

        let deliveryAddressPreferences = [
            Storefront.DeliveryAddressInput.create(
                deliveryAddress: Input(orNull: deliveryAddress))
        ]

        return Storefront.CartInput.create(
            lines: Input(
                orNull: items.map({
                    Storefront.CartLineInput.create(merchandiseId: $0)
                })),
            buyerIdentity: Input(
                orNull: Storefront.CartBuyerIdentityInput.create(
                    email: Input(orNull: email),
                    deliveryAddressPreferences: Input(
                        orNull: deliveryAddressPreferences)
                ))
        )
    }
}

extension Storefront.CartQuery {
    @discardableResult
    func cartManagerFragment() -> Storefront.CartQuery {
        self
            .id()
            .checkoutUrl()
            .totalQuantity()
            .deliveryGroups(first: 10) {
                $0
                    .nodes {
                        $0
                            .id()
                            .deliveryOptions {
                                $0
                                    .handle()
                                    .title()
                                    .code()
                                    .deliveryMethodType()
                                    .description()
                                    .estimatedCost{
                                        $0
                                            .amount()
                                            .currencyCode()
                                    }
                            }
                }
            }
            .lines(first: 250) {
                $0
                    .nodes {
                        $0
                            .id()
                            .quantity()
                            .merchandise {
                                $0
                                    .onProductVariant {
                                        $0
                                            .id()
                                            .title()
                                            .price({
                                                $0
                                                    .amount()
                                                    .currencyCode()
                                            })
                                            .product {
                                                $0
                                                    .title()
                                                    .vendor()
                                                    .featuredImage {
                                                        $0
                                                            .url()
                                                    }
                                            }
                                    }
                            }
                            .cost {
                                $0
                                    .totalAmount({
                                        $0
                                            .amount()
                                            .currencyCode()
                                    })
                            }
                    }
            }
            .totalQuantity()
            .cost {
                $0
                    .totalAmount({
                        $0
                            .amount()
                            .currencyCode()
                    })
                    .subtotalAmount {
                        $0
                            .amount()
                            .currencyCode()
                    }
                    .totalTaxAmount {
                        $0
                            .amount()
                            .currencyCode()
                    }
            }
    }
}
