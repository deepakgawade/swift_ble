//
//  BookViewModel.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//
import Combine
@MainActor
class BookViewModel: ObservableObject{
    
    @Published private(set) var book: Book?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    
    private let bookRepository: BookRepository
    
    
    init(newBookRepository:BookRepository=RemoteBookRepository()){
        self.bookRepository = newBookRepository
    }
    
    func loadBook(){
        Task{
            await fetcBook()
        }
    }
    
    func refresh(){
        loadBook()
    }
    
    private func fetcBook()async{
        isLoading=true
        errorMessage=nil
        
        defer{isLoading=false}
        
        do{
            let result = try await bookRepository.fetchBook()
            self.book = result
        }catch{
            self.errorMessage = "Failed to load book"
        }
    }
    
    
    
}
