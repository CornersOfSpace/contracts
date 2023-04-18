// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error InvalidPercentages();
error InvalidAddress();
error UnauthorizedTx();
error InvalidNonce();
error NotEnoughValue();
error ValueTransferFailed();
error InvalidTokenAmount();
error SigExpired();
error InaligiblePayToken();
error ValueSent();
error NoRefundAvailable();

contract CornersOfSpace is ERC721Enumerable, AccessControl, EIP712 {
    using SafeERC20 for IERC20;
    // Token Address -> isEligible: true for eligible; false for ineligible
    mapping(address => bool) public eligibleTokens;

    // Wallet that receives liquidity before sending them to dex, to support erc20 token
    address public liquidityReceiver;
    // DAO wallet
    address public dao;

    // ChainLink USD-BNB price feed
    AggregatorV3Interface public bnbUSDFeed;

    bytes32 internal constant ADMIN = keccak256("ADMIN");
    bytes32 internal constant ULTIMATE_ADMIN = keccak256("ULTIMATE_ADMIN");
    // DAO application backend
    address public authorizer;

    uint256 private _currentTokenId;
    string private baseURI;

    uint256 public daoSharePercentage; // 0-100 value
    uint256 public liquiditySharePercentage; // 0-100 value

    uint256 constant PERCENTAGE_DENOMINATOR = 100;
    uint256 constant REFFERAL_SHARE = 5;

    bytes32 constant MESSAGE_TYPEHASH =
        keccak256(
            "MessageType(address minter,bool free,uint256 price,address payToken,uint256 nonce,uint64 sigDeadline,string args,address referral)"
        );

    bytes32 constant BUNDLE_TYPEHASH =
        keccak256(
            "BundleType(address minter,bool free,uint256 price,address payToken,uint256 nonce,uint64 sigDeadline,string args,uint256 amount,address referral)"
        );

    bytes32 public domainSeparator;
    uint256 public lockedFunds;

    mapping(uint256 => bool) public usedNonces;

    mapping(address => uint256) public valueToReturn;

    /******************** EVENTS ********************/

    event AssetMinted(uint256 _tokenId, string indexed args);
    event BundleMinted(uint256[] _tokenIds, string indexed args);
    event BaseURISet(string newURI);
    event NewAuthorizerSet(address authorizer);
    event NewReceiversSet(address newDao, address liquidity);
    event PriceFeedUpdated(address newPriceFeed);
    event PayTokenStatusUpdated(address payToken, bool status);
    event NewSharesSet(uint256 newLiquidityShare, uint256 newDaoShare);

    /******************** MODIFIERS ********************/

    modifier validAddress(address _addr) {
        if (_addr == address(0)) {
            revert InvalidAddress();
        }
        _;
    }

    /******************** CONSTRUCTOR ********************/

    constructor(
        address _admin,
        address _adminController,
        address _authorizer,
        AggregatorV3Interface _priceFeed,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC721(_name, _symbol) EIP712(_name, "1") {
        _grantRole(ULTIMATE_ADMIN, _adminController);
        _setRoleAdmin(ADMIN, ULTIMATE_ADMIN);
        _grantRole(ADMIN, _admin);

        if (_authorizer == address(0)) {
            revert InvalidAddress();
        }

        baseURI = _uri;
        authorizer = _authorizer;
        bnbUSDFeed = _priceFeed;

        emit NewAuthorizerSet(_authorizer);
        emit BaseURISet(_uri);
        emit PriceFeedUpdated(address(_priceFeed));
    }

    /******************** BASE ERC721 OVERRIDE FUNCTIONS ********************/

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /******************** MINTING FUNCTIONS ********************/
    /**
    @dev primary function to mint one NFT; NFT minting is tied to a pseudo-random rarity "raffle"
    that happens offchain. Therefore, during function execution it's checked if application registered
    user's attempt to mint an NFT using signer recovery. ECDSA functions developer by 1inch.
    Payment for the NFT is set offchain and during function execution checked in the signature.
    Payment is distributed between 2 or 3 receivers: Liquidity receiver, DAO and referral.
    Referral transfer is happening only if _referral param passed as non-address(0)
    Signature is valid until blockDeadline param, and assigned nonce can be used only once
    
    @param _free lets users mint NFTs for free if passed as 'true'
    @param _payToken payment token address
    @param _nonce unique value assigned for minting
    @param _blockDeadline block number after which tx execution will be rewerted
    @param _sig signature signed by authorizer
    @param _args string param, that helps with indexation. Should not exceed 20 symbols
    @param _referral referral address to receive 5% payment value. Pass address(0) to indicate that there is no referall
     */
    function mint(
        bool _free,
        address _payToken,
        uint256 _nftPrice,
        uint256 _nonce,
        uint64 _blockDeadline,
        bytes calldata _sig,
        string calldata _args,
        address _referral
    ) external payable {
        _handleChecksAndNonce(_nonce, _blockDeadline, _payToken);

        bytes32 message = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MESSAGE_TYPEHASH,
                    msg.sender,
                    _free,
                    _nftPrice,
                    _payToken,
                    _nonce,
                    _blockDeadline,
                    keccak256(bytes(_args)),
                    _referral
                )
            )
        );

        if (ECDSA.recover(message, _sig) != authorizer) {
            revert UnauthorizedTx();
        }

        if (!_free) {
            if (_referral == address(0)) {
                _transfer(1, _payToken, _nftPrice);
            } else {
                _transferWithReferral(1, _payToken, _nftPrice, _referral);
            }
        }

        uint256 newTokenId = _currentTokenId + 1;
        _currentTokenId++;
        _safeMint(msg.sender, newTokenId);

        emit AssetMinted(newTokenId, _args);
    }

    /**    
    @dev primary function to mint _tokenAmount amount of NFT; NFT minting is tied to a pseudo-random rarity "raffle"
    that happens offchain. Therefore, during function execution it's checked if application registered
    user's attempt to mint an NFT using signer recovery. ECDSA functions developer by 1inch.
    Payment for the NFT is set offchain and during function execution checked in the signature.
    Payment is distributed between 2 or 3 receivers: Liquidity receiver, DAO and referral.
    Referral transfer is happening only if _referral param passed as non-address(0)
    Signature is valid until blockDeadline param, and assigned nonce can be used only once
    
    @param _free lets users mint NFTs for free if passed as 'true'
    @param _payToken payment token address
    @param _nonce unique value assigned for minting
    @param _blockDeadline block number after which tx execution will be rewerted
    @param _sig signature signed by authorizer
    @param _args string param, that helps with indexation. Should not exceed 20 symbols
    @param _tokenAmount amount of tokens to be minted. Shouldn't be more then 11, otherwise might not get mined
    @param _referral referral address to receive 5% payment value. Pass address(0) to indicate that there is no referall */
    function bundleMint(
        bool _free,
        address _payToken,
        uint256 _nftPrice,
        uint256 _nonce,
        uint64 _blockDeadline,
        bytes calldata _sig,
        string calldata _args, // 20 symbols max
        uint256 _tokenAmount,
        address _referral
    ) external payable {
        _handleChecksAndNonce(_nonce, _blockDeadline, _payToken);

        if (_tokenAmount == 0) {
            revert InvalidTokenAmount();
        }

        bytes32 message = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    BUNDLE_TYPEHASH,
                    msg.sender,
                    _free,
                    _nftPrice,
                    _payToken,
                    _nonce,
                    _blockDeadline,
                    keccak256(bytes(_args)),
                    _tokenAmount,
                    _referral
                )
            )
        );
        if (ECDSA.recover(message, _sig) != authorizer) {
            revert UnauthorizedTx();
        }
        if (!_free) {
            if (_referral == address(0)) {
                _transfer(_tokenAmount, _payToken, _nftPrice);
            } else {
                _transferWithReferral(
                    _tokenAmount,
                    _payToken,
                    _nftPrice,
                    _referral
                );
            }
        }
        uint256[] memory tokenIds = new uint256[](_tokenAmount);
        uint256 currentTokenId = _currentTokenId;
        for (uint i; i < _tokenAmount; i++) {
            currentTokenId++;
            _safeMint(msg.sender, currentTokenId);
            tokenIds[i] = currentTokenId;
        }
        _currentTokenId = currentTokenId;

        emit BundleMinted(tokenIds, _args);
    }

    function claimRefund() external {
        uint256 refundAmount = valueToReturn[msg.sender];
        if (refundAmount == 0) {
            revert NoRefundAvailable();
        }
        valueToReturn[msg.sender] = 0;
        lockedFunds -= refundAmount;
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        if (!success) {
            revert ValueTransferFailed();
        }
    }

    /******************** UTILS ********************/

    function _handleChecksAndNonce(
        uint256 _nonce,
        uint256 _blockDeadline,
        address _payToken
    ) private {
        if (usedNonces[_nonce]) {
            revert InvalidNonce();
        }
        if (_blockDeadline < block.number) {
            revert SigExpired();
        }
        if (!eligibleTokens[_payToken]) {
            revert InaligiblePayToken();
        }
        usedNonces[_nonce] = true;
    }

    function _transfer(
        uint256 _amount,
        address _payToken,
        uint256 _nftPrice // ethers.utils.parseEther("1");
    ) internal {
        if (_payToken == address(0)) {
            (, int256 answer, , , ) = bnbUSDFeed.latestRoundData();

            uint256 bnbPrice = ((_nftPrice * 10 ** 8) * _amount) /
                uint256(answer);

            if (msg.value < bnbPrice) {
                revert NotEnoughValue();
            }

            (bool success, ) = payable(dao).call{
                value: (bnbPrice * daoSharePercentage) / PERCENTAGE_DENOMINATOR
            }("");
            if (!success) {
                revert ValueTransferFailed();
            }

            (bool liquiditySuccess, ) = payable(liquidityReceiver).call{
                value: (bnbPrice * liquiditySharePercentage) /
                    PERCENTAGE_DENOMINATOR
            }("");
            if (!liquiditySuccess) {
                revert ValueTransferFailed();
            }
            if (msg.value > bnbPrice) {
                uint256 amount = msg.value - bnbPrice;
                lockedFunds += amount;
                valueToReturn[msg.sender] += amount;
            }
        } else {
            if (msg.value != 0) {
                revert ValueSent();
            }
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                liquidityReceiver,
                ((liquiditySharePercentage * _nftPrice) /
                    PERCENTAGE_DENOMINATOR) * _amount
            );
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                dao,
                ((daoSharePercentage * _nftPrice) / PERCENTAGE_DENOMINATOR) *
                    _amount
            );
        }
    }

    function _transferWithReferral(
        uint256 _amount,
        address _payToken,
        uint256 _nftPrice,
        address _referral
    ) internal {
        if (_payToken == address(0)) {
            (, int256 answer, , , ) = bnbUSDFeed.latestRoundData();

            uint256 bnbPrice = ((_nftPrice * 10 ** 8) * _amount) /
                uint256(answer);
            if (msg.value < bnbPrice) {
                revert NotEnoughValue();
            }
            (bool success, ) = payable(dao).call{
                value: (bnbPrice * daoSharePercentage) / PERCENTAGE_DENOMINATOR
            }("");
            if (!success) {
                revert ValueTransferFailed();
            }
            (bool liquiditySuccess, ) = payable(liquidityReceiver).call{
                value: (bnbPrice * (liquiditySharePercentage - 5)) /
                    PERCENTAGE_DENOMINATOR
            }("");
            if (!liquiditySuccess) {
                revert ValueTransferFailed();
            }
            (bool referralSuccess, ) = payable(_referral).call{
                value: (bnbPrice * 5) / PERCENTAGE_DENOMINATOR
            }("");
            if (!referralSuccess) {
                revert ValueTransferFailed();
            }
            if (msg.value > bnbPrice) {
                uint256 amount = msg.value - bnbPrice;
                lockedFunds += amount;
                valueToReturn[msg.sender] += amount;
            }
        } else {
            if (msg.value != 0) {
                revert ValueSent();
            }
            if (liquiditySharePercentage >= REFFERAL_SHARE) {
                IERC20(_payToken).safeTransferFrom(
                    msg.sender,
                    liquidityReceiver,
                    (((liquiditySharePercentage - REFFERAL_SHARE) * _nftPrice) /
                        PERCENTAGE_DENOMINATOR) * _amount
                );
            }
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                dao,
                ((daoSharePercentage * _nftPrice) / PERCENTAGE_DENOMINATOR) *
                    _amount
            );
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                _referral,
                ((REFFERAL_SHARE * _nftPrice) / PERCENTAGE_DENOMINATOR) *
                    _amount
            );
        }
    }

    /******************** VIEW FUNCTIONS ********************/

    function getAllTokensByOwner(
        address account
    ) external view returns (uint256[] memory) {
        uint256 length = balanceOf(account);
        uint256[] memory result = new uint256[](length);
        for (uint i = 0; i < length; i++)
            result[i] = tokenOfOwnerByIndex(account, i);
        return result;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /******************** ADMIN FUNCTIONS & EVENTS ********************/

    /**
    @dev updates address of bnb oracle
     */
    function updatePriceFeed(
        address _newPriceFeed
    ) external validAddress(_newPriceFeed) onlyRole(ADMIN) {
        bnbUSDFeed = AggregatorV3Interface(_newPriceFeed);
        emit PriceFeedUpdated(_newPriceFeed);
    }

    /**
    @dev updates addresses of mint payments receivers
     */
    function setReceivers(
        address _dao,
        address _liquidity
    ) external onlyRole(ADMIN) {
        if (_dao == address(0) || _liquidity == address(0)) {
            revert InvalidAddress();
        }
        dao = _dao;
        liquidityReceiver = _liquidity;
        emit NewReceiversSet(_dao, _liquidity);
    }

    /**
    @dev updates token status. Tokens with status "true" can be used as payment tokens durin minting functions
     */
    function setPayTokenStatus(
        address _payToken,
        bool _status
    ) external onlyRole(ADMIN) {
        eligibleTokens[_payToken] = _status;
        emit PayTokenStatusUpdated(_payToken, _status);
    }

    /**
    @dev updates payment split percentages
     */
    function setShare(
        uint256 _liquidityShare,
        uint256 _daoShare
    ) external onlyRole(ADMIN) {
        if (
            _liquidityShare + _daoShare != 100 ||
            _liquidityShare < REFFERAL_SHARE
        ) {
            revert InvalidPercentages();
        }
        liquiditySharePercentage = _liquidityShare;
        daoSharePercentage = _daoShare;

        emit NewSharesSet(_liquidityShare, _daoShare);
    }

    function setBaseURI(string memory _newURI) external onlyRole(ADMIN) {
        baseURI = _newURI;

        emit BaseURISet(_newURI);
    }

    /**
    @dev let's ADMIN to withdraw any kind of token including both native and ERC20 tokens
     */
    function withdrawOwner(address _token) external onlyRole(ADMIN) {
        if (_token == address(0)) {
            (bool liquiditySuccess, ) = payable(msg.sender).call{
                value: address(this).balance - lockedFunds
            }("");
            if (!liquiditySuccess) {
                revert ValueTransferFailed();
            }
        } else {
            IERC20(_token).safeTransfer(
                msg.sender,
                IERC20(_token).balanceOf(address(this))
            );
        }
    }

    /**
    @dev sets address of the wallet that signs a message required in mint() and bundleMint()
     */
    function setAuthorizer(
        address _authorizer
    ) external onlyRole(ADMIN) validAddress(_authorizer) {
        authorizer = _authorizer;
        emit NewAuthorizerSet(authorizer);
    }
}
