import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getAuth } from "firebase-admin/auth";

if (getApps().length === 0) {
  initializeApp();
}

export const db = getFirestore();
export const messaging = getMessaging();
export const auth = getAuth();
export { FieldValue };

export const REGION = "us-central1";

export const col = {
  users: () => db.collection("users"),
  usernames: () => db.collection("usernames"),
  queue: () => db.collection("matchQueue"),
  pacts: () => db.collection("pacts"),
  days: (pactId: string) => db.collection("pacts").doc(pactId).collection("days"),
  checkins: (pactId: string) => db.collection("pacts").doc(pactId).collection("checkins"),
  events: (pactId: string) => db.collection("pacts").doc(pactId).collection("events"),
  history: (uid: string) => db.collection("users").doc(uid).collection("pactHistory"),
};
