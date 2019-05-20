import UIKit
import Yosemite
import Gridicons
import SafariServices


/// ProductDetailsViewController: Displays the details for a given Product.
///
final class ProductDetailsViewController: UIViewController {

    /// Product view model
    ///
    private let viewModel: ProductDetailsViewModel

    /// Main TableView.
    ///
    @IBOutlet private weak var tableView: UITableView!

    /// Pull To Refresh Support.
    ///
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return refreshControl
    }()


    // MARK: - Initializers

    /// Designated Initializer
    ///
    init(viewModel: ProductDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: type(of: self).nibName, bundle: nil)
    }

    /// NSCoder Conformance
    ///
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationTitle()
        configureMainView()
        configureTableView()
        registerTableViewCells()
        registerTableViewHeaderFooters()

        initializeData()
        configureViewModel()
    }
}


// MARK: - Configuration
//
private extension ProductDetailsViewController {

    /// Setup: Navigation Title
    ///
    func configureNavigationTitle() {
        title = viewModel.title
    }

    /// Setup: main view
    ///
    func configureMainView() {
        view.backgroundColor = StyleManager.tableViewBackgroundColor
    }

    /// Setup: TableView
    ///
    func configureTableView() {
        tableView.backgroundColor = StyleManager.tableViewBackgroundColor
        tableView.estimatedSectionHeaderHeight = viewModel.sectionHeight
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = viewModel.rowHeight
        tableView.rowHeight = UITableView.automaticDimension
        tableView.refreshControl = refreshControl
        tableView.separatorInset = .zero
        tableView.tableFooterView = UIView(frame: .zero)
    }

    func initializeData() {
        viewModel.reloadTableViewSectionsAndData()
    }

    func configureViewModel() {
        configureViewModelForErrors()
        configureViewModelForSuccess()
    }

    func configureViewModelForErrors() {
        viewModel.onError = { [weak self] in
            self?.navigationController?.dismiss(animated: true, completion: nil)
            self?.displayProductRemovedNotice()
        }
    }

    func configureViewModelForSuccess() {
        viewModel.onReload = { [weak self] in
            self?.reloadTableViewDataIfPossible()
        }
    }

    /// Registers all of the available TableViewCells
    ///
    func registerTableViewCells() {
        let cells = [
            LargeImageTableViewCell.self,
            TitleBodyTableViewCell.self,
            TwoColumnTableViewCell.self,
            ProductReviewsTableViewCell.self,
            WooBasicTableViewCell.self
        ]

        for cell in cells {
            tableView.register(cell.loadNib(), forCellReuseIdentifier: cell.reuseIdentifier)
        }
    }

    /// Registers all of the available TableViewHeaderFooters
    ///
    func registerTableViewHeaderFooters() {
        let headersAndFooters = [
            TwoColumnSectionHeaderView.self,
        ]

        for kind in headersAndFooters {
            tableView.register(kind.loadNib(), forHeaderFooterViewReuseIdentifier: kind.reuseIdentifier)
        }
    }
}


// MARK: - Action Handlers
//
extension ProductDetailsViewController {

    @objc func pullToRefresh() {
        DDLogInfo("♻️ Requesting product detail data be reloaded...")
        syncProduct() { [weak self] (error) in
            if let error = error {
                 DDLogError("⛔️ Error loading product details: \(error)")
                self?.displaySyncingErrorNotice()
            }
            self?.refreshControl.endRefreshing()
        }
    }
}


// MARK: - Notices
//
private extension ProductDetailsViewController {

    /// Displays a notice indicating that the current Product has been removed from the Store.
    ///
    func displayProductRemovedNotice() {
        let message = String.localizedStringWithFormat(
            NSLocalizedString("Product %ld has been removed from your store",
                comment: "Notice displayed when the onscreen product was just deleted. It reads: Product {product number} has been removed from your store."
        ), viewModel.productID)

        let notice = Notice(title: message, feedbackType: .error)
        AppDelegate.shared.noticePresenter.enqueue(notice: notice)
    }

    /// Displays a notice indicating that an error occurred while sync'ing.
    ///
    func displaySyncingErrorNotice() {
        let message = String.localizedStringWithFormat(
            NSLocalizedString("Unable to refresh Product #%ld",
                comment: "Notice displayed when an error occurs while refreshing a product. It reads: Unable to refresh product #{product number}"
        ), viewModel.productID)
        let actionTitle = NSLocalizedString("Retry", comment: "Retry Action")
        let notice = Notice(title: message, feedbackType: .error, actionTitle: actionTitle) { [weak self] in
            self?.refreshControl.beginRefreshing()
            self?.pullToRefresh()
        }

        AppDelegate.shared.noticePresenter.enqueue(notice: notice)
    }
}


// MARK: - Sync'ing Helpers
//
private extension ProductDetailsViewController {

    func syncProduct(onCompletion: ((Error?) -> ())? = nil) {
        let action = ProductAction.retrieveProduct(siteID: viewModel.siteID, productID: viewModel.productID) { [weak self] (product, error) in
            guard let self = self, let product = product else {
                DDLogError("⛔️ Error synchronizing Product: \(error.debugDescription)")
                onCompletion?(error)
                return
            }

            self.viewModel.product = product
            onCompletion?(nil)
        }

        StoresManager.shared.dispatch(action)
    }
}


// MARK: - UITableViewDataSource Conformance
//
extension ProductDetailsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.rowAtIndexPath(indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)
        viewModel.configure(cell, for: row, at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch viewModel.rowAtIndexPath(indexPath) {
        case .productSummary:
            return viewModel.productImageHeight
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if viewModel.sections[section].title == nil {
            // iOS 11 table bug. Must return a tiny value to collapse `nil` or `empty` section headers.
            return .leastNonzeroMagnitude
        }

        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let leftText = viewModel.sections[section].title else {
            return nil
        }

        let headerID = TwoColumnSectionHeaderView.reuseIdentifier
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerID) as? TwoColumnSectionHeaderView else {
            fatalError()
        }

        headerView.leftText = leftText
        headerView.rightText = viewModel.sections[section].rightTitle

        return headerView
    }
}


// MARK: - UITableViewDelegate Conformance
//
extension ProductDetailsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch viewModel.rowAtIndexPath(indexPath) {
        case .permalink:
            if let url = URL(string: viewModel.product.permalink) {
                let safariViewController = SFSafariViewController(url: url)
                safariViewController.modalPresentationStyle = .pageSheet
                present(safariViewController, animated: true, completion: nil)
            }
        case .affiliateLink:
            if let externalUrlString = viewModel.product.externalURL,
                let url = URL(string: externalUrlString) {
                let safariViewController = SFSafariViewController(url: url)
                safariViewController.modalPresentationStyle = .pageSheet
                present(safariViewController, animated: true, completion: nil)
            }
        default:
            break
        }
    }
}


// MARK: - Tableview helpers
//
private extension ProductDetailsViewController {

    /// Reloads the tableView's data, assuming the view has been loaded.
    ///
    func reloadTableViewDataIfPossible() {
        guard isViewLoaded else {
            return
        }

        tableView.reloadData()
    }
}
