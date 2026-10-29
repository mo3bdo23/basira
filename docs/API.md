# نموذج البيانات — Firestore

> التطبيق يعمل بالكامل محليًا (Hive). هذه المجموعات تُستخدم فقط عند تفعيل Firebase.

## users/{uid}
```json
{
  "name": "سارة أحمد",
  "role": "blind | low_vision | volunteer | university_admin | admin",
  "phone": "+2010...",
  "universityId": "menoufia_university",
  "createdAt": "2026-10-29T10:00:00Z",
  "updatedAt": "2026-10-29T10:00:00Z",
  "sos_contacts": [{ "name": "أبي", "phone": "+2010...", "relation": "أب" }]
}
```

## obstacles/{obstacleId}
```json
{
  "type": "stairs | hole | construction | parked_car | blocked_sidewalk | slippery | crowd | broken_signal | other",
  "description": "سلالم بدون درابزين",
  "location": { "lat": 30.5444, "lng": 31.0122 },
  "severity": 1,
  "status": "pending | verified | resolved | rejected",
  "reporterId": "uid",
  "createdAt": "2026-10-29T10:00:00Z"
}
```
التحقق: `verificationCount ≥ 3` → `verified` · `disputeCount ≥ 3` → `rejected`.

## routes/{routeId}
```json
{
  "name": "شارع الجيش → الجامعة",
  "city": "شبين الكوم",
  "safetyScore": 5,
  "estimatedMinutes": 14,
  "points": [[30.5535, 31.0062], [30.5520, 31.0068]],
  "landmarks": ["", "ممشى مظلل", "إشارة مرور"],
  "tags": ["ممشى", "مظلل"]
}
```

## traffic_signals/{signalId}
```json
{
  "name": "إشارة ميدان شبين الكوم",
  "lat": 30.5563,
  "lng": 31.0120,
  "hasAudio": true,
  "greenSeconds": 25,
  "redSeconds": 35,
  "updatedAt": "2026-10-29T10:00:00Z"
}
```

## universities/{uniId}
```json
{
  "name": "جامعة المنوفية — شبين الكوم",
  "shortName": "جامعة المنوفية",
  "city": "شبين الكوم",
  "lat": 30.5460,
  "lng": 31.0120,
  "buildings": [
    {
      "id": "mu_library",
      "name": "المكتبة المركزية",
      "lat": 30.5455,
      "lng": 31.0115,
      "category": "library",
      "description": "...",
      "entranceNote": "...",
      "audioGuide": ["...", "..."]
    }
  ]
}
```

## sos_contacts/{contactId}
```json
{ "ownerId": "uid", "name": "منى", "phone": "+2010...", "relation": "أخت", "isPrimary": true }
```

## settings/{uid}
```json
{ "speechRate": 0.45, "verbosity": "normal", "haptics": true, "highContrast": false }
```

## القواعد

انظر [`firebase/firestore.rules`](../firebase/firestore.rules). المبدأ:
قراءة عامة للبيانات المجتمعية، وكتابة مقيدة بالمالك أو الدور.
