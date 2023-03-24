// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@1inch/solidity-utils/contracts/libraries/ECDSA.sol";

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

contract CornersOfSpace is ERC721Enumerable, AccessControl {
    using SafeERC20 for IERC20;
    // Token Address -> isEligible
    mapping(address => bool) eligibleTokens;

    address private liquidityReceiver;
    address private dao;

    //TODO: Discuss if other roles are needed
    bytes32 internal constant ADMIN = keccak256("ADMIN");
    bytes32 internal constant ULTIMATE_ADMIN = keccak256("ULTIMATE_ADMIN");
    address internal verifier;

    uint256 private _currentTokenId;
    string private baseURI;

    //TODO: Add setters
    uint256 public daoUSDShare;
    uint256 public daoBNBShare;

    //TODO: Add setters
    uint256 public liquidityUSDShare;
    uint256 public liquidityBNBShare;

    mapping(address => uint256[]) private lastCreate;
    mapping(uint256 => bool) private lockedToken;
    mapping(uint256 => bool) private usedNonces;

    /******************** EVENTS ********************/

    event AssetMinted(address indexed creator, uint256 _tokenId, string args);
    event ChangeStateToken(
        address indexed owner,
        uint256 _tokenId,
        bool _state
    );

    /******************** CONSTRUCTOR ********************/

    constructor(
        address _admin,
        address _adminController,
        address _verifier,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC721(_name, _symbol) {
        _setupRole(ULTIMATE_ADMIN, _adminController);
        _setRoleAdmin(ADMIN, ULTIMATE_ADMIN);
        _setupRole(ADMIN, _admin);

        baseURI = _uri;
        verifier = _verifier;
    }

    /******************** BASE ERC721 FUNCTIONS ********************/

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

    /******************** MINTING "CREATE" FUNCTIONS ********************/
    function mint(
        bool _free,
        address _payToken,
        string calldata _args,
        uint256 _nonce,
        bytes calldata _sig
    ) public payable {
        bytes32 message = prefixed(
            keccak256(abi.encodePacked(_free, _nonce, address(this), _args))
        );
        if (ECDSA.recover(message, _sig) != verifier) {
            revert UnauthorisedTx();
        }

        _handleNonce(_nonce);

        if (!_free) {
            _transfer(msg.sender, 1, _payToken);
        }

        uint256 newTokenId = _getNextTokenId();
        _safeMint(msg.sender, newTokenId);
        _incrementTokenId();

        emit AssetMinted(msg.sender, newTokenId, _args);
    }

    function bundleMint(
        bool _free,
        address _payToken,
        string calldata _args,
        uint256 _nonce,
        bytes calldata _sig,
        uint256 _tokenAmount
    ) external payable {
        bytes32 message = prefixed(
            keccak256(abi.encodePacked(_free, _nonce, address(this), _args))
        );
        if (ECDSA.recover(message, _sig) != verifier) {
            revert UnauthorisedTx();
        }

        for (uint i; i < _tokenAmount; i++) {
            uint256 newTokenId = _getNextTokenId();
            _safeMint(msg.sender, newTokenId);
            _incrementTokenId();
            emit AssetMinted(msg.sender, newTokenId, _args);
        }
        if (!_free) {
            _transfer(msg.sender, _tokenAmount, _payToken);
        }
    }

    /******************** UTILS ********************/

    function _handleNonce(uint256 _nonce) private {
        if (usedNonces[_nonce]) {
            revert InvalidNonce();
        }
        usedNonces[_nonce] = true;
    }

    function _incrementTokenId() private {
        _currentTokenId++;
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

    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId + 1;
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

    /******************** ADMIN FUNCTIONS ********************/

    function _transfer(
        address _from,
        uint256 _amount,
        address _payToken
    ) internal {
        if (_payToken == address(0)) {
            if (msg.value < _amount) {
                revert NotEnoughValue();
            }
            require(msg.value >= _amount, "not enough value");
            (bool success, ) = payable(dao).call{value: daoBNBShare * _amount}(
                ""
            );
            if (!success) {
                revert ValueTransferFailed();
            }
            (bool liquiditySuccess, ) = payable(liquidityReceiver).call{
                value: liquidityBNBShare * _amount
            }("");
            if (!liquiditySuccess) {
                revert ValueTransferFailed();
            }
        } else {
            IERC20(_payToken).safeTransferFrom(
                _from,
                liquidityReceiver,
                liquidityUSDShare * _amount
            );
            IERC20(_payToken).safeTransferFrom(
                _from,
                dao,
                daoUSDShare * _amount
            );
        }
    }

    function setReceivers(
        address _dao,
        address _liquidity
    ) external onlyRole(ADMIN) {
        dao = _dao;
        liquidityReceiver = _liquidity;
    }

    function setPayTokenStatus(
        address _token,
        bool _status
    ) external onlyRole(ADMIN) {
        eligibleTokens[_token] = _status;
    }

    function setBaseURI(string memory _newURI) public onlyRole(ADMIN) {
        baseURI = _newURI;
    }

    //TODO: adjust to withdraw any erc20 and native tokens
    function withdrawOwner() public onlyRole(ADMIN) {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setVerifier(
        address _verifier
    ) external onlyRole(ADMIN) validAddress(_verifier) {
        verifier = _verifier;
    }
}
