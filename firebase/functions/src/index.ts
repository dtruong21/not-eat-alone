import { initializeApp } from 'firebase-admin/app';
import { makeRequestCreated } from './triggers/request_created';
import { makeRequestUpdated } from './triggers/request_updated';
import { makeMessageCreated } from './triggers/message_created';

initializeApp();

export const requestCreatedDefault = makeRequestCreated('(default)');
export const requestCreatedStage = makeRequestCreated('stage');
export const requestUpdatedDefault = makeRequestUpdated('(default)');
export const requestUpdatedStage = makeRequestUpdated('stage');
export const messageCreatedDefault = makeMessageCreated('(default)');
export const messageCreatedStage = makeMessageCreated('stage');
