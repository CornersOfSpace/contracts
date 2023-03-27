// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@1inch/solidity-utils/contracts/libraries/ECDSA.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error ZeroAmount();
error InvalidPercentages();
error ZeroCount();
error InvalidAddress();
error UnauthorisedTx();
error InvalidNonce();
error PriceNotSet();
error MintLimitted();
error NotEnoughValue();
error NotTokenOwner();
error ValueTransferFailed();
error RaceFailed();
error PriceChanged();

contract CornersOfSpace is ERC721Enumerable, AccessControl {
    using SafeERC20 for IERC20;
    // Token Address -> isEligible: true for eligible; false for inelgibile
    mapping(address => bool) eligibleTokens;

    // Wallet that receives liquidity before sending them to dex, to support erc20 token
    address private liquidityReceiver;
    // DAO wallet
    address private dao;

    // ChainLink USD-BNB price feed
    AggregatorV3Interface bnbUSDFeed;

    //TODO: Discuss if other roles are needed
    bytes32 internal constant ADMIN = keccak256("ADMIN");
    bytes32 internal constant ULTIMATE_ADMIN = keccak256("ULTIMATE_ADMIN");
    // DAO application backend
    address private verifier;

    uint256 private _currentTokenId;
    string private baseURI;

    uint256 public daoSharePercentage; // 0-100 value
    uint256 public liquiditySharePercentage; // 0-100 value

    uint256 public usdPrice; // 18 decimal value

    mapping(uint256 => bool) private usedNonces;

    /******************** EVENTS ********************/

    event AssetMinted(address indexed creator, uint256 _tokenId, string args);

    /******************** CONSTRUCTOR ********************/

    constructor(
        address _admin,
        address _adminController,
        address _verifier,
        AggregatorV3Interface _priceFeed,
        uint256 _usdPrice,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC721(_name, _symbol) {
        _setupRole(ULTIMATE_ADMIN, _adminController);
        _setRoleAdmin(ADMIN, ULTIMATE_ADMIN);
        _setupRole(ADMIN, _admin);

        usdPrice = _usdPrice;
        baseURI = _uri;
        verifier = _verifier;
        bnbUSDFeed = _priceFeed;
    }

    /******************** BASE ERC721 OVERRIDE FUNCTIONS ********************/

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            // Keeping default error to ensure consistency and avoid frontend bugs
            "ERC721Metadata: URI query for nonexistent token"
        );

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId))
                : "";
    }

    /******************** MINTING FUNCTIONS ********************/
    function mint(
        bool _free,
        address _payToken,
        uint256 _nftPrice,
        uint256 _nonce,
        bytes calldata _sig,
        string calldata _args // 20 symbols max
    ) public payable {
        _handleNonce(_nonce);

        bytes32 message = prefixed(
            keccak256(abi.encodePacked(_free, _nftPrice, _nonce, _args))
        );
        if (ECDSA.recover(message, _sig) != verifier) {
            revert UnauthorisedTx();
        }

        if (!_free) {
            _transfer(msg.sender, 1, _payToken);
        }

        uint256 newTokenId = _currentTokenId + 1;
        _safeMint(msg.sender, newTokenId);
        _currentTokenId++;

        if (_nftPrice != usdPrice) {
            revert PriceChanged();
        }

        emit AssetMinted(msg.sender, newTokenId, _args);
    }

    function bundleMint(
        bool _free,
        address _payToken,
        uint256 _nftPrice,
        uint256 _nonce,
        bytes calldata _sig,
        string calldata _args, // 20 symbols max
        uint256 _tokenAmount
    ) external payable {
        _handleNonce(_nonce);

        bytes32 message = prefixed(
            keccak256(
                abi.encodePacked(_free, _nftPrice, _nonce, _args, _tokenAmount)
            )
        );
        if (ECDSA.recover(message, _sig) != verifier) {
            revert UnauthorisedTx();
        }
        if (!_free) {
            _transfer(msg.sender, _tokenAmount, _payToken);
        }
        for (uint i; i < _tokenAmount; i++) {
            uint256 newTokenId = _currentTokenId + 1;
            _safeMint(msg.sender, newTokenId);
            _currentTokenId++;
            emit AssetMinted(msg.sender, newTokenId, _args);
        }
        if (_nftPrice != usdPrice) {
            revert PriceChanged();
        }
    }

    /******************** UTILS ********************/

    function _handleNonce(uint256 _nonce) private {
        if (usedNonces[_nonce]) {
            revert InvalidNonce();
        }
        usedNonces[_nonce] = true;
    }

    function _transfer(
        address _from,
        uint256 _amount,
        address _payToken
    ) internal {
        if (_payToken == address(0)) {
            (, int256 answer, , , ) = bnbUSDFeed.latestRoundData();
            uint256 bnbPrice = ((usdPrice * _amount) / uint256(answer));
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
                _from,
                liquidityReceiver,
                ((liquiditySharePercentage * usdPrice) / 100) * _amount
            );
            IERC20(_payToken).safeTransferFrom(
                _from,
                dao,
                ((daoSharePercentage * usdPrice) / 100) * _amount
            );
        }
    }

    /******************** VIEW FUNCTIONS ********************/

    //TODO: Is that needed
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

    function updatePriceFeed(
        address _newPriceFeed
    ) external validAddress(_newPriceFeed) {
        bnbUSDFeed = AggregatorV3Interface(_newPriceFeed);
        emit PriceFeedUpdated(_newPriceFeed);
    }

    event NewNFTPriceSet(uint256 newPrice);

    function setUsdPrice(uint256 _newPrice) external {
        usdPrice = _newPrice;
        emit NewNFTPriceSet(_newPrice);
    }

    event NewReceiversSet(address newDao, address liquidity);

    function setReceivers(
        address _dao,
        address _liquidity
    ) external onlyRole(ADMIN) {
        dao = _dao;
        liquidityReceiver = _liquidity;
        emit NewReceiversSet(_dao, _liquidity);
    }

    event PayTokenStatusUpdated(address payToken, bool status);

    function setPayTokenStatus(
        address _payToken,
        bool _status
    ) external onlyRole(ADMIN) {
        eligibleTokens[_payToken] = _status;
        emit PayTokenStatusUpdated(_payToken, _status);
    }

    event NewSharesSet(uint256 newLiquidityShare, uint256 newDaoShare);

    function setShare(uint256 _liquidityShare, uint256 _daoShare) external {
        if (_liquidityShare + _daoShare != 100) {
            revert InvalidPercentages();
        }
        liquiditySharePercentage = _liquidityShare;
        daoSharePercentage = _daoShare;

        emit NewSharesSet(_liquidityShare, _daoShare);
    }

    event NewBaseURISet(string newURI);

    function setBaseURI(string memory _newURI) public onlyRole(ADMIN) {
        baseURI = _newURI;
        emit NewBaseURISet(_newURI);
    }

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

    function setVerifier(
        address _verifier
    ) external onlyRole(ADMIN) validAddress(_verifier) {
        verifier = _verifier;
        emit NewVerifierSet(verifier);
    }
}
