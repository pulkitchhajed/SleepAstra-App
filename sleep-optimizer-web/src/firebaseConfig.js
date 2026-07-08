import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyC1CpT15JA-qVrV1BLqi98g5rMoP6MA3HY",
  authDomain: "snoreclinics-ai.firebaseapp.com",
  projectId: "snoreclinics-ai",
  storageBucket: "snoreclinics-ai.firebasestorage.app",
  messagingSenderId: "840529050371",
  appId: "1:840529050371:web:a7eed996b70ee998b84736"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
