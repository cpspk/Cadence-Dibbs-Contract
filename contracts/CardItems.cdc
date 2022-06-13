import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"

pub contract CardItems: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, name: String, grade: String, image: String, serial: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupplys
    // The total number of CardItems that have been minted
    //
    pub var totalSupply: UInt64

    pub let exists: {String: Bool}

    pub let fractionalized: {UInt64: Bool}

    pub let isTokenLocked: {UInt64: Bool}
    

    pub fun setTokenLocked(_ id: UInt64) {
        CardItems.isTokenLocked.insert(key: id, true)
    }

    pub fun removeTokenLocked(_ id: UInt64) {
        CardItems.isTokenLocked.remove(key: id)
    }

    pub fun setFractionalized(_ id: UInt64) {
        CardItems.fractionalized.insert(key: id, true)
    }

    pub fun removeFractionalized(_ id: UInt64) {
        CardItems.fractionalized.remove(key: id)
    } 
    // A Kitty Item as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64

        // The token name (e.g. 2010 Bowman Draft Picks Manny Machado ROOKIE RC #BDPP80 PSA 10 GEM MINT)
        pub let name: String

        // The token grade (e.g. PSA 10)
        pub let grade: String

        // The token serial id (e.g. 22129333)
        pub let serial: String

        // The token hashed string for image on IPFS (e.g. Qmec8XfVmibXTYhGMn9qst6sySmcDeQk8S9p4RVX9tTPzt)
        pub let image: String

        pub let symbol: String

        init(id: UInt64, name: String, grade: String, serial: String, image: String) {
            self.id = id
            self.name = name
            self.grade = grade
            self.image = image
            self.serial = serial

            self.symbol = self.name.concat(self.grade)
                                   .concat(self.serial)
                                   .concat(self.image)

            assert(CardItems.exists[self.symbol] == nil || CardItems.exists[self.symbol] == false, message: "This NFT already exsits")
            CardItems.exists.insert(key: self.symbol, true)
        }

        pub fun description(): String {
            return "A "
                .concat(self.name.toLower())
                .concat(" ")
                .concat("with serial number ")
                .concat(self.serial)
        }

        pub fun imageCID(): String {
            return self.image
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description(),
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.imageCID(), 
                            path: "sm.png"
                        )
                    )
            }

            return nil
        }
    }

    // This is the interface that users can cast their CardItems Collection as
    // to allow others to deposit CardItems into their Collection. It also allows for reading
    // the details of CardItems in the Collection.
    pub resource interface CardItemsCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowCardItem(id: UInt64): &CardItems.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow CardToken reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of CardToken NFTs owned by an account
    //
    pub resource Collection: CardItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @CardItems.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowCardItem
        // Gets a reference to an NFT in the collection as a CardToken,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the CardToken.
        //
        pub fun borrowCardItem(id: UInt64): &CardItems.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &CardItems.NFT
            } else {
                return nil
            }
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic}, 
            name: String, 
            grade: String,
            serial: String,
            image: String
        ) {
            // deposit it in the recipient's account using their reference
            //TODO: only dibbs should be able to mint NFTs and fractionalize them
            recipient.deposit(token: <-create CardItems.NFT(id: CardItems.totalSupply, name: name, grade: grade, serial: serial, image: image))

            emit Minted(
                id: CardItems.totalSupply,
                name: name,
                grade: grade,
                image: image,
                serial: serial,
            )

            CardItems.totalSupply = CardItems.totalSupply + (1 as UInt64)
        }
    }

    // fetch
    // Get a reference to a CardToken from an account's Collection, if available.
    // If an account does not have a CardItems.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &CardItems.NFT? {
        let collection = getAccount(from)
            .getCapability(CardItems.CollectionPublicPath)!
            .borrow<&CardItems.Collection{CardItems.CardItemsCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust CardItems.Collection.borowCardToken to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowCardItem(id: itemID)
    }

    // initializer
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/CardItemsCollectionV1
        self.CollectionPublicPath = /public/CardItemsCollectionV1
        self.MinterStoragePath = /storage/CardItemsMinterV1

        // Initialize the total supply
        self.totalSupply = 0
        self.exists = {}
        self.fractionalized = {}
        self.isTokenLocked = {}

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
