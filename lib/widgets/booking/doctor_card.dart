import 'package:flutter/material.dart';

class DoctorCard extends StatelessWidget {
  final String doctorName;
  final String specialization;
  final VoidCallback onBook;

  const DoctorCard({
    Key? key,
    required this.doctorName,
    required this.specialization,
    required this.onBook,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(doctorName),
        subtitle: Text(specialization),
        trailing: ElevatedButton(
          onPressed: onBook,
          child: const Text("Book"),
        ),
      ),
    );
  }
}
