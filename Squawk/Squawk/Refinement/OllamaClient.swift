import Foundation
import os

enum OllamaError: LocalizedError {
    case invalidResponse
    case modelNotFound(String)
    case httpError(Int)
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .modelNotFound(let model):
            return "Model '\(model)' not found. Run: ollama pull \(model)"
        case .httpError(let code):
            return "Ollama returned HTTP \(code)"
        case .connectionFailed:
            return "Cannot connect to Ollama at localhost:11434"
        }
    }
}

struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let size: Int64
    }
    let models: [Model]
}

struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool = false

    struct Options: Encodable {
        let temperature: Double
        let num_predict: Int
    }
    let options: Options?
}

struct OllamaGenerateResponse: Decodable {
    let response: String
    let done: Bool
    let total_duration: Int64?
    let eval_count: Int?
}

struct OllamaClient {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func isAvailable() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    func listModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return response.models.map(\.name)
    }

    func generate(
        model: String,
        prompt: String,
        system: String?,
        temperature: Double = 0.3,
        maxTokens: Int = 2048
    ) async throws -> OllamaGenerateResponse {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            system: system,
            options: .init(temperature: temperature, num_predict: maxTokens)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        if http.statusCode == 404 {
            throw OllamaError.modelNotFound(model)
        }

        guard http.statusCode == 200 else {
            throw OllamaError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
    }
}
