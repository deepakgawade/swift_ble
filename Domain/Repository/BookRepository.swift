//
//  BookRepository.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//
import Foundation

protocol BookRepository{
    func fetchBook()async throws ->Book
}




