//
//  RepositoryViewController.swift
//  Freetime
//
//  Created by Ryan Nystrom on 9/20/17.
//  Copyright © 2017 Ryan Nystrom. All rights reserved.
//

import UIKit
import Tabman
import Pageboy
import TUSafariActivity
import SafariServices

class RepositoryViewController: TabmanViewController,
PageboyViewControllerDataSource,
NewIssueTableViewControllerDelegate {

    private let repo: RepositoryDetails
    private let client: GithubClient
    private let controllers: [UIViewController]
    private var bookmarkNavController: BookmarkNavigationController? = nil

    var moreOptionsItem: UIBarButtonItem {
        let rightItem = UIBarButtonItem(image: UIImage(named: "bullets-hollow"), target: self, action: #selector(RepositoryViewController.onMore(sender:)))
        rightItem.accessibilityLabel = NSLocalizedString("More options", comment: "")
        return rightItem
    }

    init(client: GithubClient, repo: RepositoryDetails) {
        self.repo = repo
        self.client = client

        let bookmark = Bookmark(
            type: .repo,
            name: repo.name,
            owner: repo.owner,
            hasIssueEnabled: repo.hasIssuesEnabled,
            defaultBranch: repo.defaultBranch
        )
        self.bookmarkNavController = BookmarkNavigationController(store: client.bookmarksStore, model: bookmark)

        var controllers: [UIViewController] = [RepositoryOverviewViewController(client: client, repo: repo)]
        if repo.hasIssuesEnabled {
            controllers.append(RepositoryIssuesViewController(client: client, repo: repo, type: .issues))
        }
        controllers += [
            RepositoryIssuesViewController(client: client, repo: repo, type: .pullRequests),
            RepositoryCodeDirectoryViewController.createRoot(client: client, repo: repo, branch: repo.defaultBranch)
        ]
        self.controllers = controllers

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        makeBackBarItemEmpty()

//        automaticallyAdjustsChildScrollViewInsets = false
        dataSource = self
        delegate = self
        bar.items = controllers.map { Item(title: $0.title ?? "" ) }
        bar.appearance = TabmanBar.Appearance({ appearance in
            appearance.text.font = Styles.Fonts.button
            appearance.state.color = Styles.Colors.Gray.light.color
            appearance.state.selectedColor = Styles.Colors.Blue.medium.color
            appearance.indicator.color = Styles.Colors.Blue.medium.color
        })

        configureNavigationItems()
        navigationItem.configure(title: repo.name, subtitle: repo.owner)
        navigationItem.titleView?.accessibilityLabel = .localizedStringWithFormat("Repository, %@", "\(repo.owner)/\(repo.name)")
    }

    // MARK: Private API

    var repoUrl: URL {
        return URL(string: "https://github.com/\(repo.owner)/\(repo.name)")!
    }

    func configureNavigationItems() {
        var items = [moreOptionsItem]
        if let bookmarkItem = bookmarkNavController?.navigationItem {
            items.append(bookmarkItem)
        }
        navigationItem.rightBarButtonItems = items
    }

    func newIssueAction() -> UIAlertAction? {
        guard let newIssueViewController = NewIssueTableViewController.create(
            client: client,
            owner: repo.owner,
            repo: repo.name,
            signature: .sentWithGitHawk)
        else {
            ToastManager.showGenericError()
            return nil
        }

        newIssueViewController.delegate = self
        weak var weakSelf = self

        return AlertAction(AlertActionBuilder { $0.rootViewController = weakSelf })
            .newIssue(issueController: newIssueViewController)
    }

    @objc func onMore(sender: UIButton) {
        let alertTitle = "\(repo.owner)/\(repo.name)"
        let alert = UIAlertController.configured(title: alertTitle, preferredStyle: .actionSheet)

        weak var weakSelf = self
        let alertBuilder = AlertActionBuilder { $0.rootViewController = weakSelf }

        alert.addActions([
            repo.hasIssuesEnabled ? newIssueAction() : nil,
            AlertAction(alertBuilder).share([repoUrl], activities: [TUSafariActivity()]) {
                $0.popoverPresentationController?.setSourceView(sender)
            },
            AlertAction(alertBuilder).view(owner: repo.owner, url: repo.ownerURL),
            AlertAction.cancel()
        ])
        alert.popoverPresentationController?.setSourceView(sender)

        present(alert, animated: true)
    }

    // MARK: PageboyViewControllerDataSource

    func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
        return controllers.count
    }

    func viewController(for pageboyViewController: PageboyViewController, at index: PageboyViewController.PageIndex) -> UIViewController? {
        return controllers[index]
    }

    func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
        return nil
    }

    // MARK: NewIssueTableViewControllerDelegate

    func didDismissAfterCreatingIssue(model: IssueDetailsModel) {
        let issuesViewController = IssuesViewController(client: client, model: model)
        show(issuesViewController, sender: self)
    }

    // MARK: PageboyViewControllerDelegate

//    override func pageboyViewController(
//        _ pageboyViewController: PageboyViewController,
//        willScrollToPageAt index: PageboyViewController.PageIndex,
//        direction: PageboyViewController.NavigationDirection,
//        animated: Bool
//        ) {
//        super.pageboyViewController(
//            pageboyViewController,
//            willScrollToPageAt: index,
//            direction: direction,
//            animated: animated
//        )
//
//        return
//
//        // hack to fix Tabman not applying top (nav bar) and bottom (tab bar) insets simultaneously
//        var inset: UIEdgeInsets
//        if #available(iOS 11.0, *) {
//            inset = view.safeAreaInsets
//        } else {
//            inset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: bottomLayoutGuide.length, right: 0)
//        }
//        inset.top += bar.requiredInsets.bar
//        for view in controllers[index].view.subviews {
//            if let scrollView = view as? UIScrollView {
//                scrollView.contentInset = inset
//                scrollView.scrollIndicatorInsets = inset
//            }
//        }
//    }

}
