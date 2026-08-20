import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../services/firebase_service.dart';

class CheckInResult {
  const CheckInResult({required this.streak, required this.bothGreen});
  final int streak;
  final bool bothGreen;
}

class CheckInRepository {
  const CheckInRepository(this._storage, this._fn);

  final FirebaseStorage _storage;
  final FirebaseFunctions _fn;

  /// Camera frames are 3-4 MB. Proof only needs to be recognisable, and a
  /// 1080px JPEG uploads on bad rural data in a couple of seconds.
  Future<Uint8List> _compress(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > decoded.height
        ? img.copyResize(decoded, width: 1080)
        : img.copyResize(decoded, height: 1080);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  /// Upload proof, then let the server decide what it means. The path is
  /// write-once in Storage rules, so yesterday's proof can never be replaced.
  Future<CheckInResult> submit({
    required String pactId,
    required String dayKey,
    required String uid,
    required File photo,
  }) async {
    final path = Paths.proofPath(pactId, dayKey, uid);
    final ref = _storage.ref(path);
    final data = await _compress(photo);

    await ref.putData(
      data,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'pactId': pactId, 'dayKey': dayKey},
      ),
    );
    final url = await ref.getDownloadURL();

    final res = await _fn.httpsCallable('submitCheckIn').call<Map<String, dynamic>>({
      'pactId': pactId,
      'photoUrl': url,
      'photoPath': path,
    });

    return CheckInResult(
      streak: (res.data['streak'] as num? ?? 0).toInt(),
      bothGreen: res.data['bothGreen'] == true,
    );
  }
}

final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => CheckInRepository(ref.watch(storageProvider), ref.watch(functionsProvider)),
);
