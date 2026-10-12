import Foundation

struct TBFile: Identifiable, Decodable {
    let id: Int
    let server_filename: String
    let size: Int64
    let dlink: String?   // direct stream/download link
}

enum TBError: Error {
    case unsupportedURL, missingSurl, badResponse
}

struct TBMirror {
    let host: String
    let apiHost: String
}

final class TeraBoxResolver {
    static let mirrors: [TBMirror] = [
        TBMirror(host: "terabox.com",      apiHost: "www.terabox.com"),
        TBMirror(host: "1024tera.com",     apiHost: "www.1024tera.com"),
        TBMirror(host: "teraboxapp.com",   apiHost: "www.teraboxapp.com"),
        TBMirror(host: "nephobox.com",     apiHost: "www.nephobox.com"),
        TBMirror(host: "4funbox.com",      apiHost: "www.4funbox.com"),
        TBMirror(host: "mirrobox.com",     apiHost: "www.mirrobox.com"),
        TBMirror(host: "momerybox.com",    apiHost: "www.momerybox.com"),
        TBMirror(host: "tibibox.com",      apiHost: "www.tibibox.com"),
        TBMirror(host: "freeterabox.com",  apiHost: "www.freeterabox.com"),
        TBMirror(host: "diskwala.com",     apiHost: "www.diskwala.com"),
        TBMirror(host: "flezen.com",       apiHost: "www.flezen.com"),
    ]

    struct ParsedShare {
        let mirror: TBMirror
        let surl: String
    }

    /// Match pasted URL against all 11 domains (handles www. / m. prefixes)
    func parse(urlString: String) -> ParsedShare? {
        guard let url = URL(string: urlString),
              var host = url.host?.lowercased() else { return nil }

        for prefix in ["www.", "m."] {
            if host.hasPrefix(prefix) { host.removeFirst(prefix.count) }
        }

        guard let mirror = Self.mirrors.first(where: { $0.host == host }) else { return nil }

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        // Standard format: https://<domain>/sharing/link?surl=AbCdEfGh123
        if let surl = comps.queryItems?.first(where: { $0.name == "surl" })?.value {
            return ParsedShare(mirror: mirror, surl: surl)
        }
        // Fallback: .../s/KEY format
        if let key = url.pathComponents.last, key.count > 5, !key.contains(".") {
            return ParsedShare(mirror: mirror, surl: key)
        }
        return nil
    }

    /// Resolve against the SAME mirror the link came from (geo/cookie consistency)
    func resolve(_ parsed: ParsedShare) async throws -> TBFile {
        var comps = URLComponents(string: "https://\(parsed.mirror.apiHost)/share/list")!
        comps.queryItems = [
            .init(name: "app_id", value: "250528"),
            .init(name: "shorturl", value: parsed.surl),
            .init(name: "root", value: "1")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
                     forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session(for: parsed.mirror).data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw TBError.badResponse
        }
        struct ListResponse: Decodable { let list: [TBFile] }
        let decoded = try JSONDecoder().decode(ListResponse.self, from: data)
        guard let file = decoded.list.first else { throw TBError.badResponse }
        return file
    }

    // Fresh cookie jar per domain so cookies never leak between mirrors
    private var sessions: [String: URLSession] = [:]
    private func session(for mirror: TBMirror) -> URLSession {
        if let s = sessions[mirror.host] { return s }
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage()
        let s = URLSession(configuration: config)
        sessions[mirror.host] = s
        return s
    }
}
