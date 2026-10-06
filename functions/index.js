const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

require('./chat_notifications');
