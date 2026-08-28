import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { sendUserNotification } from '../services/notification_sender.js';

function db() {
  return getFirestore();
}
const TIME_ZONE = 'Europe/Istanbul';
const TURKISH_DAYS = [
  'Pazar',
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
];

function localParts(date = new Date()) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
    weekday: 'short',
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(date).map((part) => [part.type, part.value]),
  );

  const weekdayMap = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  };

  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    weekday: weekdayMap[parts.weekday],
  };
}

function dateKey(parts) {
  return `${parts.year}-${String(parts.month).padStart(2, '0')}-${String(parts.day).padStart(2, '0')}`;
}

function addDaysLocal(parts, days) {
  // Europe/Istanbul yıl boyu UTC+3. Bu uygulamanın mevcut ana pazarı için
  // tarih sınırlarını deterministik tutuyoruz. Kullanıcı timezone desteği
  // geldiğinde bu helper kullanıcı profiline taşınacak.
  const utc = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days, 12));
  return localParts(utc);
}

function startOfLocalDay(parts) {
  return Timestamp.fromDate(
    new Date(Date.UTC(parts.year, parts.month - 1, parts.day, -3, 0, 0)),
  );
}

function endOfLocalDay(parts) {
  return Timestamp.fromDate(
    new Date(Date.UTC(parts.year, parts.month - 1, parts.day + 1, -3, 0, 0)),
  );
}

function uidFromCollectionGroupDoc(doc) {
  // users/{uid}/{collection}/{docId}
  return doc.ref.parent.parent?.id ?? null;
}

export async function runStudyReminders() {
  const now = localParts();
  const dayName = TURKISH_DAYS[now.weekday];

  const snapshot = await db()
    .collectionGroup('dersProgram')
    .where('dersProgramGun', '==', dayName)
    .where('dersProgramSaat', '==', now.hour)
    .where('tamamlandi', '==', false)
    .get();

  logger.info('Study reminder candidates', {
    dayName,
    hour: now.hour,
    count: snapshot.size,
  });

  const jobs = snapshot.docs.map(async (doc) => {
    const uid = uidFromCollectionGroupDoc(doc);
    if (!uid) return;
    const item = doc.data();
    const lesson = (item.dersProgramDersAd ?? 'Ders').toString();
    const topic = (item.dersProgramKonuAd ?? '').toString().trim();
    const bucket = `${dateKey(now)}-${String(now.hour).padStart(2, '0')}`;

    return sendUserNotification({
      uid,
      type: 'study_reminder',
      title: `${lesson} çalışma zamanı 📚`,
      body: topic ? `${topic} konusu için planladığın saat geldi.` : 'Planladığın çalışma saati geldi.',
      route: '/dersprogrami',
      preferenceKey: 'studyReminders',
      sourceId: doc.id,
      dedupeKey: `study_${doc.id}_${bucket}`,
      data: { lesson, topic },
    });
  });

  await Promise.allSettled(jobs);
}

async function sendExamReminders(uid, tomorrow) {
  const snapshot = await db()
    .collection('users')
    .doc(uid)
    .collection('sinavTakvimi')
    .where('sinavZamani', '>=', startOfLocalDay(tomorrow))
    .where('sinavZamani', '<', endOfLocalDay(tomorrow))
    .get();

  return Promise.allSettled(
    snapshot.docs.map((doc) => {
      const exam = doc.data();
      const examType = (exam.sinavTur ?? 'Sınav').toString();
      return sendUserNotification({
        uid,
        type: 'exam_reminder',
        title: `Yarın ${examType} sınavın var 📝`,
        body: 'Sınav takvimini ve bugünkü tekrar planını kontrol etmeyi unutma.',
        route: '/dersprogrami',
        preferenceKey: 'examReminders',
        sourceId: doc.id,
        dedupeKey: `exam_${doc.id}_${dateKey(tomorrow)}`,
      });
    }),
  );
}

async function sendGoalReminders(uid, today) {
  const snapshot = await db()
    .collection('users')
    .doc(uid)
    .collection('hedefler')
    .where('tamamlandi', '==', false)
    .get();

  const candidates = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const targetDate = data.hedefTarihi?.toDate?.();
    if (!targetDate) return false;
    const local = localParts(targetDate);
    return dateKey(local) === dateKey(today);
  });

  return Promise.allSettled(
    candidates.map((doc) => {
      const goal = doc.data();
      const name = (goal.hedefAd ?? 'Bugünkü hedefin').toString();
      return sendUserNotification({
        uid,
        type: 'goal_reminder',
        title: 'Bugünkü hedefin henüz tamamlanmadı 🎯',
        body: name,
        route: '/hedefler',
        preferenceKey: 'goalReminders',
        sourceId: doc.id,
        dedupeKey: `goal_${doc.id}_${dateKey(today)}`,
      });
    }),
  );
}

async function createAndSendWeeklyReport(uid, today) {
  if (today.weekday !== 0) return;

  const weekStart = addDaysLocal(today, -6);
  const start = startOfLocalDay(weekStart);
  const end = endOfLocalDay(today);

  const [questions, exams, completedGoals] = await Promise.all([
    db().collection('users').doc(uid).collection('sorular')
      .where('createdAt', '>=', start).where('createdAt', '<', end).get(),
    db().collection('users').doc(uid).collection('sinavlar')
      .where('createdAt', '>=', start).where('createdAt', '<', end).get(),
    db().collection('users').doc(uid).collection('hedefler')
      .where('tamamlandi', '==', true)
      .where('updatedAt', '>=', start).where('updatedAt', '<', end).get(),
  ]);

  const reportKey = `${dateKey(weekStart)}_${dateKey(today)}`;
  const reportRef = db()
    .collection('users')
    .doc(uid)
    .collection('weeklyReports')
    .doc(reportKey);

  await reportRef.set({
    periodStart: start,
    periodEnd: end,
    questionCount: questions.size,
    examCount: exams.size,
    completedGoalCount: completedGoals.size,
    generatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return sendUserNotification({
    uid,
    type: 'weekly_report',
    title: 'Haftalık Çalış 360 raporun hazır 📊',
    body: `${questions.size} soru, ${exams.size} deneme/sınav ve ${completedGoals.size} tamamlanan hedef.`,
    route: '/home',
    preferenceKey: 'weeklyReports',
    sourceId: reportKey,
    dedupeKey: `weekly_${reportKey}`,
  });
}

export async function runDailyDigest() {
  const today = localParts();
  const tomorrow = addDaysLocal(today, 1);
  const users = await db().collection('users').select().get();

  logger.info('Daily notification digest started', {
    users: users.size,
    date: dateKey(today),
  });

  for (const userDoc of users.docs) {
    const uid = userDoc.id;
    await Promise.allSettled([
      sendExamReminders(uid, tomorrow),
      sendGoalReminders(uid, today),
      createAndSendWeeklyReport(uid, today),
    ]);
  }
}
