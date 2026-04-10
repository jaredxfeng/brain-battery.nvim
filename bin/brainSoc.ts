// Heuristic details (tunable):
// - If you coded > 5 minutes in the 15-min window → coding interval (drains)
// - Else → break interval (recharges faster than it drains)
// - New day automatically resets fatigue to 0

import fs from "fs/promises";
import path from "path";
import os from "os";
import { Buffer } from "buffer";
import dotenv from "dotenv";

const CONFIG_DIR = path.join(os.homedir(), ".config", "brain-soc");
const ENV_FILE = path.join(CONFIG_DIR, ".env");
const CONFIG_FILE = path.join(CONFIG_DIR, "config.json");

dotenv.config({ path: ENV_FILE });

// Default values (will be overridden by config.json if it exists)
let CONFIG = {
  capacityMinutes: 300,
  drainRate: 1.1,
  codingThresholdMinutes: 5, // renamed from codingThresholdMinutes
  rechargeMinutesPerBreak: 25,
};

async function loadConfig(): Promise<void> {
  try {
    await fs.mkdir(CONFIG_DIR, { recursive: true });
    const data = await fs.readFile(CONFIG_FILE, "utf-8");
    const userConfig = JSON.parse(data);
    CONFIG = { ...CONFIG, ...userConfig };
    console.log("Loaded user config from ~/.config/brain-soc/config.json");
  } catch (e) {
    // First run or no config yet → create default
    await fs.mkdir(CONFIG_DIR, { recursive: true });
    await fs.writeFile(CONFIG_FILE, JSON.stringify(CONFIG, null, 2));
    console.log("Created default config in ~/.config/brain-soc/config.json");
  }
}

const STATE_FILE = path.join(os.homedir(), ".brain-waka-state.json");
const SOC_FILE = path.join(os.homedir(), ".brain-soc.json");
const WAKATIME_API_KEY = process.env.WAKATIME_API_KEY;
const SLACK_TOKEN = process.env.SLACK_TOKEN;

if (!WAKATIME_API_KEY || !SLACK_TOKEN) {
  console.error(
    "Missing WAKATIME_API_KEY or SLACK_TOKEN environment variables",
  );
  process.exit(1);
}

enum IntervalStatus {
  coding = "coding",
  break = "break",
}

interface State {
  last_date: string;
  last_total_seconds: number;
  current_fatigue_minutes: number;
  current_interval_status: IntervalStatus;
}

async function loadState(): Promise<State> {
  try {
    const data = await fs.readFile(STATE_FILE, "utf-8");
    return JSON.parse(data);
  } catch {
    return {
      last_date: "",
      last_total_seconds: 0,
      current_fatigue_minutes: 0,
      current_interval_status: IntervalStatus.break,
    };
  }
}

async function saveState(state: State): Promise<void> {
  await fs.writeFile(STATE_FILE, JSON.stringify(state, null, 2));
}

async function fetchTodayTotalSeconds(): Promise<number> {
  // WakaTime supports "today" as a special value and automatically respects your account timezone
  const url =
    "https://wakatime.com/api/v1/users/current/summaries?start=today&end=today";

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
  return result.data?.[0]?.grand_total?.total_seconds ?? 0;
}

function calculateBrainSOC(fatigue: number): number {
  const soc =
    ((CONFIG.capacityMinutes - fatigue) / CONFIG.capacityMinutes) * 100;
  return Math.max(0, Math.min(100, soc));
}

function getEmoji(soc: number, isCoding: IntervalStatus): string {
  if (isCoding === IntervalStatus.break) return ":battery-charging:";
  if (soc >= 70) return ":battery-plenty:";
  if (soc >= 40) return ":battery-half:";
  if (soc >= 15) return ":battery-few:";
  if (soc > 0) return ":battery-little";
  return ":battery-empty:";
}

async function checkIfSlackStatusCanBeUpdated(): Promise<boolean> {
  const getResponse = await fetch("https://slack.com/api/users.profile.get", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${SLACK_TOKEN}`,
    },
  });
  const getResult: any = await getResponse.json();

  if (!getResult.ok) {
    console.error(
      "Failed to fetch current Slack status:",
      getResult.error || getResult,
    );
    return false; // safety: don't update if we can't check
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
  const statusText = `Brain SOC: ${Math.round(soc)}%`;

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
        status_expiration: 0, // if you want it to never expire
      },
    }),
  });

  const result: any = await postResponse.json();
  if (!result.ok) {
    console.error("Slack update failed:", result.error || result);
  }
}

async function writeSOCFile(soc: number): Promise<void> {
  const payload = {
    soc: Number(soc.toFixed(1)),
    percentage: `${Math.round(soc)}%`,
    timestamp: new Date().toISOString(),
    fatigue_minutes: Number(CONFIG.capacityMinutes.toFixed(1)), // for plugin debugging if needed
  };
  await fs.writeFile(SOC_FILE, JSON.stringify(payload, null, 2));
  console.log(`Brain SOC written to ${SOC_FILE}`);
}

function getDeltaMinutes(
  state: State,
  todayStr: string,
  currentTotalSeconds: number,
): number {
  let deltaSeconds = 0;
  if (state.last_date === todayStr) {
    deltaSeconds = Math.max(0, currentTotalSeconds - state.last_total_seconds);
  } else {
    state.current_fatigue_minutes = 0;
    deltaSeconds = currentTotalSeconds;
  }
  const deltaMinutes = deltaSeconds / 60;
  return deltaMinutes;
}

function updateState(
  state: State,
  todayStr: string,
  currentTotalSeconds: number,
): void {
  const deltaMinutes = getDeltaMinutes(state, todayStr, currentTotalSeconds);
  const isCodingInterval = deltaMinutes > CONFIG.codingThresholdMinutes;

  if (isCodingInterval) {
    const drain = deltaMinutes * CONFIG.drainRate;
    state.current_fatigue_minutes = Math.min(
      state.current_fatigue_minutes + drain,
      CONFIG.capacityMinutes,
    );
    state.current_interval_status = IntervalStatus.coding;
  } else {
    state.current_fatigue_minutes = Math.max(
      0,
      state.current_fatigue_minutes - CONFIG.rechargeMinutesPerBreak,
    );
    state.current_interval_status = IntervalStatus.break;
  }

  state.last_date = todayStr;
  state.last_total_seconds = currentTotalSeconds;
}

async function runOnce() {
  await loadConfig();
  console.log("Config loaded");
  console.log(`Configs: ${JSON.stringify(CONFIG)}`);
  const state: State = await loadState();
  const todayStr = new Date().toISOString().split("T")[0];
  const currentTotalSeconds = await fetchTodayTotalSeconds();
  updateState(state, todayStr, currentTotalSeconds);
  const soc = calculateBrainSOC(state.current_fatigue_minutes);
  await saveState(state);

  // Two output actions
  await writeSOCFile(soc);
  await updateSlackStatus(soc, state);

  console.log(`Brain SOC: ${soc}% `);
}

runOnce().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
