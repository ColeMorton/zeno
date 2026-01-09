// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAchievementVerifier} from "./IAchievementVerifier.sol";

/// @title IQuizVerifier - Interface for on-chain quiz verification
/// @notice Verifies quiz completion for achievement eligibility
interface IQuizVerifier is IAchievementVerifier {
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

    // ==================== Core Functions ====================

    /// @notice Submit quiz answers for verification
    /// @param quizId The quiz identifier
    /// @param answers Array of answer indices (0-3 for multiple choice)
    function submitQuiz(bytes32 quizId, uint8[] calldata answers) external;

    /// @notice Register a new quiz definition
    /// @param quizId The quiz identifier
    /// @param correctAnswers Array of correct answer indices per question
    /// @param passingScore Minimum correct answers required to pass
    function registerQuiz(bytes32 quizId, uint8[] calldata correctAnswers, uint8 passingScore) external;

    // ==================== View Functions ====================

    /// @notice Check if a wallet has passed a specific quiz
    /// @param wallet The wallet address
    /// @param quizId The quiz identifier
    /// @return passed Whether the wallet has passed the quiz
    function quizPassed(address wallet, bytes32 quizId) external view returns (bool passed);

    /// @notice Get quiz definition
    /// @param quizId The quiz identifier
    /// @return questionCount Number of questions
    /// @return passingScore Minimum correct answers required
    /// @return exists Whether the quiz is registered
    function getQuiz(bytes32 quizId) external view returns (uint8 questionCount, uint8 passingScore, bool exists);
}
