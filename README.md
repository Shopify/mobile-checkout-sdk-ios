# Shopify Checkout Sheet Kit - Swift

[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](https://github.com/Shopify/checkout-sheet-kit-swift/blob/main/LICENSE) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-2ebb4e.svg?style=flat)](https://swift.org/package-manager/) ![Tests](https://github.com/shopify/checkout-sheet-kit-swift/actions/workflows/test-sdk.yml/badge.svg?branch=main) [![GitHub Release](https://img.shields.io/github/release/shopify/checkout-sheet-kit-swift.svg?style=flat)]()
![image](https://github.com/Shopify/checkout-sheet-kit-swift/assets/2034704/fae4e6e4-0e83-44ab-b65a-c2bceca1afc3)

**Shopify Checkout Sheet Kit** is a Swift Package library that enables Swift apps to provide the world’s highest converting, customizable, one-page checkout within the app. The presented experience is a fully-featured checkout that preserves all of the store customizations: Checkout UI extensions, Functions, branding, and more. It also provides platform idiomatic defaults such as support for light and dark mode, and convenient developer APIs to embed, customize, and follow the lifecycle of the checkout experience. Check out our blog to [learn how and why we built the Checkout Sheet Kit](https://www.shopify.com/partners/blog/mobile-checkout-sdks-for-ios-and-android).

## Requirements

- Swift 5.7+
- iOS SDK 13.0+
- The SDK is not compatible with checkout.liquid. The Shopify Store must be migrated for extensibility

### Getting Started

The SDK is an open-source [Swift Package library](https://www.swift.org/package-manager/). As a quick start, see [sample projects](Samples/README.md) or use one of the following ways to integrate the SDK into your project:

#### Package.swift

```swift
dependencies: [
  .package(url: "https://github.com/Shopify/checkout-sheet-kit-swift", from: "3")
]
```

#### Xcode

1. Open your Xcode project
2. Navigate to `File` > `Add Package Dependencies...`
3. Enter `https://github.com/Shopify/checkout-sheet-kit-swift` into the search box
4. Click `Add Package`

For more details on managing Swift Package dependencies in Xcode, please see [Apple's documentation](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

#### CocoaPods

```ruby
pod "ShopifyCheckoutSheetKit", "~> 3"
```

For more information on CocoaPods, please see their [getting started guide](https://guides.cocoapods.org/using/getting-started.html).

### Programmatic Usage

Once the SDK has been added as a dependency, you can import the library:

```swift
import ShopifyCheckoutSheetKit
```

To present a checkout to the buyer, your application must first obtain a checkout URL. The most common way is to use the [Storefront GraphQL API](https://shopify.dev/docs/api/storefront) to assemble a cart (via `cartCreate` and related update mutations) and query the [checkoutUrl](https://shopify.dev/docs/api/storefront/2023-10/objects/Cart#field-cart-checkouturl). You can use any GraphQL client to accomplish this and we recommend Shopify's [Mobile Buy SDK for iOS](https://github.com/Shopify/mobile-buy-sdk-ios) to simplify the development workflow:

```swift
import Buy

let client = Graph.Client(
  shopDomain: "yourshop.myshopify.com",
  apiKey: "<storefront access token>"
)

let query = Storefront.buildQuery { $0
  .cart(id: "myCartId") { $0
    .checkoutUrl()
  }
}

let task = client.queryGraphWith(query) { response, error in
  let checkoutURL = response?.cart.checkoutUrl
}
task.resume()
```

The `checkoutURL` object is a standard web checkout URL that can be opened in any browser. To present a native checkout sheet in your application, provide the `checkoutURL` alongside optional runtime configuration settings to the `present(checkout:)` function provided by the SDK:

```swift
import UIKit
import ShopifyCheckoutSheetKit

class MyViewController: UIViewController {
  func presentCheckout() {
    let checkoutURL: URL = // from cart object
    ShopifyCheckoutSheetKit.present(checkout: checkoutURL, from: self, delegate: self)
  }
}
```

### SwiftUI Usage

```swift
import SwiftUI
import ShopifyCheckoutSheetKit

struct ContentView: View {
  @State var isPresented = false
  @State var checkoutURL: URL?

  var body: some View {
    Button("Checkout") {
      isPresented = true
    }
    .sheet(isPresented: $isPresented) {
      if let url = checkoutURL {
        CheckoutSheet(url: url)
           /// Configuration
           .title("Checkout")
           .colorScheme(.automatic)
           .tintColor(.blue)
           .backgroundColor(.white)

           /// Lifecycle events
           .onCancel {
             isPresented = false
           }
           .onComplete { event in
             handleCompletedEvent(event)
           }
           .onFail { error in
             handleError(error)
           }
           .onPixelEvent { event in
             handlePixelEvent(event)
           }
           .onLinkClick { url in
              if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
              }
           }
           .edgesIgnoringSafeArea(.all)
      }
    }
  }
}
```

> [!TIP]
> To help optimize and deliver the best experience, the SDK also provides a [preloading API](#preloading) which can be used to initialize the checkout session ahead of time.

### Configuration

The SDK provides a way to customize the presented checkout experience via the `ShopifyCheckoutSheetKit.configuration` object.

#### `colorScheme`

By default, the SDK will match the user's device color appearance. This behavior can be customized via the `colorScheme` property:

```swift
// [Default] Automatically toggle idiomatic light and dark themes based on device preference (`UITraitCollection`)
ShopifyCheckoutSheetKit.configuration.colorScheme = .automatic

// Force idiomatic light color scheme
ShopifyCheckoutSheetKit.configuration.colorScheme = .light

// Force idiomatic dark color scheme
ShopifyCheckoutSheetKit.configuration.colorScheme = .dark

// Force web theme, as rendered by a mobile browser
ShopifyCheckoutSheetKit.configuration.colorScheme = .web
```

#### `tintColor`

If the checkout session is not ready and being initialized, a progress bar is shown and can be customized via the `tintColor` property:

```swift
// Use a custom UI color
ShopifyCheckoutSheetKit.configuration.tintColor = UIColor(red: 0.09, green: 0.45, blue: 0.69, alpha: 1.00)

// Use a system color
ShopifyCheckoutSheetKit.configuration.tintColor = .systemBlue
```

_Note: use preloading to optimize and deliver an instant buyer experience._

#### `backgroundColor`

While the checkout session is being initialized, the background color of the view can be customized via the `backgroundColor` property:

```swift
// Use a custom UI color
ShopifyCheckoutSheetKit.configuration.backgroundColor = UIColor(red: 0.09, green: 0.45, blue: 0.69, alpha: 1.00)

// Use a system color
ShopifyCheckoutSheetKit.configuration.backgroundColor = .systemBackground
```

#### `title`

By default, the Checkout Sheet Kit will look for a `shopify_checkout_sheet_title` key in a `Localizable.xcstrings` file to set the sheet title, otherwise it will fallback to "Checkout" across all locales.

The title of the sheet can be customized by either setting a value for the `shopify_checkout_sheet_title` key in the `Localizable.xcstrings` file for your application or by configuring the `title` property of the `ShopifyCheckoutSheetKit.configuration` object manually.

```swift
// Hardcoded title, applicable to all languages
ShopifyCheckoutSheetKit.configuration.title = "Custom title"
```

Here is an example of a `Localizable.xcstrings` containing translations for 2 locales - `en` and `fr`.

```json
{
  "sourceLanguage": "en",
  "strings": {
    "shopify_checkout_sheet_title": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Checkout"
          }
        },
        "fr": {
          "stringUnit": {
            "state": "translated",
            "value": "Caisse"
          }
        }
      }
    }
  }
}
```

#### SwiftUI Configuration

Similarly, configuration modifiers are available to set the configuration of your checkout when using SwiftUI:

```swift
CheckoutSheet(checkout: checkoutURL)
  .title("Checkout")
  .colorScheme(.automatic)
  .tintColor(.blue)
  .backgroundColor(.black)
```

> [!NOTE]
> Note that if the values of your SwiftUI configuration are **variable** and you are using `preload()`,
> you will need to call `preload()` each time your variables change to ensure that the checkout cache
> has been invalidated, for checkout to be loaded with the new configuration.

### Preloading

Initializing a checkout session requires communicating with Shopify servers and, depending on the network weather and the quality of the buyer's connection, can result in undesirable wait time for the buyer. To help optimize and deliver the best experience, the SDK provides a preloading hint that allows app developers to signal and initialize the checkout session in the background and ahead of time.

Preloading is an advanced feature that can be toggled via a runtime flag:

```swift
ShopifyCheckoutSheetKit.configure {
  $0.preloading.enabled = false // defaults to true
}
```

When enabled, preloading a checkout is as simple as:

```swift
ShopifyCheckoutSheetKit.preload(checkout: checkoutURL)
```

Setting enabled to `false` will cause all calls to the `preload` function to be ignored. This allows the application to selectively toggle preloading behavior as a remote feature flag or dynamically in response to client conditions — e.g. when data saver functionality is enabled by the user.

```
ShopifyCheckoutSheetKit.preloading.enabled = false
ShopifyCheckoutSheetKit.preload(checkout: checkoutURL) // no-op
```

#### Lifecycle management for preloaded checkout

Preloading renders a checkout in a background webview, which is brought to foreground when `ShopifyCheckoutSheetKit.present()` is called. The content of preloaded checkout reflects the state of the cart when `preload()` was initially called. If the cart is mutated after `preload()` is called, the application is responsible for invalidating the preloaded checkout to ensure that up-to-date checkout content is displayed to the buyer:

1. To update preloaded contents: call `preload()` once again
2. To invalidate/disable preloaded content: toggle `ShopifyCheckoutSheetKit.preloading.enabled`

The library will automatically invalidate/abort preload under following conditions:

- Request results in network error or non 2XX server response code
- The checkout has successfully completed, as indicated by the server response
- When `ShopifyCheckoutSheetKit.Configuration` object is updated by the application (e.g., theming changes)

A preloaded checkout _is not_ automatically invalidated when checkout sheet is closed. For example, if a buyer loads the checkout and then exits, the preloaded checkout is retained and should be updated when cart contents change.

#### Additional considerations for preloaded checkout

1. Preloading is a hint, not a guarantee: the library may debounce or ignore calls depending on various conditions; the preload may not complete before `present(checkout:)` is called, in which case the buyer may still see a progress bar while the checkout session is finalized.
1. Preloading results in background network requests and additional CPU/memory utilization for the client and should be used responsibly. For example, conditionally based on state of the client and when there is a high likelihood that the buyer will soon request to checkout.

### Monitoring the lifecycle of a checkout session

You can use the `ShopifyCheckoutSheetKitDelegate` protocol to register callbacks for key lifecycle events during the checkout session:

```swift
extension MyViewController: ShopifyCheckoutSheetKitDelegate {
  func checkoutDidComplete(event: CheckoutCompletedEvent) {
    // Called when the checkout was completed successfully by the buyer.
    // Use this to update UI, reset cart state, etc.
  }

  func checkoutDidCancel() {
    // Called when the checkout was canceled by the buyer.
    // Use this to call `dismiss(animated:)`, etc.
  }

  func checkoutDidFail(error: CheckoutError) {
    // Called when the checkout encountered an error and has been aborted. The callback
    // provides a `CheckoutError` enum, with one of the following values:
    // Internal error: exception within the Checkout SDK code
    // You can inspect and log the Erorr and stacktrace to identify the problem.
    case sdkError(underlying: Swift.Error)

    // Issued when the provided checkout URL results in an error related to shop configuration.
    // Note: The SDK only supports stores migrated for extensibility.
    case configurationError(message: String)

    // Unavailable error: checkout cannot be initiated or completed, e.g. due to network or server-side error
    // The provided message describes the error and may be logged and presented to the buyer.
    case checkoutUnavailable(message: String)

    // Expired error: checkout session associated with provided checkoutURL is no longer available.
    // The provided message describes the error and may be logged and presented to the buyer.
    case checkoutExpired(message: String)
  }

  func checkoutDidClickLink(url: URL) {
    // Called when the buyer clicks a link within the checkout experience:
    //  - email address (`mailto:`),
    //  - telephone number (`tel:`),
    //  - web (`http:`)
    // and is being directed outside the application.
  }

  // Issued when the Checkout has emitted a standard or custom Web Pixel event.
  // Note that the event must be handled by the consuming app, and will not be sent from inside the checkout.
  // See below for more information.
  func checkoutDidEmitWebPixelEvent(event: PixelEvent) {
    switch event {
    case .alertDisplayedEvent(let alertDisplayedEvent):
      recordAnalyticsEvent(alertDisplayedEvent)
    case .uiExtensionErroredEvent(let uiExtensionErroredEvent):
      recordAnalyticsEvent(uiExtensionErroredEvent)
    case .standardEvent(let standardEvent):
      recordAnalyticsEvent(standardEvent)
    case .customEvent(let customEvent):
      recordAnalyticsEvent(customEvent)
    }
  }
}
```

### Error handling

In the event of a checkout error occurring, the Checkout Sheet Kit _may_ attempt a retry to recover from the error. Recovery will happen in the background by discarding the failed webview and creating a new "recovery" instance. Recovery will be attempted in the following scenarios:

- The webview receives a response with a 5XX status code
- An internal SDK error is emitted

There are some caveats to note when this scenario occurs:

1. The checkout experience may look different to buyers. Though the sheet kit will attempt to load any checkout customizations for the storefront, there is no guarantee they will show in recovery mode.
2. The `checkoutDidComplete(event:)` will be emitted with partial data. Invocations will only receive the order ID via `event.orderDetails.id`.
3. `checkoutDidEmitWebPixelEvent` lifecycle methods will **not** be emitted.

Should you wish to opt-out of this fallback experience entirely, you can do so by adding a `shouldRecoverFromError(error:)` method to your delegate controller. Errors given to the `checkoutDidFail(error:)` lifecycle method, will contain an `isRecoverable` property by default indicating whether the request should be retried or not.

```swift
func shouldRecoverFromError(error: CheckoutError) {
  return error.isRecoverable // default
}
```

#### `CheckoutError`

| Type                                                            | Description                                | Recommendation                                                                                    |
| --------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `.configurationError(code: .checkoutLiquidNotAvailable)`        | `checkout.liquid` is not supported.        | Please migrate to checkout extensibility.                                                         |
| `.checkoutUnavailable(message: "Forbidden")`                    | Access to checkout is forbidden.           | This error is unrecoverable.                                                                      |
| `.checkoutUnavailable(message: "Internal Server Error")`        | An internal server error occurred.         | This error will be ephemeral. Try again shortly.                                                  |
| `.checkoutUnavailable(message: "Storefront password required")` | Access to checkout is password restricted. | We are working on ways to enable the Checkout Sheet Kit for usage with password protected stores. |
| `.checkoutExpired(message: "Checkout already completed")`       | The checkout has already been completed    | If this is incorrect, create a new cart and open a new checkout URL.                              |
| `.checkoutExpired(message: "Cart is empty")`                    | The cart session has expired.              | Create a new cart and open a new checkout URL.                                                    |
| `.sdkError(underlying:)`                                        | An error was thrown internally.            | Please open an issue in this repo with as much detail as possible. URL.                           |

#### Integrating with Web Pixels, monitoring behavioral data

App developers can use [lifecycle events](#monitoring-the-lifecycle-of-a-checkout-session) to monitor and log the status of a checkout session.

For behavioural monitoring, Checkout Web Pixel [standard](https://shopify.dev/docs/api/web-pixels-api/standard-events) and [custom](https://shopify.dev/docs/api/web-pixels-api/emitting-data) events will be relayed back to your application through the `checkoutDidEmitWebPixelEvent` delegate hook. The responsibility then falls on the application developer to ensure adherence to Apple's privacy policy and local regulations like GDPR and ePrivacy directive before disseminating these events to first-party and third-party systems.

Here's how you might intercept these events:

```swift
class MyViewController: UIViewController {
  private func sendEventToAnalytics(event: StandardEvent) {
    // Send standard event to third-party providers
  }

  private func sendEventToAnalytics(event: CustomEvent) {
    // Send custom event to third-party providers
  }
  
  private func sendEventToAnalytics(event: AlertDisplayedEvent) {
    // Send alert displayed event to third-party providers
  }
  
  private func sendEventToAnalytics(event: UIExtensionErroredEvent) {
    // Send ui extension errored event to third-party providers
  }

  private func recordAnalyticsEvent(standardEvent: StandardEvent) {
    if hasPermissionToCaptureEvents() {
      sendEventToAnalytics(event: standardEvent)
    }
  }

  private func recordAnalyticsEvent(customEvent: CustomEvent) {
    if hasPermissionToCaptureEvents() {
      sendEventToAnalytics(event: CustomEvent)
    }
  }
  
   private func recordAnalyticsEvent(customEvent: CustomEvent) {
    if hasPermissionToCaptureEvents() {
      sendEventToAnalytics(event: CustomEvent)
    }
  }

  private func recordAnalyticsEvent(alertDisplayedEvent: AlertDisplayedEvent) {
    if hasPermissionToCaptureEvents() {
      sendEventToAnalytics(event: alertDisplayedEvent)
    }
  }
  
  private func recordAnalyticsEvent(uiExtensionErrorEvent: UIExtensionErroredEvent) {
    if hasPermissionToCaptureEvents() {
      sendEventToAnalytics(event: uiExtensionErroredEvent)
    }
  } 
}

extension MyViewController: ShopifyCheckoutSheetKitDelegate {
  func checkoutDidEmitWebPixelEvent(event: PixelEvent) {
    switch event {
    case .alertDisplayedEvent(let alertDisplayedEvent):
      recordAnalyticsEvent(alertDisplayedEvent: alertDisplayedEvent)
    case .uiExtensionErroredEvent(let uiExtensionErroredEvent):
      recordAnalyticsEvent(uiExtensionErroredEvent: uiExtensionErroredEvent)
    case .standardEvent(let standardEvent):
      recordAnalyticsEvent(standardEvent: standardEvent)
    case .customEvent(let customEvent):
      recordAnalyticsEvent(customEvent: customEvent)
    }
  }
}
```

> [!NOTE]
> You may need to augment these events with customer/session information derived from app state.

> [!NOTE]
> The `customData` attribute of CustomPixelEvent can take on any shape. As such, this attribute will be returned as a String. Client applications should define a custom data type and deserialize the `customData` string into that type.

### Integrating identity & customer accounts

Buyer-aware checkout experience reduces friction and increases conversion. Depending on the context of the buyer (guest or signed-in), knowledge of buyer preferences, or account/identity system, the application can use one of the following methods to initialize a personalized and contextualized buyer experience.

#### Cart: buyer bag, identity, and preferences

In addition to specifying the line items, the Cart can include buyer identity (name, email, address, etc.), and delivery and payment preferences: see [guide](https://shopify.dev/docs/custom-storefronts/building-with-the-storefront-api/cart/manage). Included information will be used to present pre-filled and pre-selected choices to the buyer within checkout.

#### Multipass

[Shopify Plus](https://help.shopify.com/en/manual/intro-to-shopify/pricing-plans/plans-features/shopify-plus-plan) merchants using [Classic Customer Accounts](https://help.shopify.com/en/manual/customers/customer-accounts/classic-customer-accounts) can use [Multipass](https://shopify.dev/docs/api/multipass) ([API documentation](https://shopify.dev/docs/api/multipass)) to integrate an external identity system and initialize a buyer-aware checkout session.

```json
{
  "email": "<Customer's email address>",
  "created_at": "<Current timestamp in ISO8601 encoding>",
  "remote_ip": "<Client IP address>",
  "return_to": "<Checkout URL obtained from Storefront API>"
}
```

1. Follow the [Multipass documentation](https://shopify.dev/docs/api/multipass) to create a Multipass URL and set `return_to` to be the obtained `checkoutUrl`
2. Provide the Multipass URL to `present(checkout:)`

> [!IMPORTANT]
> The above JSON omits useful customer attributes that should be provided where possible and encryption and signing should be done server-side to ensure Multipass keys are kept secret.

#### Shop Pay

To initialize accelerated Shop Pay checkout, the cart can set a [walletPreference](https://shopify.dev/docs/api/storefront/latest/mutations/cartBuyerIdentityUpdate#field-cartbuyeridentityinput-walletpreferences) to 'shop_pay'. The sign-in state of the buyer is app-local. The buyer will be prompted to sign in to their Shop account on their first checkout, and their sign-in state will be remembered for future checkout sessions.

#### Customer Account API

We are working on a library to provide buyer sign-in and authentication powered by the [new Customer Account API](https://www.shopify.com/partners/blog/introducing-customer-account-api-for-headless-stores)—stay tuned.

---

### Contributing

We welcome code contributions, feature requests, and reporting of issues. Please see [guidelines and instructions](.github/CONTRIBUTING.md).

### License

Shopify's Checkout Sheet Kit is provided under an [MIT License](LICENSE).
