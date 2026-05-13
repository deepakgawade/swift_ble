//
//  BookDTO.swift
//  harry
//
//  Created by ESAB India on 07/05/26.
//


//{
//"number": 5,
//"title": "Harry Potter and the Order of the Phoenix",
//"originalTitle": "Harry Potter and the Order of the Phoenix",
//"releaseDate": "Jun 21, 2003",
//"description": "In his fifth year at Hogwarts, Harry discovers that many members of the wizarding community do not know the truth about his encounter with Lord Voldemort. Cornelius Fudge, Minister of Magic, appoints Dolores Umbridge as Defense Against the Dark Arts teacher because he believes that Professor Dumbledore plans to take over his job. But his teachings are inadequate, so Harry prepares the students to defend the school against evil.",
//"pages": 766,
//"cover": "https://raw.githubusercontent.com/fedeperin/potterapi/main/public/images/covers/5.png",
//"index": 4
//}

import Foundation

struct BookDTO:Codable{
    let number: Int
    let title: String
    let originalTitle: String
    let description: String
    let releaseDate:  String
    let cover: String
}
