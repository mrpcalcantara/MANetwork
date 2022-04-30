//
//  HTTPClient.swift
//  MANetwork
//
//  Created by Miguel Alcântara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation

// MARK: - Typealias

/// Ongoing Request list type with Request ID and number of retries.
public typealias OngoingRequestListType = [String: Int]

/// Waiting Request list type with Request ID and the request's completion handler.
public typealias WaitingRequestListType = [(HTTPRequest, ExecuteDataCompletionType?)]

/// RefreshToken type with a flag stating the token has been refreshed and the new access token.
public typealias RefreshTokenHandlerCompletionType = ((Bool, String) -> ())

/// Completion handler for when the request is executed, returning a Result with the Decoded type or the Error.
public typealias ExecuteCompletionType<T: Codable> = ((Result<HTTPClientResponse<T>, Error>) -> Void)

/// Completion handler for when the request is executed, returning the result data.
public typealias ExecuteDataCompletionType = ((HTTPResponse) -> Void)

/// Completion handler for when the download data task is executed, returning a Result with the Data object or the Error.
public typealias DownloadDataCompletionType = ((Result<Data, Error>) -> ())

// MARK: - Protocols
/**
 Delegate for the HTTPClient, in case there is some action needed that does not concern the client itself.
 */
public protocol HTTPClientProtocolDelegate: AnyObject {
    
    /**
     Notifies the delegate that a HTTP 401 occurred and further action is needed to refresh the invalid authentication token.
     
     - parameters:
        - httpRequest: the failed request of type HTTPRequest
        - completion: the completion handler once any action has been done to retry the request and pass the new refreshed token
                    
     
     Usage example
     ```
    func needsRefresh(for httpRequest: HTTPRequest, completion: @escaping RefreshTokenHandlerCompletionType) {
        // Refresh the tokens and then notify the HTTPClient to retry the request with the new token
        completion(true, "newToken")
    }
     ```
    */
    func needsRefresh(for httpRequest: HTTPRequest, completion: @escaping RefreshTokenHandlerCompletionType)
}

public protocol HTTPClientProtocol {
    /**
     Executes the REST call and decodes the response, returning the data through a completion handler.
     
     - parameters:
        - httpRequest: an object of the type HTTPRequest
        - completionHandler: the completion handler object of type Result<T, Error> in which T must conform to the Codable protocol ( to be able to decode the answer to the app's DTO response object )
                    
     
     Usage example
     ```
    HTTPClient().execute(httpRequest: request) { (result: Result<HTTPClientResponse<GitHubUser>, Error>) in
        switch result {
        case .success(let response):
            // Do something on success
        case .failure(let error):
            // Handle the error
        }
    }
     ```
    */
    func execute<T>(httpRequest: HTTPRequest, completionHandler: ExecuteCompletionType<T>?)

    func execute<T>(httpRequest: HTTPRequest) async throws -> HTTPClientResponse<T>
    
    /**
     Executes the REST call and decodes the response, returning the data through a completion handler.
     
     - parameters:
        - httpRequest: an object of the type HTTPRequest
        - completionHandler: the completion handler object of type Result<T, Error> in which T must conform to the Codable protocol ( to be able to decode the answer to the app's DTO response object )
                    
     
     Usage example
     ```
    HTTPClient().downloadData(urlString: "https://innowave.tech/wp-content/uploads/2018/05/innowave_2-01.png") { data in
        switch result {
        case .success(let response):
            // Do something on success
        case .failure(let error):
            // Handle the error
        }
    }
     ```
    */
    func downloadData(for urlString: String, completionHandler: @escaping DownloadDataCompletionType)

    func downloadData(for urlString: String) async throws -> Data
}

// MARK: - HTTPClient Implementation
/**
HTTP Client to be used in the app. It encapsulates the Foundation URLSession framework, complementing with some custom logic:

   - Handles errors, such as:
       - 401 ( Unauthorized ): Notify the class responsible for handling the token/auth refresh, through a delegate. A completion is available to notify the HTTPClient to retry the request
       - 429 ( Too Many Requests ): Pause the request for the amount of time passed on the response header.
       - To add more, as you see fit.
*/

public class HTTPClient: HTTPClientProtocol {
    
    // MARK: - Properties
    
    /// List of ongoing requests.
    private var _ongoingRequestDict = OngoingRequestListType()
    
    /// List of requests waiting to be executed.
    private var _waitingRequestDict = WaitingRequestListType()
    
    /// Maximum number of retries.
    private var _retryLimit: Int { return 3 }
    
    /// Delegate that will handle the client's actions, as needed.
    weak var delegate: HTTPClientProtocolDelegate?
    
    /// The URL Session to be used in the HTTP client.
    private let _session: URLSession
    
    // MARK: - Initializer
    
    public init(configuration : URLSessionConfiguration = .default) {
        _session = URLSession.init(configuration: configuration)
    }
    
    // MARK: - Protocol Functions
    
    public func execute<T>(httpRequest: HTTPRequest) async throws -> HTTPClientResponse<T> {
        try await withCheckedThrowingContinuation { continuation in
            execute(httpRequest: httpRequest) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func downloadData(for urlString: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            downloadData(for: urlString) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func execute<T>(httpRequest: HTTPRequest, completionHandler: ExecuteCompletionType<T>?) {
        self.execute(httpRequest: httpRequest) { (response) in
            do {
                let response = try HTTPClientResponse<T>(data: response.data, httpUrlResponse: HTTPURLResponse())
                completionHandler?(.success(response))
            } catch(let error) {
                completionHandler?(.failure(error))
            }
        }
    }

    public func downloadData(for urlString: String, completionHandler: @escaping DownloadDataCompletionType) {
        guard let url = URL(string: urlString) else {
            completionHandler(.failure(ResponseError.unsupportedURL))
            return
        }
        _session.dataTask(with: url) { (data, response, error) in
            guard error  == nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.isSuccess else {
                    if let error = error { completionHandler(.failure(error)) }
                    return
            }
            completionHandler(.success(data ?? Data()))
        }.resume()
    }

}

// MARK: - Private

private extension HTTPClient {
    /**
     Executes the request and sends the data in a Data format to be converted by the caller.
     
     - parameters:
        - httpRequest: the failed request of the type HTTPRequest
        - data: the data returned by the request
        - response: the response following the executed request
        - error: the error that occurred
        - completionHandler: the completion handler object of type ExecuteDataCompletionType which send back a Data object, if any.
    */
    func execute(httpRequest: HTTPRequest, completionHandler: ExecuteDataCompletionType?) {
        addRequest(for: httpRequest.requestID)
        _session.dataTask(with: httpRequest.request) { (data, response, error) in
            guard error  == nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.isSuccess else {
                    return self.handleError(for: httpRequest,
                                            data: data,
                                            response: response,
                                            error: error,
                                            completionHandler: completionHandler)
            }
            defer { self.removeRequest(for: httpRequest.requestID) }
            guard let data = data else { return }
            completionHandler?(HTTPResponse(data: data, httpResponse: httpResponse, error: error))
        }.resume()
    }
    
    /**
     Handles the error occurred when making the request, accordingly.
     
     - parameters:
        - httpRequest: the failed request of the type HTTPRequest
        - data: the data returned by the request
        - response: the response following the executed request
        - error: the error that occurred
        - completionHandler: the completion handler object of type ExecuteDataCompletionType which send back a Data object, if any.
    */
    func handleError(for httpRequest: HTTPRequest,
                                data: Data?,
                                response: URLResponse?,
                                error: Error?,
                                completionHandler: ExecuteDataCompletionType?) {
        guard let httpResponse = response as? HTTPURLResponse else {
            if let error = error { completionHandler?(HTTPResponse(data: data, httpResponse: nil, error: error)) }
            return
        }
        
        switch httpResponse.statusCode {
        case 401:
            //Renew token
            return handleRefresh(for: httpRequest,
                                 data: data,
                                 httpResponse: httpResponse,
                                 error: error,
                                 completionHandler: completionHandler)
        case 429:
            //Too many requests - wait and retry
            break
        default: break
        }
        
        completionHandler?(HTTPResponse(data: data, httpResponse: httpResponse, error: error))
    }
    
    /**
     Handles the refresh when a 401 occurs and retries the request, if the refresh completion input tells the client to do so.
     
     - parameters:
        - httpRequest: the failed request of the type HTTPRequest
        - data: the data returned by the request
        - response: the response following the executed request
        - error: the error that occurred
        - completionHandler: the completion handler object of type ExecuteDataCompletionType which send back a Data object, if any.
    */
    func handleRefresh(for httpRequest: HTTPRequest,
                                  data: Data?,
                                  httpResponse: HTTPURLResponse,
                                  error: Error?,
                                  completionHandler: ExecuteDataCompletionType?) {
        defer { _waitingRequestDict.append((httpRequest, completionHandler)) }
        guard _waitingRequestDict.isEmpty else {
            return
        }
        delegate?.needsRefresh(for: httpRequest, completion: { [weak self] (isRefreshed, accessToken) in
            guard let self = self else { return }
            guard isRefreshed && self.shouldRetryRequest(for: httpRequest.requestID) else {
                self.removeRequest(for: httpRequest.requestID)
                completionHandler?(HTTPResponse(data: data, httpResponse: httpResponse, error: error))
                return
            }
            
            self._waitingRequestDict.forEach {
                self.decrementRetries(for: $0.0.requestID)
                self.execute(httpRequest: $0.0, completionHandler: $0.1)
            }
            self._waitingRequestDict.removeAll()
            
        })
    }
    
    /**
     Adds the request to the list of requests that are ongoing, to handle the cancelling or retry of that same request.
     
     - parameters:
        - request: the request ID to be added
    */
    func addRequest(for request: String) {
        guard !_ongoingRequestDict.keys.contains(request) else { return }
        updateRequest(for: request, retriesLeft: _retryLimit)
    }
    
    /**
     Removes the request from the list of requests that are ongoing.
     
     - parameters:
        - request: the request ID to be added
    */
    func removeRequest(for request: String) {
        _ongoingRequestDict.removeValue(forKey: request)
    }
    
    /**
     Updates the request retry number for that request.
     
     - parameters:
        - request: the request ID to be updated
        - retriesLeft: the number of retries left
    */
    func updateRequest(for request: String, retriesLeft: Int) {
        _ongoingRequestDict.updateValue(retriesLeft, forKey: request)
    }
    
    /**
     Decrements by one, the number of retries the request still has left.
     
     - parameters:
        - request: the request ID to be updated
    */
    func decrementRetries(for request: String) {
        guard let retriesLeft = _ongoingRequestDict[request] else { return }
        _ongoingRequestDict.updateValue(retriesLeft - 1, forKey: request)
    }
    
    /**
     Checks if the request still should be retried or not.
     
     - parameters:
        - request: the request ID to be added
    */
    func shouldRetryRequest(for request: String) -> Bool {
        return (_ongoingRequestDict[request] ?? 0) > 0
    }
}
