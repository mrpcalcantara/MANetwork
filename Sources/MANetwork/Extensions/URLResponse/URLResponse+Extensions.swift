//
//  URLResponse+Extensions.swift
//  MANetwork
//
//  Created by Miguel Alcântara on 23/01/2021.
//  Copyright © 2021 Alcantech. All rights reserved.
//

import Foundation

public extension HTTPURLResponse {
    var isSuccess: Bool {
        return (200...299).contains(statusCode)
    }
}
