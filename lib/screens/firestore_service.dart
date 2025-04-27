import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== Appointment Functions ====================

  Future<void> bookAppointment(
      String clientId, String doctorId, String appointmentType) async {
    String appointmentId =
        "appt_${doctorId}_${clientId}_${DateTime.now().millisecondsSinceEpoch}";

    await _firestore.collection("appointments").doc(appointmentId).set({
      "appointment_id": appointmentId,
      "client_id": clientId,
      "doctor_id": doctorId,
      "status": "pending",
      "date_time": Timestamp.now(),
      "appointment_type": appointmentType,
    });
  }

  Future<void> updateAppointmentStatus(
      String appointmentId, String status) async {
    await _firestore
        .collection("appointments")
        .doc(appointmentId)
        .update({"status": status});
  }

  Stream<QuerySnapshot> getAppointmentsForDoctor(String doctorId) {
    return _firestore
        .collection("appointments")
        .where("doctor_id", isEqualTo: doctorId)
        .orderBy("date_time", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAppointmentsForClient(String clientId) {
    return _firestore
        .collection("appointments")
        .where("client_id", isEqualTo: clientId)
        .orderBy("date_time", descending: true)
        .snapshots();
  }

  // ==================== Prescription Functions ====================

  Future<void> addPrescription(String doctorId, String patientId,
      List<Map<String, String>> medications, String notes) async {
    try {
      print(
          "Starting to create prescription for doctor: $doctorId, patient: $patientId");

      // Fetch doctor and patient names
      String doctorName = "Unknown Doctor";
      String patientName = "Unknown Patient";

      try {
        DocumentSnapshot doctorDoc =
            await _firestore.collection("doctors").doc(doctorId).get();

        if (doctorDoc.exists) {
          Map<String, dynamic> doctorData =
              doctorDoc.data() as Map<String, dynamic>;
          doctorName = doctorData['name']?.toString() ?? "Unknown Doctor";
          print("Found doctor name: $doctorName");
        } else {
          print("Doctor document does not exist for ID: $doctorId");
        }
      } catch (doctorError) {
        print("Error fetching doctor data: $doctorError");
        // Continue with default doctor name
      }

      try {
        DocumentSnapshot patientDoc =
            await _firestore.collection("clients").doc(patientId).get();

        if (patientDoc.exists) {
          Map<String, dynamic> patientData =
              patientDoc.data() as Map<String, dynamic>;
          patientName = patientData['name']?.toString() ?? "Unknown Patient";
          print("Found patient name: $patientName");
        } else {
          print("Patient document does not exist for ID: $patientId");
        }
      } catch (patientError) {
        print("Error fetching patient data: $patientError");
        // Continue with default patient name
      }

      String? relatedId;

      // Try to find a related appointment, but don't require it
      try {
        QuerySnapshot appointmentSnapshot = await _firestore
            .collection("appointments")
            .where("doctor_id", isEqualTo: doctorId)
            .where("client_id", isEqualTo: patientId)
            .orderBy("date_time", descending: true)
            .limit(1)
            .get();

        if (appointmentSnapshot.docs.isNotEmpty) {
          relatedId = appointmentSnapshot.docs.first.id;
          print("Found related appointment ID: $relatedId");
        } else {
          print("No related appointment found between doctor and patient");
        }
      } catch (e) {
        print("Error finding related appointment, continuing anyway: $e");
        // Just continue without a related ID
      }

      // Generate a unique prescription ID
      String prescriptionId =
          "presc_${doctorId}_${patientId}_${DateTime.now().millisecondsSinceEpoch}";
      print("Generated prescription ID: $prescriptionId");

      // Convert medications to the right format
      List<Map<String, dynamic>> medicationsList = [];
      try {
        medicationsList = medications
            .map((med) => {
                  'name': med['name'] ?? '',
                  'dosage': med['dosage'] ?? '',
                  'frequency': med['frequency'] ?? '',
                })
            .toList();
        print("Processed ${medicationsList.length} medications");
      } catch (medError) {
        print("Error processing medications: $medError");
        // Use empty list if medication processing fails
      }

      // Create the prescription document
      Map<String, dynamic> prescriptionData = {
        'prescription_id': prescriptionId,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'patient_id': patientId,
        'patient_name': patientName,
        'date': Timestamp.now(),
        'medications': medicationsList,
        'additional_notes': notes,
      };

      // Only add related_id if it exists
      if (relatedId != null) {
        prescriptionData['related_id'] = relatedId;
      }

      print("Saving prescription data: ${prescriptionData.toString()}");
      await _firestore
          .collection('prescriptions')
          .doc(prescriptionId)
          .set(prescriptionData);
      print("Prescription saved successfully to Firestore");

      // Send notification to patient
      try {
        await _firestore.collection('notifications').add({
          'client_id': patientId,
          'title': 'New Prescription',
          'message': 'Dr. $doctorName has added a new prescription for you.',
          'timestamp': FieldValue.serverTimestamp(),
          'doctorId': doctorId,
          'status': 'unread',
        });
        print("Notification sent successfully");
      } catch (notifError) {
        print("Error sending notification: $notifError");
        // Continue even if notification fails
      }

      print("Prescription process completed successfully");
    } catch (e) {
      print("CRITICAL ERROR in addPrescription: $e");
      throw e; // Re-throw to allow the calling code to handle the error
    }
  }

  Stream<QuerySnapshot> getPrescriptionsForPatient(String patientId) {
    return _firestore
        .collection('prescriptions')
        .where('patient_id', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deletePrescription(String prescriptionId) async {
    await _firestore.collection('prescriptions').doc(prescriptionId).delete();
  }

  // ==================== Get Patients for Doctor ====================
  Future<List<Map<String, dynamic>>> getPatientsForDoctor(
      String doctorId) async {
    Set<String> patientIds = {};

    // ✅ Fetch patients from Approved Appointments
    QuerySnapshot appointmentSnapshot = await _firestore
        .collection('appointments')
        .where('doctor_id', isEqualTo: doctorId)
        .where('status', isEqualTo: "accepted")
        .get();

    for (var doc in appointmentSnapshot.docs) {
      patientIds.add(doc['client_id'] as String);
    }

    // ✅ Fetch patients from Prescriptions
    QuerySnapshot prescriptionSnapshot = await _firestore
        .collection('prescriptions')
        .where('doctor_id', isEqualTo: doctorId)
        .get();

    for (var doc in prescriptionSnapshot.docs) {
      patientIds.add(doc['patient_id'] as String);
    }

    // ✅ Fetch patients from MRI Uploads
    QuerySnapshot mriSnapshot = await _firestore
        .collection('mri_uploads')
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
      List<String> batch = patientIdList.sublist(
          i, i + 10 > patientIdList.length ? patientIdList.length : i + 10);
      QuerySnapshot patientSnapshot = await _firestore
          .collection('clients')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      patients.addAll(patientSnapshot.docs
          .map((doc) => {"id": doc.id, "name": doc['name'] ?? "Unknown"})
          .toList());
    }

    return patients;
  }

  // ==================== Notification Functions ====================

  Future<void> sendNotification(
      String recipientId, String title, String message) async {
    String notificationId = "notif_${DateTime.now().millisecondsSinceEpoch}";

    await _firestore
        .collection("notifications")
        .doc(recipientId)
        .collection("user_notifications")
        .doc(notificationId)
        .set({
      "notification_id": notificationId,
      "title": title,
      "message": message,
      "timestamp": Timestamp.now(),
      "is_read": false, // Mark unread by default
    });
  }

  Stream<QuerySnapshot> getUnreadNotifications(String userId) {
    return _firestore
        .collection("notifications")
        .doc(userId)
        .collection("user_notifications")
        .where("is_read", isEqualTo: false)
        .snapshots();
  }

  Future<void> markNotificationsAsRead(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection("notifications")
        .doc(userId)
        .collection("user_notifications")
        .where("is_read", isEqualTo: false)
        .get();

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
