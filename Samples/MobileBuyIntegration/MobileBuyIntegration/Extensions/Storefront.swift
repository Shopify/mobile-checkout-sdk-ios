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

extension Storefront.CartQuery {
    @discardableResult
    func cartManagerFragment() -> Storefront.CartQuery {
        id()
            .checkoutUrl()
            .totalQuantity()
            .deliveryGroups(first: 10) {
                $0.nodes {
                    $0.id()
                        .deliveryOptions {
                            $0.handle()
                                .title()
                                .code()
                                .deliveryMethodType()
                                .description()
                                .estimatedCost {
                                    $0.amount()
                                        .currencyCode()
                                }
                        }.selectedDeliveryOption {
                            $0.description()
                                .title()
                                .handle()
                                .estimatedCost {
                                    $0.amount()
                                        .currencyCode()
                                }
                        }
                }
            }
            .lines(first: 250) {
                $0.nodes {
                    $0.id()
                        .quantity()
                        .merchandise {
                            $0.onProductVariant {
                                $0.id()
                                    .title()
                                    .price {
                                        $0.amount()
                                            .currencyCode()
                                    }
                                    .product {
                                        $0.title()
                                            .vendor()
                                            .featuredImage {
                                                $0.url()
                                            }
                                    }
                            }
                        }
                        .cost {
                            $0.totalAmount {
                                $0.amount()
                                    .currencyCode()
                            }
                        }
                }
            }
            .totalQuantity()
            .cost {
                $0.totalAmount {
                    $0.amount()
                        .currencyCode()
                }
                .subtotalAmount {
                    $0.amount()
                        .currencyCode()
                }
                .totalTaxAmount {
                    $0.amount()
                        .currencyCode()
                }
            }
    }
}

extension Storefront.ProductQuery {
    @discardableResult
    func productFragment() -> Storefront.ProductQuery {
        id()
            .title()
            .handle()
            .description()
            .vendor()
            .featuredImage {
                $0
                    .url()
            }
            .collections(first: 1) {
                $0
                    .nodes {
                        $0
                            .id()
                            .title()
                    }
            }
            .variants(first: 1) {
                $0
                    .nodes {
                        $0
                            .id()
                            .title()
                            .availableForSale()
                            .price {
                                $0
                                    .amount()
                                    .currencyCode()
                            }
                    }
            }
    }
}
