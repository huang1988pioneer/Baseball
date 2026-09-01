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
    halfBadge: $('#halfBadge'),
    halfAttack: $('#halfAttack'),
    inningHeads: $('#inningHeads'),
    awayInningScores: $('#awayInningScores'),
    homeInningScores: $('#homeInningScores'),
    awayScore: $('#awayScore'),
    homeScore: $('#homeScore'),
    awayRow: $('#awayRow'),
    homeRow: $('#homeRow'),
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
    awayTeamName: $('#awayTeamName'),
    awayTeamSub: $('#awayTeamSub'),
    homeTeamName: $('#homeTeamName'),
    homeTeamSub: $('#homeTeamSub'),
    awayCrest: $('#awayCrest'),
    homeCrest: $('#homeCrest'),
    awayTag: $('#awayTag'),
    homeTag: $('#homeTag'),
    controlsLabel: $('#controlsLabel'),
    controlsHint: $('#controlsHint'),
    setupModal: $('#setupModal'),
    characterOptions: $('#characterOptions'),
    teamOptions: $('#teamOptions'),
    setupSummary: $('#setupSummary'),
    startMatchButton: $('#startMatchButton'),
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
    awayInningRuns: Array(9).fill(null),
    homeInningRuns: Array(9).fill(null),
    bases: [false, false, false], // first, second, third
    selectedPitch: 'fastball',
    aim: 4,
    pitch: null,
    pitchTimer: null,
    resolveTimer: null,
    autoPitchTimer: null,
    cpuSwingTimer: null,
    resolving: false,
    gameOver: false,
    gameStarted: false,
    matchReady: false,
    characterId: 'meow_white',
    teamId: 'home',
    half: 'top',
    combo: 0,
    hits: 0,
    perfects: 0,
    totalRuns: 0,
    sound: true,
    coachIndex: 0,
  };

  let toastTimer = null;
  let pendingCharacter = '';
  let pendingTeam = '';

  function init() {
    buildInningStrip();
    buildCountLights();
    buildSetup();
    bindEvents();
    selectPitch('fastball');
    selectAim(4);
    updateUI();
    setMessage('LINEUP', '先選角色與球隊', '選好後再開始比賽');
    setControlsDisabled(true);
    showSetup();
  }

  function playerCharacter() {
    return rules.CHARACTERS[state.characterId];
  }

  function playerTeam() {
    return rules.TEAMS[state.teamId];
  }

  function rivalTeam() {
    return rules.TEAMS[state.teamId === 'home' ? 'away' : 'home'];
  }

  function isPitcher() {
    return playerCharacter().role === 'pitcher';
  }

  function isBatter() {
    return playerCharacter().role === 'batter';
  }

  function isPlayerOffense() {
    return state.half === 'top' ? state.teamId === 'away' : state.teamId === 'home';
  }

  function isFielding() {
    return !isPlayerOffense();
  }

  function halfLabel() {
    return state.half === 'top' ? '上半局' : '下半局';
  }

  function battingSide() {
    return state.half === 'top' ? 'away' : 'home';
  }

  function awayScoreValue() {
    return state.teamId === 'away' ? state.playerScore : state.rivalScore;
  }

  function homeScoreValue() {
    return state.teamId === 'home' ? state.playerScore : state.rivalScore;
  }

  function buildSetup() {
    ui.characterOptions.innerHTML = '';
    rules.CHARACTER_ORDER.forEach((id) => {
      const character = rules.CHARACTERS[id];
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'setup-card';
      button.dataset.character = id;
      button.innerHTML = `<img src="${rules.artPath(character.art)}" alt="" /><b>${character.name}</b><small>${character.roleLabel}  ·  ${character.number}</small><em>${character.blurb}</em>`;
      ui.characterOptions.appendChild(button);
    });
    ui.teamOptions.innerHTML = '';
    rules.TEAM_ORDER.forEach((id) => {
      const team = rules.TEAMS[id];
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'setup-card setup-team-card';
      button.dataset.team = id;
      button.innerHTML = `<img src="${rules.artPath(team.art)}" alt="" /><span><b>${team.name}</b><small>${team.short}</small></span>`;
      ui.teamOptions.appendChild(button);
    });
    refreshSetup();
  }

  function showSetup() {
    ui.setupModal.hidden = false;
    refreshSetup();
  }

  function hideSetup() {
    ui.setupModal.hidden = true;
  }

  function selectSetupCharacter(id) {
    if (!rules.CHARACTERS[id]) return;
    pendingCharacter = id;
    refreshSetup();
  }

  function selectSetupTeam(id) {
    if (!rules.TEAMS[id]) return;
    pendingTeam = id;
    refreshSetup();
  }

  function refreshSetup() {
    $$('#characterOptions .setup-card').forEach((button) => {
      button.classList.toggle('selected', button.dataset.character === pendingCharacter);
    });
    $$('#teamOptions .setup-card').forEach((button) => {
      button.classList.toggle('selected', button.dataset.team === pendingTeam);
    });
    const ready = Boolean(pendingCharacter && pendingTeam);
    ui.startMatchButton.disabled = !ready;
    if (ready) {
      const character = rules.CHARACTERS[pendingCharacter];
      const team = rules.TEAMS[pendingTeam];
      ui.setupSummary.textContent = `以${character.name}（${character.roleLabel}）為${team.name}出賽`;
    } else {
      ui.setupSummary.textContent = '請先點選角色與球隊。';
    }
  }

  function startMatch() {
    if (!pendingCharacter || !pendingTeam) return;
    state.characterId = pendingCharacter;
    state.teamId = pendingTeam;
    state.half = 'top';
    state.matchReady = true;
    hideSetup();
    applyMatchIdentity();
    beginMatch();
  }

  function applyMatchIdentity() {
    const character = playerCharacter();
    const team = playerTeam();
    const away = rules.TEAMS.away;
    const home = rules.TEAMS.home;
    ui.awayTeamName.textContent = away.name;
    ui.awayTeamSub.textContent = away.short;
    ui.homeTeamName.textContent = home.name;
    ui.homeTeamSub.textContent = home.short;
    ui.awayCrest.src = rules.artPath(away.art);
    ui.homeCrest.src = rules.artPath(home.art);
    ui.awayTag.textContent = state.teamId === 'away' ? '我' : '客';
    ui.homeTag.textContent = state.teamId === 'home' ? '我' : '主';
    syncHalfControls();
    updateUI();
    showToast(`${character.name}加入${team.name} · 客隊上半先攻`);
  }

  function beginMatch() {
    selectPitch(state.selectedPitch);
    selectAim(state.aim);
    beginHalf('第 1 局上半開始');
  }

  function beginHalf(message) {
    syncHalfControls();
    setControlsDisabled(false);
    if (isPlayerOffense()) {
      setMessage('BATTER UP', message || '輪到我們打擊', '最快 3 秒、最慢 15 秒內投出');
      scheduleAutoPitch();
    } else {
      setMessage('ON THE MOUND', message || '輪到我們守備', '選球路後按投球，對手會自動揮棒');
    }
  }

  function syncHalfControls() {
    if (!state.matchReady || state.gameOver) return;
    ui.controlsLabel.textContent = isPlayerOffense() ? '預判球路' : '選擇球路';
    ui.controlsHint.innerHTML = isPlayerOffense()
      ? '<kbd>SPACE</kbd> 揮棒 · 投手 3–15 秒自動投球'
      : '<kbd>ENTER</kbd> 投球 · 對手自動打擊';
    ui.pitchButton.querySelector('b').textContent = isPlayerOffense() ? '等待投球' : '投球';
    ui.pitchButton.querySelector('small').textContent = isPlayerOffense() ? 'CPU PITCH' : 'THROW PITCH';
  }

  function scheduleAutoPitch() {
    if (!isPlayerOffense() || state.gameOver || state.pitch || state.resolving || !state.matchReady) return;
    clearAutoPitch();
    const delay = rules.autoPitchDelay(Math.random()) * 1000;
    ui.pitchSpeedReadout.textContent = `投手準備中 · ${(delay / 1000).toFixed(1)} 秒內出手`;
    state.autoPitchTimer = window.setTimeout(() => {
      if (!isPlayerOffense() || state.gameOver || state.pitch || state.resolving) return;
      state.selectedPitch = rules.cpuPickPitch();
      selectPitch(state.selectedPitch);
      startPitch();
    }, delay);
  }

  function scheduleCpuBatter() {
    if (!isFielding() || !state.pitch) return;
    const plan = rules.cpuBatterPlan(state.pitch.inZone, state.pitch.ideal);
    if (plan.action !== 'swing') return;
    clearCpuSwing();
    const wait = state.pitch.duration * plan.progress;
    state.cpuSwingTimer = window.setTimeout(() => {
      if (!state.pitch) return;
      swing(rules.cpuSwingAim(state.pitch.zone));
    }, wait);
  }

  function clearAutoPitch() {
    if (state.autoPitchTimer) {
      window.clearTimeout(state.autoPitchTimer);
      state.autoPitchTimer = null;
    }
  }

  function clearCpuSwing() {
    if (state.cpuSwingTimer) {
      window.clearTimeout(state.cpuSwingTimer);
      state.cpuSwingTimer = null;
    }
  }

  function buildInningStrip() {
    ui.inningHeads.innerHTML = '';
    ui.awayInningScores.innerHTML = '';
    ui.homeInningScores.innerHTML = '';
    for (let i = 0; i < 9; i += 1) {
      const head = document.createElement('span');
      head.textContent = String(i + 1);
      ui.inningHeads.appendChild(head);
      [ui.awayInningScores, ui.homeInningScores].forEach((row) => {
        const cell = document.createElement('span');
        cell.dataset.inning = String(i + 1);
        cell.innerHTML = `<small>—</small>`;
        row.appendChild(cell);
      });
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
    ui.characterOptions.addEventListener('click', (event) => {
      const button = event.target.closest('[data-character]');
      if (button) selectSetupCharacter(button.dataset.character);
    });
    ui.teamOptions.addEventListener('click', (event) => {
      const button = event.target.closest('[data-team]');
      if (button) selectSetupTeam(button.dataset.team);
    });
    ui.startMatchButton.addEventListener('click', startMatch);

    ui.pitchOptions.addEventListener('click', (event) => {
      const button = event.target.closest('[data-pitch]');
      if (!button || !state.matchReady || state.pitch || state.resolving || state.gameOver) return;
      selectPitch(button.dataset.pitch);
    });

    ui.aimGrid.addEventListener('click', (event) => {
      const button = event.target.closest('[data-aim]');
      if (!button || !state.matchReady || state.pitch || state.resolving || state.gameOver) return;
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
      if (!ui.setupModal.hidden) {
        if (event.key === 'Enter') {
          event.preventDefault();
          startMatch();
        }
        return;
      }
      if (event.code === 'Space') {
        event.preventDefault();
        if (isPlayerOffense()) swing();
        return;
      }
      if (event.key === 'Enter' || event.key === 't' || event.key === 'T') {
        event.preventDefault();
        if (state.gameOver) resetGame();
        else if (isFielding()) startPitch();
        return;
      }
      if (event.key === 'r' || event.key === 'R') {
        event.preventDefault();
        resetGame();
        return;
      }
      const pitchKeys = { '1': 'fastball', '2': 'curveball', '3': 'slider', '4': 'changeup' };
      if (pitchKeys[event.key] && state.matchReady && !state.pitch && !state.resolving && !state.gameOver) {
        selectPitch(pitchKeys[event.key]);
      }
      if (event.key.startsWith('Arrow') && state.matchReady && !state.pitch && !state.resolving && !state.gameOver) {
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
    if (!state.matchReady || state.pitch || state.resolving || state.gameOver) return;
    clearAutoPitch();
    state.gameStarted = true;
    const definition = PITCHES[state.selectedPitch];
    const durationMs = rules.durationMs(definition);
    const inZone = Math.random() > (1 - rules.IN_ZONE_CHANCE);
    const zone = inZone ? (isFielding() ? state.aim : Math.floor(Math.random() * 9)) : -1;
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
    if (isPlayerOffense()) {
      setMessage('WATCH THE BALL', '準備揮棒！', '球越靠近本壘，Timing 越漂亮');
    } else {
      setMessage('THE PITCH', '球已出手', '對手會自動打擊');
    }
    ui.gameMessage.classList.remove('hidden');
    setControlsDisabled(true);
    if (isPlayerOffense()) {
      ui.swingButton.disabled = false;
      ui.swingButton.classList.add('pulse');
      window.setTimeout(() => ui.swingButton.classList.remove('pulse'), 520);
    }

    state.pitchTimer = window.setTimeout(() => pitchArrived(), durationMs + 75);
    if (isFielding()) scheduleCpuBatter();
  }

  function pitchArrived() {
    if (!state.pitch) return;
    // A take is resolved just after the ball reaches the plate.
    resolveTake();
  }

  function swing(aimOverride) {
    if (!state.pitch) {
      if (!state.gameOver && !state.resolving && isPlayerOffense()) showToast('等投手把球投進來再揮棒！');
      return;
    }
    if (state.resolving) return;
    const pitch = state.pitch;
    const now = performance.now();
    const progress = Math.max(0, Math.min(1.12, (now - pitch.startedAt) / pitch.duration));
    const usedAim = Number.isInteger(aimOverride) ? aimOverride : state.aim;
    clearPitchTimer();
    clearCpuSwing();
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

    const aimDistance = pitch.inZone ? rules.gridDistance(usedAim, pitch.zone) : 2;
    const outcome = rules.rollOutcome(timing.grade, aimDistance);
    if (timing.grade === 'PERFECT' && isPlayerOffense()) {
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
      if (walked.runs > 0) addRuns(walked.runs);
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

    if (isPlayerOffense()) {
      state.hits += 1;
      state.combo += 1;
    } else {
      state.combo = 0;
    }
    const moved = rules.advanceRunners(state.bases, rules.basesAdvanced(key), key === 'homerun');
    state.bases = moved.bases;
    const runs = moved.runs;
    addRuns(runs);
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
      finishResolution(() => switchHalf(), delay + 220);
    } else {
      finishResolution(() => prepareNextPitch(reason), delay);
    }
  }

  function addRuns(runs) {
    if (runs <= 0) return;
    if (isPlayerOffense()) {
      state.playerScore += runs;
      state.totalRuns += runs;
      state.inningRuns[state.inning - 1] = (state.inningRuns[state.inning - 1] || 0) + runs;
    } else {
      state.rivalScore += runs;
    }
    const line = state.half === 'top' ? state.awayInningRuns : state.homeInningRuns;
    line[state.inning - 1] = (line[state.inning - 1] || 0) + runs;
  }

  function addPlayerRuns(runs) {
    if (runs <= 0) return;
    state.playerScore += runs;
    state.totalRuns += runs;
    state.inningRuns[state.inning - 1] = (state.inningRuns[state.inning - 1] || 0) + runs;
  }

  function homeAhead() {
    const homeScore = state.teamId === 'home' ? state.playerScore : state.rivalScore;
    const awayScore = state.teamId === 'home' ? state.rivalScore : state.playerScore;
    return homeScore > awayScore;
  }

  function endGame() {
    state.gameOver = true;
    state.resolving = false;
    state.pitch = null;
    if (state.inningRuns[state.inning - 1] == null) state.inningRuns[state.inning - 1] = 0;
    updateUI();
    setControlsDisabled(true);
    ui.pitchButton.disabled = false;
    ui.pitchButton.querySelector('b').textContent = '再來一場';
    ui.pitchButton.querySelector('small').textContent = 'PLAY AGAIN';
    const won = state.playerScore >= state.rivalScore;
    const playerName = playerTeam().name;
    const rivalName = rivalTeam().name;
    setMessage(
      won ? 'FINAL · WIN' : 'FINAL · NEXT TIME',
      won ? `${playerName} ${state.playerScore} : ${state.rivalScore} ${rivalName}` : `${rivalName} ${state.rivalScore} : ${state.playerScore} ${playerName}`,
      '按「再來一場」重新選擇角色與球隊'
    );
    ui.gameMessage.classList.remove('hidden');
    showToast(won ? `比賽結束！${playerName}拿下勝利 🏆` : '比賽結束！下一場再來。');
  }

  function switchHalf() {
    const line = state.half === 'top' ? state.awayInningRuns : state.homeInningRuns;
    if (line[state.inning - 1] == null) line[state.inning - 1] = 0;
    if (isPlayerOffense() && state.inningRuns[state.inning - 1] == null) {
      state.inningRuns[state.inning - 1] = 0;
    }
    state.bases = [false, false, false];
    state.outs = 0;
    state.balls = 0;
    state.strikes = 0;
    state.combo = 0;
    state.pitch = null;
    state.resolving = true;
    if (state.half === 'top') {
      if (state.inning >= rules.TOTAL_INNINGS && homeAhead()) {
        endGame();
        return;
      }
      state.half = 'bottom';
      updateUI();
      syncHalfControls();
      setMessage('攻守轉換', '下半局開始', isPlayerOffense() ? '客隊三人出局，換我們打擊。' : '客隊三人出局，換我們守備投球。');
      finishResolution(() => prepareNextPitch(`第 ${state.inning} 局下半開始`), 1050);
      return;
    }
    if (state.inning >= rules.TOTAL_INNINGS) {
      endGame();
      return;
    }
    state.inning += 1;
    state.half = 'top';
    updateUI();
    syncHalfControls();
    setMessage(`INNING ${state.inning}`, `第 ${state.inning} 局上半開始`, isPlayerOffense() ? '攻守再轉換，換我們打擊。' : '攻守再轉換，換我們守備投球。');
    finishResolution(() => prepareNextPitch(`第 ${state.inning} 局開始`), 1050);
  }

  function prepareNextPitch(message) {
    state.resolving = false;
    state.pitch = null;
    ui.ball.className = 'ball';
    ui.timingCursor.classList.remove('playing');
    setControlsDisabled(false);
    updateUI();
    if (state.gameOver || !state.matchReady) return;
    beginHalf(message);
  }

  function finishResolution(callback, delay = 850) {
    state.resolving = true;
    clearPitchTimer();
    clearCpuSwing();
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
    const top = state.half === 'top';
    ui.inningLabel.textContent = String(state.inning);
    ui.halfAttack.textContent = top ? '客隊進攻' : '主隊進攻';
    ui.halfBadge.textContent = `${top ? '▲' : '▼'} ${halfLabel()}`;
    ui.halfBadge.classList.toggle('bottom', !top);
    ui.awayScore.textContent = String(awayScoreValue());
    ui.homeScore.textContent = String(homeScoreValue());
    ui.miniScore.textContent = `${awayScoreValue()}  —  ${homeScoreValue()}`;
    ui.heroCombo.textContent = String(state.combo);
    const batting = rules.TEAMS[battingSide()];
    const roleVerb = isPlayerOffense() ? '打擊' : '守備';
    ui.atBatLabel.textContent = state.gameOver ? '比賽結束' : `${halfLabel()} · ${batting.name}進攻 · ${state.outs} OUT · ${roleVerb}`;
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
    ui.awayRow.classList.toggle('batting', state.half === 'top' && !state.gameOver);
    ui.homeRow.classList.toggle('batting', state.half === 'bottom' && !state.gameOver);
    paintInningLine(ui.awayInningScores, state.awayInningRuns, state.half === 'top');
    paintInningLine(ui.homeInningScores, state.homeInningRuns, state.half === 'bottom');
  }

  function paintInningLine(container, runs, batting) {
    [...container.children].forEach((cell, index) => {
      const run = runs[index];
      cell.classList.toggle('active', batting && index === state.inning - 1 && !state.gameOver);
      const small = cell.querySelector('small');
      small.textContent = run === null || run === undefined ? '—' : String(run);
    });
  }

  function setControlsDisabled(disabled) {
    if (!state.matchReady) disabled = true;
    $$('.pitch-option').forEach((button) => { button.disabled = disabled; });
    $$('[data-aim]').forEach((button) => { button.disabled = disabled; });
    ui.pitchButton.disabled = disabled || (isPlayerOffense() && !state.gameOver);
    ui.swingButton.disabled = disabled || !state.pitch || isFielding();
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
    clearAutoPitch();
    clearCpuSwing();
    window.clearTimeout(state.resolveTimer);
    state.inning = 1;
    state.outs = 0;
    state.balls = 0;
    state.strikes = 0;
    state.playerScore = 0;
    state.rivalScore = 0;
    state.inningRuns = Array(9).fill(null);
    state.rivalInningRuns = Array(9).fill(null);
    state.awayInningRuns = Array(9).fill(null);
    state.homeInningRuns = Array(9).fill(null);
    state.bases = [false, false, false];
    state.pitch = null;
    state.resolving = false;
    state.gameOver = false;
    state.gameStarted = false;
    state.matchReady = false;
    state.half = 'top';
    state.combo = 0;
    state.hits = 0;
    state.perfects = 0;
    state.totalRuns = 0;
    ui.ball.className = 'ball';
    ui.pitchButton.querySelector('b').textContent = '投球';
    ui.pitchButton.querySelector('small').textContent = 'THROW PITCH';
    selectPitch(state.selectedPitch);
    updateUI();
    setControlsDisabled(true);
    setMessage('LINEUP', '先選角色與球隊', '選好後再開始比賽');
    showSetup();
    showToast('回到選角，準備下一場。');
  }

  init();
})();
