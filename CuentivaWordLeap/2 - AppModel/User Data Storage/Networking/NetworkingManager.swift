import Foundation

struct NetworkingManager: Sendable {
    private let dataProvider: @Sendable (URL) async throws -> Data

    init(session: URLSession = .shared) {
        dataProvider = { url in
            let (data, response) = try await session.data(from: url)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            return data
        }
    }

    init(dataProvider: @escaping @Sendable (URL) async throws -> Data) {
        self.dataProvider = dataProvider
    }

    func data(from url: URL) async throws -> Data {
        try await dataProvider(url)
    }
}
