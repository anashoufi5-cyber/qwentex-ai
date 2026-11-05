import Foundation
import SwiftUI
import Speech
import AVFoundation

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: String
    var text: String
}

@MainActor final class ChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: "assistant", text: "Hey! I'm Qwentex, your AI assistant. What are we doing today? 🚀")
    ]
    @Published var draft = ""
    @Published var isBusy = false
    @Published var endpoint = UserDefaults.standard.string(forKey: "q_endpoint") ?? "http://192.168.1.10:11434/v1"
    @Published var model = UserDefaults.standard.string(forKey: "q_model") ?? "qwentex"
    @Published var apiKey = UserDefaults.standard.string(forKey: "q_key") ?? "ollama"
    private let speech = AVSpeechSynthesizer()

    func saveSettings() {
        UserDefaults.standard.set(endpoint, forKey: "q_endpoint")
        UserDefaults.standard.set(model, forKey: "q_model")
        UserDefaults.standard.set(apiKey, forKey: "q_key")
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        speech.speak(utterance)
    }

    func send(imageData: Data? = nil) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || imageData != nil), !isBusy else { return }
        draft = ""
        messages.append(ChatMessage(role: "user", text: text.isEmpty ? "What is in this picture?" : text))
        isBusy = true
        Task {
            do {
                let urlString = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
                guard let url = URL(string: urlString) else { throw URLError(.badURL) }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 180
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                var apiMessages: [[String: Any]] = [["role":"system","content":"You are Qwentex, a friendly expressive AI assistant created by Anas. Be helpful, warm, and concise."]]
                for m in messages.suffix(20) {
                    apiMessages.append(["role":m.role,"content":m.text])
                }
                if let imageData {
                    let base64 = imageData.base64EncodedString()
                    apiMessages[apiMessages.count - 1]["content"] = [
                        ["type":"text","text": text.isEmpty ? "Describe this image." : text],
                        ["type":"image_url","image_url":["url":"data:image/jpeg;base64,\(base64)"]]
                    ]
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: ["model":model,"messages":apiMessages,"stream":false], options: [])
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    let body = String(data:data,encoding:.utf8) ?? "Unknown server error"
                    throw NSError(domain:"Qwentex",code:1,userInfo:[NSLocalizedDescriptionKey:body])
                }
                let json = try JSONSerialization.jsonObject(with:data) as? [String:Any]
                let choices = json?["choices"] as? [[String:Any]]
                let message = choices?.first?["message"] as? [String:Any]
                let answer = message?["content"] as? String ?? "I couldn't read the response."
                messages.append(ChatMessage(role:"assistant",text:answer))
                speak(answer)
            } catch {
                messages.append(ChatMessage(role:"assistant",text:"Connection error: \(error.localizedDescription)\nCheck Settings and make sure Ollama is reachable."))
            }
            isBusy = false
        }
    }
}
