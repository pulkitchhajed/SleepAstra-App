import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/blog_model.dart';

class BlogService {
  static final _db = FirebaseFirestore.instance;
  static final _blogsCol = _db.collection('blogs');

  // ─── Firestore CRUD ───────────────────────────────────────────────────────

  /// Saves a new blog document to the `blogs` collection.
  static Future<void> saveBlog({
    required String title,
    required String content,
    required String summary,
    required String coverImageUrl,
    required String category,
    required String author,
    required int readTimeMinutes,
    List<String> tags = const [],
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final id = const Uuid().v4();
      await _blogsCol.doc(id).set({
        'title': title,
        'content': content,
        'summary': summary,
        'coverImageUrl': coverImageUrl,
        'category': category,
        'author': author,
        'readTimeMinutes': readTimeMinutes,
        'tags': tags,
        'uploadedBy': uid,
        'likes': [],
        'bookmarks': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[BlogService] saveBlog error: $e');
      rethrow;
    }
  }

  /// Updates an existing blog document.
  static Future<void> updateBlog({
    required String id,
    required String title,
    required String content,
    required String summary,
    required String coverImageUrl,
    required String category,
    required String author,
    required int readTimeMinutes,
    List<String> tags = const [],
  }) async {
    try {
      await _blogsCol.doc(id).update({
        'title': title,
        'content': content,
        'summary': summary,
        'coverImageUrl': coverImageUrl,
        'category': category,
        'author': author,
        'readTimeMinutes': readTimeMinutes,
        'tags': tags,
      });
    } catch (e) {
      debugPrint('[BlogService] updateBlog error: $e');
      rethrow;
    }
  }

  /// Toggles a reaction (likes or bookmarks) for the current user.
  static Future<void> toggleReaction(String blogId, String field) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _blogsCol.doc(blogId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final list = List<String>.from(data[field] as List? ?? []);

      if (list.contains(uid)) {
        await docRef.update({field: FieldValue.arrayRemove([uid])});
      } else {
        await docRef.update({field: FieldValue.arrayUnion([uid])});
      }
    } catch (e) {
      debugPrint('[BlogService] toggleReaction error: $e');
    }
  }

  /// Fetches all blogs, newest first.
  static Stream<List<BlogModel>> watchBlogs() {
    return _blogsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BlogModel.fromJson(d.id, d.data()))
            .toList());
  }

  /// Deletes a blog document from Firestore.
  static Future<void> deleteBlog(String id) async {
    try {
      await _blogsCol.doc(id).delete();
    } catch (e) {
      debugPrint('[BlogService] deleteBlog error: $e');
      rethrow;
    }
  }

  /// Seeds demo blog posts if the collection is empty.
  /// Call this once after user login.
  static Future<void> seedDemoBlogs() async {
    try {
      final snap = await _blogsCol.limit(1).get();
      if (snap.docs.isNotEmpty) return; // Already has content

      final now = DateTime.now();
      final demos = [
        {
          'id': 'demo-blog-1',
          'title': '7 Science-Backed Tips for Deeper Sleep Tonight',
          'summary': 'Discover evidence-based techniques that can help you fall asleep faster and wake up feeling truly rested.',
          'content': '''## Sleep Better Starting Tonight

Getting quality sleep doesn't have to be a mystery. Here are seven techniques backed by sleep science:

### 1. Keep a Consistent Sleep Schedule
Go to bed and wake up at the same time every day — even on weekends. This anchors your circadian rhythm.

### 2. Cool Your Bedroom
The ideal sleep temperature is **65–68°F (18–20°C)**. A cooler room signals your brain that it's time to sleep.

### 3. Limit Blue Light Before Bed
Screens emit blue light that suppresses melatonin production. Try wearing blue-light-blocking glasses or enabling night mode 2 hours before bed.

### 4. Try the 4-7-8 Breathing Method
- Inhale for **4 seconds**
- Hold for **7 seconds**
- Exhale for **8 seconds**

This activates your parasympathetic nervous system, reducing anxiety and heart rate.

### 5. Avoid Caffeine After 2 PM
Caffeine has a half-life of about 5–6 hours. An afternoon coffee can still be in your system at midnight.

### 6. Exercise — But Not Too Late
Regular exercise improves sleep quality, but vigorous workouts within 3 hours of bedtime can delay sleep onset.

### 7. Keep a Gratitude Journal
Writing down 3 things you're grateful for before bed reduces cortisol and shifts your brain away from stress.

*Track your sleep improvements with the Sleep Astra app and see the difference these habits make.*''',
          'coverImageUrl': '',
          'category': 'Sleep Tips',
          'author': 'Sleep Astra Team',
          'readTimeMinutes': 5,
          'tags': ['sleep', 'wellness', 'tips'],
          'uploadedBy': 'system',
          'likes': [],
          'bookmarks': [],
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        },
        {
          'id': 'demo-blog-2',
          'title': 'Understanding Sleep Apnea: What You Need to Know',
          'summary': 'Sleep apnea affects millions worldwide. Learn the signs, risks, and how to get the help you need.',
          'content': '''## What is Sleep Apnea?

Sleep apnea is a condition where your breathing repeatedly stops and starts during sleep. It affects over **936 million adults** worldwide.

### The Three Types

**1. Obstructive Sleep Apnea (OSA)** — The most common form. Throat muscles relax and block the airway.

**2. Central Sleep Apnea** — The brain doesn't send proper signals to the breathing muscles.

**3. Complex Sleep Apnea Syndrome** — A combination of both.

### Warning Signs

- Loud, persistent snoring
- Gasping or choking during sleep
- Waking up with a dry mouth or headache
- Excessive daytime sleepiness
- Difficulty concentrating

### Risk Factors

- Excess weight
- Being male (though it affects women too)
- Age (risk increases with age)
- Family history
- Alcohol and sedative use

### When to See a Doctor

If you or your partner notice any warning signs, speak to a healthcare professional. Untreated sleep apnea is linked to high blood pressure, type 2 diabetes, heart disease, and stroke.

### How the Sleep Astra App Can Help

Our AI-powered recording detects snoring patterns and potential apnea events overnight, giving you a detailed report to share with your doctor.

*Start your first recording tonight — it takes less than a minute to set up.*''',
          'coverImageUrl': '',
          'category': 'Research',
          'author': 'Dr. Sleep Expert',
          'readTimeMinutes': 7,
          'tags': ['sleep apnea', 'health', 'research'],
          'uploadedBy': 'system',
          'likes': [],
          'bookmarks': [],
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        },
        {
          'id': 'demo-blog-3',
          'title': 'My 30-Day Bedtime Routine Transformation',
          'summary': "One user's personal story of how building a simple bedtime routine transformed their sleep quality and energy levels.",
          'content': '''## My 30-Day Sleep Transformation

I used to pride myself on being a "night owl." Late nights scrolling, binge-watching, and convincing myself I'd catch up on sleep over the weekend. Sound familiar?

### Week 1: The Chaos

My Sleep Astra report was eye-opening. My sleep quality score was consistently below 50. I was having frequent snoring events and waking up exhausted.

I decided to try something radical: a bedtime routine.

### Week 2: Small Changes, Big Resistance

I started simple:
- No screens after 9:30 PM
- Herbal tea at 9:45 PM
- 10 minutes of light stretching
- In bed by 10:30 PM

**Was it easy?** Absolutely not. By day 5, I was restless and checking my phone out of habit.

### Week 3: The Turning Point

Something shifted around day 14. I started *craving* the routine. My body began associating the herbal tea with sleepiness. I was falling asleep within 15 minutes instead of 45.

My sleep score jumped to 68.

### Week 4: A New Normal

By the end of the month:
- Sleep score: **82 (Good Sleep)**
- Snoring events reduced by 40%
- I woke up before my alarm — naturally

### What Actually Worked

1. **Consistency over perfection** — Missing one night didn't derail me
2. **Analogue wind-down** — Reading a physical book beats any screen
3. **Tracking with Sleep Astra** — Seeing the data improve kept me motivated

*Your journey starts with one small change. What will yours be?*''',
          'coverImageUrl': '',
          'category': 'Stories',
          'author': 'Community Member',
          'readTimeMinutes': 6,
          'tags': ['story', 'routine', 'transformation'],
          'uploadedBy': 'system',
          'likes': [],
          'bookmarks': [],
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
        },
      ];

      final batch = _db.batch();
      for (final d in demos) {
        final id = d['id'] as String;
        final data = Map<String, dynamic>.from(d)..remove('id');
        batch.set(_blogsCol.doc(id), data);
      }
      await batch.commit();
      debugPrint('[BlogService] Seeded ${demos.length} demo blogs');
    } catch (e) {
      debugPrint('[BlogService] seedDemoBlogs error: $e');
    }
  }
}
