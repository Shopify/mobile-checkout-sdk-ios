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

import Foundation
import SwiftUI
import ShopifyCheckoutSheetKit

struct SettingsView: View {
	@State private var preloadingEnabled = ShopifyCheckoutSheetKit.configuration.preloading.enabled
	@State private var selectedColorScheme = ShopifyCheckoutSheetKit.configuration.colorScheme

	@Binding var colorScheme: ColorScheme

	var body: some View {
		NavigationView {
			VStack {
				List {
					Section(header: Text("Features")) {
						Toggle("Preload checkout", isOn: $preloadingEnabled)
							.onChange(of: preloadingEnabled) { newValue in
								ShopifyCheckoutSheetKit.configuration.preloading.enabled = newValue
							}
					}

					Section(header: Text("Theme")) {
						ForEach(Configuration.ColorScheme.allCases, id: \.self) { scheme in
							ColorSchemeView(scheme: scheme, isSelected: scheme == selectedColorScheme)
								.background(Color.clear)
								.contentShape(Rectangle())
								.onTapGesture {
									selectedColorScheme = scheme
									ShopifyCheckoutSheetKit.configuration.colorScheme = scheme
									ShopifyCheckoutSheetKit.configuration.tintColor = scheme.tintColor
									ShopifyCheckoutSheetKit.configuration.backgroundColor = scheme.backgroundColor

									switch ShopifyCheckoutSheetKit.configuration.colorScheme {
										case .light:
											colorScheme = .light
										case .dark:
											colorScheme = .dark
										default:
											colorScheme = .light
									}
								}
						}
					}

					Section(header: Text("Version")) {
						HStack {
							Text("App version")
							Spacer()
							Text(currentVersion())
								.font(.system(size: 14))
								.foregroundStyle(.gray)
						}
						HStack {
							Text("SDK version")
							Spacer()
							Text(ShopifyCheckoutSheetKit.version)
								.font(.system(size: 14))
								.foregroundStyle(.gray)
						}
					}
				}
				.listStyle(GroupedListStyle())

			}
			.navigationTitle("Settings")
			.preferredColorScheme(colorScheme)
		}
	}

	private func currentVersion() -> String {
		guard
			let info = Bundle.main.infoDictionary,
			let version = info["CFBundleShortVersionString"] as? String,
			let buildNumber = info["CFBundleVersion"] as? String
		else {
			return "--"
		}

		return "\(version) (\(buildNumber))"
	}
}

struct ColorSchemeView: View {
	let scheme: Configuration.ColorScheme
	let isSelected: Bool

	var body: some View {
		HStack {
			Text(scheme.prettyTitle)
			Spacer()
			if isSelected {
				Text("✓")
			}
		}
	}
}

extension Configuration.ColorScheme {
	var prettyTitle: String {
		switch self {
			case .light:
				return "Light"
			case .dark:
				return "Dark"
			case .automatic:
				return "Automatic"
			case .web:
				return "Web"
		}
	}

	var tintColor: UIColor {
		switch self {
			case .web:
				return UIColor(red: 0.18, green: 0.16, blue: 0.22, alpha: 1.00)
			default:
				return UIColor(red: 0.09, green: 0.45, blue: 0.69, alpha: 1.00)
		}
	}

	var backgroundColor: UIColor {
		switch self {
			case .web:
				return UIColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1.00)
			default:
				return .systemBackground
		}
	}
}

struct SettingsViewPreview: PreviewProvider {
	static var previews: some View {
		SettingsViewPreviewContent(colorScheme: .dark)
	}
}

struct SettingsViewPreviewContent: View {
	@State var colorScheme: ColorScheme = .dark

	var body: some View {
		SettingsView(colorScheme: $colorScheme)
	}
}
