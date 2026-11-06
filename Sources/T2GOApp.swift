import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = ViewController()
        w.makeKeyAndVisible()
        window = w
    }
}

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    var webView: WKWebView!
    let homeURL = URL(string: "https://t2liveai.io.vn")!
    var downloadFiles: [ObjectIdentifier: URL] = [:]

    override func loadView() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        // Website data store mac dinh cua iOS: cookie + localStorage duoc LUU LAI
        // sau moi lan mo app -> giu nguyen dang nhap, khong phai dang nhap lai.
        cfg.websiteDataStore = WKWebsiteDataStore.default()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.configuration.preferences.javaScriptEnabled = true
        view = wv
        webView = wv
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: homeURL))
    }

    func isInternal(_ host: String) -> Bool {
        return host.hasSuffix("t2liveai.io.vn")
    }

    func loadHome() {
        webView.load(URLRequest(url: homeURL))
    }

    // ---- Dieu huong: Google login o lai trong app, link ngoai mo Safari ----
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if url.scheme == "t2go" {
            loadHome()
            decisionHandler(.cancel)
            return
        }
        if ["tel", "mailto", "sms"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        guard let host = url.host else {
            decisionHandler(.allow)
            return
        }
        let google = host.contains("google.com") || host.contains("gstatic.com") || host.contains("googleapis.com") || host.contains("googleusercontent.com")
        if navigationAction.navigationType == .linkActivated && !isInternal(host) && !google {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // ---- File tai ve trong trang (tep dinh kem chat...) -> tai xuong + mo chia se ----
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disp = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        if disp.contains("attachment") || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
        try? FileManager.default.removeItem(at: dest)
        downloadFiles[ObjectIdentifier(download)] = dest
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloadFiles[ObjectIdentifier(download)] else { return }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        present(share, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        showErrorPage()
    }

    // ---- Mat mang / loi tai trang -> trang bao loi co nut Thu lai ----
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        showErrorPage()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        showErrorPage()
    }

    func showErrorPage() {
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>body{font-family:-apple-system,sans-serif;text-align:center;padding:70px 26px;color:#222}
        a{display:inline-block;margin-top:18px;background:#0aa2c0;color:#fff;padding:12px 30px;border-radius:24px;text-decoration:none;font-weight:600}</style>
        </head><body><div style="font-size:52px">📶</div>
        <h2>Khong co ket noi mang</h2>
        <p>Kiem tra lai WiFi/4G roi bam Thu lai nhe.</p>
        <a href="t2go://retry">Thu lai</a></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // ---- Cho phep trang web dung camera/micro trong app (goi thoai, goi video) ----
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    // Tat xem truoc link khi nhan giu (giu cam giac nhu app that)
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        completionHandler(nil)
    }
}
