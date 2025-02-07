import UIKit
import Gridicons
import WordPressUI
import Yosemite


// MARK: - DashboardViewController
//
class DashboardViewController: UIViewController {

    // MARK: Properties

    private var dashboardUI: DashboardUI!

    // MARK: View Lifecycle

    deinit {
        stopListeningToNotifications()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        startListeningToNotifications()
        tabBarItem.image = .statsAltImage
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureView()
        configureDashboardUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reset title to prevent it from being empty right after login
        configureTitle()
        reloadData()
    }
}


// MARK: - Configuration
//
private extension DashboardViewController {

    func configureView() {
        view.backgroundColor = StyleManager.tableViewBackgroundColor
    }

    func configureNavigation() {
        configureTitle()
        configureNavigationItem()
    }

    private func configureTitle() {
        let myStore = NSLocalizedString(
            "My store",
            comment: "Title of the bottom tab item that presents the user's store dashboard, and default title for the store dashboard"
        )
        title = StoresManager.shared.sessionManager.defaultSite?.name ?? myStore
        tabBarItem.title = myStore
    }

    private func resetTitle() {
        let myStore = NSLocalizedString(
            "My store",
            comment: "Title of the bottom tab item that presents the user's store dashboard, and default title for the store dashboard"
        )
        title = myStore
        tabBarItem.title = myStore
    }

    private func configureNavigationItem() {
        let rightBarButton = UIBarButtonItem(image: .cogImage,
                                             style: .plain,
                                             target: self,
                                             action: #selector(settingsTapped))
        rightBarButton.tintColor = .white
        rightBarButton.accessibilityLabel = NSLocalizedString("Settings", comment: "Accessibility label for the Settings button.")
        rightBarButton.accessibilityTraits = .button
        rightBarButton.accessibilityHint = NSLocalizedString(
            "Navigates to Settings.",
            comment: "VoiceOver accessibility hint, informing the user the button can be used to navigate to the Settings screen."
        )
        navigationItem.setRightBarButton(rightBarButton, animated: false)

        // Don't show the Dashboard title in the next-view's back button
        let backButton = UIBarButtonItem(title: String(),
                                         style: .plain,
                                         target: nil,
                                         action: nil)

        navigationItem.backBarButtonItem = backButton
    }

    func configureDashboardUI() {
        dashboardUI = DashboardUIFactory.dashboardUI()
        add(dashboardUI)
        let contentView = dashboardUI.view!
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            ])
        dashboardUI.onPullToRefresh = { [weak self] in
            self?.pullToRefresh()
        }
        dashboardUI.displaySyncingErrorNotice = { [weak self] in
            self?.displaySyncingErrorNotice()
        }
    }
}

// MARK: - Notifications
//
extension DashboardViewController {

    /// Wires all of the Notification Hooks
    ///
    func startListeningToNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(defaultAccountWasUpdated), name: .defaultAccountWasUpdated, object: nil)
    }

    /// Stops listening to all related Notifications
    ///
    func stopListeningToNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    /// Runs whenever the default Account is updated.
    ///
    @objc func defaultAccountWasUpdated() {
        guard isViewLoaded, StoresManager.shared.isAuthenticated == false else {
            return
        }

        resetTitle()
        dashboardUI.defaultAccountDidUpdate()
    }
}

// MARK: - Public API
//
extension DashboardViewController {
    func presentSettings() {
        settingsTapped()
    }
}


// MARK: - Action Handlers
//
private extension DashboardViewController {

    @objc func settingsTapped() {
        WooAnalytics.shared.track(.settingsTapped)
        performSegue(withIdentifier: Segues.settingsSegue, sender: nil)
    }

    func pullToRefresh() {
        WooAnalytics.shared.track(.dashboardPulledToRefresh)
        reloadData()
    }

    func displaySyncingErrorNotice() {
        let title = NSLocalizedString("My store", comment: "My Store Notice Title for loading error")
        let message = NSLocalizedString("Unable to load content", comment: "Load Action Failed")
        let actionTitle = NSLocalizedString("Retry", comment: "Retry Action")
        let notice = Notice(title: title, message: message, feedbackType: .error, actionTitle: actionTitle) { [weak self] in
            self?.reloadData()
        }

        AppDelegate.shared.noticePresenter.enqueue(notice: notice)
    }
}

// MARK: - Private Helpers
//
private extension DashboardViewController {
    func reloadData() {
        DDLogInfo("♻️ Requesting dashboard data be reloaded...")
        dashboardUI.reloadData(completion: { [weak self] in
            self?.configureTitle()
        })
    }
}

// MARK: - Constants
//
private extension DashboardViewController {

    struct Segues {
        static let settingsSegue        = "ShowSettingsViewController"
    }
}
