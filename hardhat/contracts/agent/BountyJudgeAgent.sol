// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILLMPrecompile {
    function requestInference(
        string calldata model,
        string calldata prompt,
        uint256 maxTokens
    ) external returns (bytes32 requestId);
}

interface IScheduler {
    function schedule(
        address target,
        bytes calldata data,
        uint256 intervalBlocks
    ) external returns (bytes32 jobId);
}

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;
}

contract BountyJudgeAgent {
    address constant LLM = 0x0000000000000000000000000000000000000802;
    address constant SCHEDULER = 0x0000000000000000000000000000000000000820;
    address constant RITUAL_WALLET = 0x0000000000000000000000000000000000000810;

    address public owner;
    uint256 public bountyCount;

    struct Bounty {
        string title;
        string rubric;
        uint256 reward;
        uint256 deadline;
        bool finalized;
        address winner;
    }

    struct Submission {
        address submitter;
        string content;
        uint256 score;
    }

    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => Submission[]) public submissions;
    mapping(bytes32 => uint256) public requestToBounty;

    event BountyCreated(uint256 indexed id, string title, uint256 reward);
    event SubmissionAdded(uint256 indexed bountyId, address submitter);
    event WinnerSelected(uint256 indexed bountyId, address winner, uint256 reward);
    event AgentSpawned(address indexed agent, address indexed owner);

    constructor() payable {
        owner = msg.sender;
        if (msg.value > 0) {
            IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(30 days);
        }
        emit AgentSpawned(address(this), msg.sender);
    }

    function createBounty(
        string calldata title,
        string calldata rubric,
        uint256 deadline
    ) external payable returns (uint256) {
        require(msg.value > 0, "Reward required");
        uint256 id = bountyCount++;
        bounties[id] = Bounty(title, rubric, msg.value, deadline, false, address(0));
        emit BountyCreated(id, title, msg.value);
        return id;
    }

    function submitAnswer(uint256 bountyId, string calldata content) external {
        Bounty storage b = bounties[bountyId];
        require(!b.finalized, "Bounty finalized");
        require(block.timestamp < b.deadline, "Deadline passed");
        submissions[bountyId].push(Submission(msg.sender, content, 0));
        emit SubmissionAdded(bountyId, msg.sender);
    }

    function judgeAndFinalize(uint256 bountyId) external {
        Bounty storage b = bounties[bountyId];
        require(!b.finalized, "Already finalized");
        require(block.timestamp >= b.deadline, "Not yet due");
        require(submissions[bountyId].length > 0, "No submissions");

        string memory prompt = buildJudgePrompt(bountyId);
        bytes32 reqId = ILLMPrecompile(LLM).requestInference(
            "llama-3.1-8b",
            prompt,
            256
        );
        requestToBounty[reqId] = bountyId;
    }

    function buildJudgePrompt(uint256 bountyId) internal view returns (string memory) {
        Bounty storage b = bounties[bountyId];
        return string(abi.encodePacked(
            "You are judging a bounty. Title: ", b.title,
            ". Rubric: ", b.rubric,
            ". Reply with only the index number (0-based) of the best submission."
        ));
    }

    function onResult(bytes32 requestId, bytes calldata result) external {
        uint256 bountyId = requestToBounty[requestId];
        Bounty storage b = bounties[bountyId];
        require(!b.finalized, "Already finalized");

        uint256 winnerIndex = uint256(bytes32(result)) % submissions[bountyId].length;
        address winner = submissions[bountyId][winnerIndex].submitter;

        b.finalized = true;
        b.winner = winner;

        (bool sent,) = winner.call{value: b.reward}("");
        require(sent, "Transfer failed");
        emit WinnerSelected(bountyId, winner, b.reward);
    }

    receive() external payable {}
}
