// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IQuizVerifier} from "../interfaces/IQuizVerifier.sol";

/// @title QuizVerifier - On-chain quiz verification for achievement eligibility
/// @notice Stores quiz definitions and verifies user answers on-chain
/// @dev Implements IAchievementVerifier for integration with ChapterMinter
contract QuizVerifier is Ownable, IQuizVerifier {
    // ==================== Storage ====================

    struct QuizDefinition {
        uint8[] correctAnswers;
        uint8 passingScore;
        bool exists;
    }

    /// @notice Quiz definitions by quizId
    mapping(bytes32 => QuizDefinition) internal _quizzes;

    /// @notice Tracks quiz completion: wallet => quizId => passed
    mapping(address => mapping(bytes32 => bool)) internal _quizPassed;

    // ==================== Constructor ====================

    constructor() Ownable(msg.sender) {}

    // ==================== Core Functions ====================

    /// @inheritdoc IQuizVerifier
    function submitQuiz(bytes32 quizId, uint8[] calldata answers) external {
        QuizDefinition storage quiz = _quizzes[quizId];
        if (!quiz.exists) revert QuizNotFound(quizId);
        if (_quizPassed[msg.sender][quizId]) revert QuizAlreadyPassed(msg.sender, quizId);
        if (answers.length != quiz.correctAnswers.length) {
            revert InvalidAnswerCount(answers.length, quiz.correctAnswers.length);
        }

        uint8 correct = 0;
        for (uint256 i = 0; i < answers.length; i++) {
            if (answers[i] == quiz.correctAnswers[i]) {
                correct++;
            }
        }

        if (correct < quiz.passingScore) {
            revert QuizFailed(correct, quiz.passingScore);
        }

        _quizPassed[msg.sender][quizId] = true;
        emit QuizCompleted(msg.sender, quizId, correct, quiz.passingScore);
    }

    /// @inheritdoc IQuizVerifier
    function registerQuiz(bytes32 quizId, uint8[] calldata correctAnswers, uint8 passingScore) external onlyOwner {
        _quizzes[quizId] = QuizDefinition({
            correctAnswers: correctAnswers,
            passingScore: passingScore,
            exists: true
        });
        emit QuizRegistered(quizId, uint8(correctAnswers.length), passingScore);
    }

    // ==================== IAchievementVerifier ====================

    /// @notice Verify if wallet passed the quiz encoded in data
    /// @param wallet The wallet to check
    /// @param data ABI-encoded quiz ID
    /// @return True if wallet passed the quiz
    function verify(address wallet, bytes32, bytes calldata data) external view returns (bool) {
        bytes32 quizId = abi.decode(data, (bytes32));
        return _quizPassed[wallet][quizId];
    }

    // ==================== View Functions ====================

    /// @inheritdoc IQuizVerifier
    function quizPassed(address wallet, bytes32 quizId) external view returns (bool) {
        return _quizPassed[wallet][quizId];
    }

    /// @inheritdoc IQuizVerifier
    function getQuiz(bytes32 quizId) external view returns (uint8 questionCount, uint8 passingScore, bool exists) {
        QuizDefinition storage quiz = _quizzes[quizId];
        return (uint8(quiz.correctAnswers.length), quiz.passingScore, quiz.exists);
    }
}
