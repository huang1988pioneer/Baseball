/*
 * Shared baseball rules for the browser prototype.
 * Keep tables in sync with game_rules.gd.
 */
(function (root) {
  'use strict';

  const TOTAL_INNINGS = 3;
  const BALLS_FOR_WALK = 4;
  const STRIKES_FOR_OUT = 3;
  const OUTS_PER_INNING = 3;
  const IN_ZONE_CHANCE = 0.82;

  const PITCHES = {
    fastball: { label: '快速球', speed: 145, duration: 1.06, ideal: 0.86, className: 'fastball' },
    curveball: { label: '曲球', speed: 118, duration: 1.4, ideal: 0.91, className: 'curveball' },
    slider: { label: '滑球', speed: 126, duration: 1.22, ideal: 0.88, className: 'slider' },
    changeup: { label: '變速球', speed: 108, duration: 1.52, ideal: 0.82, className: 'changeup' },
  };

  const COACH_NOTES = [
    'Perfect 的視窗很短，先盯著球進入好球帶。',
    '瞄準格只影響接觸點；先猜球，再用時機補救。',
    '兩好球後別急著追壞球，讓投手自己送一個保送。',
    '連續安打會疊 COMBO，下一球的飛行距離也會更漂亮。',
  ];

  const OUTCOME_LABELS = {
    homerun: '全壘打！',
    triple: '三壘安打',
    double: '二壘安打',
    single: '一壘安打',
    foul: '界外球',
    out: '守備接殺',
  };

  const OUTCOME_TABLES = {
    PERFECT: [['homerun', 0.16], ['triple', 0.08], ['double', 0.28], ['single', 0.43], ['foul', 0.02], ['out', 0.03]],
    GOOD: [['homerun', 0.07], ['triple', 0.06], ['double', 0.24], ['single', 0.43], ['foul', 0.08], ['out', 0.12]],
    EARLY: [['homerun', 0.015], ['triple', 0.025], ['double', 0.12], ['single', 0.31], ['foul', 0.28], ['out', 0.25]],
    LATE: [['homerun', 0.012], ['triple', 0.02], ['double', 0.14], ['single', 0.3], ['foul', 0.29], ['out', 0.238]],
  };

  function classifyTiming(progress, ideal) {
    const delta = progress - ideal;
    const distance = Math.abs(delta);
    if (distance <= 0.035) return { grade: 'PERFECT', label: 'PERFECT!' };
    if (distance <= 0.09) return { grade: 'GOOD', label: 'GOOD!' };
    if (distance <= 0.19) return { grade: delta < 0 ? 'EARLY' : 'LATE', label: delta < 0 ? 'EARLY' : 'LATE' };
    return { grade: 'MISS', label: 'MISS' };
  }

  function zoneRow(zone) {
    return Math.floor(zone / 3);
  }

  function gridDistance(a, b) {
    if (b < 0) return 2;
    return Math.abs(zoneRow(a) - zoneRow(b)) + Math.abs((a % 3) - (b % 3));
  }

  function moveAim(aim, key) {
    let row = zoneRow(aim);
    let col = aim % 3;
    if (key === 'ArrowUp') row = Math.max(0, row - 1);
    if (key === 'ArrowDown') row = Math.min(2, row + 1);
    if (key === 'ArrowLeft') col = Math.max(0, col - 1);
    if (key === 'ArrowRight') col = Math.min(2, col + 1);
    return Math.max(0, Math.min(8, row * 3 + col));
  }

  function basesAdvanced(key) {
    if (key === 'homerun') return 4;
    if (key === 'triple') return 3;
    if (key === 'double') return 2;
    if (key === 'single') return 1;
    return 0;
  }

  function advanceRunners(bases, distance, homeRun) {
    const current = bases.slice();
    if (homeRun || distance >= 4) {
      const runs = 1 + current.filter(Boolean).length;
      return { bases: [false, false, false], runs };
    }
    const next = [false, false, false];
    let runs = 0;
    for (let index = 2; index >= 0; index -= 1) {
      if (!current[index]) continue;
      const destination = index + distance;
      if (destination >= 3) runs += 1;
      else next[destination] = true;
    }
    const batterDestination = distance - 1;
    if (batterDestination >= 3) runs += 1;
    else next[batterDestination] = true;
    return { bases: next, runs };
  }

  function forceWalk(bases) {
    const next = bases.slice();
    let runs = 0;
    if (next[0] && next[1] && next[2]) runs = 1;
    if (next[0] && next[1]) next[2] = true;
    else if (next[0]) next[1] = true;
    next[0] = true;
    return { bases: next, runs };
  }

  function opponentRuns(roll) {
    if (roll >= 0.82) return 2;
    if (roll >= 0.35) return 1;
    return 0;
  }

  function rollOutcome(grade, aimDistance, random = Math.random) {
    const source = OUTCOME_TABLES[grade] || OUTCOME_TABLES.GOOD;
    const nudge = Math.min(0.18, aimDistance * 0.055);
    const weights = source.map(([key, weight]) => {
      if (key === 'out') return [key, weight + nudge];
      if (key === 'homerun') return [key, Math.max(0.005, weight - nudge * 0.5)];
      if (key === 'single' || key === 'double') return [key, Math.max(0.01, weight - nudge * 0.18)];
      return [key, weight];
    });
    const total = weights.reduce((sum, [, weight]) => sum + weight, 0);
    let roll = random() * total;
    let selected = 'out';
    for (const [key, weight] of weights) {
      roll -= weight;
      if (roll <= 0) {
        selected = key;
        break;
      }
    }
    const flights = {
      homerun: [0.88, 0.08],
      triple: [0.82, 0.18],
      double: [0.76, 0.27],
      single: [0.68, 0.36],
      foul: [0.24 + random() * 0.22, 0.17 + random() * 0.11],
      out: [0.54 + random() * 0.2, 0.21 + random() * 0.26],
    };
    const [flightX, flightY] = flights[selected];
    return { key: selected, label: OUTCOME_LABELS[selected], flightX, flightY };
  }

  function durationMs(pitch) {
    return Math.round(pitch.duration * 1000);
  }

  root.MeowRules = {
    TOTAL_INNINGS,
    BALLS_FOR_WALK,
    STRIKES_FOR_OUT,
    OUTS_PER_INNING,
    IN_ZONE_CHANCE,
    PITCHES,
    COACH_NOTES,
    OUTCOME_LABELS,
    classifyTiming,
    gridDistance,
    moveAim,
    basesAdvanced,
    advanceRunners,
    forceWalk,
    opponentRuns,
    rollOutcome,
    durationMs,
  };
})(typeof window !== 'undefined' ? window : globalThis);
