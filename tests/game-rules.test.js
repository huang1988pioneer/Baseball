'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');

require(path.join(__dirname, '..', 'game-rules.js'));

const rules = globalThis.MeowRules;
let passed = 0;

function test(name, fn) {
  fn();
  passed += 1;
  process.stdout.write(`ok  ${name}\n`);
}

test('perfect window is tight around the ideal point', () => {
  assert.equal(rules.classifyTiming(0.86, 0.86).grade, 'PERFECT');
  assert.equal(rules.classifyTiming(0.86 + 0.036, 0.86).grade, 'GOOD');
  assert.equal(rules.classifyTiming(0.86 - 0.1, 0.86).grade, 'EARLY');
  assert.equal(rules.classifyTiming(0.86 + 0.1, 0.86).grade, 'LATE');
  assert.equal(rules.classifyTiming(0.5, 0.86).grade, 'MISS');
});

test('aim grid uses integer rows, not float division', () => {
  assert.equal(rules.gridDistance(2, 3), 3);
  assert.equal(rules.gridDistance(5, 4), 1);
  assert.equal(rules.gridDistance(8, 0), 4);
  assert.equal(rules.moveAim(5, 'ArrowLeft'), 4);
  assert.equal(rules.moveAim(4, 'ArrowUp'), 1);
  assert.equal(rules.moveAim(0, 'ArrowLeft'), 0);
});

test('walk forces runners instead of clearing the diamond', () => {
  const loaded = rules.forceWalk([true, true, true]);
  assert.deepEqual(loaded.bases, [true, true, true]);
  assert.equal(loaded.runs, 1);

  const firstAndThird = rules.forceWalk([true, false, true]);
  assert.deepEqual(firstAndThird.bases, [true, true, true]);
  assert.equal(firstAndThird.runs, 0);

  const empty = rules.forceWalk([false, false, false]);
  assert.deepEqual(empty.bases, [true, false, false]);
  assert.equal(empty.runs, 0);
});

test('a walk is not scored like a home run', () => {
  const walk = rules.forceWalk([true, true, false]);
  const fakeHomeRun = rules.advanceRunners([true, true, false], 1, true);
  assert.equal(walk.runs, 0);
  assert.deepEqual(walk.bases, [true, true, true]);
  assert.equal(fakeHomeRun.runs, 3);
  assert.deepEqual(fakeHomeRun.bases, [false, false, false]);
});

test('home run clears the bases and scores the batter', () => {
  const result = rules.advanceRunners([true, false, true], 4, true);
  assert.equal(result.runs, 3);
  assert.deepEqual(result.bases, [false, false, false]);
});

test('opponent half-inning uses the original thresholds', () => {
  assert.equal(rules.opponentRuns(0.34), 0);
  assert.equal(rules.opponentRuns(0.35), 1);
  assert.equal(rules.opponentRuns(0.81), 1);
  assert.equal(rules.opponentRuns(0.82), 2);
});

test('weighted outcomes stay on the known result keys', () => {
  const sequence = [0.01, 0.5, 0.99];
  let index = 0;
  const random = () => {
    const value = sequence[index % sequence.length];
    index += 1;
    return value;
  };
  const outcome = rules.rollOutcome('PERFECT', 0, random);
  assert.equal(Object.prototype.hasOwnProperty.call(rules.OUTCOME_LABELS, outcome.key), true);
  assert.equal(outcome.label, rules.OUTCOME_LABELS[outcome.key]);
});

test('pitch duration is stored in seconds', () => {
  assert.equal(rules.durationMs(rules.PITCHES.fastball), 1060);
  assert.equal(rules.durationMs(rules.PITCHES.changeup), 1520);
});

process.stdout.write(`\n${passed} tests passed\n`);
