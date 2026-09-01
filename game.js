/*
 * 喵喵棒球 · 2D Baseball Lab
 * A small, dependency-free gameplay loop: pitch -> read -> swing -> resolve.
 */

(() => {
  'use strict';

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];

  const ui = {
    inningLabel: $('#inningLabel'),
    inningScores: $('#inningScores'),
    playerScore: $('#playerScore'),
    rivalScore: $('#rivalScore'),
    miniScore: $('#miniScore'),
    ballCount: $('#ballCount'),
    strikeCount: $('#strikeCount'),
    outCount: $('#outCount'),
    atBatLabel: $('#atBatLabel'),
    pitchReadout: $('#pitchReadout'),
    pitchSpeedReadout: $('#pitchSpeedReadout'),
    pitchButton: $('#pitchButton'),
    swingButton: $('#swingButton'),
    pitchOptions: $('#pitchOptions'),
    aimGrid: $('#aimGrid'),
    aimRing: $('#aimRing'),
    strikeZone: $('#strikeZone'),
    ball: $('#ball'),
    impactRing: $('#impactRing'),
    resultBurst: $('#resultBurst'),
    gameMessage: $('#gameMessage'),
    timingCursor: $('#timingCursor'),
    heroCombo: $('#heroCombo'),
    missionPerfect: $('#missionPerfect'),
    missionHits: $('#missionHits'),
    missionRuns: $('#missionRuns'),
    batterState: $('#batterState'),
    coachNote: $('#coachNote'),
    coachButton: $('#coachButton'),
    howToPlayButton: $('#howToPlayButton'),
    shortcutHelp: $('#shortcutHelp'),
    howToPlayModal: $('#howToPlayModal'),
    modalClose: $('#modalClose'),
    modalStart: $('#modalStart'),
    soundButton: $('#soundButton'),
    soundIcon: $('#soundIcon'),
    toast: $('#toast'),
    bases: {
      home: $('.base-home'),
      first: $('.base-first'),
      second: $('.base-second'),
      third: $('.base-third'),
    },
  };

  const rules = window.MeowRules;
  if (!rules) {
    throw new Error('game-rules.js must load before game.js');
  }
  const PITCHES = rules.PITCHES;
  const COACH_NOTES = rules.COACH_NOTES;

  const state = {
    inning: 1,
    innings: 3,
    outs: 0,
    balls: 0,
    strikes: 0,
    playerScore: 0,
    rivalScore: 0,
    inningRuns: Array(9).fill(null),
    rivalInningRuns: Array(9).fill(null),
    bases: [false, false, false], // first, second, third
    selectedPitch: 'fastball',
    aim: 4,
    pitch: null,
    pitchTimer: null,
    resolveTimer: null,
    resolving: false,
    gameOver: false,
    gameStarted: false,
    combo: 0,
    hits: 0,
    perfects: 0,
    totalRuns: 0,
    sound: true,
    coachIndex: 0,
  };

  let toastTimer = null;

  function init() {
    buildInningStrip();
    buildCountLights();
    bindEvents();
    selectPitch('fastball');
    selectAim(4);
    updateUI();
    setMessage('READY?', '選球後按「投球」', '靠近本壘時按下揮棒');
    setControlsDisabled(false);
  }

  function buildInningStrip() {
    ui.inningScores.innerHTML = '';
    for (let i = 0; i < 9; i += 1) {
      const cell = document.createElement('span');
      cell.dataset.inning = String(i + 1);
      cell.innerHTML = `<b>${i + 1}</b><small>—</small>`;
      ui.inningScores.appendChild(cell);
    }
  }

  function buildCountLights() {
    [ui.ballCount, ui.strikeCount, ui.outCount].forEach((container) => {
      container.innerHTML = '';
      const max = container === ui.outCount ? 3 : container === ui.ballCount ? 4 : 3;
      for (let i = 0; i < max; i += 1) {
        const light = document.createElement('i');
        container.appendChild(light);
      }
    });
  }

  function bindEvents() {
    ui.pitchOptions.addEventListener('click', (event) => {
      const button = event.target.closest('[data-pitch]');
      if (!button || state.pitch || state.resolving || state.gameOver) return;
      selectPitch(button.dataset.pitch);
    });

    ui.aimGrid.addEventListener('click', (event) => {
      const button = event.target.closest('[data-aim]');
      if (!button || state.pitch || state.resolving || state.gameOver) return;
      selectAim(Number(button.dataset.aim));
    });

    ui.pitchButton.addEventListener('click', () => {
      if (state.gameOver) {
        resetGame();
      } else {
        startPitch();
      }
    });
    ui.swingButton.addEventListener('click', swing);
    ui.coachButton.addEventListener('click', nextCoachNote);
    ui.howToPlayButton.addEventListener('click', openTutorial);
    ui.shortcutHelp.addEventListener('click', openTutorial);
    ui.modalClose.addEventListener('click', closeTutorial);
    ui.modalStart.addEventListener('click', () => {
      closeTutorial();
      window.setTimeout(() => ui.pitchButton.focus(), 50);
    });
    ui.howToPlayModal.addEventListener('click', (event) => {
      if (event.target === ui.howToPlayModal) closeTutorial();
    });
    ui.soundButton.addEventListener('click', toggleSound);

    window.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && !ui.howToPlayModal.hidden) {
        closeTutorial();
        return;
      }
      if (!ui.howToPlayModal.hidden) return;
      if (event.code === 'Space') {
        event.preventDefault();
        swing();
        return;
      }
      if (event.key === 'Enter' || event.key === 't' || event.key === 'T') {
        event.preventDefault();
        if (state.gameOver) resetGame();
        else startPitch();
        return;
      }
      if (event.key === 'r' || event.key === 'R') {
        event.preventDefault();
        resetGame();
        return;
      }
      const pitchKeys = { '1': 'fastball', '2': 'curveball', '3': 'slider', '4': 'changeup' };
      if (pitchKeys[event.key] && !state.pitch && !state.resolving && !state.gameOver) {
        selectPitch(pitchKeys[event.key]);
      }
      if (event.key.startsWith('Arrow') && !state.pitch && !state.resolving && !state.gameOver) {
        event.preventDefault();
        moveAim(event.key);
      }
    });
  }

  function selectPitch(name) {
    if (!PITCHES[name]) return;
    state.selectedPitch = name;
    $$('.pitch-option').forEach((button) => button.classList.toggle('selected', button.dataset.pitch === name));
    const pitch = PITCHES[name];
    if (!state.pitch) {
      ui.pitchReadout.textContent = pitch.label;
      ui.pitchSpeedReadout.textContent = `${pitch.speed} km/h 預測`;
    }
  }

  function selectAim(index) {
    state.aim = Math.max(0, Math.min(8, index));
    $$('[data-aim]').forEach((button) => button.classList.toggle('selected', Number(button.dataset.aim) === state.aim));
    $$('.zone-grid').forEach((zone) => zone.classList.toggle('selected', Number(zone.dataset.zone) === state.aim));
    const col = state.aim % 3;
    const row = Math.floor(state.aim / 3);
    ui.aimRing.style.left = `${(col + 0.5) * 33.333}%`;
    ui.aimRing.style.top = `${(row + 0.5) * 33.333}%`;
  }

  function moveAim(key) {
    selectAim(rules.moveAim(state.aim, key));
  }

  function startPitch() {
    if (state.pitch || state.resolving || state.gameOver) return;
    state.gameStarted = true;
    const definition = PITCHES[state.selectedPitch];
    const durationMs = rules.durationMs(definition);
    const inZone = Math.random() > (1 - rules.IN_ZONE_CHANCE);
    const zone = inZone ? Math.floor(Math.random() * 9) : -1;
    const startedAt = performance.now();
    state.pitch = { ...definition, duration: durationMs, zone, inZone, startedAt };

    const targetX = inZone ? 45 + (zone % 3) * 2.6 : 40 + Math.random() * 20;
    const targetY = inZone ? 52 + Math.floor(zone / 3) * 3.2 : 50 + Math.random() * 9;
    ui.ball.style.setProperty('--pitch-duration', `${durationMs}ms`);
    ui.ball.style.setProperty('--target-x', `${targetX}%`);
    ui.ball.style.setProperty('--target-y', `${targetY}%`);
    ui.ball.className = `ball is-pitching pitch-${definition.className}`;
    ui.timingCursor.style.setProperty('--pitch-duration', `${durationMs}ms`);
    ui.timingCursor.classList.remove('playing');
    // Force a reflow so a repeated pitch always restarts the cursor animation.
    void ui.timingCursor.offsetWidth;
    ui.timingCursor.classList.add('playing');
    ui.pitchReadout.textContent = definition.label;
    ui.pitchSpeedReadout.textContent = `${definition.speed} km/h · 球進壘中`;
    setMessage('WATCH THE BALL', '準備揮棒！', '球越靠近本壘，Timing 越漂亮');
    ui.gameMessage.classList.remove('hidden');
    setControlsDisabled(true);
    ui.swingButton.disabled = false;
    ui.swingButton.classList.add('pulse');
    window.setTimeout(() => ui.swingButton.classList.remove('pulse'), 520);

    state.pitchTimer = window.setTimeout(() => pitchArrived(), durationMs + 75);
  }

  function pitchArrived() {
    if (!state.pitch) return;
    // A take is resolved just after the ball reaches the plate.
    resolveTake();
  }

  function swing() {
    if (!state.pitch) {
      if (!state.gameOver && !state.resolving) showToast('先按「投球」，等球進來再揮棒！');
      return;
    }
    if (state.resolving) return;
    const pitch = state.pitch;
    const now = performance.now();
    const progress = Math.max(0, Math.min(1.12, (now - pitch.startedAt) / pitch.duration));
    clearPitchTimer();
    const timing = classifyTiming(progress, pitch.ideal);
    state.pitch = null;
    ui.swingButton.classList.remove('pulse');
    ui.impactRing.classList.remove('show');
    void ui.impactRing.offsetWidth;

    if (timing.grade === 'MISS') {
      showBurst('SWING & MISS', 'strike');
      resolveStrike('揮棒落空', 920);
      return;
    }

    const aimDistance = pitch.inZone ? rules.gridDistance(state.aim, pitch.zone) : 2;
    const outcome = rules.rollOutcome(timing.grade, aimDistance);
    if (timing.grade === 'PERFECT') {
      state.perfects += 1;
      ui.strikeZone.classList.add('perfect-flash');
      window.setTimeout(() => ui.strikeZone.classList.remove('perfect-flash'), 450);
    }

    ui.ball.className = `ball is-hit hit-${outcome.key}`;
    ui.ball.style.setProperty('--flight-x', `${outcome.flightX * 100}%`);
    ui.ball.style.setProperty('--flight-y', `${outcome.flightY * 100}%`);
    ui.impactRing.classList.add('show');
    showBurst(timing.label, timing.grade === 'PERFECT' ? 'perfect' : '');
    resolveContact(timing, outcome);
  }

  function classifyTiming(progress, ideal) {
    return rules.classifyTiming(progress, ideal);
  }

  function resolveTake() {
    if (!state.pitch) return;
    const wasInZone = state.pitch.inZone;
    clearPitchTimer();
    state.pitch = null;
    ui.ball.classList.remove('is-pitching');
    if (wasInZone) {
      showBurst('CALLED STRIKE', 'strike');
      resolveStrike('看球好球', 900);
    } else {
      showBurst('BALL', '');
      resolveBall(900);
    }
  }

  function resolveStrike(reason, delay = 900) {
    state.strikes += 1;
    state.combo = 0;
    updateUI();
    if (state.strikes >= rules.STRIKES_FOR_OUT) {
      registerOut(`三振！${reason}`, delay + 120);
    } else {
      finishResolution(() => prepareNextPitch('再來一球，抓住節奏。'), delay);
    }
  }

  function resolveBall(delay = 900) {
    state.balls += 1;
    state.combo = 0;
    updateUI();
    if (state.balls >= rules.BALLS_FOR_WALK) {
      showBurst('WALK', '');
      const walked = rules.forceWalk(state.bases);
      state.bases = walked.bases;
      if (walked.runs > 0) {
        state.playerScore += walked.runs;
        state.totalRuns += walked.runs;
        state.inningRuns[state.inning - 1] = (state.inningRuns[state.inning - 1] || 0) + walked.runs;
      }
      state.balls = 0;
      state.strikes = 0;
      updateUI();
      finishResolution(() => prepareNextPitch('四壞保送，跑者推進。'), delay + 120);
    } else {
      finishResolution(() => prepareNextPitch('壞球，耐心等。'), delay);
    }
  }

  function resolveContact(timing, outcome) {
    const key = outcome.key;
    if (key === 'foul') {
      state.combo = 0;
      if (state.strikes < 2) state.strikes += 1;
      updateUI();
      finishResolution(() => prepareNextPitch(state.strikes >= 2 ? '界外球，兩好球後不再追加。' : '界外球，再來。'), 980);
      return;
    }
    if (key === 'out') {
      state.combo = 0;
      registerOut(`${timing.label} · 守備接殺`, 1020);
      return;
    }

    state.hits += 1;
    state.combo += 1;
    const moved = rules.advanceRunners(state.bases, rules.basesAdvanced(key), key === 'homerun');
    state.bases = moved.bases;
    const runs = moved.runs;
    state.playerScore += runs;
    state.totalRuns += runs;
    state.inningRuns[state.inning - 1] = (state.inningRuns[state.inning - 1] || 0) + runs;
    state.balls = 0;
    state.strikes = 0;
    updateUI();
    const comboText = state.combo > 1 ? ` · COMBO ×${state.combo}` : '';
    const runText = runs > 0 ? ` · ${runs} 分進帳` : '';
    showBurst(`${outcome.label}${comboText}`, key === 'homerun' ? 'perfect' : '');
    finishResolution(() => prepareNextPitch(`${outcome.label}${runText}`), key === 'homerun' ? 1250 : 1020);
  }

  function registerOut(reason, delay = 980) {
    state.outs += 1;
    state.balls = 0;
    state.strikes = 0;
    state.combo = 0;
    updateUI();
    if (state.outs >= rules.OUTS_PER_INNING) {
      finishResolution(() => advanceInning(), delay + 220);
    } else {
      finishResolution(() => prepareNextPitch(reason), delay);
    }
  }

  function advanceInning() {
    // The opponent's half-inning is intentionally lightweight in this prototype.
    const opponentRuns = rules.opponentRuns(Math.random());
    state.rivalScore += opponentRuns;
    state.rivalInningRuns[state.inning - 1] = opponentRuns;
    state.bases = [false, false, false];
    state.outs = 0;
    state.balls = 0;
    state.strikes = 0;
    if (state.inning >= rules.TOTAL_INNINGS) {
      state.gameOver = true;
      updateUI();
      setControlsDisabled(true);
      ui.pitchButton.disabled = false;
      ui.pitchButton.querySelector('b').textContent = '再來一場';
      ui.pitchButton.querySelector('small').textContent = 'PLAY AGAIN';
      const won = state.playerScore >= state.rivalScore;
      setMessage(won ? 'FINAL · WIN' : 'FINAL · NEXT TIME', won ? `喵白白隊 ${state.playerScore} : ${state.rivalScore} 喵布布隊` : `喵布布隊 ${state.rivalScore} : ${state.playerScore} 喵白白隊`, '按「再來一場」重新挑戰');
      ui.gameMessage.classList.remove('hidden');
      showToast(won ? '比賽結束！喵白白隊拿下勝利 🏆' : '比賽結束！下一場再把球打遠。');
      return;
    }
    state.inning += 1;
    state.inningRuns[state.inning - 1] = null;
    updateUI();
    setMessage(`INNING ${state.inning}`, '新的一局，重新讀球。', '對手半局結果已自動結算');
    finishResolution(() => prepareNextPitch(`第 ${state.inning} 局開始`), 900);
  }

  function prepareNextPitch(message) {
    state.resolving = false;
    state.pitch = null;
    ui.ball.className = 'ball';
    ui.timingCursor.classList.remove('playing');
    setControlsDisabled(false);
    updateUI();
    if (message) setMessage('NEXT PITCH', message, '選球路後按投球');
  }

  function finishResolution(callback, delay = 850) {
    state.resolving = true;
    clearPitchTimer();
    setControlsDisabled(true);
    if (state.pitch) state.pitch = null;
    window.clearTimeout(state.resolveTimer);
    state.resolveTimer = window.setTimeout(callback, delay);
  }

  function clearPitchTimer() {
    if (state.pitchTimer) {
      window.clearTimeout(state.pitchTimer);
      state.pitchTimer = null;
    }
  }

  function updateUI() {
    ui.inningLabel.textContent = String(state.inning);
    ui.playerScore.textContent = String(state.playerScore);
    ui.rivalScore.textContent = String(state.rivalScore);
    ui.miniScore.textContent = `${state.playerScore}  —  ${state.rivalScore}`;
    ui.heroCombo.textContent = String(state.combo);
    ui.atBatLabel.textContent = state.gameOver ? '比賽結束' : `喵白白打擊 · ${state.outs} OUT`;
    renderLights(ui.ballCount, state.balls);
    renderLights(ui.strikeCount, state.strikes);
    renderLights(ui.outCount, state.outs);
    renderBases();
    renderInnings();
    ui.missionPerfect.textContent = `${Math.min(state.perfects, 1)}/1`;
    ui.missionHits.textContent = `${Math.min(state.hits, 3)}/3`;
    ui.missionRuns.textContent = `${Math.min(state.totalRuns, 2)}/2`;
    ui.missionPerfect.closest('.mission-item').classList.toggle('completed', state.perfects >= 1);
    ui.missionHits.closest('.mission-item').classList.toggle('completed', state.hits >= 3);
    ui.missionRuns.closest('.mission-item').classList.toggle('completed', state.totalRuns >= 2);
    ui.batterState.textContent = state.gameOver ? 'FINAL' : state.combo > 0 ? `COMBO ×${state.combo}` : 'ON DECK';
    ui.batterState.style.color = state.combo > 0 ? '#ffd56a' : '';
  }

  function renderLights(container, count) {
    [...container.children].forEach((light, index) => light.classList.toggle('lit', index < count));
  }

  function renderBases() {
    ui.bases.first.classList.toggle('occupied', state.bases[0]);
    ui.bases.second.classList.toggle('occupied', state.bases[1]);
    ui.bases.third.classList.toggle('occupied', state.bases[2]);
  }

  function renderInnings() {
    [...ui.inningScores.children].forEach((cell, index) => {
      const run = state.inningRuns[index];
      cell.classList.toggle('active', index === state.inning - 1 && !state.gameOver);
      const small = cell.querySelector('small');
      small.textContent = run === null || run === undefined ? '—' : String(run);
    });
  }

  function setControlsDisabled(disabled) {
    $$('.pitch-option').forEach((button) => { button.disabled = disabled; });
    $$('[data-aim]').forEach((button) => { button.disabled = disabled; });
    ui.pitchButton.disabled = disabled || state.gameOver;
    ui.swingButton.disabled = disabled || !state.pitch;
    if (state.gameOver) ui.pitchButton.disabled = false;
  }

  function setMessage(kicker, title, sub) {
    ui.gameMessage.querySelector('.message-kicker').textContent = kicker;
    ui.gameMessage.querySelector('strong').textContent = title;
    ui.gameMessage.querySelector('small').textContent = sub;
  }

  function showBurst(text, type = '') {
    ui.resultBurst.textContent = text;
    ui.resultBurst.className = `result-burst show ${type}`;
    window.setTimeout(() => ui.resultBurst.classList.remove('show'), 980);
  }

  function showToast(text) {
    ui.toast.textContent = text;
    ui.toast.classList.add('show');
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => ui.toast.classList.remove('show'), 2600);
  }

  function nextCoachNote() {
    state.coachIndex = (state.coachIndex + 1) % COACH_NOTES.length;
    ui.coachNote.textContent = COACH_NOTES[state.coachIndex];
  }

  function toggleSound() {
    state.sound = !state.sound;
    ui.soundButton.setAttribute('aria-pressed', String(state.sound));
    ui.soundIcon.textContent = state.sound ? '🔊' : '🔇';
    showToast(state.sound ? '音效已開啟' : '音效已靜音');
  }

  function openTutorial() {
    ui.howToPlayModal.hidden = false;
    ui.modalClose.focus();
  }

  function closeTutorial() {
    ui.howToPlayModal.hidden = true;
  }

  function resetGame() {
    clearPitchTimer();
    window.clearTimeout(state.resolveTimer);
    state.inning = 1;
    state.outs = 0;
    state.balls = 0;
    state.strikes = 0;
    state.playerScore = 0;
    state.rivalScore = 0;
    state.inningRuns = Array(9).fill(null);
    state.rivalInningRuns = Array(9).fill(null);
    state.bases = [false, false, false];
    state.pitch = null;
    state.resolving = false;
    state.gameOver = false;
    state.gameStarted = false;
    state.combo = 0;
    state.hits = 0;
    state.perfects = 0;
    state.totalRuns = 0;
    ui.ball.className = 'ball';
    ui.pitchButton.querySelector('b').textContent = '投球';
    ui.pitchButton.querySelector('small').textContent = 'THROW PITCH';
    selectPitch(state.selectedPitch);
    updateUI();
    setControlsDisabled(false);
    setMessage('READY?', '選球後按「投球」', '靠近本壘時按下揮棒');
    showToast('新比賽開始，準備好揮棒！');
  }

  init();
})();
