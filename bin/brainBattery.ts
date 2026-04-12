// Heuristic details (tunable):
// - If you coded > threshold minutes in the 15-min window → coding interval (drains)
// - Else → break interval (recharges faster than it drains)
// - New day automatically resets fatigue to 0

import fs from "fs/promises";
import path from "path";
import os from "os";
import { Buffer } from "buffer";
import dotenv from "dotenv";

enum IntervalStatus {
  coding = "coding",
  break = "break",
}

interface State {
  last_date_time: string;
  current_fatigue_minutes: number;
  current_interval_status: IntervalStatus;
  last_cumulative_seconds: number;
}

interface Config {
  capacityMinutes: number;
  drainRate: number;
  codingThresholdMinutes: number;
  rechargeMinutesPerBreak: number;
}

const MS_IN_MINUTES = 1000 * 60;
const SECONDS_IN_MINUTES = 60;
const MINUTES_IN_INTERVALS = 15;
const CONFIG_DIR = path.join(os.homedir(), ".config", "brain-battery");
const ENV_FILE = path.join(CONFIG_DIR, ".env");
dotenv.config({ path: ENV_FILE });
const CONFIG_FILE = path.join(CONFIG_DIR, "config.json");
const STATE_FILE = path.join(os.homedir(), ".brain-waka-state.json");
const BATTERY_FILE = path.join(os.homedir(), ".brain-battery.json");
const WAKATIME_API_KEY = process.env.WAKATIME_API_KEY;
const SLACK_TOKEN = process.env.SLACK_TOKEN;

if (!WAKATIME_API_KEY || !SLACK_TOKEN) {
  console.error(
    "Missing WAKATIME_API_KEY or SLACK_TOKEN environment variables",
  );
  process.exit(1);
}

let userConfig: Config;

async function loadConfig(): Promise<void> {
  try {
    await fs.mkdir(CONFIG_DIR, { recursive: true });
    const data = await fs.readFile(CONFIG_FILE, "utf-8");
    userConfig = JSON.parse(data);
  } catch (e) {
    console.error("Failed to load user config.");
  }
}

async function loadState(): Promise<State> {
  try {
    const data = await fs.readFile(STATE_FILE, "utf-8");
    return JSON.parse(data);
  } catch {
    const now = new Date().toISOString();
    return {
      last_date_time: now,
      current_fatigue_minutes: 0,
      current_interval_status: IntervalStatus.break,
      last_cumulative_seconds: 0,
    };
  }
}

async function saveState(state: State): Promise<void> {
  await fs.writeFile(STATE_FILE, JSON.stringify(state, null, 2));
}

async function fetchTotalSeconds(start: string, end: string): Promise<number> {
  const url =
    `https://wakatime.com/api/v1/users/current/summaries?` +
    `start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}`;

  const auth = Buffer.from(`${WAKATIME_API_KEY}:`).toString("base64");
  const response = await fetch(url, {
    headers: {
      Authorization: `Basic ${auth}`,
    },
  });

  if (!response.ok) {
    throw new Error(
      `WakaTime API error: ${response.status} ${response.statusText}`,
    );
  }

  const result: any = await response.json();
  let totalSeconds = 0;
  if (result.data && Array.isArray(result.data)) {
    for (const day of result.data) {
      if (day.grand_total?.total_seconds != null) {
        totalSeconds += day.grand_total.total_seconds;
      }
    }
  }
  return totalSeconds;
}

function calculateBrainBattery(fatigue: number): number {
  const soc =
    ((userConfig.capacityMinutes - fatigue) / userConfig.capacityMinutes) * 100;
  return Math.max(0, Math.min(100, soc));
}

function getEmoji(soc: number, isCoding: IntervalStatus): string {
  if (isCoding === IntervalStatus.break) return ":battery-charging:";
  if (soc >= 70) return ":battery-plenty:";
  if (soc >= 40) return ":battery-half:";
  if (soc >= 15) return ":battery-few:";
  if (soc > 0) return ":battery-little:";
  return ":battery-empty:";
}

async function checkIfSlackStatusCanBeUpdated(): Promise<boolean> {
  const profilePromise = fetch("https://slack.com/api/users.profile.get", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${SLACK_TOKEN}`,
    },
  }).then((res) => res.json());

  const presencePromise = fetch("https://slack.com/api/users.getPresence", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${SLACK_TOKEN}`,
    },
  }).then((res) => res.json());

  const [getResult, presenceResult]: any = await Promise.all([
    profilePromise,
    presencePromise,
  ]);

  if (!getResult.ok) {
    console.error(
      "Failed to fetch current Slack status:",
      getResult.error || getResult,
    );
    return false; // safety: don't update if we can't check
  }

  if (!presenceResult.ok) {
    console.error(
      "Failed to fetch Slack presence:",
      presenceResult.error || presenceResult,
    );
    return false; // safety: don't update if we can't check
  }

  // Return false if user is away (we only want to update when active)
  if (presenceResult.presence === "away") {
    return false;
  }

  const currentEmoji = getResult.profile?.status_emoji || "";

  if (currentEmoji && !currentEmoji.startsWith(":battery-")) {
    return false;
  } else return true;
}

export async function updateSlackStatus(
  soc: number,
  state: State,
): Promise<void> {
  const canUpdate: boolean = await checkIfSlackStatusCanBeUpdated();

  if (!canUpdate) return;

  const emoji = getEmoji(soc, state.current_interval_status);
  const statusText = `Brain: ${Math.round(soc)}%`;

  const postResponse = await fetch("https://slack.com/api/users.profile.set", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${SLACK_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      profile: {
        status_text: statusText,
        status_emoji: emoji,
        status_expiration: 0,
      },
    }),
  });

  const result: any = await postResponse.json();
  if (!result.ok) {
    console.error("Slack update failed:", result.error || result);
  }
}

async function writeBrainBatteryFile(soc: number): Promise<void> {
  const payload = {
    soc: Number(soc.toFixed(1)),
    timestamp: new Date().toISOString(),
  };
  await fs.writeFile(BATTERY_FILE, JSON.stringify(payload, null, 2));
}

async function updateStateLive(state: State, now: string): Promise<void> {
  const currentTotalSeconds = await fetchTotalSeconds(
    state.last_date_time,
    now,
  );
  const deltaCodingSeconds = Math.max(
    0,
    currentTotalSeconds - state.last_cumulative_seconds,
  );
  const deltaCodingMinutes = deltaCodingSeconds / SECONDS_IN_MINUTES;
  const isCodingInterval =
    deltaCodingMinutes > userConfig.codingThresholdMinutes;

  if (isCodingInterval) {
    const drainMinutes = deltaCodingMinutes * userConfig.drainRate;
    state.current_fatigue_minutes = Math.min(
      state.current_fatigue_minutes + drainMinutes,
      userConfig.capacityMinutes,
    );
    state.current_interval_status = IntervalStatus.coding;
  } else {
    state.current_fatigue_minutes = Math.max(
      0,
      state.current_fatigue_minutes - userConfig.rechargeMinutesPerBreak,
    );
    state.current_interval_status = IntervalStatus.break;
  }

  state.last_cumulative_seconds = currentTotalSeconds;
  state.last_date_time = now;
}

async function updateStateReplay(state: State, now: string): Promise<void> {
  const currentTotalSeconds = await fetchTotalSeconds(
    state.last_date_time,
    now,
  );
  const deltaCodingSeconds = Math.max(
    0,
    currentTotalSeconds - state.last_cumulative_seconds,
  );
  const deltaCodingMinutes = deltaCodingSeconds / SECONDS_IN_MINUTES;

  const diffInMinutes = diffMinutes(state, now);
  const drainMinutes = deltaCodingMinutes * userConfig.drainRate;
  const breakMinutes = Math.max(diffInMinutes - deltaCodingMinutes, 0);
  const rechargeMinutes =
    (breakMinutes / MINUTES_IN_INTERVALS) * userConfig.rechargeMinutesPerBreak;

  state.current_fatigue_minutes = Math.min(
    state.current_fatigue_minutes + drainMinutes,
    userConfig.capacityMinutes,
  );
  state.current_fatigue_minutes = Math.max(
    0,
    state.current_fatigue_minutes - rechargeMinutes,
  );
  state.current_interval_status = IntervalStatus.coding;
  state.last_date_time = now;
}

function diffMinutes(state: State, now: string): number {
  const lastRunTime = new Date(state.last_date_time);
  const thisRunTime = new Date(now);
  const diffInMs = thisRunTime.getTime() - lastRunTime.getTime();
  const diffInMinutes = Math.round(diffInMs / MS_IN_MINUTES);
  return diffInMinutes;
}

async function runOnce(): Promise<void> {
  await loadConfig();
  const state: State = await loadState();
  const now = new Date().toISOString();
  const minutesSinceLastCall = diffMinutes(state, now);
  const shouldRefetch: boolean =
    minutesSinceLastCall >= MINUTES_IN_INTERVALS;
  const isNewSession: boolean = minutesSinceLastCall > MINUTES_IN_INTERVALS;

  if (shouldRefetch) {
    if (isNewSession) {
      await updateStateReplay(state, now);
    } else {
      await updateStateLive(state, now);
    }
    await saveState(state);
  }

  const soc = calculateBrainBattery(state.current_fatigue_minutes);
  await writeBrainBatteryFile(soc);

  if (shouldRefetch) await updateSlackStatus(soc, state);
}

runOnce().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
