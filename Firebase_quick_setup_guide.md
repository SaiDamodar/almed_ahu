# Firebase Quick Setup Guide

## Step 1: Create Firebase Project

Go to https://console.firebase.google.com/ → "Add project" → Enter project name → Click "Continue"

---

## Step 2: Enable Google Analytics

Choose whether to enable → Select analytics account → Click "Create project"

---

## Step 3: Add Firebase to Your App

Click "Add app" → Choose platform (Web/Android/iOS) → Register app → **Copy config**

---

## Step 4: Get Firebase Config

Copy your Firebase config object containing:
- apiKey
- authDomain
- projectId
- storageBucket
- messagingSenderId
- appId

---

## Step 5: Enable Authentication

Go to Authentication → "Get started" → Add sign-in method → Enable "Email/Password" → Save

---

## Step 6: Create Firestore Database

Go to Firestore Database → "Create database" → Start in "Test mode" → Choose location → Enable

---

## Step 7: Install Firebase SDK

```bash
npm install firebase
```

Or for Python:
```bash
pip install firebase-admin
```

---

## Step 8: Initialize Firebase

```javascript
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
```

---

## Step 9: Write Data to Firestore

```javascript
import { collection, addDoc } from 'firebase/firestore';

await addDoc(collection(db, 'ahu_telemetry'), {
  device: 'ahu-01',
  temperature: 24.5,
  humidity: 60,
  timestamp: new Date()
});
```

---

## Step 10: Read Data from Firestore

```javascript
import { collection, getDocs } from 'firebase/firestore';

const querySnapshot = await getDocs(collection(db, 'ahu_telemetry'));
querySnapshot.forEach((doc) => {
  console.log(doc.data());
});
```

---

## Step 11: Set Up Security Rules

Go to Firestore → Rules → Update rules to allow read/write → Publish

---

## Step 12: Test Connection

Write and read sample data to verify everything works

---

## Done!

Your Firebase is ready to store AHU data and authenticate users.

