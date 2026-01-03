'use client';

import { useState } from 'react';
import { type Quiz, type QuizQuestion, calculateQuizScore } from '@/lib/education';

interface QuizCardProps {
  quiz: Quiz;
  achievementName: string;
  onComplete: (passed: boolean, score: number) => void;
}

function QuestionCard({
  question,
  index,
  selectedAnswer,
  onSelect,
  showResult,
}: {
  question: QuizQuestion;
  index: number;
  selectedAnswer: number | null;
  onSelect: (answer: number) => void;
  showResult: boolean;
}) {
  return (
    <div className="bg-gray-800/50 rounded-lg p-4">
      <p className="text-white font-medium mb-3">
        {index + 1}. {question.question}
      </p>
      <div className="space-y-2">
        {question.options.map((option, optionIndex) => {
          const isSelected = selectedAnswer === optionIndex;
          const isCorrect = optionIndex === question.correct;

          let optionStyle = 'border-gray-600 hover:border-gray-500';
          if (showResult) {
            if (isCorrect) {
              optionStyle = 'border-green-500 bg-green-500/10';
            } else if (isSelected && !isCorrect) {
              optionStyle = 'border-red-500 bg-red-500/10';
            }
          } else if (isSelected) {
            optionStyle = 'border-blue-500 bg-blue-500/10';
          }

          return (
            <button
              key={optionIndex}
              onClick={() => !showResult && onSelect(optionIndex)}
              disabled={showResult}
              className={`w-full text-left p-3 rounded-lg border-2 transition-all ${optionStyle} ${
                showResult ? 'cursor-default' : 'cursor-pointer'
              }`}
            >
              <div className="flex items-center gap-3">
                <span className={`w-6 h-6 rounded-full border-2 flex items-center justify-center text-sm ${
                  isSelected ? 'border-current bg-current/20' : 'border-gray-500'
                }`}>
                  {String.fromCharCode(65 + optionIndex)}
                </span>
                <span className="text-gray-300">{option}</span>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function QuizCard({ quiz, achievementName, onComplete }: QuizCardProps) {
  const [answers, setAnswers] = useState<(number | null)[]>(
    new Array(quiz.questions.length).fill(null)
  );
  const [submitted, setSubmitted] = useState(false);
  const [result, setResult] = useState<{ score: number; passed: boolean } | null>(null);

  const handleSelect = (questionIndex: number, answer: number) => {
    const newAnswers = [...answers];
    newAnswers[questionIndex] = answer;
    setAnswers(newAnswers);
  };

  const handleSubmit = () => {
    const validAnswers = answers.filter((a): a is number => a !== null);
    if (validAnswers.length !== quiz.questions.length) return;

    const { score, passed } = calculateQuizScore(validAnswers, quiz.questions);
    setResult({ score, passed });
    setSubmitted(true);
    onComplete(passed, score);
  };

  const handleRetry = () => {
    setAnswers(new Array(quiz.questions.length).fill(null));
    setSubmitted(false);
    setResult(null);
  };

  const allAnswered = answers.every((a) => a !== null);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold text-white">Knowledge Check</h3>
        <span className="text-sm text-gray-400">
          {quiz.questions.length} question{quiz.questions.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Questions */}
      <div className="space-y-4">
        {quiz.questions.map((question, index) => (
          <QuestionCard
            key={index}
            question={question}
            index={index}
            selectedAnswer={answers[index]}
            onSelect={(answer) => handleSelect(index, answer)}
            showResult={submitted}
          />
        ))}
      </div>

      {/* Result */}
      {result && (
        <div
          className={`p-4 rounded-lg ${
            result.passed
              ? 'bg-green-500/10 border border-green-500'
              : 'bg-red-500/10 border border-red-500'
          }`}
        >
          <div className="flex items-center justify-between">
            <div>
              <p className={`font-bold ${result.passed ? 'text-green-400' : 'text-red-400'}`}>
                {result.passed ? 'Quiz Passed!' : 'Quiz Not Passed'}
              </p>
              <p className="text-sm text-gray-400">
                Score: {result.score}% (100% required)
              </p>
            </div>
            {result.passed && (
              <span className="text-3xl">&#127942;</span>
            )}
          </div>
        </div>
      )}

      {/* Action buttons */}
      <div className="flex gap-3">
        {!submitted ? (
          <button
            onClick={handleSubmit}
            disabled={!allAnswered}
            className={`flex-1 py-3 rounded-lg font-semibold transition-colors ${
              allAnswered
                ? 'bg-blue-600 hover:bg-blue-500 text-white'
                : 'bg-gray-700 text-gray-500 cursor-not-allowed'
            }`}
          >
            Submit Answers
          </button>
        ) : (
          <>
            {!result?.passed && (
              <button
                onClick={handleRetry}
                className="flex-1 py-3 rounded-lg bg-gray-700 hover:bg-gray-600 text-white font-semibold transition-colors"
              >
                Try Again
              </button>
            )}
            {result?.passed && (
              <div className="flex-1 py-3 rounded-lg bg-green-600/20 text-green-400 font-semibold text-center">
                Ready to claim {achievementName}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export function QuizCardSkeleton() {
  return (
    <div className="space-y-6 animate-pulse">
      <div className="flex items-center justify-between">
        <div className="h-6 w-32 bg-gray-700 rounded" />
        <div className="h-4 w-20 bg-gray-700 rounded" />
      </div>
      <div className="space-y-4">
        <div className="h-32 bg-gray-700 rounded-lg" />
        <div className="h-32 bg-gray-700 rounded-lg" />
      </div>
      <div className="h-12 bg-gray-700 rounded-lg" />
    </div>
  );
}
