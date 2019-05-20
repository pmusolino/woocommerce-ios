import Foundation
import Yosemite
import UIKit
import Gridicons


// MARK: - Product details view model
//
final class ProductDetailsViewModel {

    struct Section {
        let title: String?
        let rightTitle: String?
        let footer: String?
        let rows: [Row]

        init(title: String? = nil, rightTitle: String? = nil, footer: String? = nil, rows: [Row]) {
            self.title = title
            self.rightTitle = rightTitle
            self.footer = footer
            self.rows = rows
        }

        init(title: String? = nil, rightTitle: String? = nil, footer: String? = nil, row: Row) {
            self.init(title: title, rightTitle: rightTitle, footer: footer, rows: [row])
        }
    }

    /// Rows are organized in the order they appear in the UI
    ///
    enum Row {
        case productSummary
        case productName
        case totalOrders
        case reviews
        case permalink
        case affiliateLink
        case price
        case inventory
        case sku
        case affiliateInventory

        var reuseIdentifier: String {
            switch self {
            case .productSummary:
                return LargeImageTableViewCell.reuseIdentifier
            case .productName:
                return TitleBodyTableViewCell.reuseIdentifier
            case .totalOrders:
                return TwoColumnTableViewCell.reuseIdentifier
            case .reviews:
                return ProductReviewsTableViewCell.reuseIdentifier
            case .permalink:
                return WooBasicTableViewCell.reuseIdentifier
            case .affiliateLink:
                return WooBasicTableViewCell.reuseIdentifier
            case .price:
                return TitleBodyTableViewCell.reuseIdentifier
            case .inventory:
                return TitleBodyTableViewCell.reuseIdentifier
            case .sku:
                return TitleBodyTableViewCell.reuseIdentifier
            case .affiliateInventory:
                return TitleBodyTableViewCell.reuseIdentifier
            }
        }
    }

    var onError: (() -> Void)?
    var onReload: (() -> Void)?

    /// Yosemite.Product
    ///
    var product: Product {
        didSet {
            reloadTableViewSectionsAndData()
        }
    }

    var title: String {
        return product.name
    }

    var productID: Int {
        return product.productID
    }

    var siteID: Int {
        return product.siteID
    }

    /// Sections to be rendered
    ///
    private(set) var sections = [Section]()

    /// EntityListener: Update / Deletion Notifications.
    ///
    private lazy var entityListener: EntityListener<Product> = {
        return EntityListener(storageManager: AppDelegate.shared.storageManager, readOnlyEntity: product)
    }()

    /// Grab the first available image for a product.
    ///
    private var imageURL: URL? {
        guard let productImageURLString = product.images.first?.src else {
            return nil
        }
        return URL(string: productImageURLString)
    }

    /// Check to see if the product has an image URL.
    ///
    var productHasImage: Bool {
        return imageURL != nil
    }

    var productImageHeight: CGFloat {
        return productHasImage ? Metrics.productImageHeight : Metrics.emptyProductImageHeight
    }

    var sectionHeight: CGFloat {
        return Metrics.sectionHeight
    }

    var rowHeight: CGFloat {
        return Metrics.estimatedRowHeight
    }

    /// Currency Formatter
    ///
    private var currencyFormatter = CurrencyFormatter()

    // MARK: - Intializers

    /// Designated initializer.
    ///
    init(product: Product) {
        self.product = product
    }

    /// Setup: EntityListener
    ///
    func configureEntityListener() {
        entityListener.onUpsert = { [weak self] product in
            guard let self = self else {
                return
            }

            self.product = product
        }

        entityListener.onDelete = { [weak self] in
            guard let self = self else {
                return
            }

            self.onError?()
//            self.navigationController?.dismiss(animated: true, completion: nil)
//            self.displayProductRemovedNotice()
        }
    }

    func configure(_ cell: UITableViewCell, for row: Row, at indexPath: IndexPath) {
        switch cell {
        case let cell as LargeImageTableViewCell:
            configureProductImage(cell)
        case let cell as TitleBodyTableViewCell where row == .productName:
            configureProductName(cell)
        case let cell as TwoColumnTableViewCell where row == .totalOrders:
            configureTotalOrders(cell)
        case let cell as ProductReviewsTableViewCell:
            configureReviews(cell)
        case let cell as WooBasicTableViewCell where row == .permalink:
            configurePermalink(cell)
        case let cell as WooBasicTableViewCell where row == .affiliateLink:
            configureAffiliateLink(cell)
        case let cell as TitleBodyTableViewCell where row == .price:
            configurePrice(cell)
        case let cell as TitleBodyTableViewCell where row == .inventory:
            configureInventory(cell)
        case let cell as TitleBodyTableViewCell where row == .sku:
            configureSku(cell)
        case let cell as TitleBodyTableViewCell where row == .affiliateInventory:
            configureAffiliateInventory(cell)
        default:
            fatalError("Unidentified row type")
        }
    }

    func configureProductImage(_ cell: LargeImageTableViewCell) {
        guard let mainImageView = cell.mainImageView else {
            return
        }

        if productHasImage {
            cell.heightConstraint.constant = Metrics.productImageHeight
            mainImageView.downloadImage(from: imageURL, placeholderImage: UIImage.productPlaceholderImage)
        } else {
            cell.heightConstraint.constant = Metrics.emptyProductImageHeight
            let size = CGSize(width: cell.frame.width, height: Metrics.emptyProductImageHeight)
            mainImageView.image = StyleManager.wooWhite.image(size)
        }

        if product.productStatus != .publish {
            cell.textBadge?.applyPaddedLabelSubheadStyles()
            cell.textBadge?.layer.backgroundColor = StyleManager.defaultTextColor.cgColor
            cell.textBadge?.textColor = StyleManager.wooWhite
            cell.textBadge?.text = product.productStatus.description
        }
    }

    func configureProductName(_ cell: TitleBodyTableViewCell) {
        cell.accessoryType = .none
        cell.selectionStyle = .none
        cell.titleLabel?.text = NSLocalizedString("Title", comment: "Product details screen — product title descriptive label")
        cell.bodyLabel?.applySecondaryBodyStyle()
        cell.bodyLabel?.text = product.name
        cell.secondBodyLabel.isHidden = true
    }

    func configureTotalOrders(_ cell: TwoColumnTableViewCell) {
        cell.selectionStyle = .none
        cell.leftLabel?.text = NSLocalizedString("Total Orders", comment: "Product details screen - total orders descriptive label")
        cell.rightLabel?.applySecondaryBodyStyle()
        cell.rightLabel.textInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        cell.rightLabel?.text = String(product.totalSales)
    }

    func configureReviews(_ cell: ProductReviewsTableViewCell) {
        cell.selectionStyle = .none
        cell.reviewLabel?.text = NSLocalizedString("Reviews", comment: "Reviews descriptive label")

        cell.reviewTotalsLabel?.applySecondaryBodyStyle()
        // 🖐🏼 I solemnly swear I'm not converting currency values to a Double.
        let ratingCount = Double(product.ratingCount)
        cell.reviewTotalsLabel?.text = ratingCount.humanReadableString()
        let averageRating = Double(product.averageRating)
        cell.starRatingView.rating = CGFloat(averageRating ?? 0)
    }

    func configurePermalink(_ cell: WooBasicTableViewCell) {
        cell.textLabel?.text = NSLocalizedString("View product on store", comment: "The descriptive label. Tapping the row will open the product's page in a web view.")
        cell.accessoryImage = Gridicon.iconOfType(.external)
    }

    func configureAffiliateLink(_ cell: WooBasicTableViewCell) {
        cell.textLabel?.text = NSLocalizedString("View affiliate product", comment: "The descriptive label. Tapping the row will open the affliate product's link in a web view.")
        cell.accessoryImage = Gridicon.iconOfType(.external)
    }

    func configurePrice(_ cell: TitleBodyTableViewCell) {
        cell.titleLabel?.text = NSLocalizedString("Price", comment: "Product Details > Pricing and Inventory section > descriptive label for the Price cell.")

        // determine if a `regular_price` exists.

        // if yes, then display Regular Price: / Sale Price: w/ currency formatting

        // if no, then display the `price` w/ no prefix and w/ currency formatting
    }

    func configureInventory(_ cell: TitleBodyTableViewCell) {

    }

    func configureSku(_ cell: TitleBodyTableViewCell) {

    }

    func configureAffiliateInventory(_ cell: TitleBodyTableViewCell) {

    }

    /// Returns the Row enum value for the provided IndexPath
    ///
    func rowAtIndexPath(_ indexPath: IndexPath) -> Row {
        return sections[indexPath.section].rows[indexPath.row]
    }

//    /// Reloads the tableView's data, assuming the view has been loaded.
//    ///
//    func reloadTableViewDataIfPossible() {
//        guard isViewLoaded else {
//            return
//        }
//
//        tableView.reloadData()
//    }

    /// Reloads the tableView's sections and data.
    ///
    func reloadTableViewSectionsAndData() {
        reloadSections()
        onReload?()
    }

    /// Rebuild the section struct
    ///
    func reloadSections() {
        var rows: [Row] = [.productSummary, .productName]
        var customContent = [Row]()

        switch product.productType {
        case .simple:
            customContent = [.totalOrders, .reviews, .permalink]
        case .grouped:
            customContent = [.totalOrders, .reviews, .permalink]
        case .affiliate:
            customContent = [.totalOrders, .reviews, .permalink, .affiliateLink]
        case .variable:
            customContent = [.totalOrders, .reviews, .permalink]
        case .custom(_):
            customContent = [.totalOrders, .reviews, .permalink]
        }

        rows.append(contentsOf: customContent)

        let summary = Section(rows: rows)
        sections = [summary].compactMap { $0 }
    }
}


extension ProductDetailsViewModel {
    enum Metrics {
        static let estimatedRowHeight = CGFloat(86)
        static let sectionHeight = CGFloat(44)
        static let productImageHeight = CGFloat(374)
        static let emptyProductImageHeight = CGFloat(86)
    }
}
