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

import ShopifyCheckoutSheetKit
import UIKit

class ProductViewController: UIViewController, CheckoutDelegate {
    @IBOutlet private var image: UIImageView!
    
    @IBOutlet private var titleLabel: UILabel!
    
    @IBOutlet private var variantLabel: UILabel!
    
    @IBOutlet private var buyNowButton: UIButton!
    
    private var product: Product? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateProductDetails()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Product Details"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self, action: #selector(reloadProduct)
        )
        
        reloadProduct()
    }
    
    @IBAction func beginCheckout() {
        if let url = URL(string: "https://account.kickscrew.com/cart/c/Z2NwLWFzaWEtc291dGhlYXN0MTowMUpESEY1NEJSMzM3SlQzVllWR1E5Q0o4NQ?key=xAz_vZPe8KrwPngKykOiOtFghhg3DKdVU241r7bmguOWO0fVnL3S4W2xZztIC_nabcmcM8P89PvSIW6GBo5yZUodyt6uGEA6E9rKIQyXZr0jSk3WuqaJk79fNS8aICIAkHnSlH_IDvDv1kzM_Pb0bQ%3D%3D") {
            ShopifyCheckoutSheetKit.push(checkout: url, from: self, delegate: self)
        }
    }
    
    private func presentCheckout(url: URL) {
        ShopifyCheckoutSheetKit.present(checkout: url, from: self, delegate: self)
    }
    
    @IBAction private func reloadProduct() {
        StorefrontClient.shared.product { [weak self] result in
            if case .success(let product) = result {
                self?.product = product
                self?.title = product.title
            }
        }
    }
    
    private func updateProductDetails() {
        guard let product = product else { return }
        
        titleLabel.text = product.title
        
        if let featuredImageURL = product.featuredImage?.url {
            image.load(url: featuredImageURL)
        }
        
        variantLabel.text = product.vendor
        
        if let variant = product.variants.nodes.first {
            if #available(iOS 15.0, *) {
                buyNowButton.configuration?.subtitle = variant.price.formattedString()
            } else {
                buyNowButton.setTitle(variant.price.formattedString(), for: .normal)
            }
        }
    }
    
    // MARK: ShopifyCheckoutSheetKitDelegate
    
    func checkoutDidComplete(event: ShopifyCheckoutSheetKit.CheckoutCompletedEvent) {
        // use this callback to clean up any cart state
    }
    
    func checkoutDidCancel() {
        dismiss(animated: true)
    }
    
    func checkoutDidFail(error: CheckoutError) {
        print(error)
    }
    
    func checkoutDidEmitWebPixelEvent(event: ShopifyCheckoutSheetKit.PixelEvent) {
        print(#function, event)
    }
}
