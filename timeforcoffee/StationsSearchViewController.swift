//
//  StationsSearchViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 10.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

final class StationsSearchViewController: StationsViewController, UISearchBarDelegate {

    @IBOutlet  var appsTableView2: StationTableView?
    var searchController: UISearchController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true;
        let sc: UISearchController = UISearchController(searchResultsController: nil)

        self.searchController = sc
        self.searchController?.hidesNavigationBarDuringPresentation = false;
        self.searchController?.dimsBackgroundDuringPresentation = false;
        let searchBar = self.searchController?.searchBar
        self.navigationItem.rightBarButtonItem = nil;
        self.navigationItem.titleView = searchBar
        searchBar?.delegate = self
        let appsTableView = self.appsTableView2
        sc.searchResultsUpdater = appsTableView
        definesPresentationContext = false
        self.view.alpha = 0.0
        self.searchController?.searchBar.alpha = 0.0
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.edgesForExtendedLayout = UIRectEdge.None;

    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated, noReload: true)
        if (!(self.searchController?.isViewLoaded() == true && self.searchController?.view.window != nil)) {
            self.presentViewController(self.searchController!, animated: true, completion: {
                self.searchController?.searchBar.becomeFirstResponder()
                return
            })
        }

        var duration: NSTimeInterval = 0.5
        UIView.animateWithDuration(duration,
            animations: {
                self.view.alpha = 1.0
                self.searchController?.searchBar.alpha = 1.0
                return
            }, completion: { (finished:Bool) in
                return
        })
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            let gtracker = GAI.sharedInstance().defaultTracker
            gtracker.set(kGAIScreenName, value: "search")
            gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
        }
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        var searchBar = self.searchController?.searchBar
        self.navigationController?.popToRootViewControllerAnimated(false)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var detailsViewController: DeparturesViewController = segue.destinationViewController as! DeparturesViewController

        if (self.searchController != nil) {
            self.searchController?.searchBar.resignFirstResponder()
        }
        var index = appsTableView2?.indexPathForSelectedRow()?.row
        if (index != nil) {
            var station = appsTableView2?.stations.getStation(index!)
            detailsViewController.setStation(station: station!);
        }
    }
}