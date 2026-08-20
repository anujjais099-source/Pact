import { firestore } from "firebase-admin";

export type Timestamp = firestore.Timestamp;

export type UserStatus = "idle" | "searching" | "matched";
export type PactStatus = "active" | "broken" | "ended";
export type DayStatus = "pending" | "green" | "red";

export interface UserDoc {
  uid: string;
  username: string;
  usernameLower: string;
  email: string;
  emailVerified: boolean;
  avatarUrl: string | null;
  goalName: string;
  timezone: string;
  fcmTokens: string[];
  notificationsEnabled: boolean;
  status: UserStatus;
  currentPactId: string | null;
  reliability: number;
  totalCheckins: number;
  totalExpected: number;
  missedDays: number;
  totalPacts: number;
  longestStreak: number;
  streakSafe: boolean;
}

export interface MemberInfo {
  username: string;
  avatarUrl: string | null;
  goalName: string;
  reliability: number;
}

export interface PactDoc {
  id: string;
  members: string[];
  memberInfo: Record<string, MemberInfo>;
  status: PactStatus;
  streak: number;
  longestStreak: number;
  level: number;
  levelName: string;
  timezone: string;
  startDayKey: string;
  lastEvaluatedDay: string | null;
  daysTogether: number;
  brokenBy: string[];
}

export interface DayDoc {
  dayKey: string;
  pactId: string;
  members: string[];
  statuses: Record<string, DayStatus>;
  checkins: Record<string, { photoUrl: string; photoPath: string; submittedAt: Timestamp }>;
  resolved: boolean;
  streakAfter: number;
}

export interface QueueDoc {
  uid: string;
  goalName: string;
  timezone: string;
  reliability: number;
  status: "waiting";
  joinedAt: Timestamp;
}
