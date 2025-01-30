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
import Foundation
import PassKit

class StorefrontClient {
    static let shared = StorefrontClient()

    private let client: Graph.Client

    private init() {
        client = Graph
            .Client(
                shopDomain: InfoDictionary.shared.domain,
                apiKey: InfoDictionary.shared.accessToken
            )

        /// Set the caching policy (1 hour)
        client.cachePolicy = .cacheFirst(expireIn: 60 * 60)
    }

    typealias QueryResultHandler = (Result<Storefront.QueryRoot, Error>) -> Void

    func execute(query: Storefront.QueryRootQuery, handler: @escaping QueryResultHandler) {
        let task = client.queryGraphWith(query) { query, error in
            if let root = query {
                handler(.success(root))
            } else {
                handler(.failure(error ?? URLError(.unknown)))
            }
        }

        task.resume()
    }

    func executeAsync(query: Storefront.QueryRootQuery) async throws -> Storefront.QueryRoot {
        try await withCheckedThrowingContinuation { continuation in
            let task = client.queryGraphWith(query) { query, error in
                guard let query = query else {
                    return continuation.resume(throwing: error ?? URLError(.unknown))
                }

                continuation.resume(returning: query)
            }
            task.resume()
        }
    }

    typealias MutationResultHandler = (Result<Storefront.Mutation, Error>) -> Void

    func execute(mutation: Storefront.MutationQuery, handler: @escaping MutationResultHandler) {
        let task = client.mutateGraphWith(mutation) { mutation, error in
            if let root = mutation {
                handler(.success(root))
            } else {
                handler(.failure(error ?? URLError(.unknown)))
            }
        }

        task.resume()
    }

    func executeAsync(mutation: Storefront.MutationQuery) async throws -> Storefront.Mutation {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let task = self.client.mutateGraphWith(mutation) { mutation, error in
                    guard let mutation = mutation else {
                        return continuation.resume(throwing: error ?? URLError(.unknown))
                    }

                    continuation.resume(returning: mutation)
                }
                task.resume()
            }
        }
    }
}

public struct StorefrontURL {
    public let url: URL

    private let slug = "([\\w\\d_-]+)"

    init(from url: URL) {
        self.url = url
    }

    public func isThankYouPage() -> Bool {
        return url.path.range(of: "/thank[-_]you", options: .regularExpression) != nil
    }

    public func isCheckout() -> Bool {
        return url.path.contains("/checkout")
    }

    public func isCart() -> Bool {
        return url.path.contains("/cart")
    }

    public func isCollection() -> Bool {
        return url.path.range(of: "/collections/\(slug)", options: .regularExpression) != nil
    }

    public func isProduct() -> Bool {
        return url.path.range(of: "/products/\(slug)", options: .regularExpression) != nil
    }

    public func getProductSlug() -> String? {
        guard isProduct() else { return nil }

        let pattern = "/products/([\\w_-]+)"
        if let match = url.path.range(
            of: pattern, options: .regularExpression, range: nil, locale: nil
        ) {
            let slug = url.path[match].components(separatedBy: "/").last
            return slug
        }
        return nil
    }
}

class StorefrontInputFactory {
    static let shared = StorefrontInputFactory()

    enum Errors: Error {
        case invariant(String)
    }

    public func createVaultedCartInput(_ items: [GraphQL.ID] = []) -> Storefront.CartInput {
        let vaultedContactInfo = InfoDictionary.shared
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

    public func createDefaultCartInput(_ items: [GraphQL.ID]) -> Storefront.CartInput {
        return Storefront.CartInput.create(
            lines: Input(
                orNull: items.map { Storefront.CartLineInput.create(merchandiseId: $0) }
            )
        )
    }

    public func createMailingAddressInput(
        contact: PKContact, address: CNPostalAddress
    ) -> Storefront.MailingAddressInput {
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

    public func createPaymentInput(
        payment: PKPayment,
        paymentData: PaymentData,
        totalAmount: Storefront.MoneyV2,
        billingContact: PKContact,
        billingPostalAddress: CNPostalAddress
    ) -> Storefront.CartPaymentInput {
        let billingAddressInput = StorefrontInputFactory.shared.createMailingAddressInput(
            contact: billingContact,
            address: billingPostalAddress
        )

        let header = Storefront.ApplePayWalletHeaderInput.create(
            ephemeralPublicKey: paymentData.header.ephemeralPublicKey,
            publicKeyHash: paymentData.header.publicKeyHash,
            transactionId: paymentData.header.transactionId
        )

        let applePayWalletContent = Storefront.ApplePayWalletContentInput
            .create(
                billingAddress: billingAddressInput,
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
            .create(applePayWalletContent: Input(orNull: applePayWalletContent))

        return Storefront.CartPaymentInput.create(
            amount: Storefront.MoneyInput.create(
                amount: totalAmount.amount,
                currencyCode: totalAmount.currencyCode
            ),
            walletPaymentMethod: Input(orNull: walletPaymentMethod)
        )
    }
}
