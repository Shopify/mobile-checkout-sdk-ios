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

/**
 * Contains all of the values from the `info.plist`
 */
class InfoDictionary {
    static let shared = InfoDictionary()

    let address1, address2, city, country, firstName, lastName, province, zip,
        email, phone, domain, accessToken, version, buildNumber: String

    init() {
        guard
            let infoPlist = Bundle.main.infoDictionary,
            let address1 = infoPlist["Address1"] as? String,
            let address2 = infoPlist["Address2"] as? String,
            let city = infoPlist["City"] as? String,
            let country = infoPlist["Country"] as? String,
            let firstName = infoPlist["FirstName"] as? String,
            let lastName = infoPlist["LastName"] as? String,
            let province = infoPlist["Province"] as? String,
            let zip = infoPlist["Zip"] as? String,
            let email = infoPlist["Email"] as? String,
            let phone = infoPlist["Phone"] as? String,
            let domain = infoPlist["StorefrontDomain"] as? String,
            let accessToken = infoPlist["StorefrontAccessToken"] as? String,
            let version = infoPlist["CFBundleShortVersionString"] as? String,
            let buildNumber = infoPlist["CFBundleVersion"] as? String
        else {
            fatalError("Missing required configuration. Check your info.plist.")
        }

        self.address1 = address1
        self.address2 = address2
        self.city = city
        self.country = country
        self.firstName = firstName
        self.lastName = lastName
        self.province = province
        self.zip = zip
        self.email = email
        self.phone = phone
        self.domain = domain
        self.accessToken = accessToken
        self.version = version
        self.buildNumber = buildNumber
    }
}
