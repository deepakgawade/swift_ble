//
//  RemoteBookRepository.swift
//  harry
//
//  Created by ESAB India on 11/05/26.
//

import Foundation

struct RemoteBookRepository: BookRepository {
    let session: URLSession
    init(session: URLSession = .shared){
        self.session = session
    }
    
    func fetchBook() async throws -> Book{
        
        let(data, response) = try await session.data(from: APIEndpoint.randomBook)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else{
            throw URLError(.badServerResponse)
        }
        
        let book = try JSONDecoder().decode(BookDTO.self, from: data )
        
        return BookMapper.map(book)
        
    }
}
