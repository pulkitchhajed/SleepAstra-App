import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyBsVx6A0UDuicrNRtuOaJylFgxNTg2QZHM",
  authDomain: "snoreastra.firebaseapp.com",
  projectId: "snoreastra",
  storageBucket: "snoreastra.firebasestorage.app",
  messagingSenderId: "469010978794",
  appId: "1:469010978794:web:a7f3582ae579b9fc1e0493",
  measurementId: "G-XYEFY2F675"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
