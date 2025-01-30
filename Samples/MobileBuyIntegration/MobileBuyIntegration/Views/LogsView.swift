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
import SwiftUI

@available(iOS 15.0, *)
struct LogsView: View {
    @State private var logs: [String?] = LogReader.shared.readLogs(limit: 100) ?? []

    var body: some View {
        VStack {
            List {
                if logs.isEmpty {
                    HStack {
                        Spacer()
                        Text("No logs available")
                            .font(.system(size: 12))
                            .padding()
                        Spacer()
                    }
                } else {
                    ForEach(logs, id: \.self) { log in
                        Text(log ?? "No log available")
                            .font(.system(size: 12))
                    }

                    HStack {
                        Spacer()
                        Button(action: clearLogs) {
                            Text("Clear logs")
                                .foregroundColor(.red)
                                .background(.white)
                                .font(.system(size: 12))
                        }
                        Spacer()
                    }
                }
            }
            .refreshable {
                logs = readLogs()
            }
        }
        .navigationTitle("Logs")
        .navigationBarItems(
            trailing: Button(action: clearLogs) {
                Text("Clear")
            }
        )
        .onAppear {
            logs = readLogs()
        }
    }

    private func clearLogs() {
        ShopifyCheckoutSheetKit.configuration.logger.clearLogs()
        logs = readLogs()
    }

    private func readLogs() -> [String?] {
        return LogReader.shared.readLogs(limit: 100) ?? []
    }
}
