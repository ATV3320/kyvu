//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;
//deployed first instance at: 0xf2b1009b4fe3a61e1a7abe49e08fbf9b9de9bc8c

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./IWETH.sol";

//tasks:
//1. Add events for every big function.
//2. WETH consider how it will happen. DONE
//3. only owner functions for modification of fees upto x percent, and weth updation. DONE
//4. Modify the main functions for when NFT is already minted. so modify one function here? DONE

//changed:
//removed bug of transferring weth tokens.abi
//reentrancy prevention
//logical issue spotted, nullifying the need of the creator as trade-off for saving gas of not transferring to the creator first.

//further changes,
//makeOffer some security checks, like no backdating in time, amount that you are offering should be approved on weth, and amount>0.

contract KyvuNFT is ERC721URIStorage, EIP712 {
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";
    uint256 public currentTokenId;
    address public weth;
    bool public activeFee;
    uint256 effectiveAmount = 98;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function changeActiveAmount(uint256 x) external onlyOwner {
        require(x <= 100 && x >= 90, "can't go out of this range");
        effectiveAmount = x;
    }

    struct offers {
        address recipient;
        string tokenURI;
        address offerer;
        uint96 endTime;
        uint256 approvedTokenAmount;
    }
    event offerCreated(uint256 offerId, offers offer);
    event nftRedeemed(
        uint tokenID,
        address creator,
        address redeemer,
        uint salePrice,
        string tokenURI
    );
    event offerAccepted(uint offerId, offers offer);
    event newNFTMinted(uint tokenID, address recipient, address creator);

    mapping(string => address) public uriToCreator;
    mapping(uint256 => offers) public offerIDToOffers;
    uint256 public offerCounter;

    mapping(string => uint256) uriToTokenID;

    // mapping(address=>uint) userWETHUtilization;
    //changeX
    constructor(
        address _weth
    )
        ERC721("Kyvu Restricted NFT", "Kyvu")
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        weth = _weth;
    }

    function updateWeth(address _newWeth) external onlyOwner {
        weth = _newWeth;
    }

    function toggleFee() external onlyOwner {
        if (activeFee) {
            activeFee = false;
        } else {
            activeFee = true;
        }
    }

    struct NFTVoucher {
        uint256 minPrice;
        string uri;
        bytes signature;
    }

    function redeem(NFTVoucher calldata voucher) public payable {
        address signer = _verify(voucher);
        require(
            uriToTokenID[voucher.uri] == 0,
            "This URI already exists on chain"
        );

        require(
            msg.value >= voucher.minPrice,
            "Value sent is lower than min. price"
        );
        currentTokenId++;
        _mint(msg.sender, currentTokenId);
        _setTokenURI(currentTokenId, voucher.uri);
        if (activeFee) {
            uint256 valueX = (msg.value * effectiveAmount) / 100;
            signer.call{value: valueX};
            owner.call{value: msg.value - valueX};
        } else {
            signer.call{value: msg.value};
        }
        uriToTokenID[voucher.uri] = currentTokenId;
        emit nftRedeemed(
            currentTokenId,
            signer,
            msg.sender,
            msg.value,
            voucher.uri
        );
        emit newNFTMinted(currentTokenId, msg.sender, signer);
        //in function redeem u should update uriTotoken mapping before minitng and currentTokenId  just after minting
    }

    function makeOffer(
        address offeredTo,
        string memory _tokenURI,
        uint96 _endTime,
        uint256 _approvedAmount
    ) public {
        require(_approvedAmount > 0, "Can't offer zero ether");
        require(
            IERC20(weth).allowance(msg.sender, address(this)) >=
                _approvedAmount,
            "You haven't approved enough weth"
        );
        require(
            _endTime > block.timestamp + 30,
            "Should give enough time for the offer to make sense"
        );
        offers memory offer1 = offers({
            recipient: offeredTo,
            tokenURI: _tokenURI,
            offerer: msg.sender,
            endTime: _endTime,
            approvedTokenAmount: _approvedAmount
        });
        //code that will let the second offers offered to same NFT function properly.
        if (uriToTokenID[_tokenURI] == 0) {
            uriToCreator[_tokenURI] = offeredTo;
        }
        offerIDToOffers[offerCounter] = offer1;
        emit offerCreated(offerCounter, offer1);
        offerCounter++;
    }

    function acceptOffer(string memory _tokenURI, uint256 _offerID) public {
        address recipientOfWETH = offerIDToOffers[_offerID].recipient;
        require(
            recipientOfWETH == msg.sender,
            "Only recipient can accept this offer."
        );
        require(
            block.timestamp < offerIDToOffers[_offerID].endTime,
            "Offer has expired"
        );
        address receiverOfNFT = offerIDToOffers[_offerID].offerer;
        if (uriToTokenID[_tokenURI] != 0) {
                    require(ownerOf(uriToTokenID[_tokenURI])==msg.sender, "You don't own the NFT, so you can't accept this offer anymore");
            _transfer(msg.sender, receiverOfNFT, uriToTokenID[_tokenURI]);
        } else {
            currentTokenId++;
            _mint(receiverOfNFT, currentTokenId);
            _setTokenURI(currentTokenId, _tokenURI);
            uriToTokenID[_tokenURI] = currentTokenId;
            emit newNFTMinted(currentTokenId, receiverOfNFT, msg.sender);
        }

        if (activeFee) {
            uint256 valueX = (offerIDToOffers[_offerID].approvedTokenAmount *
                effectiveAmount) / 100;
            IERC20(weth).transferFrom(receiverOfNFT, recipientOfWETH, valueX);
            IERC20(weth).transferFrom(
                receiverOfNFT,
                owner,
                offerIDToOffers[_offerID].approvedTokenAmount - valueX
            );
        } else {
            IERC20(weth).transferFrom(
                receiverOfNFT,
                recipientOfWETH,
                offerIDToOffers[_offerID].approvedTokenAmount
            );
        }
        // availableOffers[_creator][_tokenURI].cutOff = availableOffers[_creator][_tokenURI].noOfElements;
        emit offerAccepted(_offerID, offerIDToOffers[_offerID]);
    }

    function _hash(
        NFTVoucher calldata voucher
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("NFTVoucher(uint256 minPrice,bytes uri)"),
                        voucher.minPrice,
                        keccak256(bytes(voucher.uri))
                    )
                )
            );
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function _verify(
        NFTVoucher calldata voucher
    ) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721) returns (bool) {
        return ERC721.supportsInterface(interfaceId);
    }
}
