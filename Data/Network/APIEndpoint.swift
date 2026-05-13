//
//  APIEndpoint.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//
import Foundation
enum APIEndpoint{
    static let baseURL = URL(string:"https://potterapi-fedeperin.vercel.app")!
    
    static var randomBook: URL{
        baseURL.appendingPathComponent("en/books/random")
    }
    
}
