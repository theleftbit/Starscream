//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FoundationHTTPHandler.swift
//  Starscream
//
//  Created by Dalton Cherry on 4/2/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

public class FoundationHTTPServerHandler: HTTPServerHandler {
    var buffer = Data()
    weak var delegate: HTTPServerDelegate?
    
    public func register(delegate: HTTPServerDelegate) {
        self.delegate = delegate
    }
    
    public func createResponse(headers: [String: String]) -> Data {
        // Create the status line according to HTTP/1.1 spec
        var responseString = "HTTP/1.1 101 Switching Protocols\r\n"
        
        // Add headers
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        
        // Add empty line to indicate end of headers
        responseString += "\r\n"
        
        // Convert to Data
        return responseString.data(using: .utf8) ?? Data()
    }
    
    public func parse(data: Data) {
        buffer.append(data)
        if parseContent(data: buffer) {
            buffer = Data()
        }
    }
    
    //returns true when the buffer should be cleared
    func parseContent(data: Data) -> Bool {
        guard let requestString = String(data: data, encoding: .utf8) else {
            delegate?.didReceive(event: .failure(HTTPUpgradeError.invalidData))
            return true
        }
        
        // Split request into lines
        let lines = requestString.components(separatedBy: "\r\n")
        guard !lines.isEmpty else {
            return false // not enough data, wait for more
        }
        
        // Parse request line
        let requestLine = lines[0].components(separatedBy: " ")
        guard requestLine.count >= 3,
              let method = requestLine.first else {
            delegate?.didReceive(event: .failure(HTTPUpgradeError.invalidData))
            return true
        }
        
        // Verify HTTP method
        if method != "GET" {
            delegate?.didReceive(event: .failure(HTTPUpgradeError.invalidData))
            return true
        }
        
        // Find empty line that separates headers from body
        guard let emptyLineIndex = lines.firstIndex(of: "") else {
            return false // headers not complete, wait for more
        }
        
        // Parse headers
        var headers = [String: String]()
        for i in 1..<emptyLineIndex {
            let line = lines[i]
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        delegate?.didReceive(event: .success(headers))
        return true
    }
}
