import { initializeApp } from 'firebase-admin/app';
import { makeRequestCreated } from './triggers/request_created';
import { makeRequestUpdated } from './triggers/request_updated';
import { makeMessageCreated } from './triggers/message_created';
import { makeRatingCreated } from './triggers/rating_created';
import { makeDeleteAccount } from './callable/delete_account';

initializeApp();

export const requestCreatedDefault = makeRequestCreated('(default)');
export const requestCreatedStage = makeRequestCreated('stage');
export const requestUpdatedDefault = makeRequestUpdated('(default)');
export const requestUpdatedStage = makeRequestUpdated('stage');
export const messageCreatedDefault = makeMessageCreated('(default)');
export const messageCreatedStage = makeMessageCreated('stage');
export const ratingCreatedDefault = makeRatingCreated('(default)');
export const ratingCreatedStage = makeRatingCreated('stage');
export const deleteAccount = makeDeleteAccount();
