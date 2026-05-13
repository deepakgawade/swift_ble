//
//  BookView.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//
import SwiftUI

struct BookView: View {
    @StateObject private var bookVM = BookViewModel()
    
    @ViewBuilder
    private var bookStateView:some View {
        if bookVM.isLoading {
            ProgressView{
                Text("Loading...")
            }
          

        }
        else if let error = bookVM.errorMessage {
            VStack(spacing: 12) {
                Text(error).foregroundStyle(.red)
                Button("Retry") { bookVM.refresh() }
            }
        }
        else if let book = bookVM.book {
            ScrollView {
                VStack(alignment: .center, spacing: 12) {
                    BookImageView(url:URL(string:  book.coverUrl)!)
                    Text(book.title).font(.title2.bold()).multilineTextAlignment(.center).lineLimit(2)
                    HStack( alignment: .top){
                        Text("by J K Rowling").font(.subheadline).foregroundStyle(.secondary)
                        Text("Released: \(book.releaseDate)").font(.subheadline).foregroundStyle(.secondary)
                    }
        
                    Text(book.description).font(.body).lineLimit(4)
                }
                .padding()
            }
        }
        else {
            Text("Tap refresh to load a random book.")
        }
        
    }

    var body: some View {
        NavigationStack {
            Group {
                bookStateView
            }
            .navigationTitle("Random Book")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bookVM.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(bookVM.isLoading)
                }
            }
        }
        .task {
             bookVM.loadBook()
        }
    }
}


#Preview {
    BookView()
}
