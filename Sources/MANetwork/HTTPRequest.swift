//
//  HTTPRequest.swift
//  MANetwork
//
//  Created by Miguel Alcântara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation

// MARK: - Typealias

public typealias HTTPHeaders = [String: String]
public typealias HTTPBody = Data

// MARK: - Protocols

/**
 Protocol that defines the parameters needed to build the HTTP Request.
 
 - parameters:
    - requestID: The ID of the request needed to add to the list of ongoing requests
    - headers: The list of headers to be added to the request.
    - method: The HTTP method to be added to the request.
    - auth: The Authentication needed to add onto the headers. Can be Authorization or a custom value.
    - request: The request built according to the parameters described above.
    - configuration: The URLSession configuration to be used in the HTTP client.
 
*/
public protocol HTTPRequest {
    
    /// The ID of the request needed to add to the list of ongoing requests.
    var requestID   : String { get }

    /// The url of the current request.
    var url         : String { get }
    
    /// The headers of the current request.
    var headers     : HTTPHeaders? { get }
    
    /// The HTTP method of the current request.
    var method      : HTTPMethod { get }
    
    /// The authentication data of the current request.
    var auth        : HTTPAuthentication? { get }
    
    /// The request to be used in the HTTP client.
    var request     : URLRequest { get }
    
    /**
     Updates the URL Request header, by adding the header or force-update the existing header.
     
     - parameters:
        - url: The request that is being built.
        - auth: The authentication object that will be used to get the auth data.
    */
    func updateAuthentication(_ urlRequest: inout URLRequest, for auth: HTTPAuthentication)
    
    /**
     Updates the URL, by adding the parameters to its path.
     
     - parameters:
        - url: The url of the request that is being built.
        - list: The list of path parameters that will be added to the path of the URL
    */
    func addPathParameters(_ url: inout URL, for list: [HTTPPathParameterProtocol])

    /**
     Updates the URL, by adding the parameters to its path.
     
     - parameters:
        - url: The url of the request that is being built.
        - list: The list of path parameters that will be added to the path of the URL
    */
    func addPathParameters(_ urlString: inout String, for list: [HTTPPathParameterProtocol])

    /**
     Updates the URL components, by adding the parameters to its query string.
     
     - parameters:
        - urlComponents: The url of the request that is being built.
        - list: The list of path parameters that will be added to the path of the URL
    */
    func addQueryParameters(_ urlComponents: inout URLComponents, for list: [HTTPQueryParameterProtocol])
    
    /**
     Builds the request according to the base URL and its input data. Input data can contain path, query and/or body parameters.
     
     - parameters:
        - url: The base url to add to the request.
        - inputData: The input data needed to correctly build the URL request.
    */
    func buildRequest<T: HTTPRequestInputDataProtocol>(inputData: T?) -> URLRequest
    
}

// MARK: - Extensions
public extension HTTPRequest {
    
    var requestID: String {
        return "\(request.hashValue)"
    }
    
    func updateAuthentication(_ urlRequest: inout URLRequest, for auth: HTTPAuthentication) {
        guard let headerName = auth.headerName, let headerValue = auth.headerValue else { return }
        urlRequest.setValue(headerValue, forHTTPHeaderField: headerName)
    }
    
    func addPathParameters(_ url: inout URL, for list: [HTTPPathParameterProtocol]) {
        var string = url.absoluteString
        list.forEach {
            string = url.absoluteString
                .replacingOccurrences(of: $0.name, with: $0.value)
        }
        
        if let newURL = URL(string: string) {
            url = newURL
        }
        
    }

    func addPathParameters(_ urlString: inout String, for list: [HTTPPathParameterProtocol]) {
        var mappedURL = urlString
        list.forEach {
            mappedURL = urlString .replacingOccurrences(of: $0.name, with: $0.value)
        }
        guard let newURL = URL(string: mappedURL) else { return }
        urlString = newURL.absoluteString
    }
    
    func addQueryParameters(_ urlComponents: inout URLComponents, for list: [HTTPQueryParameterProtocol]) {
        urlComponents.queryItems = list.map { $0.toQueryItem() }
    }
    
    func buildRequest<T: HTTPRequestInputDataProtocol>(inputData: T? = nil) -> URLRequest {
        return buildRequest(queryParameters: inputData?.queryParameters,
                            pathParameters: inputData?.pathParameters,
                            bodyParameters: inputData?.bodyParameters)
    }
    
    
    private func buildRequest(queryParameters: [HTTPQueryParameterProtocol]?,
                              pathParameters: [HTTPPathParameterProtocol]?,
                              bodyParameters: HTTPBody?) -> URLRequest {

        var mappedURL = url
        if let pathParameters = pathParameters { addPathParameters(&mappedURL, for: pathParameters) }
        guard var urlComponents = URLComponents(string: mappedURL),
              let url = urlComponents.url else { return URLRequest.init(url: URL(string: "")!) }
        
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        if let auth = auth { updateAuthentication(&request, for: auth) }
        if let queryParameters = queryParameters { addQueryParameters(&urlComponents, for: queryParameters) }
        if let requestBody = bodyParameters { request.httpBody = requestBody }
    
        return request
    }
}

// MARK: - Basic Request

///Basic request that conforms to the HTTPRequest protocol.
public struct HTTPBasicRequest: HTTPRequest {
    public var url: String = ""
    public var headers: HTTPHeaders? = nil
    public var method: HTTPMethod { return .get }
    public var auth: HTTPAuthentication? = nil
    public var request: URLRequest { return URLRequest(url: URL(string: url)!) }

    /**
     Initializes the request with the following URL and builds the request.
     
     - parameters:
        - urlString: The URL string value.
                    
     Usage example
     ```
    let request = HTTPBasicRequest(urlString: "https://www.google.com")
     ```
    */
    public init(urlString: String) {
        url = urlString
    }
}
