import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import CardItems from "./contracts/CardItems.cdc"
import MetadataViews from "./contracts/MetadataViews.cdc"

pub struct CardItem {
    pub let name: String
    pub let description: String
    pub let thumbnail: String

    pub let itemID: UInt64
    pub let resourceID: UInt64
    pub let cardName: String
    pub let cardGrade: String
    pub let cardSerial: String
    pub let cardImage: String
    pub let owner: Address

    init(
        name: String,
        description: String,
        thumbnail: String,
        itemID: UInt64,
        resourceID: UInt64,
        cardName: String,
        cardGrade: String,
        cardSerial: String,
        cardImage: String,
        owner: Address,
    ) {
        self.name = name
        self.description = description
        self.thumbnail = thumbnail

        self.itemID = itemID
        self.resourceID = resourceID
        self.cardName = cardName
        self.cardGrade = cardGrade
        self.cardSerial = cardSerial
        self.cardImage = cardImage
        self.owner = owner
    }
}

pub fun dwebURL(_ file: MetadataViews.IPFSFile): String {
    var url = "https://"
        .concat(file.cid)
        .concat(".ipfs.dweb.link/")
    
    if let path = file.path {
        return url.concat(path)
    }
    
    return url
}

pub fun main(address: Address, itemID: UInt64): CardItem? {
    if let collection = getAccount(address).getCapability<&CardItems.Collection{NonFungibleToken.CollectionPublic, CardItems.CardItemsCollectionPublic}>(CardItems.CollectionPublicPath).borrow() {
        
        if let item = collection.borrowCardItem(id: itemID) {

            if let view = item.resolveView(Type<MetadataViews.Display>()) {

                let display = view as! MetadataViews.Display
                
                let owner: Address = item.owner!.address!

                let ipfsThumbnail = display.thumbnail as! MetadataViews.IPFSFile     

                return CardItem(
                    name: display.name,
                    description: display.description,
                    thumbnail: dwebURL(ipfsThumbnail),
                    itemID: itemID,
                    resourceID: item.uuid,
                    cardName: item.name, 
                    cardGrade: item.grade, 
                    cardSerial: item.serial,
                    cardImage: item.image,
                    owner: address,
                )
            }
        }
    }

    return nil
}
