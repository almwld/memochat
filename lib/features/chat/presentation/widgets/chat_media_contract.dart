/// Canonical media types used by the Sehatak chat timeline.
/// Keep these values aligned with Firestore message `type`.
abstract final class ChatMediaType {
  static const text = 'text';
  static const image = 'image';
  static const video = 'video';
  static const audio = 'audio';
  static const file = 'file';
  static const location = 'location';
  static const call = 'call';
  static const system = 'system';
}
