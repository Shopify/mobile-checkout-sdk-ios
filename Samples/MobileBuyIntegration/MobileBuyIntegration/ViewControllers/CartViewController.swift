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
import ShopifyCheckoutSheetKit
import UIKit

class CartItemCell: UITableViewCell {
    let titleLabel = UILabel()
    let vendorLabel = UILabel()
    let quantityLabel = UILabel()
    let decreaseButton = UIButton(type: .system)
    let increaseButton = UIButton(type: .system)
    let labelStackView = UIStackView()
    let quantityStackView = UIStackView()
    let activityIndicator = UIActivityIndicatorView()

    var onQuantityChange: ((_ quantity: Int32) -> Void)?

    private var quantity: Int32 = 0 {
        didSet {
            quantityLabel.text = "\(quantity)"
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        /// Title stack config
        labelStackView.axis = .vertical
        labelStackView.alignment = .leading
        labelStackView.spacing = 4
        labelStackView.translatesAutoresizingMaskIntoConstraints = false

        /// Quantity stack config
        quantityStackView.axis = .horizontal
        quantityStackView.alignment = .center
        quantityStackView.spacing = 8
        quantityStackView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.numberOfLines = 0
        vendorLabel.numberOfLines = 0
        vendorLabel.textColor = .systemBlue
        vendorLabel.font = UIFont.systemFont(ofSize: 12)

        /// Title / vendor
        labelStackView.addArrangedSubview(titleLabel)
        labelStackView.addArrangedSubview(vendorLabel)

        /// Configure spinner
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        /// Quantity controls
        quantityStackView.addArrangedSubview(decreaseButton)
        quantityStackView.addArrangedSubview(activityIndicator)
        quantityStackView.addArrangedSubview(quantityLabel)
        quantityStackView.addArrangedSubview(increaseButton)

        decreaseButton.setTitle("-", for: .normal)
        increaseButton.setTitle("+", for: .normal)
        decreaseButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        increaseButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)

        activityIndicator.widthAnchor.constraint(equalToConstant: 20).isActive = true
        quantityLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true
        quantityLabel.textAlignment = .center

        decreaseButton.addTarget(self, action: #selector(decreaseQuantity), for: .touchUpInside)
        increaseButton.addTarget(self, action: #selector(increaseQuantity), for: .touchUpInside)

        contentView.addSubview(labelStackView)
        contentView.addSubview(quantityStackView)

        NSLayoutConstraint.activate([
            labelStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            labelStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelStackView.trailingAnchor.constraint(equalTo: quantityStackView.leadingAnchor, constant: -16),

            quantityStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            quantityStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    @objc private func decreaseQuantity() {
        if quantity > 1 {
            quantity -= 1
            onQuantityChange?(quantity)
        }
    }

    @objc private func increaseQuantity() {
        quantity += 1
        onQuantityChange?(quantity)
    }

    func showLoading(_ loading: Bool) {
        if loading {
            quantityLabel.isHidden = true
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
            quantityLabel.isHidden = false
        }
    }

    func configure(with variant: Storefront.ProductVariant, quantity: Int32) {
        titleLabel.text = variant.product.title
        vendorLabel.text = variant.product.vendor
        self.quantity = quantity
    }
}

class CartViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // MARK: Properties

    private var bag = Set<AnyCancellable>()

    @IBOutlet private var emptyView: UIView!

    @IBOutlet private var tableView: UITableView!

    @IBOutlet private var footerView: UIView!

    @IBOutlet private var checkoutButton: UIButton!

    // MARK: Initializers

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Reset", style: .plain, target: self, action: #selector(resetCart)
        )

        CartManager.shared.$cart
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.cartDidUpdate()
            }
            .store(in: &bag)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UIViewController Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(
            UITableViewCell.self, forCellReuseIdentifier: "CartItemCell"
        )
        tableView.allowsSelection = false
        tableView.rowHeight = 80

        cartDidUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView.reloadData()

        if let url = CartManager.shared.cart?.checkoutUrl {
            ShopifyCheckoutSheetKit.preload(checkout: url)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        tableView.contentInset.bottom = footerView.frame.size.height
    }

    // MARK: UITableViewDataSource

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return CartManager.shared.cart?.lines.nodes.count ?? 0
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let node = node(at: indexPath)
        let variant = variant(at: indexPath)

        let cell = CartItemCell()
        cell.configure(with: variant, quantity: node.quantity)
        cell.onQuantityChange = { quantity in
            /// Display loading state on row + disable checkout button
            cell.showLoading(true)
            self.checkoutButton.isEnabled = false

            /// Invalidate checkout cache to ensure correct number of items are shown on checkout
            ShopifyCheckoutSheetKit.invalidate()

            /// Update cart quantities
            _Concurrency.Task {
                let cart = try await CartManager.shared.performCartLinesUpdate(id: node.id, quantity: quantity)

                cell.showLoading(false)
                self.checkoutButton.isEnabled = true
                cell.quantityLabel.text = "\(cart.lines.nodes[indexPath.item].quantity)"

                ShopifyCheckoutSheetKit.preload(checkout: cart.checkoutUrl)
            }
        }
        return cell
    }

    // MARK: Private

    private func cartDidUpdate() {
        let cart = CartManager.shared.cart
        let totalQuantity = cart?.totalQuantity ?? 0

        tabBarItem.badgeValue = String(totalQuantity)

        if isViewLoaded {
            emptyView.isHidden = totalQuantity > 0
            tableView.reloadData()
            tableView.isHidden = totalQuantity <= 0
            checkoutButton.isHidden = totalQuantity <= 0

            if #available(iOS 15.0, *) {
                checkoutButton.configuration?
                    .subtitle = cart?.cost.totalAmount.formattedString()
            }
        }
    }

    @IBAction private func presentCheckout() {
        guard let url = CartManager.shared.cart?.checkoutUrl else { return }

        ShopifyCheckoutSheetKit.present(checkout: url, from: self, delegate: self)
    }

    @IBAction private func resetCart() {
        CartManager.shared.resetCart()
    }

    private func node(at indexPath: IndexPath) -> BaseCartLine {
        guard let lines = CartManager.shared.cart?.lines.nodes else {
            fatalError("invald index path")
        }

        return lines[indexPath.item]
    }

    private func variant(at indexPath: IndexPath) -> Storefront.ProductVariant {
        guard
            let variant = node(at: indexPath).merchandise as? Storefront.ProductVariant
        else {
            fatalError("invald index path")
        }
        return variant
    }
}

extension CartViewController: CheckoutDelegate {
    func checkoutDidComplete(event: ShopifyCheckoutSheetKit.CheckoutCompletedEvent) {
        resetCart()

        ShopifyCheckoutSheetKit.configuration.logger.log("Order created: \(event.orderDetails.id)")
    }

    func checkoutDidCancel() {
        dismiss(animated: true)
    }

    func checkoutDidClickContactLink(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    func checkoutDidFail(error: ShopifyCheckoutSheetKit.CheckoutError) {
        var errorMessage = ""

        /// Internal Checkout SDK error
        if case let .sdkError(underlying, _) = error {
            errorMessage = "\(underlying.localizedDescription)"
        }

        /// Checkout unavailable error
        if case let .checkoutUnavailable(message, code, _) = error {
            errorMessage = message
            handleCheckoutUnavailable(message, code)
        }

        /// Storefront configuration error
        if case let .configurationError(message, _, _) = error {
            errorMessage = message
        }

        /// Checkout has expired, re-create cart to fetch a new checkout URL
        if case let .checkoutExpired(message, _, _) = error {
            errorMessage = message
        }

        print(errorMessage, "Recoverable: \(error.isRecoverable)")

        if !error.isRecoverable {
            handleUnrecoverableError(errorMessage)
        }
    }

    private func handleCheckoutUnavailable(_ message: String, _ code: CheckoutUnavailable) {
        switch code {
        case let .clientError(clientErrorCode):
            print("[CheckoutUnavailable] (checkoutError)", message, clientErrorCode)
        case let .httpError(statusCode):
            print("[CheckoutUnavailable] (httpError)", statusCode)
        }
    }

    func checkoutDidEmitWebPixelEvent(event: ShopifyCheckoutSheetKit.PixelEvent) {
        switch event {
        case let .customEvent(customEvent):
            print("[PIXEL - Custom]", customEvent.name!)
            if let genericEvent = mapToGenericEvent(customEvent: customEvent) {
                recordAnalyticsEvent(genericEvent)
            }
        case let .standardEvent(standardEvent):
            print("[PIXEL - Standard]", standardEvent.name!)
            recordAnalyticsEvent(mapToGenericEvent(standardEvent: standardEvent))
        }
    }

    private func handleUnrecoverableError(_ message: String = "Checkout unavailable") {
        DispatchQueue.main.async {
            self.resetCart()
            self.showAlert(message: message)
        }
    }
}

extension CartViewController {
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Checkout Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in }))

        present(alert, animated: true, completion: nil)
    }
}

// analytics examples
extension CartViewController {
    private func mapToGenericEvent(standardEvent: StandardEvent) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: standardEvent.name!,
            userId: getUserId(),
            timestamp: standardEvent.timestamp!,
            checkoutTotal: standardEvent.data?.checkout?.totalPrice?.amount ?? 0.0
        )
    }

    private func mapToGenericEvent(customEvent: CustomEvent) -> AnalyticsEvent? {
        guard customEvent.name != nil else {
            print("Failed to parse custom event", customEvent)
            return nil
        }
        return AnalyticsEvent(
            name: customEvent.name!,
            userId: getUserId(),
            timestamp: customEvent.timestamp!,
            checkoutTotal: nil
        )
    }

    private func decodeAndMap(event: CustomEvent, decoder _: JSONDecoder = JSONDecoder()) throws -> AnalyticsEvent {
        return AnalyticsEvent(
            name: event.name!,
            userId: getUserId(),
            timestamp: event.timestamp!,
            checkoutTotal: nil
        )
    }

    private func getUserId() -> String {
        // return ID for user used in your existing analytics system
        return "123"
    }

    func recordAnalyticsEvent(_ event: AnalyticsEvent) {
        // send the event to an analytics system, e.g. via an analytics sdk
        appConfiguration.webPixelsLogger.log(event.name)
    }
}

// example type, e.g. that may be defined by an analytics sdk
struct AnalyticsEvent: Codable {
    var name = ""
    var userId = ""
    var timestamp = ""
    var checkoutTotal: Double? = 0.0
}

struct CustomPixelEventData: Codable {
    var customAttribute = 0.0
}
