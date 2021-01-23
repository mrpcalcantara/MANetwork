//
//  HTTPParameters.swift
//  MANetwork
//
//  Created by Miguel Alcantara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation

// MARK: - Input Type
/**
 Enum that represents the HTTP input parameter type.
 */
public enum HTTPInputType {
    case query
    case path
    case body
}

// MARK: - Base Protocol
/**
 Base protocol for the HTTP input parameters
 - parameters:
    - name: the name of the parameter
    - inputType: The type of the input ( Path, Query or Body )
*/
protocol HTTPParameterable {
    var name: String { get }
    var inputType: HTTPInputType { get }
}

// MARK: - Base Input Parameter implementation
/**
 The enum of the input parameter that will be mapped into the URL request when built.
 - parameters:
    - parameter: the input parameter conforming to HTTPParameterable
    - value: The value of the parameter
*/
public enum HTTPRequestInputParameter {
    case query(String, String)
    case path(String, String)
    case body(Any?)
    
    /// Contains the parameter type and its key.
    var parameter: String? {
        switch self {
        case .query(let parameter, _),
             .path(let parameter, _):
            return parameter
        default:
            return nil
        }
    }
    
    /// Contains the value for the current parameter, if any.
    var value: Any? {
        switch self {
        case .query(_, let value),
             .path(_, let value):
            return value
        case .body(let value):
            return value
        }
    }
    
    /**
     Getter for the value cast to a generic type.
     - parameters: none.
     - returns: The value cast to the generic type T.
    */
    func getValue<T>(for type: T.Type) -> T? {
        return value as? T
    }
}

// MARK: - Input Data
/**
 Protocol for the object that will contain all the HTTP input parameter types.
 - parameters:
    - inputParameters: The list of all the input parameters.
    - queryParameters: A computed variable filtering the query parameters from the inputParameters property.
    - pathParameters: A computed variable filtering the path parameters from the inputParameters property.
    - bodyParameters: A computed variable filtering the body parameter from the inputParameters property.
*/
public protocol HTTPRequestInputDataProtocol {
    
    /// The associatedtype of the body value to be encoded/decoded.
    associatedtype BodyValueType: Codable = String
    
    /// The list of all the input parameters.
    var inputParameters: [HTTPRequestInputParameter] { get }
    
    /// Computed variable filtering the query parameters from the inputParameters property.
    var queryParameters: [HTTPQueryParameterProtocol]? { get }
    
    /// Computed variable filtering the path parameters from the inputParameters property.
    var pathParameters: [HTTPPathParameterProtocol]? { get }
    
    /// Computed variable filtering the body parameter from the inputParameters property.
    var bodyParameters: HTTPBody? { get }
}

public extension HTTPRequestInputDataProtocol {
    
    var queryParameters: [HTTPQueryParameterProtocol]? {
        inputParameters
            .filter { if case .query = $0 { return true } else { return false } }
            .map { HTTPQueryParameter(name: $0.parameter ?? "", value: $0.value as? String) }
    }
    
    var pathParameters: [HTTPPathParameterProtocol]? {
        inputParameters
            .filter { if case .path = $0 { return true } else { return false } }
            .compactMap { ($0.parameter ?? "", $0.value as? String ?? "") }
            .map { HTTPPathParameter(name: $0.0, value: $0.1) }
    }
    
    var bodyParameters: HTTPBody? {
        inputParameters
            .filter { if case .body = $0 { return true } else { return false } }
            .compactMap { try? JSONEncoder().encode($0.getValue(for: BodyValueType.self)) }
            .first
    }
}


// MARK: - Path Parameter
/**
 Protocol for the HTTP input path parameter types.
 - parameters:
    - name: the name of the parameter
    - value: the value of the parameter to replace the placeholder in the path.
*/
public protocol HTTPPathParameterProtocol {
    var name: String { get }
    var value: String { get }
    
    init(name: String, value: String)
}

/**
 Class implementation of the HTTP Path parameter.
 - parameters:
    - name: the name of the parameter
    - value: the value of the parameter to replace the placeholder in the path.
*/
public struct HTTPPathParameter: HTTPPathParameterProtocol {
    public var name: String
    public var value: String
    
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - Query Parameter
/**
 Protocol for the HTTP input query parameter types.
 - parameters:
    - name: the name of the parameter
    - value: the value of the parameter to add to the query item.
*/
public protocol HTTPQueryParameterProtocol {
    var name: String { get }
    var value: String? { get }
    
    init(name: String, value: String?)
    
    func toQueryItem() -> URLQueryItem
}

/**
 Class implementation of the HTTP Query parameter.
 - parameters:
    - name: the name of the parameter
    - value: the value of the parameter to replace the placeholder in the path.
*/
public struct HTTPQueryParameter: HTTPQueryParameterProtocol {
    public var name: String
    public var value: String?
    
    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
    
    public func toQueryItem() -> URLQueryItem {
        return URLQueryItem(name: name, value: value)
    }
}

// MARK: - Body Parameter
/**
 Default enum of the HTTP Body parameter, to be able to follow the input parameters logic.
 - parameters:
    - body: Default parameter.
*/
private enum HTTPBodyParameterable: HTTPParameterable {
    var inputType: HTTPInputType { return .body }
    var name: String { return "" }
    
    case body
}

protocol HTTPBodyParameterProtocol {
    var value: AnyObject { get }
    init<T: Codable>(value: T)
}

/**
 Class implementation of the HTTP Body parameter.
 - parameters:
    - value: the value of the parameter to be encoded and added to the body of the HTTP request. Must conform to the Codable protocol.
*/
public struct HTTPBodyParameter: HTTPBodyParameterProtocol {
    
    var value: AnyObject
    
    init<T: Codable>(value: T) {
        self.value = value as AnyObject
    }
    
}
