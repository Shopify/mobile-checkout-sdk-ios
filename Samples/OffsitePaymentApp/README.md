```diff
extension CheckoutWebView: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard let url = action.request.url else {
			decisionHandler(.allow)
			return
		}

+		if url.absoluteString.contains("offsite") {
+			UIApplication.shared.open(URL(string:"offsitepayment://payment?url=\(url.absoluteString)")!)
+			decisionHandler(.cancel)
+			return
+		}

		if isExternalLink(action) || CheckoutURL(from: url).isDeepLink() {
			OSLogger.shared.debug("External or deep link clicked: \(url.absoluteString) - request intercepted")
			viewDelegate?.checkoutViewDidClickLink(url: removeExternalParam(url))
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}
}
```
