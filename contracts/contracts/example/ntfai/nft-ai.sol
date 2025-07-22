// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../core/multiowner-base.sol";
import "../../utils/dtn-defaults.sol";
import "../../utils/with-dtn-ai-upgradeable.sol";

/**
 * @title NftAi
 * @notice NftAi is an example project to use DtnAi to create an nft
 * First we ask AI to create an image based on a prompt
 * Then we ask AI to create nft metadata based on the image
 * Then we mint an nft with the metadata
 */

contract NftAi is
    WithDtnAiUpgradeable,
    OwnableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable {
    uint256 public constant CREATE_IMAGE_CALLBACK_GAS = 10_000;
    uint256 public constant CREATE_METADATA_CALLBACK_GAS = 10_000;
    uint256 public sessionId;
    uint256 public minPrice;
    string public createImagePrompt;
    string public createNftMetadataPrompt;
    mapping(bytes32 => address) public requestIdToNftOwner;

    // Rate limiting
    uint256 public constant RATE_LIMIT_INTERVAL = 1 hours;
    uint256 public constant MAX_PURCHASES_PER_INTERVAL = 5;
    mapping(address => uint256) public lastPurchaseTime;
    mapping(address => uint256) public purchasesInInterval;

    // Events
    event RequestSent(bytes32 indexed requestId);
    event AiError(bytes32 indexed requestId);
    event NFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        string prompt,
        string imageUri
    );
    event MinPriceUpdated(uint256 newPrice);
    event PurchaseAttempted(address indexed buyer, string prompt, uint256 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address router, 
        uint256 _minPrice
    ) public initializer {
        __ERC721_init("AI Generated NFT", "AINFT");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __WithDtnAi_init(router);
        minPrice = _minPrice;
    }

    function setPrompts(string calldata _createImagePrompt, string calldata _createNftPrompt) external onlyOwner {
        createImagePrompt = _createImagePrompt;
        createNftMetadataPrompt = _createNftPrompt;
    }

    function startSession(uint256 amount) external onlyOwner {
        // No need to transfer tokens here as it's handled in startUserSession
        sessionId = ai().startUserSession();
    }

    function closeSession() external onlyOwner {
        require(sessionId != 0, "No active session");
        ai().closeUserSession(sessionId);
        sessionId = 0;
    }

    function setMinPrice(uint256 _minPrice) external onlyOwner {
        minPrice = _minPrice;
        emit MinPriceUpdated(_minPrice);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function purchaseNft(string calldata userSubPrompt) external payable 
        nonReentrant 
        whenNotPaused 
    {
        // Input validation
        require(bytes(userSubPrompt).length > 0, "Empty prompt not allowed");
        require(bytes(userSubPrompt).length <= 1000, "Prompt too long");
        require(sessionId != 0, "No active session");
        require(msg.value >= minPrice, "Insufficient price");

        emit PurchaseAttempted(msg.sender, userSubPrompt, msg.value);

        // Get model ID from model manager
        bytes32 imageModelId = ai().modelId("system.models.openai.dall-e-3");
        
        bytes memory aiCall = abi.encode(
            "createImage",
            "640x640",
            createImagePrompt,
            "string",
            abi.encode(userSubPrompt)
        );

        IDtnAi.CallBack memory callback = IDtnAi.CallBack(
            this.createNftMetadataFromImage.selector,
            this.aiError.selector,
            address(this)
        );

        IDtnAi.DtnRequest memory dtnRequest = IDtnAi.DtnRequest({
            call: aiCall,
            calltype: IDtnAi.CallType.IPFS,
            feePerByteReq: 0,
            feePerByteRes: 0,
            totalFeePerRes: 0,
            extraParams: ""
        });
        bytes32 requestId = ai().request{value: CREATE_IMAGE_CALLBACK_GAS}(
            sessionId,
            imageModelId,
            DtnDefaults.defaultRoutingSystemValidatedAny(),
            dtnRequest,
            callback,
            msg.sender,
            CREATE_IMAGE_CALLBACK_GAS);
        
        emit RequestSent(requestId);
        requestIdToNftOwner[requestId] = msg.sender;
    }

    function createNftMetadataFromImage(bytes32 requestId) external onlyDtn {
        (,,bytes memory ipfsCid) = ai().fetchResponse(requestId);
        
        // Get model ID from model manager
        bytes32 metadataModelId = ai().modelId("system.models.openai.gpt-4");
        
        bytes memory aiCall = abi.encode(
            "text",
            createNftMetadataPrompt,
            "string",
            abi.encode(ipfsCid)
        );

        IDtnAi.CallBack memory callback = IDtnAi.CallBack(
            this.mintNft.selector,
            this.aiError.selector,
            address(this)
        );

        bytes32 nextRequestId = ai().request{value: CREATE_METADATA_CALLBACK_GAS}(
            sessionId,
            metadataModelId,
            DtnDefaults.defaultRoutingSystemValidatedAny(),
            IDtnAi.DtnRequest({ call: aiCall,
            calltype: IDtnAi.CallType.IPFS, feePerByteReq: 0, feePerByteRes: 0, totalFeePerRes: 0,
            extraParams: ""
             }),
            callback,
            msg.sender,
            CREATE_METADATA_CALLBACK_GAS
        );

        emit RequestSent(nextRequestId);
        requestIdToNftOwner[nextRequestId] = requestIdToNftOwner[requestId];
    }

    function mintNft(bytes32 requestId) external onlyDtn {
        // Given the nft metadata, mint an nft
        (,,bytes memory ipfsCid) = ai().fetchResponse(requestId);
        mintTokenFromJson(requestIdToNftOwner[requestId], abi.decode(ipfsCid, (string)));
    }

    function aiError(bytes32 requestId) external onlyDtn {
        // Handle ai error
        // TODO: Implement error handling
        emit AiError(requestId);
    }

    function mintTokenFromJson(
        address to,
        string memory ipfsCid
    ) internal
    {
        uint256 newTokenId = totalSupply() + 1;
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, string.concat("ipfs://", ipfsCid));
    }

    function mintWithAI(
        string memory prompt,
        address to,
        uint256 tokenId
    ) public payable {
        // Check if payment amount is correct
        require(msg.value >= minPrice, "Insufficient payment");
        
        // Ensure token ID hasn't been minted yet
        // require(!_exists(tokenId), "Token already exists");
        
        // Generate AI content based on prompt
        string memory imageUri = generateAIContent(prompt);
        
        // Mint the NFT
        _safeMint(to, tokenId);
        
        // Set the token URI with AI-generated content
        _setTokenURI(tokenId, imageUri);
        
        // Store prompt for future reference
        tokenPrompts[tokenId] = prompt;
        
        // Emit minting event
        emit NFTMinted(to, tokenId, prompt, imageUri);
    }

    function generateAIContent(string memory prompt) internal pure returns (string memory) {
        // This function would integrate with your AI service
        // For now, return a placeholder URI
        // In a real implementation, this would call an oracle or external service
        return string(abi.encodePacked("ipfs://ai-generated-content/", prompt));
    }

    // Mapping to store prompts for each token
    mapping(uint256 => string) public tokenPrompts;

    // Add withdrawal function for contract owner
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(
            ERC721Upgradeable, 
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable
        ) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    // Override required functions for compatibility
    function _update(address to, uint256 tokenId, address auth) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, amount);
    }
}
