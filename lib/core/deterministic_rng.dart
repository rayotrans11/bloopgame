/// Deterministic Mulberry32 PRNG (Section 1.4)
/// Guarantees bit-exact identical pseudo-random stream across platforms & Dart versions
class DeterministicRng {
  int _state;

  DeterministicRng(int seed) : _state = seed & 0xFFFFFFFF;

  /// Returns unsigned 32-bit integer
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _state;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t ^= (t + ((t ^ (t >> 7)) * (t | 61))) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  /// Returns double in [0.0, 1.0)
  double nextDouble() {
    return (nextUint32() & 0xFFFFFF) / 16777216.0;
  }

  /// Returns int in [0, maxExclusive)
  int nextInt(int maxExclusive) {
    if (maxExclusive <= 1) return 0;
    return (nextDouble() * maxExclusive).floor().clamp(0, maxExclusive - 1);
  }
}
