//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  NativeEngine.swift
//  Starscream
//
//  Created by Dalton Cherry on 6/15/19
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
#if os(Android)
import FoundationNetworking
#endif

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class NativeEngine: NSObject, Engine, URLSessionDataDelegate, URLSessionWebSocketDelegate, @unchecked Sendable {
    private var task: URLSessionWebSocketTask?
    weak var delegate: EngineDelegate?
    
    public func register(delegate: EngineDelegate) {
        self.delegate = delegate
    }
    
    public func start(request: URLRequest) {
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        task = session.webSocketTask(with: request)
        doRead()
        task?.resume()
    }
    
    public func stop(closeCode: UInt16) {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
        task?.cancel(with: closeCode, reason: nil)
    }
    
    public func forceStop() {
        stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue))
    }
    
    public func write(string: String) async throws {
        try await task?.send(.string(string))
    }
    
    public func write(data: Data, opcode: FrameOpCode) async throws {
        switch opcode {
        case .binaryFrame:
            try await task?.send(.data(data))
        case .textFrame:
            guard let text = String(data: data, encoding: .utf8) else { return }
            try await write(string: text)
        case .ping:
            break
//            try await task?.sendPing()
        default:
            break //unsupported
        }
    }
    
    private func doRead() {
        Task {
            do {
                guard let task = self.task else { return }
                let message = try await task.receive()
                switch message {
                case .string(let string):
                    broadcast(event: .text(string))
                case .data(let data):
                    broadcast(event: .binary(data))
                @unknown default:
                    break
                }
                doRead() // Continue reading
            } catch {
                broadcast(event: .error(error))
            }
        }
    }
    
    private func broadcast(event: WebSocketEvent) {
        self.delegate?.didReceive(event: event)
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let p = `protocol` ?? ""
        broadcast(event: .connected([HTTPWSHeader.protocolName: p]))
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        var r = ""
        if let d = reason {
            r = String(data: d, encoding: .utf8) ?? ""
        }
        broadcast(event: .disconnected(r, UInt16(closeCode.rawValue)))
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        broadcast(event: .error(error))
    }
}
