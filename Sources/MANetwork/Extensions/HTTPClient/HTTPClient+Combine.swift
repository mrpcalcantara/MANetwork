//
//  HTTPClient.swift
//  MANetwork
//
//  Created by Miguel Alcântara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation
import Combine

// MARK: - Public

public extension HTTPClient {
    func execute<T: Codable>(apiRequest: HTTPRequest) -> AnyPublisher<T, Error> {
        execute(apiRequest: apiRequest)
            .map { $0.entity }
            .eraseToAnyPublisher()
    }

    func execute<T: Codable>(apiRequest: HTTPRequest) -> AnyPublisher<HTTPClientResponse<T>, Error> {
        executeRequest(for: apiRequest.request)
            .tryCatch { try self.handleError(for: apiRequest, error: $0) }
            .tryMap {
                try HTTPClientResponse<T>(data: $0.data, httpUrlResponse: $0.response as! HTTPURLResponse)
            }
            .eraseToAnyPublisher()
    }

    func handleError(for apiRequest: HTTPRequest, error: Error) throws -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        guard let errorCode = error as? HTTPResponseErrorCode else { throw HTTPResponseErrorCode.internalServerError }
        switch errorCode {
        case .unauthorized:
            return handleRefresh(for: apiRequest)
        default:
            throw errorCode
        }
    }
    
    func handleRefresh(for apiRequest: HTTPRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        executeRequest(for: apiRequest.request)
    }
}

// MARK: - Private

private extension HTTPClient {
    func executeRequest(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryFilter { try self.checkError(for: $0.response) }
            .eraseToAnyPublisher()
    }
    
    func checkError(for response: URLResponse) throws -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return true }
        guard (200...299).contains(httpResponse.statusCode) else { throw HTTPResponseErrorCode(code: httpResponse.statusCode) }
        return true
    }
}
