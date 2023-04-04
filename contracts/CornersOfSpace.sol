// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@1inch/solidity-utils/contracts/libraries/ECDSA.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error InvalidPercentages();
error InvalidAddress();
error UnauthorizedTx();
error InvalidNonce();
error NotEnoughValue();
error ValueTransferFailed();
error PriceChanged();
error InvalidTokenAmount();
error SigExpired();

contract CornersOfSpace is ERC721Enumerable, AccessControl {
    using SafeERC20 for IERC20;
    // Token Address -> isEligible: true for eligible; false for inelgibile
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
    address public verifier;

    uint256 private _currentTokenId;
    string private baseURI;

    uint256 public daoSharePercentage; // 0-100 value
    uint256 public liquiditySharePercentage; // 0-100 value

    mapping(uint256 => bool) public usedNonces;

    /******************** EVENTS ********************/

    event AssetMinted(uint256 _tokenId, string args);
    event BundleMinted(uint256[] _tokenIds, string args);

    /******************** CONSTRUCTOR ********************/

    constructor(
        address _admin,
        address _adminController,
        address _verifier,
        AggregatorV3Interface _priceFeed,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC721(_name, _symbol) {
        _setupRole(ULTIMATE_ADMIN, _adminController);
        _setRoleAdmin(ADMIN, ULTIMATE_ADMIN);
        _setupRole(ADMIN, _admin);

        baseURI = _uri;
        verifier = _verifier;
        bnbUSDFeed = _priceFeed;
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
    @param _sig signature signed by verifier
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
    ) public payable {
        _handleNonce(_nonce);
        if (_blockDeadline < block.number) {
            revert SigExpired();
        }

        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _free,
                    _nftPrice,
                    _payToken,
                    _nonce,
                    _blockDeadline,
                    _args,
                    _referral
                )
            )
        );
        if (ECDSA.recover(message, _sig) != verifier) {
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
    @param _sig signature signed by verifier
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
        _handleNonce(_nonce);
        if (_blockDeadline < block.number) {
            revert SigExpired();
        }

        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _free,
                    _nftPrice,
                    _payToken,
                    _nonce,
                    _blockDeadline,
                    _args,
                    _tokenAmount,
                    _referral
                )
            )
        );
        if (ECDSA.recover(message, _sig) != verifier) {
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
        for (uint i; i < _tokenAmount; i++) {
            uint256 newTokenId = _currentTokenId + 1;
            _currentTokenId++;
            _safeMint(msg.sender, newTokenId);
            tokenIds[i] = newTokenId;
        }

        if (_tokenAmount == 0) {
            revert InvalidTokenAmount();
        }
        emit BundleMinted(tokenIds, _args);
    }

    /******************** UTILS ********************/

    function _handleNonce(uint256 _nonce) private {
        if (usedNonces[_nonce]) {
            revert InvalidNonce();
        }
        usedNonces[_nonce] = true;
    }

    function _transfer(
        uint256 _amount,
        address _payToken,
        uint256 _nftPrice
    ) internal {
        if (_payToken == address(0)) {
            (, int256 answer, , , ) = bnbUSDFeed.latestRoundData();
            uint256 bnbPrice = ((_nftPrice * _amount) / uint256(answer));
            if (msg.value < bnbPrice) {
                revert NotEnoughValue();
            }
            require(msg.value >= _amount, "not enough value");
            (bool success, ) = payable(dao).call{
                value: (bnbPrice * daoSharePercentage) / 100
            }("");
            if (!success) {
                revert ValueTransferFailed();
            }
            (bool liquiditySuccess, ) = payable(liquidityReceiver).call{
                value: (bnbPrice * liquiditySharePercentage) / 100
            }("");
            if (!liquiditySuccess) {
                revert ValueTransferFailed();
            }
        } else {
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                liquidityReceiver,
                ((liquiditySharePercentage * _nftPrice) / 100) * _amount
            );
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                dao,
                ((daoSharePercentage * _nftPrice) / 100) * _amount
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
            uint256 bnbPrice = ((_nftPrice * _amount) / uint256(answer));
            if (msg.value < bnbPrice) {
                revert NotEnoughValue();
            }
            require(msg.value >= _amount, "not enough value");
            (bool success, ) = payable(dao).call{
                value: (bnbPrice * daoSharePercentage) / 100
            }("");
            if (!success) {
                revert ValueTransferFailed();
            }
            (bool liquiditySuccess, ) = payable(liquidityReceiver).call{
                value: (bnbPrice * (liquiditySharePercentage - 5)) / 100
            }("");
            if (!liquiditySuccess) {
                revert ValueTransferFailed();
            }
            (bool referralSuccess, ) = payable(_referral).call{
                value: (bnbPrice * 5) / 100
            }("");
            if (!referralSuccess) {
                revert ValueTransferFailed();
            }
        } else {
            if (liquiditySharePercentage >= 5) {
                IERC20(_payToken).safeTransferFrom(
                    msg.sender,
                    liquidityReceiver,
                    (((liquiditySharePercentage - 5) * _nftPrice) / 100) *
                        _amount
                );
            }
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                dao,
                ((daoSharePercentage * _nftPrice) / 100) * _amount
            );
            IERC20(_payToken).safeTransferFrom(
                msg.sender,
                _referral,
                ((5 * _nftPrice) / 100) * _amount
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

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
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

    /******************** MODIFIERS ********************/

    modifier validAddress(address _addr) {
        if (_addr == address(0)) {
            revert InvalidAddress();
        }
        _;
    }

    /******************** ADMIN FUNCTIONS & EVENTS ********************/

    event PriceFeedUpdated(address newPriceFeed);

    /**
    @dev updates address of bnb oracle
     */
    function updatePriceFeed(
        address _newPriceFeed
    ) external validAddress(_newPriceFeed) onlyRole(ADMIN) {
        bnbUSDFeed = AggregatorV3Interface(_newPriceFeed);
        emit PriceFeedUpdated(_newPriceFeed);
    }

    event NewReceiversSet(address newDao, address liquidity);

    /**
    @dev updates addresses of mint payments receivers
     */
    function setReceivers(
        address _dao,
        address _liquidity
    ) external onlyRole(ADMIN) {
        dao = _dao;
        liquidityReceiver = _liquidity;
        emit NewReceiversSet(_dao, _liquidity);
    }

    event PayTokenStatusUpdated(address payToken, bool status);

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

    event NewSharesSet(uint256 newLiquidityShare, uint256 newDaoShare);

    /**
    @dev updates payment split percentages
     */
    function setShare(
        uint256 _liquidityShare,
        uint256 _daoShare
    ) external onlyRole(ADMIN) {
        if (_liquidityShare + _daoShare != 100) {
            revert InvalidPercentages();
        }
        liquiditySharePercentage = _liquidityShare;
        daoSharePercentage = _daoShare;

        emit NewSharesSet(_liquidityShare, _daoShare);
    }

    event BaseURISet(string newURI);

    function setBaseURI(string memory _newURI) public onlyRole(ADMIN) {
        baseURI = _newURI;

        emit BaseURISet(_newURI);
    }

    /**
    @dev let's ADMIN to withdraw any kind of token including both native and ERC20 tokens
     */
    function withdrawOwner(address _token) public onlyRole(ADMIN) {
        if (_token == address(0)) {
            (bool liquiditySuccess, ) = payable(msg.sender).call{
                value: address(this).balance
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

    event NewVerifierSet(address verifier);

    /**
    @dev sets address of the wallet that signs a message required in mint() and bundleMint()
     */
    function setVerifier(
        address _verifier
    ) external onlyRole(ADMIN) validAddress(_verifier) {
        verifier = _verifier;
        emit NewVerifierSet(verifier);
    }
}
