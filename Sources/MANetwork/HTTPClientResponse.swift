//
//  HTTPClientResponse.swift
//  MANetwork
//
//  Created by Miguel Alcântara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation

enum ResponseError: Error, CaseIterable {
    //Validate which are needed, delete the others
    case unknownError
    case connectionError
    case invalidCredentials
    case invalidRequest
    case notFound
    case invalidResponse
    case serverError
    case serverUnavailable
    case timeOut
    case unsupportedURL
    case noData
}

/// Enum that lists all the possible error codes.
enum HTTPResponseErrorCode : Int, Error, CaseIterable {
    
    /// OK ( HTTP 200 )
    case ok = 200
    
    /// Created ( HTTP 201 )
    case created = 201
    
    /// No Content ( HTTP 204 )
    case noContent = 204
    
    /// Bad Request ( HTTP 400 )
    case badRequest = 400
    
    /// Unauthorized ( HTTP 401 )
    case unauthorized = 401
    
    /// Forbidden ( HTTP 403 )
    case forbidden = 403
    
    /// Not Found ( HTTP 404 )
    case notFound = 404
    
    /// Method Not Allowed ( HTTP 405 )
    case methodNotAllowed = 405
    
    /// Resource Conflict ( HTTP 409 )
    case resourceConflict = 409
    
    /// Internal Server Error ( HTTP 500 )
    case internalServerError = 500
    
    /// Request timeout.
    case timeout = -1001
    
    /// Offline ( No internet connection ).
    case offline = -1009
    
    /// Host Name Not Found.
    case hostNameNotFound = -1003 //github-awardsboooo.com
    
    /// Could not Connect to server.
    case couldNotConnectToServer = -1004 //ex: localhost turned off
    
    /// Unknown. Default value
    case unknown = -1
    
    /**
     Initializes the request with the response object following the request execution.
     
     - parameters:
        - response: The URL response object.
                    
     Usage example
     ```
    let errorCode = HTTPResponseErrorCode(response: response)
     ```
    */
    init(response: HTTPURLResponse) {
        self = HTTPResponseErrorCode(rawValue: response.statusCode) ?? .unknown
    }
    
    /**
     Initializes the request with the response status code.
     
     - parameters:
        - code: The URL response status code.
                    
     Usage example
     ```
    let errorCode = HTTPResponseErrorCode(code: 200)
     ```
    */
    init(code: Int) {
        self = HTTPResponseErrorCode(rawValue: code) ?? .unknown
    }
    
    /// Custom error description for the URL response. Needs to be localized.
    var description: String {
        switch self {
        case .ok: return "ok"
        case .created: return "created"
        case .noContent: return "noContent"
        case .badRequest: return "badRequest"
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .notFound: return "notFound"
        case .methodNotAllowed: return "methodNotAllowed"
        case .timeout: return "timeout"
        case .internalServerError: return "internalError"
        case .resourceConflict: return "resourceConflict"
        case .unknown: return "unknown"
        case .offline: return "offline"
        case .hostNameNotFound: return "hostNameNotFound"
        case .couldNotConnectToServer: return "couldNotConnectToServer"
        }
    }
    
}

/**
 Protocol that defines the properties of the custom HTTPError to be handled by the app.
 
 - parameters:
    - data: URL response data, if any.
    - httpUrlResponse: URL response, if any.
*/
public protocol HTTPURLErrorProtocol {
    
    /// URL response data, if any.
    var data            : Data? { get }
    
    /// URL response, if any.
    var httpUrlResponse : HTTPURLResponse? { get }
}

/**
 Struct implementation of the HTTPURLErrorProtocol protocol.
 
 - parameters:
    - data: URL response data, if any.
    - httpUrlResponse: URL response, if any.
    - error: Error returned by the HTTP call. Universal as it can be an error that reached the network or not.
*/
public struct HTTPError: Error, HTTPURLErrorProtocol {
    public var data            : Data?
    public var httpUrlResponse : HTTPURLResponse?
    
    /// Error returned by the HTTP call.
    let error           : Error?
    
    /// Computed variable that returns a value of the enum HTTPResponseErrorCode.
    var errorCode: HTTPResponseErrorCode {
        guard let response = httpUrlResponse else { return .unknown }
        return HTTPResponseErrorCode(response: response)
    }
   
    /// Computed variable that returns the description of the errorCode description
    var description : String{
        return errorCode.description
    }
}

/**
 Struct implementation of the HTTPURLErrorProtocol protocol, when there was an error parsing the URL response data.
 
 - parameters:
    - data: URL response data, if any.
    - httpUrlResponse: URL response, if any.
    - error: Error returned by the HTTP call. Universal as it can be an error that reached the network or not.
*/
public struct HTTPParseError: Error, HTTPURLErrorProtocol {
    static let code = HTTPResponseErrorCode.unknown.rawValue
    
    public var error           : Error
    public var httpUrlResponse : HTTPURLResponse?
    public let data            : Data?
    
    var localizedDescription: String {
        return error.localizedDescription
    }
}


public protocol HTTPClientResponseProtocol {
    associatedtype ResponseType: Codable
    var entity          : ResponseType { get }
    var httpUrlResponse : HTTPURLResponse? { get }
    var data            : Data? { get }
}
/**
 Response object that contains the HTTP data, such as response and data as well as the decoded data, according to the generic type associated with the request.
 
 - parameters:
    - entity: Decoded DTO object from the data property.
    - httpUrlResponse: URL response, if any.
    - data: Response data after making the request.
*/
public struct HTTPClientResponse<T : Codable>: HTTPClientResponseProtocol {
    
    /// Decoded DTO object from the data property.
    public let entity          : T
    public let httpUrlResponse : HTTPURLResponse?
    public let data            : Data?
    
    init(data: Data?, httpUrlResponse: HTTPURLResponse, toDecode: Bool = true) throws {
        do {
            let decoder = JSONDecoder()
            self.entity             = try decoder.decode(T.self, from: data!)
            self.httpUrlResponse    = httpUrlResponse
            self.data               = data
        } catch {
            throw HTTPParseError(error: error,
                                 httpUrlResponse: httpUrlResponse,
                                 data: data)
        }
    }
    
    init(from response: HTTPResponse) throws {
        do {
            guard let data = response.data else { throw ResponseError.noData }
            let decoder = JSONDecoder()
            self.entity             = try decoder.decode(T.self, from: data)
            self.httpUrlResponse    = response.httpResponse as? HTTPURLResponse
            self.data               = response.data
        } catch {
            throw HTTPParseError(error: error,
                                 httpUrlResponse: response.httpResponse as? HTTPURLResponse,
                                 data: response.data)
        }
    }
}


public struct HTTPResponse {
    
    let data: Data?
    let httpResponse: URLResponse?
    let error: Error?
    
}
