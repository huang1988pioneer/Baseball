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
  const AUTO_PITCH_MIN = 3;
  const AUTO_PITCH_MAX = 15;

  const CHARACTER_ORDER = ['meow_white', 'meow_boo', 'meow_mi'];
  const TEAM_ORDER = ['home', 'away'];

  const CHARACTERS = {
    meow_white: {
      id: 'meow_white',
      name: '喵白白',
      role: 'pitcher',
      roleLabel: '投手',
      number: '#1',
      blurb: '主場王牌，球速快、節奏穩。',
      art: 'pitcher-v2.png',
    },
    meow_boo: {
      id: 'meow_boo',
      name: '喵布布',
      role: 'batter',
      roleLabel: '打者',
      number: '#B',
      blurb: '揮棒果斷，擅長抓準甜蜜點。',
      art: 'batter-v2.png',
    },
    meow_mi: {
      id: 'meow_mi',
      name: '咪嚕',
      role: 'batter',
      roleLabel: '打者',
      number: '#7',
      blurb: '外野砲，安打後推進特別積極。',
      art: 'runner-v1.png',
    },
  };

  const TEAMS = {
    home: {
      id: 'home',
      name: '喵白白隊',
      short: 'HOME CAT  ·  喵白白',
      art: 'home-crest-v1.png',
    },
    away: {
      id: 'away',
      name: '喵布布隊',
      short: 'AWAY CAT  ·  喵布布',
      art: 'away-crest-v1.png',
    },
  };

  const PITCHES = {
    fastball: { label: '快速球', speed: 145, duration: 1.06, ideal: 0.86, className: 'fastball' },
    curveball: { label: '曲球', speed: 118, duration: 1.4, ideal: 0.91, className: 'curveball' },
    slider: { label: '滑球', speed: 126, duration: 1.22, ideal: 0.88, className: 'slider' },
    changeup: { label: '變速球', speed: 108, duration: 1.52, ideal: 0.82, className: 'changeup' },
  };

  const PITCH_ORDER = ['fastball', 'curveball', 'slider', 'changeup'];

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

  function autoPitchDelay(roll) {
    const t = Math.max(0, Math.min(1, roll));
    return AUTO_PITCH_MIN + t * (AUTO_PITCH_MAX - AUTO_PITCH_MIN);
  }

  function cpuPickPitch(random = Math.random) {
    const index = Math.min(PITCH_ORDER.length - 1, Math.floor(random() * PITCH_ORDER.length));
    return PITCH_ORDER[index];
  }

  function cpuBatterPlan(inZone, ideal, random = Math.random) {
    const swingChance = inZone ? 0.88 : 0.22;
    if (random() > swingChance) return { action: 'take', progress: 0 };
    let progress = Math.max(0.52, Math.min(0.97, ideal + (-0.12 + random() * 0.24)));
    if (random() < 0.08) progress = 0.4;
    return { action: 'swing', progress };
  }

  function cpuSwingAim(pitchZone, random = Math.random) {
    if (pitchZone < 0) return Math.min(8, Math.floor(random() * 9));
    if (random() < 0.5) return pitchZone;
    const offset = Math.floor(random() * 5) - 2;
    return Math.max(0, Math.min(8, pitchZone + offset));
  }

  function artPath(filename) {
    return `assets/generated/${filename}`;
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
    AUTO_PITCH_MIN,
    AUTO_PITCH_MAX,
    PITCHES,
    PITCH_ORDER,
    CHARACTERS,
    CHARACTER_ORDER,
    TEAMS,
    TEAM_ORDER,
    COACH_NOTES,
    OUTCOME_LABELS,
    classifyTiming,
    gridDistance,
    moveAim,
    basesAdvanced,
    advanceRunners,
    forceWalk,
    opponentRuns,
    autoPitchDelay,
    cpuPickPitch,
    cpuBatterPlan,
    cpuSwingAim,
    artPath,
    rollOutcome,
    durationMs,
  };
})(typeof window !== 'undefined' ? window : globalThis);
