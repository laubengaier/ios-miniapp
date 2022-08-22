//
//  RemoteImageView.swift
//  MiniApp_Example
//
//  Created by Timotheus Laubengaier on 2022/08/22.
//  Copyright © 2022 Rakuten Group, Inc. All rights reserved.
//

import SwiftUI

class ImageLoaderService: ObservableObject {
    @Published var image: UIImage = UIImage()

    func loadImage(for urlString: String) {
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            DispatchQueue.main.async {
                self.image = UIImage(data: data) ?? UIImage()
            }
        }
        task.resume()
    }
    
}

struct RemoteImageView: View {
    var urlString: String
    @ObservedObject var imageLoader = ImageLoaderService()
    @State var image: UIImage = UIImage()

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .onReceive(imageLoader.$image) { image in
                self.image = image
            }
            .onAppear {
                imageLoader.loadImage(for: urlString)
            }
    }
}

struct RemoteImageView_Previews: PreviewProvider {
    static var previews: some View {
        RemoteImageView(urlString: "https://via.placeholder.com/300.png")
    }
}
