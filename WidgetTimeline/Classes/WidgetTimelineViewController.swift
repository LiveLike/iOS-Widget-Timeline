import EngagementSDK
import UIKit

public class WidgetTimelineViewController: UIViewController {
    struct Section {
        static let widgets = 0
        static let loadMoreControl = 1
    }

    private let cellReuseIdentifer: String = "myCell"

    public var session: ContentSession? {
        didSet {
            widgetModels.removeAll()
            self.tableView.reloadData()

            session?.getPostedWidgetModels(page: .first) { result in
                switch result {
                case let .success(widgetModels):
                    guard let widgetModels = widgetModels else { return }
                    self.widgetModels.append(contentsOf: widgetModels)
                    widgetModels.forEach {
                        self.widgetIsInteractableByID[$0.id] = false
                    }
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                        self.tableView.isHidden = false
                    }
                case let .failure(error):
                    print(error)
                }
                self.session?.delegate = self
            }
        }
    }

    public let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsSelection = false
        tableView.separatorStyle = .none
        tableView.isHidden = true
        return tableView
    }()

    private let snapToLiveButton: UIImageView = {
        let snapToLiveButton = UIImageView()
        snapToLiveButton.translatesAutoresizingMaskIntoConstraints = false
        snapToLiveButton.alpha = 0.0
        return snapToLiveButton
    }()
    private var snapToLiveBottomConstraint: NSLayoutConstraint!

    // Determines if the displayed widget should be interactable or not
    private var widgetIsInteractableByID: [String: Bool] = [:]
    private var widgetModels: [WidgetModel] = []

    private let loadMoreCell: LoadMoreCell = {
        let loadMoreCell = LoadMoreCell()
        loadMoreCell.translatesAutoresizingMaskIntoConstraints = false
        loadMoreCell.activityIndicator.hidesWhenStopped = true
        loadMoreCell.button.setTitle("Load More...", for: .normal)
        return loadMoreCell
    }()

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        super.loadView()

        view.addSubview(tableView)
        view.addSubview(snapToLiveButton)

        snapToLiveBottomConstraint = snapToLiveButton.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: -16
        )
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            snapToLiveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            snapToLiveBottomConstraint
        ])
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(WidgetTableViewCell.self, forCellReuseIdentifier: cellReuseIdentifer)
        tableView.dataSource = self
        tableView.delegate = self

        loadMoreCell.button.addTarget(self, action: #selector(loadMoreButtonPressed), for: .touchUpInside)

        snapToLiveButton.addGestureRecognizer({
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(snapToLive))
            tapGestureRecognizer.numberOfTapsRequired = 1
            return tapGestureRecognizer
        }())
    }

    public func makeWidget(_ widgetModel: WidgetModel) -> Widget? {
        guard let widget = DefaultWidgetFactory.makeWidget(from: widgetModel) else { return nil }
        widget.delegate = self
        if widgetIsInteractableByID[widgetModel.id] ?? false {
            widget.moveToNextState()
        } else {
            widget.currentState = .finished
        }
        return widget
    }

    private func snapToLiveIsHidden(_ isHidden: Bool) {
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
            self.snapToLiveBottomConstraint?.constant = isHidden ? self.snapToLiveButton.bounds.height : -16
            self.view.layoutIfNeeded()
            self.snapToLiveButton.alpha = isHidden ? 0 : 1
        }, completion: nil)
    }

    @objc func snapToLive() {
        tableView.scrollToRow(at: IndexPath(row: 0, section: Section.widgets), at: .top, animated: true)
    }
}

extension WidgetTimelineViewController: ContentSessionDelegate {
    public func playheadTimeSource(_ session: ContentSession) -> Date? { return nil }
    public func session(_ session: ContentSession, didChangeStatus status: SessionStatus) {}
    public func session(_ session: ContentSession, didReceiveError error: Error) {}
    public func chat(session: ContentSession, roomID: String, newMessage message: ChatMessage) {}
    public func widget(_ session: ContentSession, didBecomeReady widget: Widget) {}
    public func contentSession(_ session: ContentSession, didReceiveWidget widget: WidgetModel) {
        DispatchQueue.main.async {
            self.widgetModels.insert(widget, at: 0)
            self.widgetIsInteractableByID[widget.id] = true
            self.tableView.insertRows(at: [IndexPath(row: 0, section: Section.widgets)], with: .top)
        }
    }
}

extension WidgetTimelineViewController: UITableViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if
            let firstVisibleRow = self.tableView.indexPathsForVisibleRows?.first?.row,
            firstVisibleRow > 0
        {
            self.snapToLiveIsHidden(false)
        } else {
            self.snapToLiveIsHidden(true)
        }
    }
}

extension WidgetTimelineViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == Section.widgets {
            return widgetModels.count
        } else {
            return 1
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Section.widgets {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifer) as? WidgetTableViewCell else {
                return UITableViewCell()
            }
            // prepare for reuse
            cell.widget?.removeFromParentViewController()
            cell.widget?.view.removeFromSuperview()
            cell.widget = nil

            let widgetModel = widgetModels[indexPath.row]

            if let widget = self.makeWidget(widgetModel) {
                addChildViewController(widget)
                widget.didMove(toParentViewController: self)
                widget.view.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(widget.view)

                NSLayoutConstraint.activate([
                    widget.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                    widget.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                    widget.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                    widget.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
                ])

                widgetIsInteractableByID[widgetModel.id] = false
                cell.widget = widget
            }

            return cell
        } else {
            return loadMoreCell
        }
    }

    @objc private func loadMoreButtonPressed() {
        loadMoreCell.button.isHidden = true
        loadMoreCell.activityIndicator.startAnimating()

        session?.getPostedWidgetModels(page: .next) { result in
            switch result {
            case let .success(widgetModels):
                guard let widgetModels = widgetModels else { return }

                DispatchQueue.main.async {
                    let indexPaths: [IndexPath] = widgetModels.enumerated().map {
                        return IndexPath(row: self.widgetModels.count + $0.offset, section: Section.widgets)
                    }
                    self.widgetModels.append(contentsOf: widgetModels)
                    widgetModels.forEach {
                        self.widgetIsInteractableByID[$0.id] = false
                    }
                    self.tableView.insertRows(at: indexPaths, with: .none)
                    self.loadMoreCell.button.isHidden = false
                    self.loadMoreCell.activityIndicator.stopAnimating()
                }
            case let .failure(error):
                print(error)
                self.loadMoreCell.button.isHidden = false
                self.loadMoreCell.activityIndicator.stopAnimating()
            }
        }
    }
}

class WidgetTableViewCell: UITableViewCell {
    var widget: UIViewController?
}

extension WidgetTimelineViewController: WidgetViewDelegate {
    public func widgetDidEnterState(widget: WidgetViewModel, state: WidgetState) {
        switch state {
        case .ready:
            break
        case .interacting:
            widget.addTimer(seconds: widget.interactionTimeInterval ?? 5) { _ in
                widget.moveToNextState()
            }
        case .results:
            break
        case .finished:
            break
        }
    }

    public func widgetStateCanComplete(widget: WidgetViewModel, state: WidgetState) {
        switch state {
        case .ready:
            break
        case .interacting:
            break
        case .results:
            if widget.kind == .imagePredictionFollowUp || widget.kind == .textPredictionFollowUp {
                widget.addTimer(seconds: widget.interactionTimeInterval ?? 5) { _ in
                    widget.moveToNextState()
                }
            } else {
                widget.moveToNextState()
            }
        case .finished:
            break
        }
    }

    public func userDidInteract(_ widget: WidgetViewModel) { }
}

class LoadMoreCell: UITableViewCell {
    let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    let button: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        contentView.addSubview(activityIndicator)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            activityIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            activityIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
