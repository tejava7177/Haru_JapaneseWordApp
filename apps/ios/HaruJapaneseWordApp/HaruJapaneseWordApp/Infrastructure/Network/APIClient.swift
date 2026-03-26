import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case encodingFailed(Error)
    case requestFailed(Error)
    case invalidResponse
    case server(statusCode: Int, message: String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "API 주소가 올바르지 않아요."
        case .encodingFailed:
            return "요청 데이터를 만들지 못했어요."
        case .requestFailed:
            return "서버와 통신하지 못했어요."
        case .invalidResponse:
            return "서버 응답을 확인하지 못했어요."
        case .server(_, let message):
            return message ?? "요청을 처리하지 못했어요."
        case .decodingFailed:
            return "서버 응답 형식이 예상과 달라요."
        }
    }
}

final class APIClient: @unchecked Sendable {
    private struct ServerErrorResponse: Decodable {
        let message: String?
        let error: String?
    }

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = APIConfiguration.baseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func get<Response: Decodable>(_ endpoint: APIEndpoint, responseType: Response.Type) async throws -> Response {
        try await send(endpoint, responseType: responseType)
    }

    func post<Request: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Request,
        responseType: Response.Type
    ) async throws -> Response {
        let endpoint = try endpointWithJSONBody(endpoint, body: body)
        return try await send(endpoint, responseType: responseType)
    }

    func post<Request: Encodable>(_ endpoint: APIEndpoint, body: Request) async throws {
        let endpoint = try endpointWithJSONBody(endpoint, body: body)
        _ = try await sendWithoutResponseBody(endpoint)
    }

    func postMultipart<Response: Decodable>(
        _ endpoint: APIEndpoint,
        fileData: Data,
        fieldName: String,
        fileName: String,
        mimeType: String,
        responseType: Response.Type
    ) async throws -> Response {
        let boundary = "Boundary-\(UUID().uuidString)"
        let multipartBody = makeMultipartBody(
            boundary: boundary,
            fileData: fileData,
            fieldName: fieldName,
            fileName: fileName,
            mimeType: mimeType
        )
        var endpoint = endpoint
        endpoint.body = multipartBody
        endpoint.headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        return try await send(endpoint, responseType: responseType)
    }

    func patch<Request: Encodable, Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: Request,
        responseType: Response.Type
    ) async throws -> Response {
        let endpoint = try endpointWithJSONBody(endpoint, body: body)
        return try await send(endpoint, responseType: responseType)
    }

    func delete<Response: Decodable>(_ endpoint: APIEndpoint, responseType: Response.Type) async throws -> Response {
        try await send(endpoint, responseType: responseType)
    }

    func delete(_ endpoint: APIEndpoint) async throws {
        _ = try await sendWithoutResponseBody(endpoint)
    }

    private func endpointWithJSONBody<Request: Encodable>(_ endpoint: APIEndpoint, body: Request) throws -> APIEndpoint {
        do {
            var endpoint = endpoint
            endpoint.body = try encoder.encode(body)
            endpoint.headers["Content-Type"] = "application/json"
            return endpoint
        } catch {
            throw APIError.encodingFailed(error)
        }
    }

    private func send<Response: Decodable>(_ endpoint: APIEndpoint, responseType: Response.Type) async throws -> Response {
        let request = try makeRequest(for: endpoint)
        let (data, _) = try await perform(request)
        return try decode(Response.self, from: data, request: request)
    }

    private func sendWithoutResponseBody(_ endpoint: APIEndpoint) async throws -> HTTPURLResponse {
        let request = try makeRequest(for: endpoint)
        let (_, response) = try await perform(request)
        return response
    }

    private func decode<Response: Decodable>(
        _ responseType: Response.Type,
        from data: Data,
        request: URLRequest
    ) throws -> Response {
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            logDecodingFailure(
                error,
                data: data,
                modelName: String(describing: Response.self),
                request: request
            )
            throw APIError.decodingFailed(error)
        }
    }

    private func makeRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        if endpoint.queryItems.isEmpty == false {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = endpoint.body
        return request
    }

    private func makeMultipartBody(
        boundary: String,
        fileData: Data,
        fieldName: String,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append(Data("--\(boundary)\(lineBreak)".utf8))
        body.append(
            Data(
                "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(lineBreak)".utf8
            )
        )
        body.append(Data("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".utf8))
        body.append(fileData)
        body.append(Data(lineBreak.utf8))
        body.append(Data("--\(boundary)--\(lineBreak)".utf8))

        return body
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        logNetworkIfNeeded(request: request, response: httpResponse, data: data)

        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = decodeServerMessage(from: data)
            throw APIError.server(statusCode: httpResponse.statusCode, message: serverMessage)
        }

        return (data, httpResponse)
    }

    private func decodeServerMessage(from data: Data) -> String? {
        guard data.isEmpty == false else { return nil }
        if let errorResponse = try? decoder.decode(ServerErrorResponse.self, from: data) {
            return errorResponse.message ?? errorResponse.error
        }
        return String(data: data, encoding: .utf8)
    }

    private func logNetworkIfNeeded(request: URLRequest, response: HTTPURLResponse, data: Data) {
        #if DEBUG
        guard let url = request.url else { return }

        let requestSnippet = request.httpBody.flatMap(bodySnippet(from:)) ?? "-"
        let responseSnippet = bodySnippet(from: data)

        print(
            "[APIClient] \(request.httpMethod ?? "GET") \(url.path) " +
            "status=\(response.statusCode) request=\(requestSnippet) response=\(responseSnippet)"
        )
        #endif
    }

    private func bodySnippet(from data: Data) -> String {
        guard data.isEmpty == false else { return "-" }
        let text = String(data: data.prefix(240), encoding: .utf8) ?? "<non-utf8 body>"
        if data.count > 240 {
            return "\(text)..."
        }
        return text
    }

    private func logDecodingFailure(
        _ error: Error,
        data: Data,
        modelName: String,
        request: URLRequest
    ) {
        let path = request.url?.path ?? "<unknown>"
        let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"

        if let decodingError = error as? DecodingError {
            print("[APIClient] Decoding failed model=\(modelName) path=\(path) reason=\(describe(decodingError))")
        } else {
            print("[APIClient] Decoding failed model=\(modelName) path=\(path) reason=\(error.localizedDescription)")
        }

        print("[APIClient] Decoding failure raw body path=\(path) body=\(bodyText)")
    }

    private func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "keyNotFound key=\(key.stringValue) path=\(codingPathString(context.codingPath)) debug=\(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "typeMismatch type=\(type) path=\(codingPathString(context.codingPath)) debug=\(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "valueNotFound type=\(type) path=\(codingPathString(context.codingPath)) debug=\(context.debugDescription)"
        case .dataCorrupted(let context):
            return "dataCorrupted path=\(codingPathString(context.codingPath)) debug=\(context.debugDescription)"
        @unknown default:
            return "unknownDecodingError"
        }
    }

    private func codingPathString(_ codingPath: [CodingKey]) -> String {
        if codingPath.isEmpty {
            return "<root>"
        }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }
}
