const express = require('express');
const admin = require('firebase-admin');
require('dotenv').config();
const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '64kb' }));
const PORT = Number(process.env.PORT || process.env.NOTIFICATION_PORT || 3001);
const WINDOW_MS = 60 * 1000;
const MAX_PER_MINUTE = 100;
const limits = new Map();
const TYPES = ['new_message','appointment','medication','lab_result','payment','order','promotional','system','health','social'];
const CHANNELS = {new_message:'sehatak_messages_v2',appointment:'sehatak_appointments_v1',medication:'sehatak_medications_v1',lab_result:'sehatak_labs_v1',payment:'sehatak_payments_v1',order:'sehatak_orders_v1',promotional:'sehatak_promotions_v1',system:'sehatak_system_v1',health:'sehatak_health_v1',social:'sehatak_social_v1'};
const HIGH = new Set(['new_message','appointment','payment','order','lab_result']);
const TTL = {new_message:3600000,appointment:86400000,medication:43200000,lab_result:604800000,payment:86400000,order:86400000,promotional:86400000,system:604800000,health:21600000,social:86400000};
let firebaseConfigured = false;
if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  try { admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)) }); firebaseConfigured = true; }
  catch (e) { console.error('Firebase init failed:', e.message); }
} else console.warn('FIREBASE_SERVICE_ACCOUNT_JSON is not configured');
const db = () => admin.firestore();
const messaging = () => admin.messaging();
function getBearer(req) { const h = req.get('authorization') || ''; return h.startsWith('Bearer ') ? h.slice(7).trim() : null; }
async function verifyUser(req) {
  if (!firebaseConfigured) throw Object.assign(new Error('Firebase authentication is not configured'), { statusCode: 503 });
  const token = getBearer(req);
  if (!token) throw Object.assign(new Error('Firebase ID token is required'), { statusCode: 401 });
  try { return await admin.auth().verifyIdToken(token); }
  catch (_) { throw Object.assign(new Error('Invalid or expired Firebase ID token'), { statusCode: 401 }); }
}
function checkLimit(uid, max = MAX_PER_MINUTE) {
  const now = Date.now(); const current = (limits.get(uid) || []).filter(t => now - t < WINDOW_MS);
  if (current.length >= max) return { allowed: false, retryAfter: Math.ceil((WINDOW_MS - (now - current[0])) / 1000) };
  current.push(now); limits.set(uid, current); return { allowed: true, remaining: max - current.length };
}
setInterval(() => { const now = Date.now(); for (const [uid, values] of limits.entries()) { const valid = values.filter(t => now - t < WINDOW_MS); if (valid.length) limits.set(uid, valid); else limits.delete(uid); } }, 300000).unref();
function stringData(data) { return Object.fromEntries(Object.entries(data || {}).map(([k,v]) => [k, String(v)])); }
function dndActive(p) { const s=Number(p?.dndStart), e=Number(p?.dndEnd); if(!Number.isInteger(s)||!Number.isInteger(e)||s===e||s<0||s>23||e<0||e>23)return false; const h=new Date().getHours(); return s<e ? h>=s&&h<e : h>=s||h<e; }
async function sendOne(input) {
  const { receiverId, type, subType, title, body, data = {}, skipPreferences = false, skipDnd = false } = input || {};
  if (!receiverId || !type || !title || !body) throw Object.assign(new Error('receiverId, type, title and body are required'), { code:'MISSING_FIELDS' });
  if (!TYPES.includes(type)) throw Object.assign(new Error(`Invalid notification type: ${type}`), { code:'INVALID_TYPE' });
  const snap = await db().collection('users').doc(String(receiverId)).get();
  if (!snap.exists) throw Object.assign(new Error('Receiver not found'), { code:'RECEIVER_NOT_FOUND' });
  const user = snap.data() || {}; const token = typeof user.fcmToken === 'string' ? user.fcmToken.trim() : '';
  if (!token) return { success:true, skipped:'fcm_token_missing', receiverId };
  const preferences = user.notificationPreferences || {};
  if (!skipPreferences && preferences[type] === false) return { success:true, skipped:'user_disabled', receiverId };
  if (!skipPreferences && !skipDnd && dndActive(preferences) && type !== 'new_message') return { success:true, skipped:'dnd_active', receiverId };
  const high = HIGH.has(type);
  const message = { token, data:{ type, subType:subType||'', title:String(title), body:String(body), channelId:CHANNELS[type], ...stringData(data), timestamp:String(Date.now()) }, android:{ priority:high?'high':'normal', ttl:TTL[type]||86400000, ...(type==='new_message'&&data.chatId?{collapseKey:`chat_${data.chatId}`}:{}) }, apns:{ headers:{'apns-priority':high?'10':'5','apns-push-type':'alert'}, payload:{aps:{alert:{title:String(title),body:String(body)},badge:1,'content-available':1,'thread-id':String(data.chatId||data.orderId||type)}}} };
  try { return { success:true, sent:true, messageId:await messaging().send(message), receiverId, type }; }
  catch (e) { if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(e.code)) await db().collection('users').doc(String(receiverId)).set({fcmToken:null,lastTokenUpdate:null},{merge:true}); throw Object.assign(new Error(e.message||'FCM send failed'),{code:e.code||'FCM_SEND_FAILED'}); }
}
async function logNotification(senderId,input,result,requestId) { try { await db().collection('notifications_log').add({senderId,receiverId:input?.receiverId||null,type:input?.type||null,subType:input?.subType||null,title:input?.title||null,body:input?.body||null,data:input?.data||{},result,requestId,createdAt:admin.firestore.FieldValue.serverTimestamp()}); } catch(e) { console.warn('Notification log failed:',e.message); } }
app.get('/health', (_req,res) => res.json({status:'ok',service:'sehatak-notification-server',firebaseAuth:firebaseConfigured?'configured':'not_configured',uptime:process.uptime()}));
app.get('/notification/health', (_req,res) => res.json({status:'ok',service:'sehatak-notification-server',firebaseAuth:firebaseConfigured?'configured':'not_configured',uptime:process.uptime(),supportedTypes:TYPES}));
app.post('/notification', async (req,res) => { const id=`notify-${Date.now()}-${Math.random().toString(36).slice(2,8)}`; try { const user=await verifyUser(req); const rl=checkLimit(user.uid); if(!rl.allowed)return res.status(429).json({success:false,code:'RATE_LIMIT',retryAfter:rl.retryAfter,requestId:id}); const result=await sendOne(req.body||{}); await logNotification(user.uid,req.body||{},result,id); return res.json({...result,requestId:id,rateLimitRemaining:rl.remaining}); } catch(e) { const status=e.statusCode||({MISSING_FIELDS:400,INVALID_TYPE:400,RECEIVER_NOT_FOUND:404}[e.code]||500); return res.status(status).json({success:false,code:e.code||'UNKNOWN',error:e.message,requestId:id}); } });
app.post('/notification/batch', async (req,res) => { const id=`batch-${Date.now()}-${Math.random().toString(36).slice(2,8)}`; try { const user=await verifyUser(req); const rl=checkLimit(user.uid,20); if(!rl.allowed)return res.status(429).json({success:false,code:'RATE_LIMIT',retryAfter:rl.retryAfter,requestId:id}); const n=req.body?.notifications; if(!Array.isArray(n)||!n.length)return res.status(400).json({success:false,code:'INVALID_DATA',requestId:id}); if(n.length>100)return res.status(400).json({success:false,code:'BATCH_TOO_LARGE',requestId:id}); const results=await Promise.allSettled(n.map(sendOne)); const succeeded=[],failed=[]; results.forEach((r,i)=>r.status==='fulfilled'?succeeded.push({index:i,...r.value}):failed.push({index:i,receiverId:n[i]?.receiverId,error:r.reason?.message,code:r.reason?.code})); for(let i=0;i<n.length;i++) await logNotification(user.uid,n[i],results[i].status==='fulfilled'?results[i].value:{success:false,error:results[i].reason?.message},id); return res.json({success:failed.length===0,requestId:id,total:n.length,succeeded:succeeded.length,failed:failed.length,results:{succeeded,failed}}); } catch(e) { return res.status(e.statusCode||500).json({success:false,code:e.code||'UNKNOWN',error:e.message,requestId:id}); } });
app.post('/notification/topic', async (req,res) => { try { const user=await verifyUser(req); const rl=checkLimit(user.uid,20); if(!rl.allowed)return res.status(429).json({success:false,code:'RATE_LIMIT'}); const snap=await db().collection('users').doc(user.uid).get(); if(!['admin','supervisor'].includes(snap.data()?.role))return res.status(403).json({success:false,code:'FORBIDDEN'}); const {topic,type='system',title,body,data={}}=req.body||{}; if(!topic||!title||!body)return res.status(400).json({success:false,code:'MISSING_FIELDS'}); if(!TYPES.includes(type))return res.status(400).json({success:false,code:'INVALID_TYPE'}); const messageId=await messaging().send({topic:String(topic),data:{type,title:String(title),body:String(body),...stringData(data),timestamp:String(Date.now())},android:{priority:'normal',ttl:86400000}}); return res.json({success:true,messageId,topic}); } catch(e) { return res.status(e.statusCode||500).json({success:false,code:e.code||'UNKNOWN',error:e.message}); } });
app.post('/notification/test', async (req,res) => { if(process.env.NODE_ENV==='production')return res.status(403).json({success:false,code:'DISABLED_IN_PRODUCTION'}); try { const {fcmToken,type='system',title,body,data={}}=req.body||{}; if(!fcmToken||!title||!body)return res.status(400).json({success:false,code:'MISSING_FIELDS'}); const messageId=await messaging().send({token:String(fcmToken),data:{type,title:String(title),body:String(body),...stringData(data)},android:{priority:'high',ttl:3600000}}); return res.json({success:true,messageId}); } catch(e) { return res.status(500).json({success:false,code:e.code||'FCM_SEND_FAILED',error:e.message}); } });
app.use((error,_req,res,_next)=>res.status(400).json({success:false,code:'BAD_REQUEST',error:error.message}));
app.listen(PORT,'0.0.0.0',()=>console.log(`Sehatak Notification Server listening on ${PORT}`));
module.exports=app;
