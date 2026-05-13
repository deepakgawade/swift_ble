//
//  BookImageView.swift
//  harry
//
//  Created by ESAB India on 08/05/26.
//

import SwiftUI

struct BookImageView: View{
    let url:URL
    
var body: some View {
    
    AsyncImage(url:url) { phase in
        switch phase {
        case .empty:
            ProgressView()
        case .success(let image):
            image.resizable().scaledToFill()
                .frame( width:250,)
                .clipped()
            
                
        case .failure:
            Image(systemName: "book.closed.fill")
        @unknown default:
            EmptyView()
        }
    }
        
    }
    
    
    
}
