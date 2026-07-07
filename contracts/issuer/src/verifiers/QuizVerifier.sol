// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title QuizVerifier - On-chain quiz verification for achievement eligibility
/// @notice Stores quiz definitions and verifies user answers on-chain
/// @dev Implements IAchievementVerifier for integration with ChapterMinter
contract QuizVerifier is Ownable, IAchievementVerifier {
    // ==================== Events ====================

    /// @notice Emitted when a user completes a quiz
    event QuizCompleted(address indexed wallet, bytes32 indexed quizId, uint8 score, uint8 required);

    /// @notice Emitted when a quiz is registered
    event QuizRegistered(bytes32 indexed quizId, uint8 questionCount, uint8 passingScore);

    // ==================== Errors ====================

    /// @notice Quiz not found
    error QuizNotFound(bytes32 quizId);

    /// @notice User already passed this quiz
    error QuizAlreadyPassed(address wallet, bytes32 quizId);

    /// @notice Quiz failed - score below passing threshold
    error QuizFailed(uint8 score, uint8 required);

    /// @notice Answer count doesn't match question count
    error InvalidAnswerCount(uint256 provided, uint256 expected);

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

    /// @notice Submit quiz answers for verification
    /// @param quizId The quiz identifier
    /// @param answers Array of answer indices (0-3 for multiple choice)
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

    /// @notice Register a new quiz definition
    /// @param quizId The quiz identifier
    /// @param correctAnswers Array of correct answer indices per question
    /// @param passingScore Minimum correct answers required to pass
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

    /// @notice Check if a wallet has passed a specific quiz
    /// @param wallet The wallet address
    /// @param quizId The quiz identifier
    function quizPassed(address wallet, bytes32 quizId) external view returns (bool) {
        return _quizPassed[wallet][quizId];
    }

    /// @notice Get quiz definition
    /// @param quizId The quiz identifier
    /// @return questionCount Number of questions
    /// @return passingScore Minimum correct answers required
    /// @return exists Whether the quiz is registered
    function getQuiz(bytes32 quizId) external view returns (uint8 questionCount, uint8 passingScore, bool exists) {
        QuizDefinition storage quiz = _quizzes[quizId];
        return (uint8(quiz.correctAnswers.length), quiz.passingScore, quiz.exists);
    }
}
