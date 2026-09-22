/// Generates a deterministic, non-negative 31-bit integer notification ID
/// from a UUID string using FNV-1a hashing.
int notificationIdForItem(String itemId) {
  var hash = 0x811C9DC5;
  for (final codeUnit in itemId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
