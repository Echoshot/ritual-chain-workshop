// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PrecompileConsumer} from "../utils/PrecompileConsumer.sol";

interface IRitualWallet {
    function deposit(uint256 lockDuration) external payable;
}

contract GoldSignalAgent is PrecompileConsumer {
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

    struct ConvoHistory {
        string platform;
        string path;
        string credsRef;
    }

    mapping(uint256 => Signal) public signals;

    event SignalGenerated(uint256 indexed signalId, string bias, string setupGrade, string entry, string stopLoss, string waveCount);
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
        string memory prompt = buildPrompt(goldPrice);
        string memory messagesJson = string(abi.encodePacked('[{"role":"user","content":"', prompt, '"}]'));

        ConvoHistory memory convo = ConvoHistory("none", "", "");

        bytes memory llmInput = _buildLLMInput(messagesJson, convo);

        bytes memory output = _executePrecompile(LLM_INFERENCE_PRECOMPILE, llmInput);

        (bool hasError, bytes memory completionData, , string memory errorMessage, ) =
            abi.decode(output, (bool, bytes, bytes, string, ConvoHistory));
        require(!hasError, errorMessage);

        string memory raw = string(completionData);
        signals[id] = Signal({
            timestamp: block.timestamp,
            goldPrice: goldPrice,
            bias: _extract(raw, "BIAS:"),
            setupGrade: _extract(raw, "GRADE:"),
            entry: _extract(raw, "ENTRY:"),
            stopLoss: _extract(raw, "SL:"),
            tp1: _extract(raw, "TP1:"),
            tp2: _extract(raw, "TP2:"),
            tp3: _extract(raw, "TP3:"),
            waveCount: _extract(raw, "WAVE:"),
            rawAnalysis: raw,
            fulfilled: true
        });

        emit SignalGenerated(id, signals[id].bias, signals[id].setupGrade, signals[id].entry, signals[id].stopLoss, signals[id].waveCount);
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

        struct LLMRequestParams {
        address field1;
        bytes[] field2;
        uint256 field3;
        bytes[] field4;
        bytes field5;
        string field6;
        string field7;
        int256 field8;
        string field9;
        bool field10;
        int256 field11;
        string field12;
        string field13;
        uint256 field14;
        bool field15;
        int256 field16;
        string field17;
        bytes field18;
        int256 field19;
        string field20;
        string field21;
        bool field22;
        int256 field23;
        bytes field24;
        bytes field25;
        int256 field26;
        int256 field27;
        string field28;
        bool field29;
        ConvoHistory field30;
    }

    function _buildLLMInput(string memory messagesJson, ConvoHistory memory convo) internal pure returns (bytes memory) {
        bytes[] memory emptyBytesArr = new bytes[](0);
        LLMRequestParams memory p;
        p.field1 = address(0);
        p.field2 = emptyBytesArr;
        p.field3 = uint256(0);
        p.field4 = emptyBytesArr;
        p.field5 = bytes("");
        p.field6 = messagesJson;
        p.field7 = "zai-org/GLM-4.7-FP8";
        p.field8 = int256(0);
        p.field9 = "";
        p.field10 = false;
        p.field11 = int256(512);
        p.field12 = "";
        p.field13 = "";
        p.field14 = uint256(1);
        p.field15 = false;
        p.field16 = int256(0);
        p.field17 = "";
        p.field18 = bytes("");
        p.field19 = int256(-1);
        p.field20 = "";
        p.field21 = "";
        p.field22 = false;
        p.field23 = int256(700);
        p.field24 = bytes("");
        p.field25 = bytes("");
        p.field26 = int256(-1);
        p.field27 = int256(1000);
        p.field28 = "";
        p.field29 = false;
        p.field30 = convo;
        return abi.encode(p);
    }

    receive() external payable {}
}
