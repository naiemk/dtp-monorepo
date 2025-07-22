// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../utils/with-dtn-ai.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../utils/dtn-defaults.sol";
import "hardhat/console.sol";

contract CallAiExample is WithDtnAi {
    using SafeERC20 for IERC20;
    event Request(bytes32 requestId, string prompt);
    event Result(bytes32 requestId, IDtnAi.ResponseStatus status, string message, string result);
    event Error(bytes32 requestId);

    string public result;
    string public error;
    uint256 public sessionId;
    bytes32 public requestId;
    
    constructor(address ai) {
        setAi(ai);
    }

    function doCallAi(string memory prompt, string memory node, string memory model) public payable {
        if (sessionId == 0) {
            uint amount = 1*10**18;
            IERC20( ai.feeToken() ).safeTransferFrom(
            msg.sender, ai.feeTarget(), amount);
            sessionId = ai.startUserSession();
        }

        string[] memory prompt_lines = new string[](2);
        prompt_lines[0] = "text {0:uint8} and {1:address}";
        prompt_lines[1] = prompt;
        bytes memory extraParams = abi.encode(12, address(this)); // These are the extra parmeters to the prompt's line[0]

        requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)), // the model ID
            DtnDefaults.defaultCustomNodesValidatedAny(DtnDefaults.singleArray(keccak256(abi.encodePacked(node)))),
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines),
                extraParams: extraParams,
                calltype: IDtnAi.CallType.DIRECT, 
                feePerByteReq: 0.001 * 10**18,
                feePerByteRes: 0.001 * 10**18,
                totalFeePerRes: 1 * 10**18
            }),
            IDtnAi.CallBack(
                this.callback.selector,
                this.aiError.selector,
                address(this)
            ),
            msg.sender, 
            msg.value
        );
        emit Request(requestId, prompt);
    }

    function callback(bytes32 _requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);
        result = abi.decode(response, (string));
        emit Result(_requestId, status, message, result);
    }

    function aiError(bytes32 _requestId) external onlyDtn {
        (, string memory message, ) = ai.fetchResponse(_requestId);
        error = message;
        emit Error(_requestId);
    }
}