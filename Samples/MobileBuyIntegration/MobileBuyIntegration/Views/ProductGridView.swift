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

struct ProductGridView: View {
    @StateObject private var productCache = ProductCache.shared
    @State private var selectedProduct: Storefront.Product?
    @State private var showProductSheet = false

    let columns = [
        GridItem(.fixed(UIScreen.main.bounds.width / 2 - 10)),
        GridItem(.fixed(UIScreen.main.bounds.width / 2 - 10))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                if let products = productCache.collection, !products.isEmpty {
                    ForEach(products, id: \.id) { product in
                        ProductGridItem(product: product)
                            .onTapGesture {
                                selectProductAndShowSheet(for: product)
                            }
                    }
                } else {
                    Text("Loading products...")
                        .padding()
                }
            }
            .padding(.horizontal, 5)
        }
        .onAppear {
            if productCache.collection == nil {
                productCache.fetchCollection()
            }
        }
        .sheet(isPresented: $showProductSheet) {
            ProductSheetView(product: $selectedProduct, isPresented: $showProductSheet)
        }
    }

    private func selectProductAndShowSheet(for product: Storefront.Product) {
        selectedProduct = product
        if selectedProduct != nil {
            showProductSheet = true
        }
    }
}

struct ProductSheetView: View {
    @Binding var product: Storefront.Product?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let product = product {
                ProductView(product: product)
            }

            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .padding()
                    .foregroundStyle(.white)
            }
            .padding([.top, .trailing], 16)
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct ProductGridItem: View {
    let product: Storefront.Product
    let maxWidth = UIScreen.main.bounds.width / 2 - 10
    var body: some View {
        VStack {
            if let imageURL = product.featuredImage?.url {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: maxWidth)
                        .frame(height: 150)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: maxWidth)
                        .frame(height: 150)
                        .clipped()
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: maxWidth)
                        .frame(height: 150)
                        .clipped()

                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }

            VStack {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.top, 4)

                if let price = product.variants.nodes.first?.price {
                    Text(price.formattedString()!)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(alignment: .leading)
        }
    }
}

struct ProductGrid_Previews: PreviewProvider {
    static var previews: some View {
        ProductGridView()
    }
}
