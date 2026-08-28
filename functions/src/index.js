import { getApps, initializeApp } from 'firebase-admin/app';
import { logger } from 'firebase-functions';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { deleteCurrentAccountHandler } from './account.js';
import { solveQuestionWithAiHandler } from './ai_solver.js';
import { authorizeAudioLessonHandler } from './audio_access.js';
import {
  getBillingCatalogHandler,
  getMyBillingStatusHandler,
  verifyGooglePlayPurchaseHandler,
} from './billing.js';
import { runDailyDigest, runStudyReminders } from './jobs/smart_reminders.js';

if (getApps().length === 0) {
  initializeApp();
}

setGlobalOptions({
  region: 'europe-west1',
  maxInstances: 10,
  memory: '256MiB',
  timeoutSeconds: 120,
});

export const sendStudyReminders = onSchedule(
  {
    schedule: '0 * * * *',
    timeZone: 'Europe/Istanbul',
    retryCount: 1,
  },
  async () => {
    logger.info('sendStudyReminders started');
    await runStudyReminders();
  },
);

export const sendDailyReminderDigest = onSchedule(
  {
    schedule: '0 19 * * *',
    timeZone: 'Europe/Istanbul',
    retryCount: 1,
  },
  async () => {
    logger.info('sendDailyReminderDigest started');
    await runDailyDigest();
  },
);

export const deleteCurrentAccount = deleteCurrentAccountHandler;
export const solveQuestionWithAi = solveQuestionWithAiHandler;
export const authorizeAudioLesson = authorizeAudioLessonHandler;

export const getBillingCatalog = getBillingCatalogHandler;
export const getMyBillingStatus = getMyBillingStatusHandler;
export const verifyGooglePlayPurchase = verifyGooglePlayPurchaseHandler;