// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../utils/with-dtn-ai.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../utils/dtn-defaults.sol";
import "hardhat/console.sol";

contract CallAiExample is WithDtnAi {
    using SafeERC20 for IERC20;
    event Request(bytes32 requestId, string[] prompt_lines, bytes extraParams);
    event Result(bytes32 requestId, IDtnAi.ResponseStatus status, string message, string result);
    event Error(bytes32 requestId);

    string public result;
    string public error;
    uint256 public sessionId;
    bytes32 public requestId;
    string public ipfsCid;
    
    constructor(address ai) {
        setAi(ai);
    }

    function doCallAi(string memory prompt, string memory node, string memory model) public payable {
        string[] memory prompt_lines = new string[](2);
        prompt_lines[0] = "This is metadata - {0:uint8} and {1:address} -. Ignore the metadata and answer the next question:";
        prompt_lines[1] = prompt;
        bytes memory extraParams = abi.encode(26, address(this)); // These are the extra parmeters to the prompt's line[0]
        doCallAiDetailed(prompt_lines, extraParams, node, model);
    }

    function doCallAiDetailed(string[] memory prompt_lines, bytes memory extraParamsEncoded, string memory node, string memory model) public payable {
        if (sessionId == 0) {
            restartSession();
        }
        requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)), // the model ID
            DtnDefaults.defaultCustomNodesValidatedAny(DtnDefaults.singleArray(keccak256(abi.encodePacked(node)))),
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines),
                extraParams: extraParamsEncoded,
                calltype: IDtnAi.CallType.DIRECT, 
                feePerByteReq: 5, // USDC has 6 digits
                feePerByteRes: 5,
                totalFeePerRes: 1000000 // 1 USDC
            }),
            IDtnAi.CallBack(
                this.callback.selector,
                this.aiError.selector,
                address(this)
            ),
            msg.sender, 
            msg.value
        );
        emit Request(requestId, prompt_lines, extraParamsEncoded);
    }

    function doCallAiImage(
        string[] memory prompt_lines, bytes memory extraParamsEncoded, string memory node, string memory model, uint64 width, uint64 height
        ) public payable {
        if (sessionId == 0) {
            restartSession();
        }
        requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)), // the model ID
            DtnDefaults.defaultCustomNodesValidatedAny(DtnDefaults.singleArray(keccak256(abi.encodePacked(node)))),
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines, width, height),
                extraParams: extraParamsEncoded,
                calltype: IDtnAi.CallType.IPFS, 
                feePerByteReq: 1, // USDC has 6 digits
                feePerByteRes: 1,
                totalFeePerRes: 1000000 // 1 USDC
            }),
            IDtnAi.CallBack(
                this.callbackIpfs.selector,
                this.aiError.selector,
                address(this)
            ),
            msg.sender, 
            msg.value
        );
        emit Request(requestId, prompt_lines, extraParamsEncoded);
    }

    function restartSession() public {
        if (sessionId != 0) {
            ai.closeUserSession(sessionId);
        }
        uint amount = IERC20(ai.feeToken()).balanceOf(address(this)); // Use what we have to start a session
        require(amount > 0, "Not enough tokens to start a session");
        IERC20( ai.feeToken() ).safeTransfer(ai.feeTarget(), amount);
        sessionId = ai.startUserSession();
    }

    function callback(bytes32 _requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);
        result = abi.decode(response, (string));
        emit Result(_requestId, status, message, result);
    }

    function callbackIpfs(bytes32 _requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);
        ipfsCid = abi.decode(response, (string));
        emit Result(_requestId, status, message, ipfsCid);
    }

    function aiError(bytes32 _requestId) external onlyDtn {
        (, string memory message, ) = ai.fetchResponse(_requestId);
        error = message;
        emit Error(_requestId);
    }
}