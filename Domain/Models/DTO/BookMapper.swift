//
//  BookMapper.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//


enum BookMapper{
    static func map(_ dto: BookDTO)->Book{
        Book(
            id:String(dto.number),
            title: dto.title,
            releaseDate: dto.releaseDate,
            description: dto.description,
            coverUrl:dto.cover
        )
    }
}
