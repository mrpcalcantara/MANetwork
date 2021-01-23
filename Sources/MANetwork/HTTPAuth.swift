//
//  HTTPAuth.swift
//  MANetwork
//
//  Created by Miguel Alcântara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation

/**
 Protocol that will set the authentication parameters to be used in the HTTP request
 - parameters:
    - headerToken: The authentication token in the form of a HTTPHeaders type.
    - headerName: A computed variable mapping the header name. For example "Authorization".
    - headerValue: A computed variable mapping the header value. For example, "Bearer access_token".
*/
public protocol HTTPAuthentication {
    /// The authentication token in the form of a HTTPHeaders type.
    var headerToken: HTTPHeaders? { get }
    
    /// A computed variable mapping the header name.
    var headerName: String? { get }
    
    /// A computed variable mapping the header value.
    var headerValue: String? { get }
}

public extension HTTPAuthentication {
    var headerToken: HTTPHeaders? {
        guard let name = headerName, let value = headerValue else { return nil }
        return [name: value]
    }
}
