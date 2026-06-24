/**
 * useFeedback — submission hook for in-app feedback.
 *
 * Skeleton only. Wire up the Firestore wrapper at `lib/firebase/feedback.ts`
 * via the `/firestore feedback uid:string category:string body:string` command
 * before this file compiles.
 */

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { track } from '@/lib/analytics/client';
// Generate this via `/firestore feedback ...`:
// import { createFeedback, type Feedback } from '@/lib/firebase/feedback';
// import { getAuth } from 'firebase/auth';
// import { Platform } from 'react-native';
// import Constants from 'expo-constants';

export type FeedbackCategory = 'bug' | 'idea' | 'praise' | 'other';

export type SubmitFeedbackInput = {
  category: FeedbackCategory;
  body: string;
  route: string;
};

export function useFeedback() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (_input: SubmitFeedbackInput) => {
      // const uid = getAuth().currentUser?.uid;
      // if (!uid) throw new Error('Must be signed in to submit feedback');
      //
      // const doc: Omit<Feedback, 'id' | 'created_at'> = {
      //   uid,
      //   category: input.category,
      //   body: input.body.trim(),
      //   app_version: Constants.expoConfig?.version ?? 'unknown',
      //   platform: Platform.OS as 'ios' | 'android' | 'web',
      //   route: input.route,
      // };
      //
      // return createFeedback(doc);
      throw new Error('useFeedback: wire lib/firebase/feedback.ts via /firestore first');
    },
    onSuccess: (_id, input) => {
      track('feedback_submitted', {
        category: input.category,
        length_chars: input.body.length,
      });
      queryClient.invalidateQueries({ queryKey: ['feedback'] });
    },
  });
}
