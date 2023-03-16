//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
pragma abicoder v2;
//deployed first instance at: 0xf2b1009b4fe3a61e1a7abe49e08fbf9b9de9bc8c

//this instance is deployed at: 0xdc0b866b7d92b4c3862f3f5af6cec88a03b8fbee

// import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
// import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

// import "./IWETH.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
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
    error invalidFee();
    error sentValueTooLow();
    error alreadyExists();
    error tooLittleTime();
    error lessWethAllowance();
    error expiredOffer();
    error wrongRecipient();
    error notTheOwner();
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function changeActiveAmount(uint256 x) external onlyOwner {
        if (x > 100 || x < 90) {
            revert invalidFee();
        }
        // require(, "can't go out of this range");
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
//made redeem, makeOffer, and acceptOffer functions external.
    function redeem(NFTVoucher calldata voucher) external payable { 
        address signer = _verify(voucher);
        // require(
        //     uriToTokenID[voucher.uri] == 0,
        //     "This URI already exists on chain"
        // );
        if (uriToTokenID[voucher.uri] != 0) {
            revert alreadyExists();
        }
        if (msg.value < voucher.minPrice) {
            revert sentValueTooLow();
        }
        // require(
        //     msg.value >= voucher.minPrice,
        //     "Value sent is lower than min. price"
        // );
        currentTokenId++;
        uriToCreator[voucher.uri] = msg.sender;
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
    ) external {
        if (_approvedAmount == 0) {
            revert sentValueTooLow(); //if we want to keep these changes, and keep on working with reverts like these, I'll be more explicit.
        }
        // require(_approvedAmount > 0, "Can't offer zero ether");
        if (
            IERC20(weth).allowance(msg.sender, address(this)) < _approvedAmount
        ) {
            revert lessWethAllowance();
        }
        // require(
        //     IERC20(weth).allowance(msg.sender, address(this)) >=
        //         _approvedAmount,
        //     "You haven't approved enough weth"
        // );
        //recheck with reviewer, because time is in seconds not milliseconds.
        if (_endTime < block.timestamp + 300) {
            revert tooLittleTime();
        }
        // require(
        //     _endTime > block.timestamp + 30,
        //     "Should give enough time for the offer to make sense"
        // );
        offers memory offer1 = offers({
            recipient: offeredTo,
            tokenURI: _tokenURI,
            offerer: msg.sender,
            endTime: _endTime,
            approvedTokenAmount: _approvedAmount
        });
        //code that will let the second offers offered to same NFT function properly.
        // if (uriToTokenID[_tokenURI] == 0) {
        //     uriToCreator[_tokenURI] = offeredTo;
        // }
        offerIDToOffers[offerCounter] = offer1;
        emit offerCreated(offerCounter, offer1);
        offerCounter++;
    }
//string memory _tokenURI, removed as param as offerID also has account of tokenURI.
    function acceptOffer(uint256 _offerID) external {
        offers memory offerX = offerIDToOffers[_offerID];
        uint thisTokenID = uriToTokenID[offerX.tokenURI];
        address recipientOfWETH = offerX.recipient;
        if(recipientOfWETH!=msg.sender){
            revert wrongRecipient();
        }
        // require(
        //     recipientOfWETH == msg.sender,
        //     "Only recipient can accept this offer."
        // );
        if(block.timestamp > offerX.endTime){
            revert expiredOffer();
        }
        // require(
        //     block.timestamp < offerIDToOffers[_offerID].endTime,
        //     "Offer has expired"
        // );
        address receiverOfNFT = offerX.offerer;
        if (thisTokenID != 0) {
            if(ownerOf(thisTokenID) != msg.sender){
                revert notTheOwner();
            }
            // require(
            //     ownerOf(uriToTokenID[_tokenURI]) == msg.sender,
            //     "You don't own the NFT, so you can't accept this offer anymore"
            // );
            _transfer(msg.sender, receiverOfNFT, thisTokenID);
        } else {
            currentTokenId++;
            uriToCreator[offerX.tokenURI] = offerX.recipient;
            _mint(receiverOfNFT, currentTokenId);
            _setTokenURI(currentTokenId, offerX.tokenURI);
            thisTokenID = currentTokenId;
            emit newNFTMinted(currentTokenId, receiverOfNFT, msg.sender);
        }

        if (activeFee) {
            uint256 valueX = (offerX.approvedTokenAmount *
                effectiveAmount) / 100;
            IERC20(weth).transferFrom(receiverOfNFT, recipientOfWETH, valueX);
            IERC20(weth).transferFrom(
                receiverOfNFT,
                owner,
                offerX.approvedTokenAmount - valueX
            );
        } else {
            IERC20(weth).transferFrom(
                receiverOfNFT,
                recipientOfWETH,
                offerX.approvedTokenAmount
            );
        }
        // availableOffers[_creator][_tokenURI].cutOff = availableOffers[_creator][_tokenURI].noOfElements;
        emit offerAccepted(_offerID, offerX);
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
