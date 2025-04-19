import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== Appointment Functions ====================

  Future<void> bookAppointment(String clientId, String doctorId, String appointmentType) async {
    String appointmentId = "appt_${doctorId}_${clientId}_${DateTime.now().millisecondsSinceEpoch}";

    await _firestore.collection("appointments").doc(appointmentId).set({
      "appointment_id": appointmentId,
      "client_id": clientId,
      "doctor_id": doctorId,
      "status": "pending",
      "date_time": Timestamp.now(),
      "appointment_type": appointmentType,
    });
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _firestore.collection("appointments").doc(appointmentId).update({"status": status});
  }

  Stream<QuerySnapshot> getAppointmentsForDoctor(String doctorId) {
    return _firestore.collection("appointments")
        .where("doctor_id", isEqualTo: doctorId)
        .orderBy("date_time", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAppointmentsForClient(String clientId) {
    return _firestore.collection("appointments")
        .where("client_id", isEqualTo: clientId)
        .orderBy("date_time", descending: true)
        .snapshots();
  }

  // ==================== Prescription Functions ====================

  Future<void> addPrescription(String doctorId, String patientId, List<Map<String, String>> medications, String notes) async {
    String? relatedId;

    // Fetch latest approved appointment ID
    QuerySnapshot appointmentSnapshot = await _firestore.collection("appointments")
        .where("doctor_id", isEqualTo: doctorId)
        .where("client_id", isEqualTo: patientId)
        .where("status", isEqualTo: "accepted")
        .orderBy("date_time", descending: true)
        .limit(1)
        .get();

    if (appointmentSnapshot.docs.isNotEmpty) {
      relatedId = appointmentSnapshot.docs.first.id;
    } else {
      // Fetch latest MRI Upload ID
      QuerySnapshot mriSnapshot = await _firestore.collection("mri_uploads")
          .where("doctor_id", isEqualTo: doctorId)
          .where("patient_id", isEqualTo: patientId)
          .orderBy("upload_time", descending: true)
          .limit(1)
          .get();

      if (mriSnapshot.docs.isNotEmpty) {
        relatedId = mriSnapshot.docs.first.id;
      }
    }

    if (relatedId == null) {
      throw Exception("No valid appointment or MRI record found for prescription.");
    }

    // Generate a unique prescription ID
    String prescriptionId = "presc_${relatedId}_${DateTime.now().millisecondsSinceEpoch}";

    await _firestore.collection('prescriptions').doc(prescriptionId).set({
      'prescription_id': prescriptionId,
      'related_id': relatedId,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'date': Timestamp.now(),
      'medications': medications,
      'additional_notes': notes,
    });
  }

  Stream<QuerySnapshot> getPrescriptionsForPatient(String patientId) {
    return _firestore.collection('prescriptions')
        .where('patient_id', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deletePrescription(String prescriptionId) async {
    await _firestore.collection('prescriptions').doc(prescriptionId).delete();
  }

  // ==================== Get Patients for Doctor ====================
  Future<List<Map<String, dynamic>>> getPatientsForDoctor(String doctorId) async {
    Set<String> patientIds = {};

    // ✅ Fetch patients from Approved Appointments
    QuerySnapshot appointmentSnapshot = await _firestore.collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('status', isEqualTo: "accepted")
        .get();

    for (var doc in appointmentSnapshot.docs) {
      patientIds.add(doc['client_id'] as String);
    }

    // ✅ Fetch patients from Prescriptions
    QuerySnapshot prescriptionSnapshot = await _firestore.collection('prescriptions')
        .where('doctor_id', isEqualTo: doctorId)
        .get();

    for (var doc in prescriptionSnapshot.docs) {
      patientIds.add(doc['patient_id'] as String);
    }

    // ✅ Fetch patients from MRI Uploads
    QuerySnapshot mriSnapshot = await _firestore.collection('mri_uploads')
        .where('doctor_id', isEqualTo: doctorId)
        .get();

    for (var doc in mriSnapshot.docs) {
      patientIds.add(doc['patient_id'] as String);
    }

    if (patientIds.isEmpty) return [];

    // ✅ Fetch patient details from Firestore
    List<Map<String, dynamic>> patients = [];
    List<String> patientIdList = patientIds.toList();

    for (int i = 0; i < patientIdList.length; i += 10) {
      List<String> batch = patientIdList.sublist(i, i + 10 > patientIdList.length ? patientIdList.length : i + 10);
      QuerySnapshot patientSnapshot = await _firestore.collection('clients')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      patients.addAll(patientSnapshot.docs.map((doc) => {
        "id": doc.id,
        "name": doc['name'] ?? "Unknown"
      }).toList());
    }

    return patients;
  }

  // ==================== Notification Functions ====================

  Future<void> sendNotification(String recipientId, String title, String message) async {
    String notificationId = "notif_${DateTime.now().millisecondsSinceEpoch}";

    await _firestore.collection("notifications").doc(recipientId).collection("user_notifications").doc(notificationId).set({
      "notification_id": notificationId,
      "title": title,
      "message": message,
      "timestamp": Timestamp.now(),
      "is_read": false,  // Mark unread by default
    });
  }

  Stream<QuerySnapshot> getUnreadNotifications(String userId) {
    return _firestore.collection("notifications").doc(userId).collection("user_notifications")
        .where("is_read", isEqualTo: false)
        .snapshots();
  }

  Future<void> markNotificationsAsRead(String userId) async {
    QuerySnapshot snapshot = await _firestore.collection("notifications").doc(userId).collection("user_notifications")
        .where("is_read", isEqualTo: false).get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({"is_read": true});
    }
  }


  Future<void> createNotification(
      String userId, String title, String message) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .add({
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false, // New notifications are unread by default
      });
      print("Notification added successfully!");
    } catch (e) {
      print("Error adding notification: $e");
    }
  }


}
