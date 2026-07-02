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

contract GoldSignalAgent {
    address constant LLM = 0x0000000000000000000000000000000000000802;
    address constant SCHEDULER = 0x0000000000000000000000000000000000000820;
    address constant RITUAL_WALLET = 0x0000000000000000000000000000000000000810;

    address public owner;
    uint256 public signalCount;

    struct Signal {
        uint256 timestamp;
        string goldPrice;
        string bias;
        string setupGrade;
        string entry;
        string stopLoss;
        string tp1;
        string tp2;
        string tp3;
        string waveCount;
        string rawAnalysis;
        bool fulfilled;
    }

    mapping(uint256 => Signal) public signals;
    mapping(bytes32 => uint256) public requestToSignal;

    event SignalRequested(uint256 indexed signalId, bytes32 requestId, string goldPrice);
    event SignalGenerated(
        uint256 indexed signalId,
        string bias,
        string setupGrade,
        string entry,
        string stopLoss,
        string waveCount
    );
    event AgentSpawned(address indexed agent, address indexed owner);

    constructor() payable {
        owner = msg.sender;
        if (msg.value > 0) {
            IRitualWallet(RITUAL_WALLET).deposit{value: msg.value}(30 days);
        }
        emit AgentSpawned(address(this), msg.sender);
    }

    function requestSignal(string calldata goldPrice) external returns (uint256) {
        uint256 id = signalCount++;
        signals[id] = Signal({
            timestamp: block.timestamp,
            goldPrice: goldPrice,
            bias: "",
            setupGrade: "",
            entry: "",
            stopLoss: "",
            tp1: "",
            tp2: "",
            tp3: "",
            waveCount: "",
            rawAnalysis: "",
            fulfilled: false
        });

        string memory prompt = buildPrompt(goldPrice);
        bytes32 reqId = ILLMPrecompile(LLM).requestInference(
            "llama-3.1-8b",
            prompt,
            512
        );

        requestToSignal[reqId] = id;
        emit SignalRequested(id, reqId, goldPrice);
        return id;
    }

    function buildPrompt(string memory goldPrice) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "You are an Elliott Wave + SMC expert analyzing XAU/USD. ",
            "Current gold price: $", goldPrice, ". ",
            "Apply strict Elliott Wave rules: motive waves (1,3,5) subdivide into 5, ",
            "corrective waves (2,4) subdivide into 3. Wave 2 never retraces beyond wave 1 start. ",
            "Wave 3 is never the shortest. Wave 4 never overlaps wave 1 territory. ",
            "Reply in this exact format only: ",
            "GRADE:A|BIAS:Bullish|WAVE:3of5|ENTRY:2650|SL:2620|TP1:2700|TP2:2750|TP3:2800"
        ));
    }

    function onResult(bytes32 requestId, bytes calldata result) external {
        uint256 signalId = requestToSignal[requestId];
        Signal storage s = signals[signalId];
        require(!s.fulfilled, "Already fulfilled");

        string memory raw = string(result);
        s.rawAnalysis = raw;
        s.fulfilled = true;

        // Parse the structured response
        s.setupGrade = _extract(raw, "GRADE:");
        s.bias = _extract(raw, "BIAS:");
        s.waveCount = _extract(raw, "WAVE:");
        s.entry = _extract(raw, "ENTRY:");
        s.stopLoss = _extract(raw, "SL:");
        s.tp1 = _extract(raw, "TP1:");
        s.tp2 = _extract(raw, "TP2:");
        s.tp3 = _extract(raw, "TP3:");

        emit SignalGenerated(signalId, s.bias, s.setupGrade, s.entry, s.stopLoss, s.waveCount);
    }

    function _extract(string memory src, string memory key) internal pure returns (string memory) {
        bytes memory srcBytes = bytes(src);
        bytes memory keyBytes = bytes(key);
        for (uint i = 0; i < srcBytes.length - keyBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < keyBytes.length; j++) {
                if (srcBytes[i + j] != keyBytes[j]) { found = false; break; }
            }
            if (found) {
                uint start = i + keyBytes.length;
                uint end = start;
                while (end < srcBytes.length && srcBytes[end] != '|' && srcBytes[end] != '\n') end++;
                bytes memory val = new bytes(end - start);
                for (uint k = 0; k < end - start; k++) val[k] = srcBytes[start + k];
                return string(val);
            }
        }
        return "";
    }

    function getSignal(uint256 signalId) external view returns (Signal memory) {
        return signals[signalId];
    }

    function getLatestSignal() external view returns (Signal memory) {
        require(signalCount > 0, "No signals yet");
        return signals[signalCount - 1];
    }

    receive() external payable {}
}
