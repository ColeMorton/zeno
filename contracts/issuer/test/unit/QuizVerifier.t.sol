// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {QuizVerifier} from "../../src/verifiers/QuizVerifier.sol";
import {IQuizVerifier} from "../../src/interfaces/IQuizVerifier.sol";

contract QuizVerifierTest is Test {
    QuizVerifier public verifier;
    address public owner;
    address public alice;
    address public bob;

    bytes32 public constant QUIZ_ID = keccak256("STUDENT_CH1");
    uint8[] public correctAnswers;
    uint8 public constant PASSING_SCORE = 3;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        verifier = new QuizVerifier();

        // Set up a 5-question quiz with passing score of 3
        correctAnswers = new uint8[](5);
        correctAnswers[0] = 1;
        correctAnswers[1] = 0;
        correctAnswers[2] = 2;
        correctAnswers[3] = 3;
        correctAnswers[4] = 1;

        verifier.registerQuiz(QUIZ_ID, correctAnswers, PASSING_SCORE);
    }

    // ==================== Registration Tests ====================

    function test_RegisterQuiz() public view {
        (uint8 questionCount, uint8 passingScore, bool exists) = verifier.getQuiz(QUIZ_ID);
        assertEq(questionCount, 5);
        assertEq(passingScore, PASSING_SCORE);
        assertTrue(exists);
    }

    function test_RegisterQuiz_EmitsEvent() public {
        bytes32 newQuizId = keccak256("NEW_QUIZ");
        uint8[] memory answers = new uint8[](3);
        answers[0] = 0;
        answers[1] = 1;
        answers[2] = 2;

        vm.expectEmit(true, false, false, true);
        emit IQuizVerifier.QuizRegistered(newQuizId, 3, 2);
        verifier.registerQuiz(newQuizId, answers, 2);
    }

    function test_RegisterQuiz_RevertIf_NotOwner() public {
        bytes32 newQuizId = keccak256("UNAUTHORIZED");
        uint8[] memory answers = new uint8[](2);

        vm.prank(alice);
        vm.expectRevert();
        verifier.registerQuiz(newQuizId, answers, 1);
    }

    // ==================== Submit Quiz Tests ====================

    function test_SubmitQuiz_Pass() public {
        // All correct answers
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1;
        answers[1] = 0;
        answers[2] = 2;
        answers[3] = 3;
        answers[4] = 1;

        vm.prank(alice);
        verifier.submitQuiz(QUIZ_ID, answers);

        assertTrue(verifier.quizPassed(alice, QUIZ_ID));
    }

    function test_SubmitQuiz_PassWithMinimumScore() public {
        // 3 correct, 2 wrong (minimum to pass)
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1; // correct
        answers[1] = 0; // correct
        answers[2] = 2; // correct
        answers[3] = 0; // wrong
        answers[4] = 0; // wrong

        vm.prank(alice);
        verifier.submitQuiz(QUIZ_ID, answers);

        assertTrue(verifier.quizPassed(alice, QUIZ_ID));
    }

    function test_SubmitQuiz_EmitsEvent() public {
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1;
        answers[1] = 0;
        answers[2] = 2;
        answers[3] = 3;
        answers[4] = 1;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IQuizVerifier.QuizCompleted(alice, QUIZ_ID, 5, PASSING_SCORE);
        verifier.submitQuiz(QUIZ_ID, answers);
    }

    function test_SubmitQuiz_RevertIf_QuizNotFound() public {
        bytes32 invalidQuiz = keccak256("NONEXISTENT");
        uint8[] memory answers = new uint8[](5);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IQuizVerifier.QuizNotFound.selector, invalidQuiz));
        verifier.submitQuiz(invalidQuiz, answers);
    }

    function test_SubmitQuiz_RevertIf_AlreadyPassed() public {
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1;
        answers[1] = 0;
        answers[2] = 2;
        answers[3] = 3;
        answers[4] = 1;

        vm.prank(alice);
        verifier.submitQuiz(QUIZ_ID, answers);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IQuizVerifier.QuizAlreadyPassed.selector, alice, QUIZ_ID));
        verifier.submitQuiz(QUIZ_ID, answers);
    }

    function test_SubmitQuiz_RevertIf_InvalidAnswerCount() public {
        uint8[] memory answers = new uint8[](3); // Wrong count

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IQuizVerifier.InvalidAnswerCount.selector, 3, 5));
        verifier.submitQuiz(QUIZ_ID, answers);
    }

    function test_SubmitQuiz_RevertIf_Failed() public {
        // Only 2 correct (below passing score of 3)
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1; // correct
        answers[1] = 0; // correct
        answers[2] = 0; // wrong
        answers[3] = 0; // wrong
        answers[4] = 0; // wrong

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IQuizVerifier.QuizFailed.selector, 2, PASSING_SCORE));
        verifier.submitQuiz(QUIZ_ID, answers);
    }

    // ==================== Verify Tests (IAchievementVerifier) ====================

    function test_Verify_ReturnsTrueIfPassed() public {
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1;
        answers[1] = 0;
        answers[2] = 2;
        answers[3] = 3;
        answers[4] = 1;

        vm.prank(alice);
        verifier.submitQuiz(QUIZ_ID, answers);

        bytes memory data = abi.encode(QUIZ_ID);
        bool result = verifier.verify(alice, bytes32(0), data);
        assertTrue(result);
    }

    function test_Verify_ReturnsFalseIfNotPassed() public {
        bytes memory data = abi.encode(QUIZ_ID);
        bool result = verifier.verify(alice, bytes32(0), data);
        assertFalse(result);
    }

    function test_Verify_DifferentUsers() public {
        uint8[] memory answers = new uint8[](5);
        answers[0] = 1;
        answers[1] = 0;
        answers[2] = 2;
        answers[3] = 3;
        answers[4] = 1;

        // Alice passes
        vm.prank(alice);
        verifier.submitQuiz(QUIZ_ID, answers);

        bytes memory data = abi.encode(QUIZ_ID);
        assertTrue(verifier.verify(alice, bytes32(0), data));
        assertFalse(verifier.verify(bob, bytes32(0), data));
    }

    // ==================== Multiple Quiz Tests ====================

    function test_MultipleQuizzes() public {
        bytes32 quiz2 = keccak256("QUIZ_2");
        uint8[] memory answers2 = new uint8[](3);
        answers2[0] = 2;
        answers2[1] = 1;
        answers2[2] = 0;
        verifier.registerQuiz(quiz2, answers2, 2);

        // Alice passes both quizzes
        uint8[] memory aliceAnswers1 = new uint8[](5);
        aliceAnswers1[0] = 1;
        aliceAnswers1[1] = 0;
        aliceAnswers1[2] = 2;
        aliceAnswers1[3] = 3;
        aliceAnswers1[4] = 1;

        vm.prank(alice);
        verifier.submitQuiz(QUIZ_ID, aliceAnswers1);

        uint8[] memory aliceAnswers2 = new uint8[](3);
        aliceAnswers2[0] = 2;
        aliceAnswers2[1] = 1;
        aliceAnswers2[2] = 0;

        vm.prank(alice);
        verifier.submitQuiz(quiz2, aliceAnswers2);

        assertTrue(verifier.quizPassed(alice, QUIZ_ID));
        assertTrue(verifier.quizPassed(alice, quiz2));
    }

    // ==================== Edge Cases ====================

    function test_GetQuiz_NonExistent() public view {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        (uint8 questionCount, uint8 passingScore, bool exists) = verifier.getQuiz(nonExistent);
        assertEq(questionCount, 0);
        assertEq(passingScore, 0);
        assertFalse(exists);
    }

    function testFuzz_SubmitQuiz_VariousScores(uint8 wrongCount) public {
        vm.assume(wrongCount <= 5);

        uint8[] memory answers = new uint8[](5);
        answers[0] = 1;
        answers[1] = 0;
        answers[2] = 2;
        answers[3] = 3;
        answers[4] = 1;

        // Make some answers wrong
        for (uint8 i = 0; i < wrongCount && i < 5; i++) {
            answers[i] = 9; // Invalid answer
        }

        uint8 correctCount = 5 - wrongCount;

        vm.prank(alice);
        if (correctCount >= PASSING_SCORE) {
            verifier.submitQuiz(QUIZ_ID, answers);
            assertTrue(verifier.quizPassed(alice, QUIZ_ID));
        } else {
            vm.expectRevert(abi.encodeWithSelector(IQuizVerifier.QuizFailed.selector, correctCount, PASSING_SCORE));
            verifier.submitQuiz(QUIZ_ID, answers);
        }
    }
}
