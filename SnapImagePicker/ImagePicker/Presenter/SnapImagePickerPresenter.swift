import UIKit
import Photos

class SnapImagePickerPresenter {
    private weak var view: SnapImagePickerViewControllerProtocol?
    
    var interactor: SnapImagePickerInteractorProtocol?
    weak var connector: SnapImagePickerConnectorProtocol?
    
    var albumType = AlbumType.AllPhotos {
        didSet {
            interactor?.clearPendingRequests()
            loadAlbum()
        }
    }
    
    enum RequestStatus {
        case None
        case Requested
        case Completed
        
        func isInitializedOrCompleted() -> Bool {
            switch self {
            case .None: return false
            case .Requested: return true
            case .Completed: return true
            }
        }
    }
    
    private var mainImage: SnapImagePickerImage?
    private var requestedMainImage: String?
    private var albumSize: Int?
    private var albumImages: [(imageWrapper: SnapImagePickerImage?, status: RequestStatus)]?
    private var indexes = [String: Int]()

    private var selectedIndex = 0
    
    private var rotation = CGFloat(0)
    private var cellSize = CGSize(width: 64, height: 64)
    
    private let loadingBufferSize = 20
    
    init(view: SnapImagePickerViewControllerProtocol) {
        self.view = view
    }
}

extension SnapImagePickerPresenter {
    private func loadAlbum() {
        interactor?.loadInitialAlbum(albumType)
    }
    
    private func display() {
        view?.display(SnapImagePickerViewModel(albumTitle: albumType.getAlbumName(),
            mainImage: mainImage,
            selectedIndex: selectedIndex,
            isLoading: mainImage?.localIdentifier != requestedMainImage))
    }
}

extension SnapImagePickerPresenter {
    func photosAccessStatusChanged() {
        checkPhotosAccessStatus()
    }
    
    private func checkPhotosAccessStatus() {
        validatePhotosAccessStatus(PHPhotoLibrary.authorizationStatus())
    }
    
    private func validatePhotosAccessStatus(availability: PHAuthorizationStatus, retry: Bool = true) {
        switch availability {
        case .Restricted: fallthrough
        case .Authorized: loadAlbum()
        case .Denied:connector?.requestPhotosAccess()
        case .NotDetermined:
            if retry {
                PHPhotoLibrary.requestAuthorization() {
                    [weak self] status in self?.validatePhotosAccessStatus(status, retry: false)
                }
            } else {
                connector?.requestPhotosAccess()
            }
        }
    }
}

extension SnapImagePickerPresenter: SnapImagePickerPresenterProtocol {
    func presentInitialAlbum(image: SnapImagePickerImage, albumSize: Int) {
        mainImage = image
        requestedMainImage = image.localIdentifier
        albumImages = [(imageWrapper: SnapImagePickerImage?, status: RequestStatus)](count: albumSize,
                                                                                     repeatedValue: (imageWrapper: nil, status: RequestStatus.None))
        display()
    }
    
    func presentMainImage(image: SnapImagePickerImage) -> Bool {
        if image.localIdentifier == requestedMainImage {
            mainImage = image
            
            display()
            return true
        }
        
        return false
    }
    
    func presentAlbumImage(image: SnapImagePickerImage, atIndex index: Int) -> Bool {
        if index < albumImages?.count && index >= 0 {
            albumImages?[index] = (imageWrapper: image, status: RequestStatus.Completed)
            
            display()
            return true
        }
        
        return false
    }
}

extension SnapImagePickerPresenter: SnapImagePickerEventHandlerProtocol {
    func viewWillAppearWithCellSize(cellSize: CGFloat) {
        self.cellSize = CGSize(width: cellSize, height: cellSize)
        checkPhotosAccessStatus()
    }

    func albumImageClicked(index: Int) -> Bool {
        if let albumImages = albumImages
           where index < albumImages.count {
            if let localIdentifier = albumImages[index].imageWrapper?.localIdentifier {
                selectedIndex = index
                requestedMainImage = localIdentifier
                interactor?.loadImageWithLocalIdentifier(localIdentifier)
                
                display()
                return true
            }
        }
        
        return false
    }
    
    func albumTitleClicked(destinationViewController: UIViewController) {
        connector?.prepareSegueToAlbumSelector(destinationViewController)
    }

    func selectButtonPressed(image: UIImage, withImageOptions options: ImageOptions) {
        connector?.setChosenImage(image, withImageOptions: options)
    }
    
    func numberOfSectionsForNumberOfColumns(columns: Int) -> Int {
        if let albumImages = albumImages {
            return max(albumImages.count / columns, 1)
        }
        
        return 0
    }
    
    func numberOfItemsInSection(section: Int, withColumns columns: Int) -> Int {
        if let albumImages = albumImages {
            let previouslyUsedImages = section * columns
            let remainingImages = albumImages.count - previouslyUsedImages
            let columns = max(min(columns, remainingImages), 0)
        
            return columns
        }
        
        return 0
    }
    
    func presentCell(cell: ImageCell, atIndex index: Int) -> ImageCell {
        if let albumImages = albumImages
           where index < albumImages.count {
            let albumImage = albumImages[index]
            if let imageWrapper = albumImages[index].imageWrapper {
                let image = imageWrapper.image.square()
            
                if index == selectedIndex {
                    cell.backgroundColor = SnapImagePicker.Theme.color
                    cell.spacing = 2
                } else {
                    cell.spacing = 0
                }
            
                cell.imageView?.contentMode = .ScaleAspectFill
                cell.imageView?.image = image
            } else if !albumImage.status.isInitializedOrCompleted() {
                self.albumImages?[index] = (imageWrapper: nil, status: RequestStatus.Requested)
                interactor?.loadAlbumImageWithType(albumType, withTargetSize: cellSize, atIndex: index)
            }
        }
        
        return cell
    }
}