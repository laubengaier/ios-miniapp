import Foundation
import SwiftUI
import Combine

/// MiniAppView's convenience SwiftUI view wrapper
public struct MiniAppSUIView: UIViewRepresentable {

    @ObservedObject var handler: MiniAppSUIViewHandler

    var params: MiniAppViewParameters

    public init(params: MiniAppViewParameters.DefaultParams, handler: MiniAppSUIViewHandler) {
        self.params = .default(params)
        self.handler = handler
    }

    public init(urlParams: MiniAppViewParameters.UrlParams) {
        self.params = .url(urlParams)
        self.handler = MiniAppSUIViewHandler()
    }

    public init(infoParams: MiniAppViewParameters.InfoParams) {
        self.params = .info(infoParams)
        self.handler = MiniAppSUIViewHandler()
    }

    public func makeUIView(context: Context) -> MiniAppView {
        let view = MiniAppView(params: params)
        view.progressStateView = MiniAppProgressView()
        view.load { _ in
            // load finished
        }
        context.coordinator.onGoBack = {
            _ = view.miniAppNavigationBar(didTriggerAction: .back)
        }
        context.coordinator.onGoForward = {
            _ = view.miniAppNavigationBar(didTriggerAction: .forward)
        }
        return view
    }

    public func updateUIView(_ uiView: MiniAppView, context: Context) {}

    public func makeCoordinator() -> MiniAppSUIView.Coordinator {
        Coordinator(handler: handler)
    }
}

// MARK: - Coordinator
extension MiniAppSUIView {
    public class Coordinator: NSObject, ObservableObject {
        @ObservedObject var handler: MiniAppSUIViewHandler
        var bag = Set<AnyCancellable>()

        var onGoBack: (() -> Void)?
        var onGoForward: (() -> Void)?

        init(handler: MiniAppSUIViewHandler) {
            self.handler = handler
            super.init()
            handler
                .$action
                .debounce(for: 0.01, scheduler: RunLoop.main)
                .sink { [weak self] action in
                    guard let action = action else { return }
                    MiniAppLogger.d("MiniAppSUIView - action: \(action)")
                    switch action {
                    case .goBack:
                        self?.onGoBack?()
                    case .goForward:
                        self?.onGoForward?()
                    }
                }
                .store(in: &bag)
        }
    }
}

// MARK: - Handler
public class MiniAppSUIViewHandler: ObservableObject {

    @Published public var action: MiniAppSUIViewAction?

    public init() {}
}

// MARK: - Action
public enum MiniAppSUIViewAction {
    case goBack
    case goForward
}
