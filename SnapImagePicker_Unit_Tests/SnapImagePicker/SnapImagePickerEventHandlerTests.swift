import XCTest
@testable import SnapImagePicker

class SnapImagePickerEventHandlerTests: XCTestCase {
    var viewController: SnapImagePickerViewControllerSpy?
    var interactor: SnapImagePickerInteractorSpy?
    var connector: SnapImagePickerConnectorSpy?
    var eventHandler: SnapImagePickerPresenter?

    override func setUp() {
        super.setUp()
        viewController = SnapImagePickerViewControllerSpy()
        interactor = SnapImagePickerInteractorSpy()
        connector = SnapImagePickerConnectorSpy()
        
        eventHandler = SnapImagePickerPresenter(view: viewController!, cameraRollAccess: true)
        eventHandler?.interactor = interactor
        eventHandler?.connector = connector
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    fileprivate func createSnapImagePickerImage(_ image: UIImage = UIImage(), localIdentifier: String = "", createdDate: Date? = nil) -> SnapImagePickerImage {
        return SnapImagePickerImage(image: image, localIdentifier: localIdentifier, createdDate: createdDate as Date?)
    }
    
    fileprivate func presentAlbum(_ albumType: AlbumType = AlbumType.allPhotos, image: UIImage = UIImage(), localIdentifier: String = "", createdDate: Date? = nil, albumSize: Int = 30) {
        let mainImage = createSnapImagePickerImage(image, localIdentifier: localIdentifier, createdDate: createdDate)
        eventHandler?.presentAlbum(albumType, withMainImage: mainImage, albumSize: albumSize)
    }
    
    fileprivate func presentAlbumImages(_ albumType: AlbumType = AlbumType.allPhotos, image: UIImage = UIImage(), localIdentifier: String = "", createdDate: Date? = nil, albumSize: Int = 30) {
        let image = createSnapImagePickerImage(image, localIdentifier: localIdentifier, createdDate: createdDate)
        var results = [Int: SnapImagePickerImage]()
        for i in 0..<albumSize {
            results[i] = image
        }
        
        eventHandler?.presentAlbumImages(results, fromAlbum: albumType)
    }

    func testViewWillAppearWithCellSizeShouldSetCellSize() {
        eventHandler?.cameraRollAccess = true
        let cellSize = CGSize(width: 20, height: 20)
        let targetSize = CGSize(width: cellSize.width * 2, height: cellSize.height * 2)
        
        eventHandler?.viewWillAppearWithCellSize(cellSize)
        eventHandler?.scrolledToCells(0..<2, increasing: true)
        XCTAssertEqual(targetSize, interactor?.loadAlbumImagesFromAlbumTargetSize)
    }
    
    func testAlbumImageClickedShouldTriggerLoadMainImage() {
        let albumSize = 2
        presentAlbum(albumSize: albumSize)
        presentAlbumImages(albumSize: albumSize)
        
        eventHandler?.cameraRollAccess = true
        let _ = eventHandler?.albumImageClicked(1)
        XCTAssertEqual(1, interactor?.loadMainImageFromAlbumCount)
        XCTAssertEqual(AlbumType.allPhotos, interactor?.loadMainImageFromAlbumType)
        XCTAssertEqual(1, interactor?.loadMainImageFromAlbumIndex)
    }
    
    func testAlbumImageClickedShouldTriggerReloadCells() {
        let albumSize = 2
        presentAlbum(albumSize: albumSize)
        presentAlbumImages(albumSize: albumSize)
        
        let precedingCount = viewController!.reloadCellAtIndexesCount
        eventHandler?.cameraRollAccess = true
        let _ = eventHandler?.albumImageClicked(1)
        XCTAssertEqual(precedingCount + 1, viewController?.reloadCellAtIndexesCount)
        XCTAssertNotNil(viewController?.reloadCellAtIndexesIndexes)
        XCTAssertEqual([0, 1], viewController!.reloadCellAtIndexesIndexes!.sorted())
    }
    
    func testNumberOfItemsInSectionShouldEqualAlbumSize() {
        let albumSize = 30
        presentAlbum(albumSize: albumSize)
        
        XCTAssertEqual(albumSize, eventHandler?.numberOfItemsInSection(0))
        XCTAssertEqual(0, eventHandler?.numberOfItemsInSection(1))
    }
    
    func testPresentCellShouldDoNothingForInvalidIndex() {
        let cell = ImageCell()
        
        let _ = eventHandler?.presentCell(cell, atIndex: 10)
        XCTAssertNil(cell.imageView?.image)
    }
    
    func testPresentCellShouldSetImage() {
        if let image = UIImage(named: "dummy", in: Bundle(for: SnapImagePickerEventHandlerTests.self), compatibleWith: nil) {
            eventHandler?.cameraRollAccess = true
            presentAlbum(image: image)
            eventHandler?.scrolledToCells(0..<2, increasing: true)
            presentAlbumImages(image: image)

            let cell = ImageCell()
            let imageView = UIImageView()
            cell.imageView = imageView
            let _ = eventHandler?.presentCell(cell, atIndex: 1)
            XCTAssertNotNil(imageView.image)
        } else {
            XCTFail("Unable to load image dummy for testing")
        }
    }
    
    func testPresentSelectedIndexShouldSetSpacing() {
        eventHandler?.cameraRollAccess = true
        presentAlbum()
        eventHandler?.scrolledToCells(0..<2, increasing: true)
        presentAlbumImages()
        
        let cell = ImageCell()
        let _ = eventHandler?.presentCell(cell, atIndex: 0)
        XCTAssertEqual(2, cell.spacing)
    }
    
    func testScrolledToCellsShouldTriggerLoadImages() {
        eventHandler?.cameraRollAccess = true
        presentAlbum()
        presentAlbumImages()
        let range = 0..<10
        
        eventHandler?.scrolledToCells(range, increasing: true)
        XCTAssertEqual(1, interactor?.loadAlbumImagesFromAlbumCount)
        XCTAssertEqual(range, interactor?.loadAlbumImagesFromAlbumRange)
    }
    
    func testAlbumTitlePressedShouldTriggerSegue() {
        eventHandler?.cameraRollAccess = true
        eventHandler?.albumTitlePressed(nil)
        XCTAssertEqual(1, connector?.segueToAlbumSelectorCount)
    }
}
