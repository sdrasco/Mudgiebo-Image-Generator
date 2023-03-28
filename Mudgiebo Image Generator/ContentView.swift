//
//  ContentView.swift
//  Mudgiebo Image Generator
//
//
//  Created by Steve Drasco on 3/21/23.
//

import SwiftUI
import KeychainSwift

struct ContentView: View {
    private let keychain = KeychainSwift()
    @State private var imageDescription = ""
    @State private var apiKey: String = {
        let keychain = KeychainSwift()
        if let key = keychain.get("OPENAI_API_KEY") {
            return key
        }
        return ""
    }()
    @State private var hasApiKey: Bool = false
    @State private var generatedImage: NSImage?

    var body: some View {
        VStack {
            if !hasApiKey {
                Text("Enter your OpenAI API Key:")
                    .font(.headline)

                TextField("API Key", text: $apiKey, onCommit: {
                    let keychain = KeychainSwift()
                    keychain.set(apiKey, forKey: "OPENAI_API_KEY")
                    hasApiKey = true
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            } else {
                Text("Enter image description:")
                    .font(.headline)

                TextEditor(text: $imageDescription)
                    .font(.system(size: 14))
                    .padding(.vertical, 3)
                    .frame(height: 50)
                    .border(Color.gray, width: 1)

                Button(action: generateImage) {
                    Text("Generate Image")
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .cornerRadius(4)
                }
                .padding()

                if let image = generatedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 512, height: 512)

                    Button(action: saveImage) {
                        Text("Save Image")
                            .padding()
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .cornerRadius(4)
                    }
                    .padding()
                }
            }
        }
        .padding()
        .frame(width: 600, height: 400)
        .onAppear {
            hasApiKey = !apiKey.isEmpty
        }
    }

    func generateImage() {
        guard let apiKey = keychain.get("OPENAI_API_KEY") else { return }

        let prompt = imageDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.isEmpty {
            return
        }

        let headers: [String: String] = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]

        let parameters: [String: Any] = [
            "prompt": prompt,
            "n": 1
        ]

        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let imageURLString = (json["data"] as? [[String: Any]])?.first?["url"] as? String,
                       let imageURL = URL(string: imageURLString) {
                        
                        URLSession.shared.dataTask(with: imageURL) { data, _, _ in
                            if let data = data, let image = NSImage(data: data) {
                                DispatchQueue.main.async {
                                    self.generatedImage = image
                                }
                            }
                        }.resume()
                    }
                } catch {
                    print("Error: \(error)")
                }
            }
        }
        task.resume()
    }

    
    func saveImage() {
        guard let image = generatedImage else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "Generated Image - \(Date()).png"
        savePanel.allowedContentTypes = [.png]

        savePanel.begin { response in
            if response == .OK {
                if let url = savePanel.url {
                    if let imageData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: imageData) {
                        let pngData = bitmap.representation(using: .png, properties: [:])
                        do {
                            try pngData?.write(to: url)
                            print("Image saved to: \(url)")
                        } catch {
                            print("Error saving image: \(error)")
                        }
                    }
                }
            }
        }
    }
    

}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
