//
//  MANetworkTests.swift
//  MANetworkTests
//
//  Created by Miguel Alcantara on 23/01/2021.
//

import XCTest
import Combine
@testable import MANetwork

struct TestHelper {
    struct GitHubUser: Codable {
        struct GitHubActor: Codable {
            let login: String
        }
        let actor: GitHubActor
    }

    struct TestRequestInputData: HTTPRequestInputDataProtocol {
        var inputParameters: [HTTPRequestInputParameter] = [.path("{user}", "mrpcalcantara")]
    }
    class TestRequest: HTTPRequest {
        var headers: HTTPHeaders?
        var method: HTTPMethod { .get }
        var inputData: TestRequestInputData
        var url: String = "https://api.github.com/users/{user}/events"
        var auth: HTTPAuthentication? = nil
        
        // MARK: - Computed variables
        
        /// The URLRequest to be used in the URLSession instance.
        var request : URLRequest { buildRequest(inputData: inputData) }
        
        // MARK: - Initializers
        
        init(headers: HTTPHeaders = HTTPHeaders()) {
            self.headers = headers
            inputData = TestRequestInputData()
        }
    }
}

class MANetworkTests: XCTestCase {
    

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        disposables.removeAll()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        disposables.removeAll()
    }

    let client = HTTPClient()
    var disposables = Set<AnyCancellable>()

    func testHTTPRequest_build_noHeaders() throws {
        let request = TestHelper.TestRequest()
        XCTAssert(request.headers?.isEmpty == true, "Headers should be empty.")
    }

    func testHTTPRequest_build_withHeaders() throws {
        let request = TestHelper.TestRequest(headers: ["Accept":"application/json"])
        XCTAssert(request.headers?.isEmpty == false, "Headers should NOT be empty. it has \(request.headers?.count)")
    }

    func testHTTPRequestProtocol_noCombine() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let request = TestHelper.TestRequest()
        let expectation = XCTestExpectation(description: "REGULAR: Check communication and decoding is successful")
        client.execute(httpRequest: request) { (result: Result<HTTPClientResponse<[TestHelper.GitHubUser]>, Error>) in
            switch result {
            case .success(let value):
                guard let entity = value.entity.first else { return XCTFail("No user found") }
                print(entity)
                XCTAssert(!entity.actor.login.isEmpty, "Should contain value")
            case .failure(let error):
                XCTFail("error thrown: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }

    func testHTTPRequestProtocol_combine() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let request = TestHelper.TestRequest()
        let expectation = XCTestExpectation(description: "COMBINE: Check communication and decoding is successful")
        let requestPublisher: AnyPublisher<HTTPClientResponse<[TestHelper.GitHubUser]>, Error> = client.execute(apiRequest: request)
        requestPublisher.sink(receiveCompletion: {
            switch $0 {
            case .finished: break
            case .failure(let error): XCTFail("error thrown: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }, receiveValue: { (response) in
            guard let entity = response.entity.first else { return XCTFail("No user found") }
            XCTAssert(!entity.actor.login.isEmpty, "Should contain value")
        })
        .store(in: &disposables)

        wait(for: [expectation], timeout: 10)
    }
}
