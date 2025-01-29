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

import SafariServices
import SwiftUI
import WebKit

@main
struct OffsitePaymentApp: App {
    @State private var showPaymentSheet: Bool = false
    @State private var paymentUrl: String = ""
    @State private var paymentStatus: PaymentStatus?
    @State private var timer: Timer?
    @State private var error: String?

    enum PaymentStatus {
        case confirmed, cancelled
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 15) {
                Image(systemName: iconForStatus())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .foregroundColor(colorForStatus())

                Text(statusText())
					.font(.title3)
                    .fontWeight(.bold)
					.lineLimit(1)

				Text(descriptionText())
					.font(.body)
					.lineLimit(3)
					.multilineTextAlignment(.center)
					.padding(5)

				Text(error ?? "")
					.font(.footnote)
					.foregroundStyle(Color.red)
            }
            .padding(30)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(20)
            .shadow(
				color: Color.black.opacity(0.1),
				radius: 10,
				x: 0,
				y: 10
			)
			.padding()
            .onOpenURL(perform: handleOpenURL)
			.sheet(isPresented: $showPaymentSheet, onDismiss: {
				self.startTimer()
			}) {
				PaymentConfirmationView(url: $paymentUrl)
					.navigationTitle("Payment Confirmation")
					.presentationDragIndicator(.visible)
					.navigationBarTitleDisplayMode(.inline)
            }
            .padding(30)
        }
    }

    private func handleOpenURL(_ url: URL) {
		let urlString = url.absoluteString
        print("Received URL: \(urlString)")

        if url.scheme == "offsitepayment" {
			if let urlComponents = URLComponents(string: url.absoluteString) {
				if let urlQueryItem = urlComponents.queryItems?.first(where: { $0.name == "url" }) {
					if let urlValue = urlQueryItem.value {
						print("url parameter: \(urlValue)")
						paymentUrl = urlValue
						showPaymentSheet = true
					} else {
						showError("The url parameter is present but has no value", url)
					}
				} else {
					showError("The url parameter is not found", url)
				}
			} else {
				showError("Invalid URL", url)
			}
        } else {
            showError("Scheme does not match", url)
        }
    }

    private func showError(_ message: String, _ url: URL) {
		error = "\(message). \n\n\(url.absoluteString)"
	}

    private func iconForStatus() -> String {
		switch paymentStatus {
		case .confirmed:
			return "checkmark.circle.fill"
		case .cancelled:
			return "xmark.circle.fill"
		default:
			return "creditcard.fill"
		}
	}

	private func colorForStatus() -> Color {
		switch paymentStatus {
		case .confirmed:
			return .green
		case .cancelled:
			return .red
		default:
			return .blue
		}
	}

	private func statusText() -> String {
		switch paymentStatus {
		case .confirmed:
			return "Payment Confirmed"
		case .cancelled:
			return "Payment Cancelled"
		default:
			return "Offsite Payment"
		}
	}

	private func descriptionText() -> String {
		switch paymentStatus {
		case .confirmed:
			return "Redirecting..."
		case .cancelled:
			return "Payment cancelled. Redirecting..."
		default:
			return "This app is intended to simulate the experience of an offiste payment app."
		}
	}

	private func startTimer() {
		// Invalidate any existing timer before creating a new one
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
			resetState()
		}
	}

	private func stopTimer() {
		timer?.invalidate()
		timer = nil
	}

	private func resetState() {
		showPaymentSheet = false
		paymentUrl = ""
		paymentStatus = nil
	}
}

    // Safari View for SwiftUI
struct SafariView: UIViewControllerRepresentable {
    let url: String

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: URL(string: url)!)
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No update logic needed for SFSafariViewController
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isInspectable = true
        webView.navigationDelegate = context.coordinator

        // Set up cookie synchronization
        syncCookies(webView: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            print("Loading URL: \(url)")
            webView.load(request)
        } else {
            print("Invalid URL: \(urlString)")
        }
    }

    func syncCookies(webView: WKWebView) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = HTTPCookieStorage.shared.cookies ?? []

        cookies.forEach { cookie in
            cookieStore.setCookie(cookie)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("Started loading: \(String(describing: webView.url))")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Finished loading: \(String(describing: webView.url))")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Failed to load: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Failed provisional navigation: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            print("Received server redirect")
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            print("Web content process terminated")
        }
    }
}

struct PaymentConfirmationView: View {
    @Binding var url: String

    var body: some View {
        NavigationView {
			SafariView(url: url).edgesIgnoringSafeArea(.all)
        }
    }
}
